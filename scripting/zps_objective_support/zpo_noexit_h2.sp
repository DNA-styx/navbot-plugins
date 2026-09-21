/**
 * zpo_noexit_h2.sp
 *
 * NavBot ZPS objective support module for the zpo_noexit_h2 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.3.2
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: WIP
 *
 * Issues: Players needed to get Office Keys
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

void ZPONoexitH2_Init()
{
	g_ThinkFunc = ZPONoexitH2_Think;

	ZPONoexitH2_CloseStartDoors();
}

void ZPONoexitH2_Think()
{
	// Left empty until a phase needs per-tick polling.
}

static void ZPONoexitH2_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - Close start doors
 * Summary: Close the start garage doors.
 * Entity: func_rot_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPONoexitH2_CloseStartDoors()
{
	ZPONoexitH2_ChatMsgSurvivors("Get to the lift and shut the door!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_rot_button", "no_exitdoors_button");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		HookSingleEntityOutput(button, "OnPressed", ZPONoexitH2_OnStartDoorsButtonPressed, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find func_rot_button! Name: no_exitdoors_button");
	}
}

static void ZPONoexitH2_OnStartDoorsButtonPressed(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_WaitForDoors();
}

/**
 * Phase: 1 - Wait for doors
 * Summary: Hold at the elevator while the doors close.
 * Entity: math_counter
 * Bot action: MOVETO
 * Confirmation: The door counter reaches its maximum.
 */
static void ZPONoexitH2_WaitForDoors()
{
	ZPONoexitH2_ChatMsgSurvivors("Guard the lift!");

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "no_exitdoors_counter");

	if (counter != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { 1625.3, -508.2, -9.0 };
		NavBotZPSModInterface.ResetObjective();
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		HookSingleEntityOutput(counter, "OnHitMax", ZPONoexitH2_OnDoorsClosed, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find math_counter! Name: no_exitdoors_counter");
	}
}

static void ZPONoexitH2_OnDoorsClosed(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_CallElevator();
}

/**
 * Phase: 2 - Call elevator
 * Summary: Start the elevator.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPONoexitH2_CallElevator()
{
	ZPONoexitH2_ChatMsgSurvivors("Doors are shut, start the elevator!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "elevator2_button");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		HookSingleEntityOutput(button, "OnPressed", ZPONoexitH2_OnElevatorCalled, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find func_button! Name: elevator2_button");
	}
}

static void ZPONoexitH2_OnElevatorCalled(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_RideElevator();
}

/**
 * Phase: 2.1 - Ride elevator
 * Summary: Hold at the elevator until it reaches the bottom.
 * Entity: path_track
 * Bot action: MOVETO
 * Confirmation: The elevator passes its final track node.
 */
static void ZPONoexitH2_RideElevator()
{
	ZPONoexitH2_ChatMsgSurvivors("Hold on, heading down!");

	int track = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "elevator2_track2");

	if (track != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { 1625.3, -508.2, -9.0 };
		NavBotZPSModInterface.ResetObjective();
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		HookSingleEntityOutput(track, "OnPass", ZPONoexitH2_OnElevatorArrived, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find path_track! Name: elevator2_track2");
	}
}

static void ZPONoexitH2_OnElevatorArrived(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_FindKeys();
}

/**
 * Phase: 3 - Find keys
 * Summary: Wait for the keys to be found.
 * Entity: item_deliver
 * Bot action: None
 * Confirmation: The keys are taken.
 */
static void ZPONoexitH2_FindKeys()
{
	ZPONoexitH2_ChatMsgSurvivors("Find the keys! We will guard!");

	int keys = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "keys");

	if (keys != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		HookSingleEntityOutput(keys, "OnItemTaken", ZPONoexitH2_OnKeysTaken, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find item_deliver! Name: keys");
	}
}

static void ZPONoexitH2_OnKeysTaken(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_UseKeys();
}

/**
 * Phase: 4 - Use keys
 * Summary: Use the keys on the office door.
 * Entity: trigger_useable
 * Bot action: USE_ITEM
 * Confirmation: The keys are used.
 */
