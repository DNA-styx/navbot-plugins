/**
 * zpo_abandoned_base_r2.sp
 *
 * NavBot ZPS objective support module for the zpo_abandoned_base_r2 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.3.1
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

void ZPOAbandonedBaseR2_Init()
{
	g_ThinkFunc = ZPOAbandonedBaseR2_Think;

	ZPOAbandonedBaseR2_ActivatePowerButton();
}

void ZPOAbandonedBaseR2_Think()
{
	// Left empty until a phase needs per-tick polling.
}

/**
 * Phase: 0 - Press power button
 * Summary: Bot presses the button that restores power to the base.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: Power button pressed.
 */
static void ZPOAbandonedBaseR2_ActivatePowerButton()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "Bot?o Energia");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find Bot?o Energia func_button!");
		return;
	}

	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOAbandonedBaseR2_OnPowerButtonPressed, true);
}

/**
 * Phase: 1 - Wait for gate to open
 * Summary: Bot waits for the gate to start opening.
 * Entity: func_door
 * Bot action: none
 * Confirmation: Gate has started opening.
 */
static void ZPOAbandonedBaseR2_OnPowerButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int gate = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "Port?o Principal 2");

	if (gate == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find Port?o Principal 2 (Gate) func_door!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	HookSingleEntityOutput(gate, "OnOpen", ZPOAbandonedBaseR2_OnGateOpen, true);
}

/**
 * Phase: 2 - Open MainDoor
 * Summary: Bot presses the button that opens MainDoor.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: MainDoor button pressed.
 */
static void ZPOAbandonedBaseR2_OnGateOpen(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "portao1");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find portao1 func_button!");
		return;
	}

	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOAbandonedBaseR2_OnMainDoorButtonPressed, true);
}

/**
 * Phase: 3 - Wait for MainDoor to open
 * Summary: Bot waits for MainDoor to fully open.
 * Entity: func_door
 * Bot action: none
 * Confirmation: MainDoor fully open.
 */
static void ZPOAbandonedBaseR2_OnMainDoorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int mainDoor = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "Port?o Central 1");

	if (mainDoor == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find Port?o Central 1 (MainDoor) func_door!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	HookSingleEntityOutput(mainDoor, "OnFullyOpen", ZPOAbandonedBaseR2_OnMainDoorOpened, true);
}

/**
 * Phase: 4 - Press security button
 * Summary: Bot presses the button in the security room.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: Security button pressed.
 */
static void ZPOAbandonedBaseR2_OnMainDoorOpened(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "Bot?o Sala 1");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find Bot?o Sala 1 func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOAbandonedBaseR2_OnSecurityButtonPressed, true);
}

/**
 * Phase: 5 - Wait for green room timer
 * Summary: Bot idles until the green room timer elapses.
 * Entity: none
 * Bot action: none
 * Confirmation: 66s timer elapsed.
 */
static void ZPOAbandonedBaseR2_OnSecurityButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// triggerlockeddoor is enabled by this same button press, 66s delay.
	// There is no native to hook an entity input, so a timer bridges the gap.
	CreateTimer(66.0, ZPOAbandonedBaseR2_OnGreenRoomTriggerEnabled, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * Phase: 6 - Move to green room trigger
 * Summary: Bot moves to the green room trigger.
 * Entity: trigger_once
 * Bot action: MOVETO trigger origin
 * Confirmation: Green room trigger fired.
 */
static void ZPOAbandonedBaseR2_OnGreenRoomTriggerEnabled(Handle timer)
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "triggerlockeddoor");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find triggerlockeddoor trigger_once!");
		return;
	}

	float goal[3];
	GetEntPropVector(trigger, Prop_Data, "m_vecAbsOrigin", goal);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	HookSingleEntityOutput(trigger, "OnTrigger", ZPOAbandonedBaseR2_OnGreenRoomReached, true);
}

/**
 * Phase: 7 - Break basement wood
 * Summary: Bot destroys the wooden board blocking the basement.
 * Entity: func_breakable
 * Bot action: DESTROY_ENTITY
 * Confirmation: Basement wood broken.
 */
static void ZPOAbandonedBaseR2_OnGreenRoomReached(const char[] output, int caller, int activator, float delay)
{
	int wood = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "basement wood");

	if (wood == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find basement wood func_breakable!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(wood);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
	HookSingleEntityOutput(wood, "OnBreak", ZPOAbandonedBaseR2_OnBasementWoodBroken, true);
}

/**
 * Phase: 8 - Press elevator button
 * Summary: Bot presses the elevator call button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: Elevator button pressed.
 */
static void ZPOAbandonedBaseR2_OnBasementWoodBroken(const char[] output, int caller, int activator, float delay)
{
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 1570);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find func_button! Hammer ID: 1570");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOAbandonedBaseR2_OnElevatorButtonPressed, true);
}

/**
 * Phase: 9 - Break vent cover
 * Summary: Bot destroys the Metal Porao vent cover (the 1hp breakable behind it breaks with it).
 * Entity: func_breakable
 * Bot action: DESTROY_ENTITY
 * Confirmation: Vent cover broken.
 */
static void ZPOAbandonedBaseR2_OnElevatorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int vent = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "Metal Porao");

	if (vent == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find Metal Porao func_breakable!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(vent);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
	HookSingleEntityOutput(vent, "OnBreak", ZPOAbandonedBaseR2_OnVentBroken, true);
}

/**
 * Phase: 10 - Move to control room trigger
 * Summary: Bot moves to the control room keypad trigger.
 * Entity: trigger_once
 * Bot action: MOVETO trigger origin
 * Confirmation: Control room trigger fired.
 */
