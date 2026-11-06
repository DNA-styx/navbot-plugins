/**
 * zpo_residentevil_mov_zb_dc6.sp
 *
 * NavBot ZPS objective support module for the zpo_residentevil_mov_zb_dc6 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.3.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

static bool s_bTrainStarted;

void ZPOResidentEvilDC6_Init()
{
	g_ThinkFunc = ZPOResidentEvilDC6_Think;
	s_bTrainStarted = false;

	ZPOResidentEvilDC6_HackPanel();
}

void ZPOResidentEvilDC6_Think()
{
	// Left empty until a phase needs per-tick polling.
}

static void ZPOResidentEvilDC6_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - Hack panel
 * Summary: Hack the mansion access panel.
 * Entity: func_button, func_door
 * Bot action: USE_BUTTON
 * Confirmation: The mirror doors start to open.
 */
static void ZPOResidentEvilDC6_HackPanel()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "mirror_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: mirror_button");
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "mirror_door_01a");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_door! Name: mirror_door_01a");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Hack the access panel!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(door, "OnOpen", ZPOResidentEvilDC6_RestorePower, true);
}

/**
 * Phase: 1 - Restore power
 * Summary: Restore power to the train.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The power switch is pressed.
 */
static void ZPOResidentEvilDC6_RestorePower(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "button_01");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: button_01");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Doors are open, restore power to the train!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOResidentEvilDC6_BoardTrain, true);
}

/**
 * Phase: 2 - Board train
 * Summary: Get on the train.
 * Entity: func_button
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The boarding delay ends, or the train start button is pressed.
 */
static void ZPOResidentEvilDC6_BoardTrain(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "tb1");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: tb1");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Power is on, get on the train!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
	HookSingleEntityOutput(button, "OnPressed", ZPOResidentEvilDC6_RideTrain, true);
	CreateTimer(15.0, ZPOResidentEvilDC6_StartTrain, EntIndexToEntRef(button), TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * Phase: 2.1 - Start train
 * Summary: Start the train.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The train start button is pressed.
 */
static Action ZPOResidentEvilDC6_StartTrain(Handle timer, int ref)
{
	int button = EntRefToEntIndex(ref);

	if (s_bTrainStarted || button == INVALID_ENT_REFERENCE)
	{
		return Plugin_Stop;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Everyone aboard, start the train!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	return Plugin_Stop;
}

/**
 * Phase: 2.2 - Ride train
 * Summary: Stay on the train until it reaches the Hive.
 * Entity: func_button, path_track
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The train reaches the Hive station.
 */
static void ZPOResidentEvilDC6_RideTrain(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "tb1");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: tb1");
		return;
	}

	int track = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "p2");

	if (track == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find path_track! Name: p2");
		return;
	}

	s_bTrainStarted = true;

	ZPOResidentEvilDC6_ChatMsgSurvivors("Stay on the train!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
	HookSingleEntityOutput(track, "OnPass", ZPOResidentEvilDC6_PlantCharge, true);
}

/**
 * Phase: 2.3 - Plant charge
 * Summary: Plant the charge on the Hive entrance.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The charge button is pressed.
 */
static void ZPOResidentEvilDC6_PlantCharge(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "c4_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: c4_button");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Plant the charge on the Hive entrance!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOResidentEvilDC6_ClearBlast, true);
}

/**
 * Phase: 2.4 - Clear blast
 * Summary: Roam until the Hive entrance opens.
 * Entity: func_door
 * Bot action: None (ResetObjective)
 * Confirmation: The Hive entrance is fully open.
 */
static void ZPOResidentEvilDC6_ClearBlast(const char[] output, int caller, int activator, float delay)
{
	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "Hive_main_entrance");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_door! Name: Hive_main_entrance");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Charge planted, get clear!");

	NavBotZPSModInterface.ResetObjective();
	HookSingleEntityOutput(door, "OnFullyOpen", ZPOResidentEvilDC6_DiningHall, true);
}

/**
 * Phase: 3 - Dining hall
 * Summary: Open the Dining Hall B door.
 * Entity: func_button, func_door
 * Bot action: USE_BUTTON
 * Confirmation: The Dining Hall B doors start to open.
 */
static void ZPOResidentEvilDC6_DiningHall(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "dh-B_door_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: dh-B_door_button");
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "Dinning_Hall-B_door01");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_door! Name: Dinning_Hall-B_door01");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("We're in! Make your way to Dining Hall B!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(door, "OnOpen", ZPOResidentEvilDC6_ChamberDoors, true);
}

/**
 * Phase: 3.1 - Chamber doors
 * Summary: Open the chamber doors.
 * Entity: func_button, func_door
 * Bot action: USE_BUTTON
 * Confirmation: The chamber doors start to open.
 */
static void ZPOResidentEvilDC6_ChamberDoors(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "chamber_doors_button_6");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: chamber_doors_button_6");
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "chamber_door_left_01");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_door! Name: chamber_door_left_01");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Open the chamber doors!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(door, "OnOpen", ZPOResidentEvilDC6_HackDoor, true);
}

/**
 * Phase: 4 - Hack door
 * Summary: Hack the defense door.
 * Entity: func_button, func_door
 * Bot action: USE_BUTTON
 * Confirmation: The defense door is fully open.
 */