static void ZPONoexitH2_UseKeys()
{
	ZPONoexitH2_ChatMsgSurvivors("Keys found! Open the office door!");

	int lock = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "office_doors_trigger");

	if (lock != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
		NavBotZPSModInterface.SetObjectiveItemUseTarget(lock);
		NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
		HookSingleEntityOutput(lock, "OnUsed", ZPONoexitH2_OnKeysUsed, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find trigger_useable! Name: office_doors_trigger");
	}
}

static void ZPONoexitH2_OnKeysUsed(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_FindKeycard();
}

/**
 * Phase: 5 - Find keycard
 * Summary: Find the keycard.
 * Entity: item_deliver
 * Bot action: FIND_ITEM
 * Confirmation: The keycard is taken.
 */
static void ZPONoexitH2_FindKeycard()
{
	ZPONoexitH2_ChatMsgSurvivors("Find the keycard!");

	int keycard = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "keycard");

	if (keycard != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemSearchID("keycard");
		NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius * 2.0);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
		HookSingleEntityOutput(keycard, "OnItemTaken", ZPONoexitH2_OnKeycardTaken, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find item_deliver! Name: keycard");
	}
}

static void ZPONoexitH2_OnKeycardTaken(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_UseKeycard();
}

/**
 * Phase: 6 - Use keycard
 * Summary: Use the keycard on the card reader.
 * Entity: trigger_useable
 * Bot action: USE_ITEM
 * Confirmation: The keycard is used.
 */
static void ZPONoexitH2_UseKeycard()
{
	ZPONoexitH2_ChatMsgSurvivors("Keycard found! Open the lab door!");

	int reader = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "cardreader_trigger");

	if (reader != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemSearchID("keycard");
		NavBotZPSModInterface.SetObjectiveItemUseTarget(reader);
		NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
		HookSingleEntityOutput(reader, "OnUsed", ZPONoexitH2_OnKeycardUsed, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find trigger_useable! Name: cardreader_trigger");
	}
}

static void ZPONoexitH2_OnKeycardUsed(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_GuardLab();
}

/**
 * Phase: 7 - Guard lab
 * Summary: Hold in the lab until the airlock opens.
 * Entity: func_door
 * Bot action: MOVETO
 * Confirmation: The airlock doors are fully open.
 */
static void ZPONoexitH2_GuardLab()
{
	ZPONoexitH2_ChatMsgSurvivors("Guard the lab until the airlock opens!");

	int airlock = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "airlock_doors");

	if (airlock != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { -459.3, 139.2, -1568.0 };
		NavBotZPSModInterface.ResetObjective();
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		HookSingleEntityOutput(airlock, "OnFullyOpen", ZPONoexitH2_OnAirlockOpened, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find func_door! Name: airlock_doors");
	}
}

static void ZPONoexitH2_OnAirlockOpened(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_CallLabElevator();
}

/**
 * Phase: 8 - Call lab elevator
 * Summary: Press the lab elevator button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPONoexitH2_CallLabElevator()
{
	ZPONoexitH2_ChatMsgSurvivors("Airlock is open, take the elevator!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "elevator_button");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		HookSingleEntityOutput(button, "OnPressed", ZPONoexitH2_OnLabElevatorCalled, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find func_button! Name: elevator_button");
	}
}

static void ZPONoexitH2_OnLabElevatorCalled(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_RideLabElevator();
}

/**
 * Phase: 8.1 - Ride lab elevator
 * Summary: Hold in the elevator until it reaches the bottom.
 * Entity: path_track
 * Bot action: MOVETO
 * Confirmation: The elevator passes the bottom track node.
 */
static void ZPONoexitH2_RideLabElevator()
{
	ZPONoexitH2_ChatMsgSurvivors("Wait for the elevator to reach the bottom!");

	int track = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "track2");

	if (track != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { -442.9, 886.4, -1568.0 };
		NavBotZPSModInterface.ResetObjective();
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		HookSingleEntityOutput(track, "OnPass", ZPONoexitH2_OnLabElevatorArrived, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find path_track! Name: track2");
	}
}

