/**
 * zpo_blackbird_v4.sp
 *
 * NavBot ZPS objective support module for the zpo_blackbird_v4 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.3.1
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: {good / usable / partially complete / unusable}
 *
 * Issues: {description of things that do not work, or "none known"}
 */

static bool s_bPollingDoorDestroyed;
static bool s_bCratesPushed;
static bool s_bUnitPushed;

void ZPOBlackbird_Init()
{
	g_ThinkFunc = ZPOBlackbird_Think;

	s_bPollingDoorDestroyed = false;
	s_bCratesPushed = false;
	s_bUnitPushed = false;

	ZPOBlackbird_ActivateGetInside();
}

void ZPOBlackbird_Think()
{
	if (s_bPollingDoorDestroyed)
	{
		ZPOBlackbird_PollDoorDestroyed();
	}
}

/**
 * Phase: 0 - Get inside the club
 * Summary: Wait for the entry route to be picked.
 * Entity: logic_case, func_button
 * Bot action: USE_BUTTON (garage route only)
 * Confirmation: paths's OnCase02, or filGarageDoor's OnPass.
 */
static void ZPOBlackbird_ActivateGetInside()
{
	int paths = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_case", "paths");

	if (paths == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find paths logic_case!");
		return;
	}

	HookSingleEntityOutput(paths, "OnCase01", ZPOBlackbird_OnGarageRouteActive, true);
	HookSingleEntityOutput(paths, "OnCase02", ZPOBlackbird_ActivatePowerOn, true);
}

// Garage route: open the garage door.
static void ZPOBlackbird_OnGarageRouteActive(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "garagedoor_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find garagedoor_button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	int filter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "filter_activator_team", "filGarageDoor");

	if (filter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find filGarageDoor filter_activator_team!");
		return;
	}

	HookSingleEntityOutput(filter, "OnPass", ZPOBlackbird_ActivatePowerOn, true);
}

/**
 * Phase: 1 - Turn on the power
 * Summary: Bot presses the power button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: filPwr's OnPass.
 */
static void ZPOBlackbird_ActivatePowerOn(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "club_pwr");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find club_pwr func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	int filter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "filter_activator_team", "filPwr");

	if (filter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find filPwr filter_activator_team!");
		return;
	}

	HookSingleEntityOutput(filter, "OnPass", ZPOBlackbird_OnPowerOn, true);
}

// Confirms Phase 1.
static void ZPOBlackbird_OnPowerOn(const char[] output, int caller, int activator, float delay)
{
	CreateTimer(16.0, ZPOBlackbird_OnMusicButtonUnlocked, _, TIMER_FLAG_NO_MAPCHANGE);
}

// sound_button unlocks 16s after filPwr's OnPass - see ActivatePowerOn's
// Confirmation.
static Action ZPOBlackbird_OnMusicButtonUnlocked(Handle timer)
{
	ZPOBlackbird_ActivateMusicOff();
	return Plugin_Stop;
}

/**
 * Phase: 2 - Turn off the music
 * Summary: Bot presses the button that stops the club music.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: filMusic's OnPass.
 */
static void ZPOBlackbird_ActivateMusicOff()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "sound_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find sound_button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	int filter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "filter_activator_team", "filMusic");

	if (filter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find filMusic filter_activator_team!");
		return;
	}

	HookSingleEntityOutput(filter, "OnPass", ZPOBlackbird_OnMusicOff, true);
}

