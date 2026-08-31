/**
 * zpo_area41_v7f.sp
 *
 * NavBot ZPS objective support module for the zpo_area41_v7f map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.4.1
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: Partially complete
 *
 * Issues: In testing
 */

static bool s_ToiletFlush;

void ZPOArea41V7F_Init()
{
	g_ThinkFunc = ZPOArea41V7F_Think;
	s_ToiletFlush = false;

	int pathTrack = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "Path_Chinook5");

	if (pathTrack == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find Path_Chinook5 path_track!");
	}
	else
	{
		HookSingleEntityOutput(pathTrack, "OnPass", ZPOArea41V7F_OnChinookExit, true);
	}
}

void ZPOArea41V7F_Think()
{
	// Left empty until a phase needs per-tick polling.
}

/**
 * Phase: 0 - ChinookExit
 * Summary: Moves bots off the Chinook as it passes the exit path point.
 * Entity: path_track
 * Bot action: MOVETO fixed position
 * Confirmation: Path_Chinook5's OnPass
 */
static void ZPOArea41V7F_OnChinookExit(const char[] output, int caller, int activator, float delay)
{
	float goal[3] = { 771.0, -7320.0, 84.0 };

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "MathSurf1");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find MathSurf1 math_counter!");
	}
	else
	{
		HookSingleEntityOutput(counter, "OnHitMax", ZPOArea41V7F_OnToiletDoorUnlocked, true);
	}
}

/**
 * Phase: 1 - ToiletDoorUnlocked
 * Summary: Announces the door, then forces the flush button objective if it hasn't been pressed within 30 seconds.
 * Entity: math_counter, func_button
 * Bot action: USE_BUTTON (fallback only)
 * Confirmation: MathSurf1's OnHitMax; 30s timeout checks the button's press state
 */
static void ZPOArea41V7F_OnToiletDoorUnlocked(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	PrintToChatAll("\x04[NAV]\x01 There's a floater! Flush it!");
	CreateTimer(30.0, ZPOArea41V7F_OnFlushTimeout, .flags = TIMER_FLAG_NO_MAPCHANGE);

	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 730833);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find flush func_button! Hammer ID: 730833");
	}
	else
	{
		HookSingleEntityOutput(button, "OnPressed", ZPOArea41V7F_OnFlushButtonPressed, true);
	}
}

static void ZPOArea41V7F_OnFlushTimeout(Handle timer)
{
	if (s_ToiletFlush)
	{
		return;
	}

	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 730833);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find flush func_button! Hammer ID: 730833");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 2 - FlushButtonPressed
 * Summary: Moves bots to the elevator shaft once the flush button is pressed.
 * Entity: func_button
 * Bot action: MOVETO fixed position
 * Confirmation: flush button's OnPressed
 */
static void ZPOArea41V7F_OnFlushButtonPressed(const char[] output, int caller, int activator, float delay)
{
	s_ToiletFlush = true;

	float goal[3] = { 778.7, -7615.8, 84.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int elevatorTop = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "Path_ElevatorA3");

	if (elevatorTop == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find Path_ElevatorA3 path_track!");
	}
	else
	{
		HookSingleEntityOutput(elevatorTop, "OnPass", ZPOArea41V7F_OnElevatorAtTop, true);
	}
}

/**
 * Phase: 3 - ElevatorAtTop
 * Summary: Moves bots onto the lift once it arrives at the top of its path.
 * Entity: path_track
 * Bot action: MOVETO fixed position
 * Confirmation: Path_ElevatorA3's OnPass
 */
static void ZPOArea41V7F_OnElevatorAtTop(const char[] output, int caller, int activator, float delay)
{
	float goal[3] = { 767.0, -7321.0, 3.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int elevatorBottom = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "Path_ElevatorA1");

	if (elevatorBottom == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find Path_ElevatorA1 path_track!");
	}
	else
	{
		HookSingleEntityOutput(elevatorBottom, "OnPass", ZPOArea41V7F_OnElevatorAtBottom, true);
	}
}

/**
 * Phase: 4 - ElevatorAtBottom
 * Summary: Sends bots to press the tunnel door button once the lift reaches the bottom.
 * Entity: path_track, func_button
 * Bot action: USE_BUTTON
 * Confirmation: Path_ElevatorA1's OnPass
 */
static void ZPOArea41V7F_OnElevatorAtBottom(const char[] output, int caller, int activator, float delay)
{
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 734624);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find tunnel door func_button! Hammer ID: 734624");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOArea41V7F_OnTunnelDoorButtonPressed, true);
}

/**
 * Phase: 5 - TunnelDoorButtonPressed
 * Summary: Waits for the tunnel door to open before the hacking button becomes reachable.
 * Entity: func_button
 * Bot action: none (waits on the door)
 * Confirmation: tunnel door button's OnPressed
 */
static void ZPOArea41V7F_OnTunnelDoorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", 734632);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find Door_Tunnel1! Hammer ID: 734632");
		return;
	}

	HookSingleEntityOutput(door, "OnOpen", ZPOArea41V7F_OnTunnelDoorOpen, true);
}

/**
 * Phase: 6 - TunnelDoorOpen
 * Summary: Sends bots to press the hacking button once the tunnel door opens.
 * Entity: func_door, func_button
 * Bot action: USE_BUTTON
 * Confirmation: Door_Tunnel1's OnOpen
 */
static void ZPOArea41V7F_OnTunnelDoorOpen(const char[] output, int caller, int activator, float delay)
{
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 735463);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find Bt1O func_button! Hammer ID: 735463");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOArea41V7F_OnBt1OPressed, true);
}

/**
 * Phase: 7 - Bt1OPressed
 * Summary: Moves bots on once the hacking button is pressed.
 * Entity: func_button
 * Bot action: MOVETO fixed position
 * Confirmation: Bt1O's OnPressed
 */
static void ZPOArea41V7F_OnBt1OPressed(const char[] output, int caller, int activator, float delay)
{
	float goal[3] = { 2568.0, -7029.0, -958.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int captureTrigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "HackingTrigger1");

	if (captureTrigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_area41_v7f: Failed to find HackingTrigger1 trigger_capturepoint_zp!");
	}
	else
	{
		HookSingleEntityOutput(captureTrigger, "OnHumanCaptureCompleted", ZPOArea41V7F_OnHackingComplete, true);
	}
}

/**
 * Phase: 8 - HackingComplete
 * Summary: Moves bots on once the hacking capture point is taken and the tunnel door opens.
 * Entity: trigger_capturepoint_zp
 * Bot action: MOVETO fixed position
 * Confirmation: HackingTrigger1's OnHumanCaptureCompleted
 */
static void ZPOArea41V7F_OnHackingComplete(const char[] output, int caller, int activator, float delay)
{
	float goal[3] = { 5218.8, -7027.5, -958.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}
