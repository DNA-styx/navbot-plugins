/**
 * zpo_area41_v7f.sp
 *
 * NavBot ZPS objective support module for the zpo_area41_v7f map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.10.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: Partially complete
 *
 * Issues: In testing
 */

static const int PLANK_HAMMERIDS[3] = { 1551723, 1551719, 1551715 };
static bool s_PlankBroken[3];

void ZPOArea41V7F_Init()
{
	g_ThinkFunc = ZPOArea41V7F_Think;

	for (int i = 0; i < sizeof(s_PlankBroken); i++)
	{
		s_PlankBroken[i] = false;
	}

	ZPOArea41V7F_WaitForChinook();
}

void ZPOArea41V7F_Think()
{
	// Left empty until a phase needs per-tick polling.
}

// Helpers used by more than one phase.

static void ZPOArea41V7F_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - WaitForChinook
 * Summary: Wait for the Chinook to land.
 * Entity: path_track
 * Bot action: none
 * Confirmation: the exit path point's OnPass
 */
static void ZPOArea41V7F_WaitForChinook()
{
	int pathTrack = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "Path_Chinook5");

	if (pathTrack == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find Path_Chinook5 path_track!");
		return;
	}

	HookSingleEntityOutput(pathTrack, "OnPass", ZPOArea41V7F_OnChinookExit, true);
}

/**
 * Phase: 1 - ChinookExit
 * Summary: Break the planks on the toilet door.
 * Entity: func_breakable
 * Bot action: DESTROY_ENTITY, one plank at a time
 * Confirmation: every plank broken or already gone
 */
static void ZPOArea41V7F_OnChinookExit(const char[] output, int caller, int activator, float delay)
{
	ZPOArea41V7F_ChatMsgSurvivors("Break the planks on the toilet door!");

	for (int i = 0; i < sizeof(PLANK_HAMMERIDS); i++)
	{
		int plank = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", PLANK_HAMMERIDS[i]);

		if (plank != INVALID_ENT_REFERENCE)
		{
			HookSingleEntityOutput(plank, "OnBreak", ZPOArea41V7F_OnPlankBroken, true);
		}
	}

	ZPOArea41V7F_TargetNextPlank();
}

static void ZPOArea41V7F_OnPlankBroken(const char[] output, int caller, int activator, float delay)
{
	int hammerid = GetEntProp(caller, Prop_Data, "m_iHammerID");

	for (int i = 0; i < sizeof(PLANK_HAMMERIDS); i++)
	{
		if (hammerid == PLANK_HAMMERIDS[i])
		{
			s_PlankBroken[i] = true;
		}
	}

	ZPOArea41V7F_TargetNextPlank();
}

// A missing plank counts as broken.
static void ZPOArea41V7F_TargetNextPlank()
{
	for (int i = 0; i < sizeof(PLANK_HAMMERIDS); i++)
	{
		if (s_PlankBroken[i])
		{
			continue;
		}

		int plank = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", PLANK_HAMMERIDS[i]);

		if (plank == INVALID_ENT_REFERENCE)
		{
			s_PlankBroken[i] = true;
			continue;
		}

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveGenericTargetEntity(plank);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
		return;
	}

	ZPOArea41V7F_FlushToilet();
}

/**
 * Phase: 2 - FlushToilet
 * Summary: Press the flush button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the flush button's OnPressed
 */
static void ZPOArea41V7F_FlushToilet()
{
	const int hammerid = 730833;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find flush func_button! Hammer ID: %i", hammerid);
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Find the toilet and flush it!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOArea41V7F_OnFlushButtonPressed, true);
}

/**
 * Phase: 3 - FlushButtonPressed
 * Summary: Move to the lift shaft.
 * Entity: path_track
 * Bot action: MOVETO fixed position
 * Confirmation: the lift's top path point OnPass
 */
static void ZPOArea41V7F_OnFlushButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int elevatorTop = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "Path_ElevatorA3");

	if (elevatorTop == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find Path_ElevatorA3 path_track!");
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Something opened, get to the lift!");

	float goal[3] = { 778.7, -7615.8, 84.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	CanAllBotsReachGoal(goal);

	HookSingleEntityOutput(elevatorTop, "OnPass", ZPOArea41V7F_OnElevatorAtTop, true);
}

/**
 * Phase: 4 - ElevatorAtTop
 * Summary: Get on the lift.
 * Entity: func_tracktrain, func_door
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: the lift gate's OnFullyOpen
 */
static void ZPOArea41V7F_OnElevatorAtTop(const char[] output, int caller, int activator, float delay)
{
	int lift = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_tracktrain", "ElevatorA");

	if (lift == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find ElevatorA func_tracktrain!");
		return;
	}

	int gate = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "FenceDoor1_Elevator1");

	if (gate == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find FenceDoor1_Elevator1 func_door!");
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("The lift is here, everyone on!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(lift);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);

	HookSingleEntityOutput(gate, "OnFullyOpen", ZPOArea41V7F_OnElevatorAtBottom, true);
}

/**
 * Phase: 5 - ElevatorAtBottom
 * Summary: Press the tunnel door button.
 * Entity: func_button, func_door
 * Bot action: USE_BUTTON
 * Confirmation: the tunnel door's OnOpen
 */
static void ZPOArea41V7F_OnElevatorAtBottom(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 734624;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find tunnel door func_button! Hammer ID: %i", hammerid);
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "Door_Tunnel1");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find Door_Tunnel1 func_door!");
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Open the tunnel door!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(door, "OnOpen", ZPOArea41V7F_OnTunnelDoorOpen, true);
}

/**
 * Phase: 6 - TunnelDoorOpen
 * Summary: Press the hacking panel button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the panel button's OnPressed
 */
static void ZPOArea41V7F_OnTunnelDoorOpen(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "Bt1O");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find Bt1O func_button!");
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Hack the panel!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOArea41V7F_OnBt1OPressed, true);
}