// transmitter_door unlocks 4s after filMusic's OnPass.
static void ZPOBlackbird_OnMusicOff(const char[] output, int caller, int activator, float delay)
{
	CreateTimer(4.0, ZPOBlackbird_ActivateCheckTransmitter, _, TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * Phase: 3 - Check the transmitter
 * Summary: Bot moves to the transmitter to check it.
 * Entity: trigger_multiple
 * Bot action: MOVETO
 * Confirmation: filTransmitter's OnPass.
 */
static Action ZPOBlackbird_ActivateCheckTransmitter(Handle timer)
{
	float goal[3] = { -260.5, 666.8, 400.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int filter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "filter_activator_team", "filTransmitter");

	if (filter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find filTransmitter filter_activator_team!");
		return Plugin_Stop;
	}

	HookSingleEntityOutput(filter, "OnPass", ZPOBlackbird_ActivateFindParts, true);
	return Plugin_Stop;
}

/**
 * Phase: 4 - Find parts
 * Summary: Bot presses the relocated part button.
 * Entity: logic_case, func_button
 * Bot action: USE_BUTTON
 * Confirmation: filPartGet's OnPass.
 */
static void ZPOBlackbird_ActivateFindParts(const char[] output, int caller, int activator, float delay)
{
	int partTele = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_case", "partTele");

	if (partTele == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find partTele logic_case!");
		return;
	}

	HookSingleEntityOutput(partTele, "OnCase01", ZPOBlackbird_OnPartsRelocated, true);
	HookSingleEntityOutput(partTele, "OnCase02", ZPOBlackbird_OnPartsRelocated, true);
	HookSingleEntityOutput(partTele, "OnCase03", ZPOBlackbird_OnPartsRelocated, true);
	HookSingleEntityOutput(partTele, "OnCase04", ZPOBlackbird_OnPartsRelocated, true);
	HookSingleEntityOutput(partTele, "OnCase05", ZPOBlackbird_OnPartsRelocated, true);
	HookSingleEntityOutput(partTele, "OnCase06", ZPOBlackbird_OnPartsRelocated, true);
}

// Fires once the part button has been relocated.
static void ZPOBlackbird_OnPartsRelocated(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "transParts_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find transParts_button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	int filter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "filter_activator_team", "filPartGet");

	if (filter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find filPartGet filter_activator_team!");
		return;
	}

	HookSingleEntityOutput(filter, "OnPass", ZPOBlackbird_OnPartsFound, true);
}

// Confirms Phase 4.
static void ZPOBlackbird_OnPartsFound(const char[] output, int caller, int activator, float delay)
{
	CreateTimer(5.1, ZPOBlackbird_OnRepairButtonUnlocked, _, TIMER_FLAG_NO_MAPCHANGE);
}

// transmitterRepair unlocks 5.1s after filPartGet's OnPass - see
// ActivateFindParts's Confirmation.
static Action ZPOBlackbird_OnRepairButtonUnlocked(Handle timer)
{
	ZPOBlackbird_ActivateRepairTransmitter("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
	return Plugin_Stop;
}

/**
 * Phase: 5 - Repair the transmitter
 * Summary: Bot presses the repair button and holds position until repaired.
 * Entity: func_button, trigger_multiple, logic_timer
 * Bot action: USE_BUTTON, then MOVETO
 * Confirmation: repairTimer's OnTimer. repairChk's OnEndTouchAll restarts
 *   it early.
 */
static void ZPOBlackbird_ActivateRepairTransmitter(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "transmitterRepair");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find transmitterRepair func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	int filter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "filter_activator_team", "filRepair");

	if (filter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find filRepair filter_activator_team!");
		return;
	}

	HookSingleEntityOutput(filter, "OnPass", ZPOBlackbird_OnRepairStarted, true);
}

// Fires once the repair button has been pressed.
static void ZPOBlackbird_OnRepairStarted(const char[] output, int caller, int activator, float delay)
{
	float goal[3] = { -267.0, 652.0, 387.5 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int timer = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_timer", "repairTimer");

	if (timer == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find repairTimer logic_timer!");
		return;
	}

	UnhookSingleEntityOutput(timer, "OnTimer", ZPOBlackbird_ActivateDestroyDoor);
	HookSingleEntityOutput(timer, "OnTimer", ZPOBlackbird_ActivateDestroyDoor, true);

	int hold = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "repairChk");

	if (hold == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find repairChk trigger_multiple!");
		return;
	}

	HookSingleEntityOutput(hold, "OnEndTouchAll", ZPOBlackbird_ActivateRepairTransmitter, true);
}

// Phase 6 prerequisite - door blocking the radio button.
static void ZPOBlackbird_ActivateDestroyDoor(const char[] output, int caller, int activator, float delay)
{
	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_door_rotating", "doordmgblock");

	if (door == INVALID_ENT_REFERENCE)
	{
		ZPOBlackbird_ActivateCallForHelp();
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(door);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);

	s_bPollingDoorDestroyed = true;
}

// Polls for doordmgblock ceasing to exist, in place of an OnBreak hook.
static void ZPOBlackbird_PollDoorDestroyed()
{
	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_door_rotating", "doordmgblock");

	if (door != INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_bPollingDoorDestroyed = false;
	ZPOBlackbird_ActivateCallForHelp();
}

/**
 * Phase: 6 - Call for help
 * Summary: Bot presses the radio button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: radioButton's own OnPressed.
 */
static void ZPOBlackbird_ActivateCallForHelp()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "radioButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find radioButton func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOBlackbird_OnHelpCalled, true);
}

static void ZPOBlackbird_OnHelpCalled(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	int relay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "currentPath_relay");

	if (relay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find currentPath_relay logic_relay!");
		return;
	}

	HookSingleEntityOutput(relay, "OnTrigger", ZPOBlackbird_ActivatePushCrates, true);
}

/**
 * Phase: 7 - Push the crates
 * Summary: Push the crates to the roof edge.
 * Entity: trigger_multiple, path_track
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: crates_path5's OnPass.
 */
static void ZPOBlackbird_ActivatePushCrates(const char[] output, int caller, int activator, float delay)
{
	int cratesEnd = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "crates_path5");

	if (cratesEnd == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find crates_path5 path_track!");
		return;
	}

	HookSingleEntityOutput(cratesEnd, "OnPass", ZPOBlackbird_ActivatePushUnit, true);

	int unitEnd = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "unit_path5");

	if (unitEnd == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find unit_path5 path_track!");
		return;
	}

	HookSingleEntityOutput(unitEnd, "OnPass", ZPOBlackbird_OnUnitPushed, true);

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "pushCrateTrigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find pushCrateTrigger trigger_multiple!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}

/**
 * Phase: 8 - Push the unit
 * Summary: Push the unit to block the ladder.
 * Entity: trigger_multiple, path_track
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: unit_path5's OnPass.
 */
static void ZPOBlackbird_ActivatePushUnit(const char[] output, int caller, int activator, float delay)
{
	s_bCratesPushed = true;

	if (s_bUnitPushed)
	{
		ZPOBlackbird_ClearRoof();
		return;
	}

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "pushUnitTrigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_blackbird_v4: Failed to find pushUnitTrigger trigger_multiple!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}

// Fires when the unit reaches the end of its track.
static void ZPOBlackbird_OnUnitPushed(const char[] output, int caller, int activator, float delay)
{
	s_bUnitPushed = true;

	if (s_bCratesPushed)
	{
		ZPOBlackbird_ClearRoof();
	}
}

/**
 * Phase: 9 - Clear the roof
 * Summary: Roam and kill zombies.
 * Entity: none
 * Bot action: none (objective reset)
 * Confirmation: The round ends.
 */
static void ZPOBlackbird_ClearRoof()
{
	NavBotZPSModInterface.ResetObjective();
}