static void ZPONoexitH2_OnLabElevatorArrived(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_PullLever();
}

/**
 * Phase: 9 - Pull lever
 * Summary: Pull the bucket transport lever.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPONoexitH2_PullLever()
{
	ZPONoexitH2_ChatMsgSurvivors("Pull the lever!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "bucket_button");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		HookSingleEntityOutput(button, "OnPressed", ZPONoexitH2_OnLeverPulled, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find func_button! Name: bucket_button");
	}
}

static void ZPONoexitH2_OnLeverPulled(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_WaitForPipeDrop();
}

/**
 * Phase: 10 - Wait for pipe drop
 * Summary: Wait for the pipe drop.
 * Entity: func_breakable
 * Bot action: MOVETO
 * Confirmation: The lower pipe barrier is broken.
 */
static void ZPONoexitH2_WaitForPipeDrop()
{
	ZPONoexitH2_ChatMsgSurvivors("Wait for the pipe drop!");

	int pipe = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "breakpipe_down");

	if (pipe != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { -441.2, 3836.7, -2933.0 };
		NavBotZPSModInterface.ResetObjective();
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		HookSingleEntityOutput(pipe, "OnBreak", ZPONoexitH2_OnPipeBroken, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find func_breakable! Name: breakpipe_down");
	}
}

static void ZPONoexitH2_OnPipeBroken(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_ApproachFinalDoor();
}

/**
 * Phase: 11 - Approach final door
 * Summary: Hold at the final door until it opens.
 * Entity: func_door
 * Bot action: MOVETO
 * Confirmation: The final door is fully open.
 */
static void ZPONoexitH2_ApproachFinalDoor()
{
	ZPONoexitH2_ChatMsgSurvivors("Pipe is open, get to the final door!");

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "final_door");

	if (door != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { -1376.4, 4075.6, -2672.0 };
		NavBotZPSModInterface.ResetObjective();
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		HookSingleEntityOutput(door, "OnFullyOpen", ZPONoexitH2_OnFinalDoorOpened, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find func_door! Name: final_door");
	}
}

static void ZPONoexitH2_OnFinalDoorOpened(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_CloseBlastDoors();
}

/**
 * Phase: 12 - Close blast doors
 * Summary: Close the final blast doors.
 * Entity: func_rot_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPONoexitH2_CloseBlastDoors()
{
	ZPONoexitH2_ChatMsgSurvivors("Final door is open, close the blast doors!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_rot_button", "final_blastdoor_button");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		HookSingleEntityOutput(button, "OnPressed", ZPONoexitH2_OnBlastDoorsButtonPressed, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find func_rot_button! Name: final_blastdoor_button");
	}
}

static void ZPONoexitH2_OnBlastDoorsButtonPressed(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_WaitForBlastDoors();
}

/**
 * Phase: 12.1 - Wait for blast doors
 * Summary: Hold until the blast doors close.
 * Entity: math_counter
 * Bot action: MOVETO
 * Confirmation: The blast door counter reaches its maximum.
 */
static void ZPONoexitH2_WaitForBlastDoors()
{
	ZPONoexitH2_ChatMsgSurvivors("Wait for the blast doors to close!");

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "final_blastdoors_counter");

	if (counter != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { -1645.5, 4074.0, -2672.0 };
		NavBotZPSModInterface.ResetObjective();
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		HookSingleEntityOutput(counter, "OnHitMax", ZPONoexitH2_OnBlastDoorsClosed, true);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find math_counter! Name: final_blastdoors_counter");
	}
}

static void ZPONoexitH2_OnBlastDoorsClosed(const char[] output, int caller, int activator, float delay)
{
	ZPONoexitH2_CallEscapeElevator();
}

/**
 * Phase: 13 - Call escape elevator
 * Summary: Start the escape elevator.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPONoexitH2_CallEscapeElevator()
{
	ZPONoexitH2_ChatMsgSurvivors("Blast doors are shut, start the escape elevator!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "final_elevator_button");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	}
	else
	{
		LogError("zpo_noexit_h2: Failed to find func_button! Name: final_elevator_button");
	}
}
