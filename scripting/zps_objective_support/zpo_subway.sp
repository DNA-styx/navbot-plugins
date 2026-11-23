/**
 * zpo_subway.sp
 *
 * NavBot ZPS objective support module for the zpo_subway map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.1.3
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

static int s_SecurityDoorRef;
static bool s_bWatchSecurityDoor;
static bool s_bTDCPressed;

void ZPOSubway_Init()
{
	g_ThinkFunc = ZPOSubway_Think;

	s_SecurityDoorRef = INVALID_ENT_REFERENCE;
	s_bWatchSecurityDoor = false;
	s_bTDCPressed = false;

	ZPOSubway_FindKeycard();
}

void ZPOSubway_Think()
{
	if (s_bWatchSecurityDoor)
	{
		ZPOSubway_CheckSecurityDoorDestroyed();
	}
}

static void ZPOSubway_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - Find keycard
 * Summary: Find the keycard.
 * Entity: item_deliver
 * Bot action: FIND_ITEM
 * Confirmation: The keycard is taken.
 */
static void ZPOSubway_FindKeycard()
{
	ZPOSubway_ChatMsgSurvivors("Find the keycard!");

	const int hammerid = 1690784;
	int keycard = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "item_deliver", hammerid);

	if (keycard == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find KeycardDeliver item_deliver! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("KC");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius * 2.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
	HookSingleEntityOutput(keycard, "OnItemTaken", ZPOSubway_UseKeycard, true);
}

/**
 * Phase: 1 - Use keycard
 * Summary: Open the control room with the keycard.
 * Entity: trigger_useable, func_door
 * Bot action: USE_ITEM
 * Confirmation: The control room door opens.
 */
static void ZPOSubway_UseKeycard(const char[] output, int caller, int activator, float delay)
{
	ZPOSubway_ChatMsgSurvivors("Keycard found! Open the control room!");

	const int readerHammerid = 1734621;
	int reader = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_useable", readerHammerid);

	if (reader == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Trigger_CRUseable trigger_useable! Hammer ID: %i", readerHammerid);
		return;
	}

	const int doorHammerid = 790280;
	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", doorHammerid);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Door_ControlRoom func_door! Hammer ID: %i", doorHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("KC");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(reader);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
	HookSingleEntityOutput(door, "OnOpen", ZPOSubway_PowerFirstGenerator, true);
}

/**
 * Phase: 2 - Power first generator
 * Summary: Pull the generator lever.
 * Entity: func_rot_button
 * Bot action: USE_BUTTON
 * Confirmation: The lever is pulled.
 */
static void ZPOSubway_PowerFirstGenerator(const char[] output, int caller, int activator, float delay)
{
	ZPOSubway_ChatMsgSurvivors("Control room open! Power up the generator!");

	const int hammerid = 1801805;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_rot_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Button_ActivateGen func_rot_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnIn", ZPOSubway_WaitForGenerator, true);
}

/**
 * Phase: 3 - Wait for generator
 * Summary: Hold at the cargo door while the generator powers up.
 * Entity: func_door
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The cargo door is fully open.
 */
static void ZPOSubway_WaitForGenerator(const char[] output, int caller, int activator, float delay)
{
	ZPOSubway_ChatMsgSurvivors("Generator starting! Hold at the cargo door!");

	const int doorHammerid = 790585;
	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", doorHammerid);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Door_Cargo func_door! Hammer ID: %i", doorHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(door);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
	HookSingleEntityOutput(door, "OnFullyOpen", ZPOSubway_PowerSecondGenerator, true);
}

/**
 * Phase: 4 - Power second generator
 * Summary: Press the second generator button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPOSubway_PowerSecondGenerator(const char[] output, int caller, int activator, float delay)
{
	ZPOSubway_ChatMsgSurvivors("Cargo door open! Power up the second generator!");

	const int hammerid = 848598;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Button_Activate2ndGen func_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOSubway_FindSecurityRoom, true);
}

/**
 * Phase: 5 - Find security room
 * Summary: Head down towards the security room.
 * Entity: info_beacon, trigger_once
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: A survivor touches the lower level trigger.
 */
static void ZPOSubway_FindSecurityRoom(const char[] output, int caller, int activator, float delay)
{
	ZPOSubway_ChatMsgSurvivors("Lower doors open! Find the security room!");

	const int beaconHammerid = 1692207;
	int beacon = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "info_beacon", beaconHammerid);

	if (beacon == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Beacon_ThroughHere info_beacon! Hammer ID: %i", beaconHammerid);
		return;
	}

	const int triggerHammerid = 1474689;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", triggerHammerid);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Trigger_ThroughHere trigger_once! Hammer ID: %i", triggerHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(beacon);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOSubway_BreakSecurityDoor, true);
}