/**
 * Phase: 7 - Bt1OPressed
 * Summary: Hold the hacking capture point.
 * Entity: trigger_capturepoint_zp, func_door
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: the next tunnel door's OnOpen, fired when the capture completes
 */
static void ZPOArea41V7F_OnBt1OPressed(const char[] output, int caller, int activator, float delay)
{
	int captureTrigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "HackingTrigger1");

	if (captureTrigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find HackingTrigger1 trigger_capturepoint_zp!");
		return;
	}

	const int hammerid = 735474;
	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", hammerid);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find Door_Tunnel2 func_door! Hammer ID: %i", hammerid);
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Hold the area until the hack is done!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(captureTrigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);

	HookSingleEntityOutput(door, "OnOpen", ZPOArea41V7F_UseKeycard, true);
}

/**
 * Phase: 8 - UseKeycard
 * Summary: Find the keys in the security room and use them on the door panel.
 * Entity: item_deliver, trigger_useable
 * Bot action: USE_ITEM
 * Confirmation: the door panel's OnUsed
 */
static void ZPOArea41V7F_UseKeycard(const char[] output, int caller, int activator, float delay)
{
	int key = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "KeyCardDeliver1");

	if (key == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find KeyCardDeliver1 item_deliver!");
		return;
	}

	int receiver = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "ReceiverItemKey");

	if (receiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find ReceiverItemKey trigger_useable!");
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Find the keys in the security room!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("KeyCardDeliver1");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(receiver);
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(key);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);

	HookSingleEntityOutput(receiver, "OnUsed", ZPOArea41V7F_OnKeycardUsed, true);
}

/**
 * Phase: 9 - KeycardUsed
 * Summary: Press the blast door button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the blast door button's OnPressed
 */
static void ZPOArea41V7F_OnKeycardUsed(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "ButtonROTATEKEYBZ");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find ButtonROTATEKEYBZ func_button!");
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Keys are in, press the door button!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOArea41V7F_OnDoorButtonPressed, true);
}

/**
 * Phase: 10 - DoorButtonPressed
 * Summary: Wait for the blast doors to open.
 * Entity: func_door
 * Bot action: none (roam)
 * Confirmation: the inner blast door's OnFullyOpen
 */
static void ZPOArea41V7F_OnDoorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 881114;
	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", hammerid);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find BlastDoorH2 func_door! Hammer ID: %i", hammerid);
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Wait for the blast doors!");

	NavBotZPSModInterface.ResetObjective();

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOArea41V7F_MoveToGeneratorRoom, true);
}

/**
 * Phase: 11 - MoveToGeneratorRoom
 * Summary: Go to the generator room doors.
 * Entity: prop_door_rotating, trigger_once
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: the generator room doorway trigger's OnTrigger
 */
static void ZPOArea41V7F_MoveToGeneratorRoom(const char[] output, int caller, int activator, float delay)
{
	const int doorHammerid = 1467686;
	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_door_rotating", doorHammerid);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find DoubleDoorsGen1 prop_door_rotating! Hammer ID: %i", doorHammerid);
		return;
	}

	const int triggerHammerid = 2232239;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", triggerHammerid);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find generator room trigger_once! Hammer ID: %i", triggerHammerid);
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Head for the generator room!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(door);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);

	HookSingleEntityOutput(trigger, "OnTrigger", ZPOArea41V7F_OnBlastDoorOpen, true);
}

/**
 * Phase: 12 - GeneratorRoomReached
 * Summary: Pull the first generator lever.
 * Entity: func_button, math_counter
 * Bot action: USE_BUTTON
 * Confirmation: the first lever's OnPressed, or the generator counter's OnHitMax
 */
static void ZPOArea41V7F_OnBlastDoorOpen(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 1583831;
	int lever = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (lever == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find first generator lever func_button! Hammer ID: %i", hammerid);
		return;
	}

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "MathPowerHangar");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find MathPowerHangar math_counter!");
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Get to the generator and pull the levers!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(lever);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(lever, "OnPressed", ZPOArea41V7F_OnFirstLeverPressed, true);
	HookSingleEntityOutput(counter, "OnHitMax", ZPOArea41V7F_OnGeneratorOn, true);
}

/**
 * Phase: 13 - FirstLeverPressed
 * Summary: Pull the second generator lever.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the generator counter's OnHitMax
 */
static void ZPOArea41V7F_OnFirstLeverPressed(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 1583840;
	int lever = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (lever == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find second generator lever func_button! Hammer ID: %i", hammerid);
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Now the other lever!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(lever);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 14 - GeneratorOn
 * Summary: Call the cargo lift.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the lift button's OnPressed
 */
static void ZPOArea41V7F_OnGeneratorOn(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "ButtonElevator1");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find ButtonElevator1 func_button!");
		return;
	}

	ZPOArea41V7F_ChatMsgSurvivors("Power is on, call the cargo lift!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOArea41V7F_OnLiftCalled, true);
}

/**
 * Phase: 15 - LiftCalled
 * Summary: Wait for the cargo lift.
 * Entity: func_button
 * Bot action: none (roam)
 * Confirmation: none yet
 */
static void ZPOArea41V7F_OnLiftCalled(const char[] output, int caller, int activator, float delay)
{
	ZPOArea41V7F_ChatMsgSurvivors("Lift is on its way, hold on!");

	NavBotZPSModInterface.ResetObjective();
}
