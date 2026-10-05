/**
 * zpo_dayofthedead_v3.sp
 *
 * NavBot ZPS objective support module for the zpo_dayofthedead_v3 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.3.4
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: Usable
 *
 * Issues: In testing
 */

void ZPODayOfTheDeadV3_Init()
{
	g_ThinkFunc = ZPODayOfTheDeadV3_Think;

	ZPODayOfTheDeadV3_ActivateFindKeyCard();
}

void ZPODayOfTheDeadV3_Think()
{
	// Left empty until a phase needs per-tick polling.
}

/**
 * Phase: 0 - FindKeyCard
 * Summary: Press the button on the keycard prop to pick it up.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
static void ZPODayOfTheDeadV3_ActivateFindKeyCard()
{
	const int hammerid = 223854;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_dayofthedead_v3: Failed to find keycard func_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPODayOfTheDeadV3_OnKeyCardTaken, true);
}

/**
 * Phase: 1 - SwitchOnPower
 * Summary: Press the control room switch to turn on the power.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the switch's OnPressed output
 */
static void ZPODayOfTheDeadV3_OnKeyCardTaken(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "ControlRoom_Switch");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_dayofthedead_v3: Failed to find ControlRoom_Switch func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPODayOfTheDeadV3_OnPowerSwitched, true);
}

/**
 * Phase: 2 - WaitForCargoDoor
 * Summary: Move to a staging position and wait for the cargo door.
 * Entity: none (fixed staging position)
 * Bot action: MOVETO
 * Confirmation: cargo door's OnOpen output
 */
static void ZPODayOfTheDeadV3_OnPowerSwitched(const char[] output, int caller, int activator, float delay)
{
	float goal[3] = { 5743.0, 258.0, -812.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "ControlRoom_CargoDoor");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_dayofthedead_v3: Failed to find ControlRoom_CargoDoor func_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnOpen", ZPODayOfTheDeadV3_OnCargoDoorOpening, true);
}

/**
 * Phase: 3 - PressLiftButton
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
static void ZPODayOfTheDeadV3_OnCargoDoorOpening(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "Elevator_Button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_dayofthedead_v3: Failed to find Elevator_Button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPODayOfTheDeadV3_OnLiftButtonPressed, true);
}

/**
 * Phase: 4 - FindIED
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
static void ZPODayOfTheDeadV3_OnLiftButtonPressed(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 345471;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_dayofthedead_v3: Failed to find IED func_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPODayOfTheDeadV3_OnIEDFound, true);
}

/**
 * Phase: 5 - PlantIED
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
static void ZPODayOfTheDeadV3_OnIEDFound(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "IED_Placement_Button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_dayofthedead_v3: Failed to find IED_Placement_Button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPODayOfTheDeadV3_OnIEDArmed, true);
}

/**
 * Phase: 6 - WaitForC4Door
 * Entity: none (fixed staging position)
 * Bot action: MOVETO
 * Confirmation: C4 door's OnOpen output
 */
static void ZPODayOfTheDeadV3_OnIEDArmed(const char[] output, int caller, int activator, float delay)
{
	float goal[3] = { 3571.462158, -131.787628, -939.968750 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "C4_Door");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_dayofthedead_v3: Failed to find C4_Door func_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnOpen", ZPODayOfTheDeadV3_OnIEDPlanted, true);
}

/**
 * Phase: 7 - FindKeys
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
static void ZPODayOfTheDeadV3_OnIEDPlanted(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 224297;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_dayofthedead_v3: Failed to find keys func_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPODayOfTheDeadV3_OnKeysFound, true);
}

/**
 * Phase: 8 - FuelHelicopter
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output starts a 30s timer for the on-screen countdown
 */
static void ZPODayOfTheDeadV3_OnKeysFound(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "Chopper_Gas_Button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_dayofthedead_v3: Failed to find Chopper_Gas_Button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPODayOfTheDeadV3_OnFueled, true);
}

static void ZPODayOfTheDeadV3_OnFueled(const char[] output, int caller, int activator, float delay)
{
	CreateTimer(30.0, ZPODayOfTheDeadV3_OnCountdownTimer);
}

/**
 * Phase: 9 - BoardHelicopter
 * Entity: none (fixed boarding position)
 * Bot action: MOVETO
 * Confirmation: none - terminal phase, objective is not reset
 */
static void ZPODayOfTheDeadV3_OnCountdownTimer(Handle timer, any data)
{
	float goal[3] = { -31.0, -213.0, 160.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}
