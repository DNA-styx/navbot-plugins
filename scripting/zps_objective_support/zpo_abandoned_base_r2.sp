/**
 * zpo_abandoned_base_r2.sp
 *
 * NavBot ZPS objective support module for the zpo_abandoned_base_r2 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.6.1
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

static void ZPOAbandonedBaseR2_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - Press power button
 * Summary: Bot presses the button that restores power to the base.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: Power button pressed.
 */
static void ZPOAbandonedBaseR2_ActivatePowerButton()
{
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Press the power button!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "Bot?o Energia");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find Bot?o Energia func_button!");
		return;
	}

	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOAbandonedBaseR2_OnPowerButtonPressed, true);

	int gate = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "Port?o Principal 2");

	if (gate == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find Port?o Principal 2 (Gate) func_door!");
		return;
	}

	HookSingleEntityOutput(gate, "OnOpen", ZPOAbandonedBaseR2_OnGateOpen, true);
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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Power's on, wait for the gate!");

	NavBotZPSModInterface.ResetObjective();
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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Gate's open, press the door button!");

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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Wait for the door to open!");

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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Press the security button!");

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
 * Phase: 5 - Wait for armory door to open
 * Summary: Bot waits for the armory door to start opening.
 * Entity: func_door
 * Bot action: none
 * Confirmation: Armory door has started opening.
 */
static void ZPOAbandonedBaseR2_OnSecurityButtonPressed(const char[] output, int caller, int activator, float delay)
{
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Wait for the armory door!");

	int armoryDoor = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", 1955);

	if (armoryDoor == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find func_door! Hammer ID: 1955");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	HookSingleEntityOutput(armoryDoor, "OnOpen", ZPOAbandonedBaseR2_OnArmoryDoorOpen, true);
}

/**
 * Phase: 6 - Move to green room trigger
 * Summary: Bot moves to the green room trigger entity.
 * Entity: trigger_once
 * Bot action: MOVETO ENTITY
 * Confirmation: Green room trigger fired.
 */
static void ZPOAbandonedBaseR2_OnArmoryDoorOpen(const char[] output, int caller, int activator, float delay)
{
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Head for the green room!");

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "triggerlockeddoor");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find triggerlockeddoor trigger_once!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Break through the basement wood!");

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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Press the elevator button!");

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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Break the vent cover!");

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
 * Summary: Bot moves to the control room keypad trigger entity.
 * Entity: trigger_once
 * Bot action: MOVETO ENTITY
 * Confirmation: Control room trigger fired.
 */
static void ZPOAbandonedBaseR2_OnVentBroken(const char[] output, int caller, int activator, float delay)
{
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Head for the control room!");

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "Teclado Sala de Controle");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find Teclado Sala de Controle trigger_once!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Wait for the blast to clear the glass!");

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
 * Summary: Bot moves to the gate trigger entity to investigate it.
 * Entity: trigger_once
 * Bot action: MOVETO ENTITY
 * Confirmation: Gate trigger fired.
 */
static void ZPOAbandonedBaseR2_OnControlRoomGlassBroken(const char[] output, int caller, int activator, float delay)
{
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Go investigate the gate!");

	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", 247502);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find trigger_once! Hammer ID: 247502");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Press the prison button!");

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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Wait for the prison door!");

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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Press the cell buttons!");

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
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Grab the keycard!");

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
 * Phase: 17 - Open the back door
 * Summary: Bot uses its +USE button on the back door.
 * Entity: func_door
 * Bot action: USE_BUTTON
 * Confirmation: Back door has started opening.
 */
static void ZPOAbandonedBaseR2_OnKeycardFound(const char[] output, int caller, int activator, float delay)
{
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Open the back door!");

	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", 1680);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find func_door! Hammer ID: 1680");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(door);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(door, "OnOpen", ZPOAbandonedBaseR2_OnBackDoorOpen, true);
}

/**
 * Phase: 18 - Press the pit button
 * Summary: Bot presses the pit button that unlocks the nested final doors.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: Pit button pressed.
 */
static void ZPOAbandonedBaseR2_OnBackDoorOpen(const char[] output, int caller, int activator, float delay)
{
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Press the pit button!");

	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 1433);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find func_button! Hammer ID: 1433");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOAbandonedBaseR2_OnPitButtonPressed, true);
}

/**
 * Phase: 18.1 - Wait for the final door to fully open
 * Summary: Bot waits for the innermost of the nested final doors to fully open.
 * Entity: func_door
 * Bot action: none
 * Confirmation: Final nested door fully open.
 */
static void ZPOAbandonedBaseR2_OnPitButtonPressed(const char[] output, int caller, int activator, float delay)
{
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Wait for the final door!");

	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", 1429);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find func_door! Hammer ID: 1429");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	HookSingleEntityOutput(door, "OnFullyOpen", ZPOAbandonedBaseR2_OnFinalDoorOpened, true);
}

/**
 * Phase: 19 - Move to the helicopter
 * Summary: Bot moves to the helicopter.
 * Entity: prop_dynamic
 * Bot action: MOVETO ENTITY
 * Confirmation: none - final phase.
 */
static void ZPOAbandonedBaseR2_OnFinalDoorOpened(const char[] output, int caller, int activator, float delay)
{
	ZPOAbandonedBaseR2_ChatMsgSurvivors("Get to the helicopter!");

	int helicopter = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_dynamic", 1578);

	if (helicopter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_abandoned_base_r2: Failed to find prop_dynamic! Hammer ID: 1578");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(helicopter);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}
