/**
 * zpo_corpsington.sp
 *
 * NavBot ZPS objective support module for the zpo_corpsington map.
 *
 * Module version: 0.12.6
 * Author: Claude.ai guided by DNA.styx
 * 
 * Status: Usable
 *
 * Issues: None
 */

enum
{
	ZPOCORP_PHASE_BREAKINTOOFFICE = 0,
	ZPOCORP_PHASE_WAITFORCART,
	ZPOCORP_PHASE_CLOSEDOORS,
	ZPOCORP_PHASE_DONE
};

static int s_CurrentPhase = ZPOCORP_PHASE_BREAKINTOOFFICE;

void ZPOCorpsington_Init()
{
	g_ThinkFunc = ZPOCorpsington_Think;
	s_CurrentPhase = ZPOCORP_PHASE_BREAKINTOOFFICE;

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "breakdoor1");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the breakdoor1 func_door_rotating!");
	}
	else
	{
		HookSingleEntityOutput(door, "OnFullyOpen", ZPOCorpsington_OnBreakdoorsOpened, true);
	}

	ZPOCorpsington_UpdateBarricadeObjective();
}

void ZPOCorpsington_Think()
{
	switch (s_CurrentPhase)
	{
		case ZPOCORP_PHASE_BREAKINTOOFFICE:
		{
			ZPOCorpsington_UpdateBarricadeObjective();
		}
		case ZPOCORP_PHASE_WAITFORCART:
		{
			ZPOCorpsington_UpdateToolButtonObjective();
		}
		case ZPOCORP_PHASE_CLOSEDOORS:
		{
			ZPOCorpsington_UpdateCloseDoorsObjective();
		}
	}
}

// Sends a parameterless plugin command (e.g. NAVBOT_PLUGINCMD_PATROL,
// NAVBOT_PLUGINCMD_STOPCMD) to all survivors.
void ZPOCorpsington_CommandSurvivors(NavBotPluginCommandTypes command)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !NavBotManager.IsNavBot(client) || GetClientTeam(client) != 2)
		{
			continue;
		}

		NavBot bot = view_as<NavBot>(client);
		bot.SendPluginCommand(command);
	}
}

/**
 * Phase: 1 - BreakIntoOffice
 * Summary: Survivors destroy 3 barricades nailed across the office door.
 * Entity: wooden_barricade (prop_physics_multiplayer, 908234 / 908281 / 908312)
 * Bot action: DESTROY_ENTITY, re-targeted to the next surviving barricade
 *   each tick
 * Confirmation: breakdoor1's OnFullyOpen output (func_door_rotating, 34159)
 */
void ZPOCorpsington_UpdateBarricadeObjective()
{
	static int s_CurrentBarricadeRef = INVALID_ENT_REFERENCE;

	// Current target still alive, nothing to do.
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
			NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
			NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
			return;
		}
	}

	// No barricades left to target - Phase 1 completion is confirmed by
	// ZPOCorpsington_OnBreakdoorsOpened, hooked in Init().
}

// Confirms Phase 1 - see ZPOCorpsington_UpdateBarricadeObjective above.

/**
 * Phase: 2.1 - OpenWarehouse
 * Summary: Press wh_button to open the warehouse door.
 * Entity: wh_button (func_button, 54540)
 * Bot action: USE_BUTTON
 * Confirmation: wh_button's OnPressed output
 */
void ZPOCorpsington_OnBreakdoorsOpened(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "wh_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the wh_button func_button!");
		s_CurrentPhase = ZPOCORP_PHASE_DONE;
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_OnWarehouseButtonPressed, true);

	s_CurrentPhase = ZPOCORP_PHASE_DONE;
}

/**
 * Phase: 2.2 - OpenWarehouse (waiting)
 * Summary: Wait for the door to open.
 * Entity: none (patrols near wh_button, no specific target)
 * Bot action: NAVBOT_PLUGINCMD_PATROL
 * Confirmation: OnWarehouseDoorOpened
 */
void ZPOCorpsington_OnWarehouseButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	ZPOCorpsington_CommandSurvivors(NAVBOT_PLUGINCMD_PATROL);

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "big_wh_door1");

	if (door != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(door, "OnFullyOpen", ZPOCorpsington_OnWarehouseDoorOpened, true);
	}
}

/**
 * Phase: 3 - CutPower
 * Summary: Destroy the fuse box
 * Entity: big_wh_door1 (func_door, 26975) / fuse_box_breakable
 *   (func_breakable, 928335)
 * Bot action: DESTROY_ENTITY 
 * Confirmation: fuse_box_breakable's OnBreak
 */
