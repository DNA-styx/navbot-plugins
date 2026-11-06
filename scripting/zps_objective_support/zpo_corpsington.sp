/**
 * zpo_corpsington.sp
 *
 * NavBot ZPS objective support module for the zpo_corpsington map.
 *
 * Module version: 0.14.1
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

static bool s_PollBarricades = false;

void ZPOCorpsington_Init()
{
	g_ThinkFunc = ZPOCorpsington_Think;
	s_PollBarricades = false;

	ZPOCorpsington_BreakIntoOffice();
}

void ZPOCorpsington_Think()
{
	if (s_PollBarricades)
	{
		ZPOCorpsington_UpdateBarricadeObjective();
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

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "breakdoor1");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the breakdoor1 func_door_rotating!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOCorpsington_OpenWarehouse, true);

	s_PollBarricades = true;
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
	s_PollBarricades = false;

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
	HookSingleEntityOutput(entity, "OnBreak", ZPOCorpsington_GetInsideUpperFloor, true);
}

/**
 * Phase: 3/4 - Wait for power to fail / Get inside upper floor
 * Summary: Cross the container bridge into the upper floor once it lands.
 * Entity: trigger_once
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The upper floor trigger is touched.
 */
static void ZPOCorpsington_GetInsideUpperFloor(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("Wait for the power to fail, then cross the container!");

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "enter_2nd_floor");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the enter_2nd_floor trigger_once!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOCorpsington_PushGenerator, true);
}

/**
 * Phase: 5/6 - Get to street / Push generator
 * Summary: Stay with the generator cart until it reaches the end of the track.
 * Entity: func_button / path_track
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The cart passes path30.
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

	int track = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "path30");

	if (track == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the path30 path_track!");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_CloseDoors, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
	HookSingleEntityOutput(track, "OnPass", ZPOCorpsington_PullLever, true);
}

/**
 * Phase: 6.1 - Pull lever
 * Summary: Pull the generator lever.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The lever is pressed.
 */
static void ZPOCorpsington_PullLever(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("The generator is in place, pull the lever!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the toolButton func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 7 - Close doors
 * Summary: Wait at the safehouse door button until the safehouse opens.
 * Entity: func_button / func_door
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The safehouse door starts opening.
 */
static void ZPOCorpsington_CloseDoors(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("Get into the safehouse and close the doors!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "safehouse_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the safehouse_button func_button!");
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "safehouse_door");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the safehouse_door func_door!");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_KillZombies, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
	HookSingleEntityOutput(door, "OnOpen", ZPOCorpsington_PressSafehouseButton, true);
}

/**
 * Phase: 7.1 - Press safehouse button
 * Summary: Press the safehouse door button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPOCorpsington_PressSafehouseButton(const char[] output, int caller, int activator, float delay)
{
	ZPOCorpsington_ChatMsgSurvivors("The safehouse is open, press the button!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "safehouse_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the safehouse_button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
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
