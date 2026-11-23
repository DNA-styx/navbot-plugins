/**
 * zpo_residentevil_mov_zb_dc6.sp
 *
 * NavBot ZPS objective support module for the zpo_residentevil_mov_zb_dc6 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.5.2
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

static bool s_bTrainStarted;
static int s_ChamberBotUserId;
static int s_ChamberButtonRef = INVALID_ENT_REFERENCE;
static bool s_bChamberButtonLocked;
static bool s_bChamberButtonSeenLocked;

void ZPOResidentEvilDC6_Init()
{
	g_ThinkFunc = ZPOResidentEvilDC6_Think;
	s_bTrainStarted = false;
	s_ChamberBotUserId = 0;
	s_ChamberButtonRef = INVALID_ENT_REFERENCE;
	s_bChamberButtonLocked = false;
	s_bChamberButtonSeenLocked = false;

	ZPOResidentEvilDC6_HackPanel();
}

void ZPOResidentEvilDC6_Think()
{
	ZPOResidentEvilDC6_CheckChamberButton();
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

static NavBot ZPOResidentEvilDC6_GetChamberBot(int client)
{
	if (client <= 0 || !IsClientInGame(client) || !NavBotManager.IsNavBot(client))
	{
		return NULL_NAVBOT;
	}

	if (GetClientTeam(client) != 2 || !IsPlayerAlive(client))
	{
		return NULL_NAVBOT;
	}

	return NavBotManager.GetNavBotByIndex(client);
}

// Sends the chamber bot to press the given button. The first alive survivor
// bot becomes the chamber bot on the first call; later calls use only that bot.
static void ZPOResidentEvilDC6_SendChamberPress(int button)
{
	NavBot bot = NULL_NAVBOT;

	if (s_ChamberBotUserId != 0)
	{
		bot = ZPOResidentEvilDC6_GetChamberBot(GetClientOfUserId(s_ChamberBotUserId));
	}
	else
	{
		for (int client = 1; client <= MaxClients && bot == NULL_NAVBOT; client++)
		{
			bot = ZPOResidentEvilDC6_GetChamberBot(client);

			if (bot != NULL_NAVBOT)
			{
				s_ChamberBotUserId = GetClientUserId(client);
			}
		}
	}

	if (bot != NULL_NAVBOT)
	{
		bot.SendPluginCommand(NAVBOT_PLUGINCMD_USE_ENTITY, button);
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
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
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
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
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
 * Summary: Chamber bot moves to the chamber button and presses it once it unlocks.
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

	s_ChamberButtonRef = EntIndexToEntRef(button);
	s_bChamberButtonLocked = GetEntProp(button, Prop_Data, "m_bLocked") != 0;
	s_bChamberButtonSeenLocked = s_bChamberButtonLocked;
	LogDebugMessage("ResidentEvilDC6: Chamber button locked at Phase 5 start: %d", s_bChamberButtonLocked);
}

static void ZPOResidentEvilDC6_CheckChamberButton()
{
	if (s_ChamberButtonRef == INVALID_ENT_REFERENCE)
	{
		return;
	}

	int button = EntRefToEntIndex(s_ChamberButtonRef);

	if (button == INVALID_ENT_REFERENCE)
	{
		s_ChamberButtonRef = INVALID_ENT_REFERENCE;
		return;
	}

	bool locked = GetEntProp(button, Prop_Data, "m_bLocked") != 0;

	if (locked == s_bChamberButtonLocked)
	{
		return;
	}

	s_bChamberButtonLocked = locked;
	LogDebugMessage("ResidentEvilDC6: Chamber button locked changed to: %d", locked);

	if (locked)
	{
		s_bChamberButtonSeenLocked = true;
		return;
	}

	if (s_bChamberButtonSeenLocked)
	{
		s_ChamberButtonRef = INVALID_ENT_REFERENCE;
		ZPOResidentEvilDC6_SendChamberPress(button);
	}
}

/**
 * Phase: 5.1 - Survive attack
 * Summary: Roam while the laser defense runs.
 * Entity: none
 * Bot action: None (ResetObjective)
 * Confirmation: none yet (last phase).
 */
static void ZPOResidentEvilDC6_SurviveAttack(const char[] output, int caller, int activator, float delay)
{
	ZPOResidentEvilDC6_ChatMsgSurvivors("Lasers! Survive the attack!");

	NavBotZPSModInterface.ResetObjective();
}