/**
 * Phase: 6 - Break security door
 * Summary: Break down the security room door.
 * Entity: prop_door_rotating, func_button
 * Bot action: DESTROY_ENTITY
 * Confirmation: The door is gone (polled), or the platform door button is
 *   pressed.
 */
static void ZPOSubway_BreakSecurityDoor(const char[] output, int caller, int activator, float delay)
{
	ZPOSubway_ChatMsgSurvivors("Break down the security room door!");

	const int buttonHammerid = 1692277;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", buttonHammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Button_TDC func_button! Hammer ID: %i", buttonHammerid);
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOSubway_PowerTrain, true);

	const int doorHammerid = 1633659;
	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_door_rotating", doorHammerid);

	if (door == INVALID_ENT_REFERENCE)
	{
		ZPOSubway_OpenPlatformDoors();
		return;
	}

	s_SecurityDoorRef = EntIndexToEntRef(door);
	s_bWatchSecurityDoor = true;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(door);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
}

static void ZPOSubway_CheckSecurityDoorDestroyed()
{
	if (s_bTDCPressed)
	{
		s_bWatchSecurityDoor = false;
		return;
	}

	if (EntRefToEntIndex(s_SecurityDoorRef) != INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_bWatchSecurityDoor = false;
	s_SecurityDoorRef = INVALID_ENT_REFERENCE;
	ZPOSubway_OpenPlatformDoors();
}

/**
 * Phase: 7 - Open platform doors
 * Summary: Press the platform door button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed (hooked in Phase 6).
 */
static void ZPOSubway_OpenPlatformDoors()
{
	ZPOSubway_ChatMsgSurvivors("Security room open! Open the platform doors!");

	const int hammerid = 1692277;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Button_TDC func_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 8 - Power train
 * Summary: Press the train power button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPOSubway_PowerTrain(const char[] output, int caller, int activator, float delay)
{
	s_bTDCPressed = true;
	s_bWatchSecurityDoor = false;

	ZPOSubway_ChatMsgSurvivors("Platform doors open! Power up the train!");

	const int hammerid = 797012;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Button_ActivateTrain func_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOSubway_BoardTrain, true);
}

/**
 * Phase: 9 - Board train
 * Summary: Board the train and wait for it to leave.
 * Entity: prop_dynamic, path_track
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The train reaches the end of its track.
 */
static void ZPOSubway_BoardTrain(const char[] output, int caller, int activator, float delay)
{
	ZPOSubway_ChatMsgSurvivors("Train powering up! Get on board!");

	const int seatHammerid = 1493767;
	int seat = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_dynamic", seatHammerid);

	if (seat == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Train_Props seat prop_dynamic! Hammer ID: %i", seatHammerid);
		return;
	}

	const int trackHammerid = 810647;
	int track = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "path_track", trackHammerid);

	if (track == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find track2 path_track! Hammer ID: %i", trackHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(seat);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
	HookSingleEntityOutput(track, "OnPass", ZPOSubway_OpenTunnel, true);
}

/**
 * Phase: 10 - Open tunnel
 * Summary: Pull the tunnel door lever.
 * Entity: func_rot_button
 * Bot action: USE_BUTTON
 * Confirmation: The tunnel door is fully open.
 */
static void ZPOSubway_OpenTunnel(const char[] output, int caller, int activator, float delay)
{
	ZPOSubway_ChatMsgSurvivors("Missed the train! Open the tunnel door!");

	const int buttonHammerid = 1801808;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_rot_button", buttonHammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Button_OpenPlanB func_rot_button! Hammer ID: %i", buttonHammerid);
		return;
	}

	const int doorHammerid = 984690;
	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", doorHammerid);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Door_PlanB func_door! Hammer ID: %i", doorHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(door, "OnFullyOpen", ZPOSubway_EscapeTunnel, true);
}

/**
 * Phase: 11 - Escape tunnel
 * Summary: Escape through the tunnel.
 * Entity: info_beacon
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: none - final phase.
 */
static void ZPOSubway_EscapeTunnel(const char[] output, int caller, int activator, float delay)
{
	ZPOSubway_ChatMsgSurvivors("Tunnel open! Escape!");

	const int hammerid = 1741988;
	int beacon = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "info_beacon", hammerid);

	if (beacon == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_subway: Failed to find Beacon_TTunnels info_beacon! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(beacon);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}