static void ZPOResidentEvilDC6_HackDoor(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "defense_door_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: defense_door_button");
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "defense_door");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_door! Name: defense_door");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Hack the defense door!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(door, "OnFullyOpen", ZPOResidentEvilDC6_OpenChamber, true);
}

/**
 * Phase: 5 - Open chamber
 * Summary: One survivor bot presses the chamber button.
 * Entity: func_button
 * Bot action: Plugin command USE_ENTITY (single bot)
 * Confirmation: The chamber button is pressed.
 */
static void ZPOResidentEvilDC6_OpenChamber(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "redqueen_door_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: redqueen_door_button");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Defense door is open, open the Red Queen chamber!");

	NavBotZPSModInterface.ResetObjective();
	HookSingleEntityOutput(button, "OnPressed", ZPOResidentEvilDC6_SurviveAttack, true);
	ZPOResidentEvilDC6_SendChamberPress(button);
	CreateTimer(5.0, ZPOResidentEvilDC6_RepressChamber, EntIndexToEntRef(button), TIMER_FLAG_NO_MAPCHANGE);
}

static void ZPOResidentEvilDC6_SendChamberPress(int button)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !NavBotManager.IsNavBot(client))
		{
			continue;
		}

		if (GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		{
			continue;
		}

		NavBot bot = NavBotManager.GetNavBotByIndex(client);

		if (bot == NULL_NAVBOT)
		{
			continue;
		}

		bot.SendPluginCommand(NAVBOT_PLUGINCMD_USE_ENTITY, button);
		return;
	}
}

static Action ZPOResidentEvilDC6_RepressChamber(Handle timer, int ref)
{
	int button = EntRefToEntIndex(ref);

	if (button != INVALID_ENT_REFERENCE)
	{
		ZPOResidentEvilDC6_SendChamberPress(button);
	}

	return Plugin_Stop;
}

/**
 * Phase: 5.1 - Survive attack
 * Summary: Roam while the laser defense runs.
 * Entity: func_door_rotating
 * Bot action: None (ResetObjective)
 * Confirmation: The Red Queen chamber door starts to open.
 */
static void ZPOResidentEvilDC6_SurviveAttack(const char[] output, int caller, int activator, float delay)
{
	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "redqueen_door2");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_door_rotating! Name: redqueen_door2");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Lasers! Survive the attack!");

	NavBotZPSModInterface.ResetObjective();
	HookSingleEntityOutput(door, "OnOpen", ZPOResidentEvilDC6_EnterChamber, true);
}

/**
 * Phase: 6 - Enter chamber
 * Summary: Move to the Red Queen hatch.
 * Entity: info_beacon, trigger_once
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: A survivor reaches the hatch.
 */
static void ZPOResidentEvilDC6_EnterChamber(const char[] output, int caller, int activator, float delay)
{
	int beacon = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "info_beacon", "rqb");

	if (beacon == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find info_beacon! Name: rqb");
		return;
	}

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "hatch_doors_open_trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find trigger_once! Name: hatch_doors_open_trigger");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Chamber is open, get to the Red Queen!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(beacon);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
	HookSingleEntityOutput(trigger, "OnTrigger", ZPOResidentEvilDC6_WaitForEMP, true);
}

/**
 * Phase: 6.1 - Wait for EMP
 * Summary: Roam until the EMP button appears.
 * Entity: point_template
 * Bot action: None (ResetObjective)
 * Confirmation: The EMP button is spawned.
 */
static void ZPOResidentEvilDC6_WaitForEMP(const char[] output, int caller, int activator, float delay)
{
	int temp = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "point_template", "pb_temp");

	if (temp == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find point_template! Name: pb_temp");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Hold on, the Red Queen is rising!");

	NavBotZPSModInterface.ResetObjective();
	HookSingleEntityOutput(temp, "OnEntitySpawned", ZPOResidentEvilDC6_InstallEMP, true);
}

/**
 * Phase: 6.2 - Install EMP
 * Summary: Install the EMP device.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The EMP button is pressed.
 */
static void ZPOResidentEvilDC6_InstallEMP(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "part_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: part_button");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Install the EMP device!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOResidentEvilDC6_ShutdownRedQueen, true);
}

/**
 * Phase: 6.3 - Shutdown Red Queen
 * Summary: Deactivate the Red Queen.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The deactivate button is pressed.
 */
static void ZPOResidentEvilDC6_ShutdownRedQueen(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "redqueens_last_words");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: redqueens_last_words");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("EMP installed, shut down the Red Queen!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOResidentEvilDC6_FindKeycard, true);
}

/**
 * Phase: 7 - Find keycard
 * Summary: Find the utility access keycard.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The keycard is picked up.
 */
static void ZPOResidentEvilDC6_FindKeycard(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "keycard_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: keycard_button");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Red Queen is down, find the utility keycard!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOResidentEvilDC6_ReactivateRedQueen, true);
}

/**
 * Phase: 8 - Reactivate Red Queen
 * Summary: Reboot the Red Queen mainframe.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The reactivate button is pressed.
 */
static void ZPOResidentEvilDC6_ReactivateRedQueen(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "reactivate");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_residentevil_mov_zb_dc6: Failed to find func_button! Name: reactivate");
		return;
	}

	ZPOResidentEvilDC6_ChatMsgSurvivors("Keycard found! Get back and reactivate the Red Queen!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}
