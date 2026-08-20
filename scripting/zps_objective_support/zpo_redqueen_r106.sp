/**
 * zpo_redqueen_r106.sp
 *
 * NavBot ZPS objective support module for the zpo_redqueen_r106 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.4.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: WIP - Exit spawn, find keycard and open first door.
 *
 * Issues: 
 */

void ZPORedQueenR106_Init()
{
	g_ThinkFunc = ZPORedQueenR106_Think;

	ZPORedQueenR106_ActivateOpenSpawnDoor();
}

void ZPORedQueenR106_Think()
{

}

/**
 * Phase: 0 - OpenSpawnDoor
 * Summary: Bot opens the spawn door.
 * Entity: trigger_once; opens door1
 * Bot action: MOVETO trigger
 * Confirmation: trigger's OnStartTouch, then a timer matched to the door's opening time
 */
void ZPORedQueenR106_ActivateOpenSpawnDoor()
{
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", 1560);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find spawn door trigger_once! Hammer ID: 1560");
		return;
	}

	float goal[3];
	goal[0] = 288.0;
	goal[1] = 288.0;
	goal[2] = 108.0;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPORedQueenR106_OnSpawnDoorTriggerTouched, true);
}

void ZPORedQueenR106_OnSpawnDoorTriggerTouched(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	CreateTimer(10.0, ZPORedQueenR106_Timer_SpawnDoorOpen, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

void ZPORedQueenR106_Timer_SpawnDoorOpen(Handle timer)
{
	ZPORedQueenR106_ActivateGetKeycard();
}

/**
 * Phase: 1 - GetKeycard
 * Summary: Bot picks up the keycard.
 * Entity: trigger_once
 * Bot action: MOVETO trigger
 * Confirmation: trigger's OnStartTouch output
 */
void ZPORedQueenR106_ActivateGetKeycard()
{
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", 1326);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find keycard trigger_once! Hammer ID: 1326");
		return;
	}

	float goal[3];
	goal[0] = 1356.5;
	goal[1] = -272.5;
	goal[2] = -950.5;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPORedQueenR106_OnKeycardPickedUp, true);
}

void ZPORedQueenR106_OnKeycardPickedUp(const char[] output, int caller, int activator, float delay)
{
	ZPORedQueenR106_ActivateUseKeycardOnDoor();
}

/**
 * Phase: 2 - UseKeycardOnDoor
 * Summary: Bot uses the keycard on the door.
 * Entity: door3tr (trigger_once); opens door3 (func_door)
 * Bot action: MOVETO trigger
 * Confirmation: door3tr's OnStartTouch, then a timer matched to the door's scripted open delay
 */
void ZPORedQueenR106_ActivateUseKeycardOnDoor()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "door3tr");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find door3tr trigger_once!");
		return;
	}

	float goal[3];
	goal[0] = 1518.9;
	goal[1] = -1500.0;
	goal[2] = -127.0;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPORedQueenR106_OnDoor3trTouched, true);
}

void ZPORedQueenR106_OnDoor3trTouched(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	CreateTimer(5.0, ZPORedQueenR106_Timer_Door3Opening, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

void ZPORedQueenR106_Timer_Door3Opening(Handle timer)
{

}
