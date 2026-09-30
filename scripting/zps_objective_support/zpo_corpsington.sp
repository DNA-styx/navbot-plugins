/**
 * zpo_corpsington.sp
 *
 * NavBot ZPS objective support module for the zpo_corpsington map.
 *
 * Module version: 0.13.1
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

enum
{
	ZPOCORP_PHASE_IDLE = 0,
	ZPOCORP_PHASE_BREAKINTOOFFICE,
	ZPOCORP_PHASE_PUSHGENERATOR,
	ZPOCORP_PHASE_CLOSEDOORS
};

static int s_CurrentPhase = ZPOCORP_PHASE_IDLE;

void ZPOCorpsington_Init()
{
	g_ThinkFunc = ZPOCorpsington_Think;

	ZPOCorpsington_BreakIntoOffice();
}

void ZPOCorpsington_Think()
{
	switch (s_CurrentPhase)
	{
		case ZPOCORP_PHASE_BREAKINTOOFFICE:
		{
			ZPOCorpsington_UpdateBarricadeObjective();
		}
		case ZPOCORP_PHASE_PUSHGENERATOR:
		{
			ZPOCorpsington_UpdateToolButtonObjective();
		}
		case ZPOCORP_PHASE_CLOSEDOORS:
		{
			ZPOCorpsington_UpdateCloseDoorsObjective();
		}
	}
}

static void ZPOCorpsington_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

/**
 * Phase: 0 - Break into office
 * Summary: Destroy the barricades on the office door.
 * Entity: prop_physics_multiplayer / func_door_rotating
 * Bot action: DESTROY_ENTITY
 * Confirmation: The office door is fully open.
 */
static void ZPOCorpsington_BreakIntoOffice()
{
	ZPOCorpsington_ChatMsgSurvivors("Break the barricades on the office door!");

	s_CurrentPhase = ZPOCORP_PHASE_IDLE;

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "breakdoor1");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the breakdoor1 func_door_rotating!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOCorpsington_OpenWarehouse, true);

	s_CurrentPhase = ZPOCORP_PHASE_BREAKINTOOFFICE;
	ZPOCorpsington_UpdateBarricadeObjective();
}

static void ZPOCorpsington_UpdateBarricadeObjective()
{
	static int s_CurrentBarricadeRef = INVALID_ENT_REFERENCE;

	if (s_CurrentBarricadeRef != INVALID_ENT_REFERENCE && EntRefToEntIndex(s_CurrentBarricadeRef) != INVALID_ENT_REFERENCE)
	{
		return;
	}

	static const int barricadeHammerIDs[] = { 908234, 908281, 908312 };

	for (int i = 0; i < sizeof(barricadeHammerIDs); i++)
	{
		int entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics_multiplayer", barricadeHammerIDs[i]);

		if (entity != INVALID_ENT_REFERENCE)
		{
			s_CurrentBarricadeRef = EntIndexToEntRef(entity);
			NavBotZPSModInterface.ResetObjective();
			NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
			NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
			return;
		}
	}
}

/**
 * Phase: 1 - Open warehouse
 * Summary: Press the warehouse door button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPOCorpsington_OpenWarehouse(const char[] output, int caller, int activator, float delay)
{
	s_CurrentPhase = ZPOCORP_PHASE_IDLE;

	ZPOCorpsington_ChatMsgSurvivors("Open the warehouse door!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "wh_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the wh_button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_WaitForWarehouse, true);
}

/**
 * Phase: 1.1 - Wait for warehouse
 * Summary: Follow players while the warehouse door opens.
 * Entity: func_door
 * Bot action: none (objective reset)
 * Confirmation: The warehouse door is fully open.
 */
static void ZPOCorpsington_WaitForWarehouse(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("Hold on while the warehouse door opens!");

	NavBotZPSModInterface.ResetObjective();

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "big_wh_door1");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the big_wh_door1 func_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOCorpsington_CutPower, true);
}

/**
 * Phase: 2 - Cut power
 * Summary: Destroy the fuse box.
 * Entity: func_breakable
 * Bot action: DESTROY_ENTITY
 * Confirmation: The fuse box breaks.
 */
