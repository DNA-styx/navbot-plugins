/**
 * zpo_redqueen_r106.sp
 *
 * NavBot ZPS objective support module for the zpo_redqueen_r106 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.5.1
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: WIP - Exit spawn, find keycard and open first door.
 *
 * Issues: Bots not restocking on ammo, not able to find keycard
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

void ZPORedQueenR106_Init()
{
	g_ThinkFunc = ZPORedQueenR106_Think;

	ZPORedQueenR106_ActivateOpenSpawnDoor();
}

void ZPORedQueenR106_Think()
{
	// Left empty until a phase needs per-tick polling.
}

/**
 * Phase: 0 - OpenSpawnDoor
 * Summary: Bot opens the spawn door.
 * Entity: trigger_once, func_door
 * Bot action: MOVETO trigger
 * Confirmation: trigger touched, then a timer matched to the door's opening time
 */
static void ZPORedQueenR106_ActivateOpenSpawnDoor()
{
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", 1560);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find spawn door trigger_once! Hammer ID: %i", 1560);
	}
	else
	{
		float goal[3] = { 288.0, 288.0, 108.0 };

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

		HookSingleEntityOutput(trigger, "OnStartTouch", ZPORedQueenR106_OnSpawnDoorTriggerTouched, true);
	}
}

static void ZPORedQueenR106_OnSpawnDoorTriggerTouched(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	CreateTimer(10.0, ZPORedQueenR106_Timer_SpawnDoorOpen, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

static void ZPORedQueenR106_Timer_SpawnDoorOpen(Handle timer)
{
	ZPORedQueenR106_ActivateGetKeycard();
}

/**
 * Phase: 1 - GetKeycard
 * Summary: Bot picks up the keycard.
 * Entity: trigger_once
 * Bot action: MOVETO trigger
 * Confirmation: trigger touched
 */
static void ZPORedQueenR106_ActivateGetKeycard()
{
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", 1326);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find keycard trigger_once! Hammer ID: %i", 1326);
	}
	else
	{
		float goal[3] = { 1356.5, -272.5, -950.5 };

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

		HookSingleEntityOutput(trigger, "OnStartTouch", ZPORedQueenR106_OnKeycardPickedUp, true);
	}
}

static void ZPORedQueenR106_OnKeycardPickedUp(const char[] output, int caller, int activator, float delay)
{
	ZPORedQueenR106_ActivateUseKeycardOnDoor();
}

/**
 * Phase: 2 - UseKeycardOnDoor
 * Summary: Bot uses the keycard on the door.
 * Entity: trigger_once, func_door
 * Bot action: MOVETO trigger
 * Confirmation: trigger touched, then a timer matched to the door's scripted open delay
 */
static void ZPORedQueenR106_ActivateUseKeycardOnDoor()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "door3tr");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find door3tr trigger_once!");
	}
	else
	{
		float goal[3] = { 1518.9, -1500.0, -127.0 };

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

		HookSingleEntityOutput(trigger, "OnStartTouch", ZPORedQueenR106_OnDoor3trTouched, true);
	}
}

static void ZPORedQueenR106_OnDoor3trTouched(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	CreateTimer(5.0, ZPORedQueenR106_Timer_Door3Opening, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

static void ZPORedQueenR106_Timer_Door3Opening(Handle timer)
{
	ZPORedQueenR106_ActivateHackPanel();
}

/**
 * Phase: 3 - HackPanel
 * Summary: Bot hacks the panel by holding the capture zone.
 * Entity: trigger_capturepoint_zp
 * Bot action: MOVETO capture zone
 * Confirmation: capture completed
 */
static void ZPORedQueenR106_ActivateHackPanel()
{
	int capturepoint = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", 1565);

	if (capturepoint == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find hack panel trigger_capturepoint_zp! Hammer ID: %i", 1565);
	}
	else
	{
		float goal[3] = { 1813.1, -2807.8, -141.8 };

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

		HookSingleEntityOutput(capturepoint, "OnHumanCaptureCompleted", ZPORedQueenR106_OnHackPanelCaptured, true);
	}
}

static void ZPORedQueenR106_OnHackPanelCaptured(const char[] output, int caller, int activator, float delay)
{
	ZPORedQueenR106_ActivateApproachDoor4();
}

/**
 * Phase: 4 - ApproachDoor4
 * Summary: Bot moves toward door4 while it opens.
 * Entity: func_door
 * Bot action: MOVETO fixed position
 * Confirmation: a timer matched to door4end's scripted open delay
 */
static void ZPORedQueenR106_ActivateApproachDoor4()
{
	float goal[3] = { 3056.1, -2915.5, -192.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	CreateTimer(60.0, ZPORedQueenR106_Timer_Door4EndOpening, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

static void ZPORedQueenR106_Timer_Door4EndOpening(Handle timer)
{
	ZPORedQueenR106_ActivateMoveThroughDoor4End();
}

/**
 * Phase: 5 - MoveThroughDoor4End
 * Summary: Bot moves through door4end.
 * Entity: func_door
 * Bot action: MOVETO fixed position
 * Confirmation: none yet - last phase implemented so far
 */
static void ZPORedQueenR106_ActivateMoveThroughDoor4End()
{
	float goal[3] = { 3931.8, -1725.6, -192.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}