void ZPOCorpsington_OnWarehouseDoorOpened(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_CommandSurvivors(NAVBOT_PLUGINCMD_STOPCMD);

	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "fuse_box_breakable");

	if (entity == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the fuse_box_breakable func_breakable!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
	HookSingleEntityOutput(entity, "OnBreak", ZPOCorpsington_OnFuseBoxBroken, true);
}

// Confirms Phase 3 - see ZPOCorpsington_OnWarehouseDoorOpened above.

/**
 * Phase: 4 - WaitForPowerToFail
 * Summary: Wait for container to make path.
 * Entity: none (fixed staging position)
 * Bot action: MOVETO 
 * Confirmation: 33s CreateTimer
 */
void ZPOCorpsington_OnFuseBoxBroken(const char[] output, int caller, int activator, float delay)
{
	float goal[3];
	goal[0] = 1800.841187;
	goal[1] = 508.958191;
	goal[2] = 288.142029;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	CreateTimer(33.0, ZPOCorpsington_Timer_EnterSecondFloor, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

// Confirms Phase 4 (timer elapsed) - see ZPOCorpsington_OnFuseBoxBroken above.
void ZPOCorpsington_Timer_EnterSecondFloor(Handle timer)
{
	ZPOCorpsington_ActivateEnterSecondFloor();
}

/**
 * Phase: 5 - GetInsideUpperFloor
 * Summary: Access building through window.
 * Entity: enter_2nd_floor (trigger_once, 34622)
 * Bot action: MOVETO 
 * Confirmation: enter_2nd_floor's OnStartTouch output
 */
void ZPOCorpsington_ActivateEnterSecondFloor()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "enter_2nd_floor");

	float goal[3];
	goal[0] = 1904.0;
	goal[1] = 1120.0;
	goal[2] = 288.0;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the enter_2nd_floor trigger_once!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOCorpsington_OnEnteredSecondFloor, true);
}

// Confirms Phase 5 - see ZPOCorpsington_ActivateEnterSecondFloor above.
void ZPOCorpsington_OnEnteredSecondFloor(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_NONE);
	NavBotZPSModInterface.ResetObjective();

	s_CurrentPhase = ZPOCORP_PHASE_WAITFORCART;
}

/**
 * Phase: 6/7 - GetToStreet / PushGenerator
 * Summary: Push generator, then turn it on.
 * Entity: toolButton (func_button, 66092)
 * Bot action: MOVETO toolButton's live position while locked, then
 *   USE_BUTTON once unlocked
 * Confirmation: m_bLocked polled each tick; toolButton's OnPressed output
  */
void ZPOCorpsington_UpdateToolButtonObjective()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		return;
	}

	int locked = GetEntProp(button, Prop_Data, "m_bLocked", 1);

	if (locked != 0)
	{
		// Still locked - toolButton is parented to the moving cart
		float pos[3];
		GetEntPropVector(button, Prop_Data, "m_vecAbsOrigin", pos);

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(pos);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_OnToolButtonPressed, true);

	s_CurrentPhase = ZPOCORP_PHASE_DONE;
}

// Confirms Phase 6/7 - see ZPOCorpsington_UpdateToolButtonObjective above.
void ZPOCorpsington_OnToolButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_NONE);
	NavBotZPSModInterface.ResetObjective();

	s_CurrentPhase = ZPOCORP_PHASE_CLOSEDOORS;
}

/**
 * Phase: 8 - CloseDoors
 * Summary: Press safehouse_button
 * Entity: safehouse_button (func_button, 66545)
 * Bot action: USE_BUTTON once unlocked
 * Confirmation: safehouse_button's OnPressed
 */
void ZPOCorpsington_UpdateCloseDoorsObjective()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "safehouse_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		return;
	}

	int locked = GetEntProp(button, Prop_Data, "m_bLocked", 1);

	if (locked != 0)
	{
		return; // still waiting on GenLever() to unlock it
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_OnSafehouseButtonPressed, true);

	s_CurrentPhase = ZPOCORP_PHASE_DONE;
}

/**
 * Phase: 9 - KillZombies
 * Summary: Kill all zombies in safe house.
 * Entity: none 
 * Bot action: PATROL 
 * Confirmation: none - round end
 */
void ZPOCorpsington_OnSafehouseButtonPressed(const char[] output, int caller, int activator, float delay)
{

	NavBotZPSModInterface.ResetObjective();
	ZPOCorpsington_CommandSurvivors(NAVBOT_PLUGINCMD_PATROL);
}