static void ZPOCorpsington_CutPower(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("Destroy the fuse box!");

	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "fuse_box_breakable");

	if (entity == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the fuse_box_breakable func_breakable!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
	HookSingleEntityOutput(entity, "OnBreak", ZPOCorpsington_WaitForPowerToFail, true);
}

/**
 * Phase: 3 - Wait for power to fail
 * Summary: Hold at the staging position until the container bridge lands.
 * Entity: func_breakable
 * Bot action: MOVETO
 * Confirmation: The upper floor window glass breaks.
 */
static void ZPOCorpsington_WaitForPowerToFail(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("Wait for the power to fail!");

	int glass = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "windowGlass");

	if (glass == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the windowGlass func_breakable!");
		return;
	}

	float goal[3] = { 1800.8, 509.0, 288.1 };

	NavBotZPSModInterface.ResetObjective();
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	HookSingleEntityOutput(glass, "OnBreak", ZPOCorpsington_GetInsideUpperFloor, true);
}

/**
 * Phase: 4 - Get inside upper floor
 * Summary: Cross the container bridge into the upper floor.
 * Entity: trigger_once
 * Bot action: MOVETO
 * Confirmation: The upper floor trigger is touched.
 */
static void ZPOCorpsington_GetInsideUpperFloor(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("Cross the container and get inside!");

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "enter_2nd_floor");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the enter_2nd_floor trigger_once!");
		return;
	}

	float goal[3] = { 1582.3, 1367.7, 288.0 };

	NavBotZPSModInterface.ResetObjective();
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOCorpsington_PushGenerator, true);
}

/**
 * Phase: 5/6 - Get to street / Push generator
 * Summary: Stay with the generator cart, then pull its lever.
 * Entity: func_button
 * Bot action: MOVETO, then USE_BUTTON
 * Confirmation: The lever is pressed.
 */
static void ZPOCorpsington_PushGenerator(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("Get to the street and push the generator!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the toolButton func_button!");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_CloseDoors, true);

	s_CurrentPhase = ZPOCORP_PHASE_PUSHGENERATOR;
	ZPOCorpsington_UpdateToolButtonObjective();
}

static void ZPOCorpsington_UpdateToolButtonObjective()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the toolButton func_button!");
		s_CurrentPhase = ZPOCORP_PHASE_IDLE;
		return;
	}

	if (GetEntProp(button, Prop_Data, "m_bLocked", 1) != 0)
	{
		float pos[3];
		GetEntPropVector(button, Prop_Data, "m_vecAbsOrigin", pos);

		NavBotZPSModInterface.ResetObjective();
		CanAllBotsReachGoal(pos);
		NavBotZPSModInterface.SetObjectiveMoveGoal(pos);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		return;
	}

	ZPOCorpsington_ChatMsgSurvivors("The generator is in place, pull the lever!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	s_CurrentPhase = ZPOCORP_PHASE_IDLE;
}

/**
 * Phase: 7 - Close doors
 * Summary: Press the safehouse door button once it unlocks.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPOCorpsington_CloseDoors(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("Get into the safehouse and close the doors!");

	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_NONE);
	NavBotZPSModInterface.ResetObjective();

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "safehouse_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the safehouse_button func_button!");
		s_CurrentPhase = ZPOCORP_PHASE_IDLE;
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_KillZombies, true);

	s_CurrentPhase = ZPOCORP_PHASE_CLOSEDOORS;
}

static void ZPOCorpsington_UpdateCloseDoorsObjective()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "safehouse_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the safehouse_button func_button!");
		s_CurrentPhase = ZPOCORP_PHASE_IDLE;
		return;
	}

	if (GetEntProp(button, Prop_Data, "m_bLocked", 1) != 0)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	s_CurrentPhase = ZPOCORP_PHASE_IDLE;
}

/**
 * Phase: 8 - Kill zombies
 * Summary: Follow players and kill anything trapped inside.
 * Entity: none
 * Bot action: none (objective reset)
 * Confirmation: The round ends.
 */
static void ZPOCorpsington_KillZombies(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("Doors are closing, kill any zombies inside!");

	NavBotZPSModInterface.ResetObjective();
}