static void ZPOAbandonedBaseR2_OnVentBroken(const char[] output, int caller, int activator, float delay)
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "Teclado Sala de Controle");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find Teclado Sala de Controle trigger_once!");
		return;
	}

	float goal[3];
	GetEntPropVector(trigger, Prop_Data, "m_vecAbsOrigin", goal);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	HookSingleEntityOutput(trigger, "OnTrigger", ZPOAbandonedBaseR2_OnControlRoomTriggered, true);
}

/**
 * Phase: 11 - Wait for the C4 blast
 * Summary: Bot idles while the scripted C4 blast breaks the control room glass.
 * Entity: func_breakable
 * Bot action: none
 * Confirmation: Control room glass broken.
 */
static void ZPOAbandonedBaseR2_OnControlRoomTriggered(const char[] output, int caller, int activator, float delay)
{
	int glass = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", 1559);

	if (glass == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find func_breakable! Hammer ID: 1559");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	HookSingleEntityOutput(glass, "OnBreak", ZPOAbandonedBaseR2_OnControlRoomGlassBroken, true);
}

/**
 * Phase: 12 - Investigate the gate
 * Summary: Bot moves to the gate trigger to investigate it.
 * Entity: trigger_once
 * Bot action: MOVETO fixed position
 * Confirmation: Gate trigger fired.
 */
static void ZPOAbandonedBaseR2_OnControlRoomGlassBroken(const char[] output, int caller, int activator, float delay)
{
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", 247502);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find trigger_once! Hammer ID: 247502");
		return;
	}

	float goal[3] = { 1210.0, 6909.0, 89.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	HookSingleEntityOutput(trigger, "OnTrigger", ZPOAbandonedBaseR2_OnGateTriggered, true);
}

/**
 * Phase: 13 - Press prison button
 * Summary: Bot presses the button that unlocks the prison door.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: Prison button pressed.
 */
static void ZPOAbandonedBaseR2_OnGateTriggered(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// The gate trigger unlocks Bot?o prisao by input, 2s delay.
	// There is no native to hook an entity input, so a timer bridges the gap.
	CreateTimer(2.0, ZPOAbandonedBaseR2_OnPrisonButtonUnlocked, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

static void ZPOAbandonedBaseR2_OnPrisonButtonUnlocked(Handle timer)
{
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 1220);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find func_button! Hammer ID: 1220");
		return;
	}

	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOAbandonedBaseR2_OnPrisonButtonPressed, true);
}

/**
 * Phase: 14 - Wait for prison door to open
 * Summary: Bot waits for the prison door to fully open.
 * Entity: func_door
 * Bot action: none
 * Confirmation: Prison door fully open.
 */
static void ZPOAbandonedBaseR2_OnPrisonButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", 1218);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find func_door! Hammer ID: 1218");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	HookSingleEntityOutput(door, "OnFullyOpen", ZPOAbandonedBaseR2_OnPrisonDoorOpened, true);
}

/**
 * Phase: 15 - Press the three cell buttons
 * Summary: Press the three cell buttons in any order.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: all three buttons pressed.
 */
static const int CELL_BUTTON_HAMMERIDS[3] = { 1275, 1277, 1279 };
static bool s_CellButtonDone[3];

static void ZPOAbandonedBaseR2_OnPrisonDoorOpened(const char[] output, int caller, int activator, float delay)
{
	s_CellButtonDone[0] = false;
	s_CellButtonDone[1] = false;
	s_CellButtonDone[2] = false;

	for (int i = 0; i < 3; i++)
	{
		int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", CELL_BUTTON_HAMMERIDS[i]);

		if (button == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_abandoned_base_r2: Failed to find func_button! Hammer ID: %i", CELL_BUTTON_HAMMERIDS[i]);
			continue;
		}

		HookSingleEntityOutput(button, "OnPressed", ZPOAbandonedBaseR2_OnCellButtonPressed, true);
	}

	ZPOAbandonedBaseR2_TargetNextCellButton();
}

static void ZPOAbandonedBaseR2_OnCellButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int hammerid = GetEntProp(caller, Prop_Data, "m_iHammerID");

	for (int i = 0; i < 3; i++)
	{
		if (hammerid == CELL_BUTTON_HAMMERIDS[i])
		{
			s_CellButtonDone[i] = true;
		}
	}

	ZPOAbandonedBaseR2_TargetNextCellButton();
}

// A missing button counts as done.
static void ZPOAbandonedBaseR2_TargetNextCellButton()
{
	for (int i = 0; i < 3; i++)
	{
		if (s_CellButtonDone[i])
		{
			continue;
		}

		int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", CELL_BUTTON_HAMMERIDS[i]);

		if (button == INVALID_ENT_REFERENCE)
		{
			s_CellButtonDone[i] = true;
			continue;
		}

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		return;
	}

	ZPOAbandonedBaseR2_ActivateFindKeycard();
}

/**
 * Phase: 16 - Find the keycard
 * Summary: Bot presses the button that picks up the keycard.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: Keycard button pressed.
 */
static void ZPOAbandonedBaseR2_ActivateFindKeycard()
{
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 1283);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find func_button! Hammer ID: 1283");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOAbandonedBaseR2_OnKeycardFound, true);
}

/**
 * Phase: 17 - Reset objective
 * Summary: Objective resets once the keycard is found.
 * Entity: func_button
 * Bot action: none
 * Confirmation: Keycard button pressed.
 */
static void ZPOAbandonedBaseR2_OnKeycardFound(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
}
