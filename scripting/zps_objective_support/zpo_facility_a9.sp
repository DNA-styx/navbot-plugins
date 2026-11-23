/**
 * zpo_facility_a9.sp
 *
 * NavBot ZPS objective support module for the zpo_facility_a9 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.5.1
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

void ZPOFacilityA9_Init()
{
	g_ThinkFunc = ZPOFacilityA9_Think;

	ZPOFacilityA9_TryLevel3Keypad();
}

void ZPOFacilityA9_Think()
{
}

static void ZPOFacilityA9_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - Try Level 3 keypad
 * Summary: Enter the code on the Level 3 keypad.
 * Entity: momentary_rot_button, logic_branch
 * Bot action: USE_BUTTON
 * Confirmation: The keypad code is rejected.
 */
static void ZPOFacilityA9_TryLevel3Keypad()
{
	int keypad = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "momentary_rot_button", "CLNumPad3");

	if (keypad == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find CLNumPad3 momentary_rot_button!");
		return;
	}

	int branch = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_branch", "lvl3branch");

	if (branch == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find lvl3branch logic_branch!");
		return;
	}

	HookSingleEntityOutput(branch, "OnFalse", ZPOFacilityA9_MaintenanceKeypad, true);

	ZPOFacilityA9_ChatMsgSurvivors("Enter the code on the Level 3 keypad!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(keypad);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 1 - Maintenance keypad
 * Summary: Enter the code on the maintenance tunnel keypad.
 * Entity: momentary_rot_button, func_door_rotating
 * Bot action: USE_BUTTON
 * Confirmation: The maintenance tunnel door opens.
 */
static void ZPOFacilityA9_MaintenanceKeypad(const char[] output, int caller, int activator, float delay)
{
	int keypad = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "momentary_rot_button", "CLNumPad1");

	if (keypad == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find CLNumPad1 momentary_rot_button!");
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "lab_door1");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find lab_door1 func_door_rotating!");
		return;
	}

	HookSingleEntityOutput(door, "OnOpen", ZPOFacilityA9_TunnelKeypad, true);

	ZPOFacilityA9_ChatMsgSurvivors("The code didn't work! Try the maintenance tunnel keypad!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(keypad);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 2 - Tunnel keypad
 * Summary: Enter the code on the keypad past the maintenance tunnel.
 * Entity: momentary_rot_button, func_door_rotating
 * Bot action: USE_BUTTON
 * Confirmation: The doors past the keypad open.
 */
static void ZPOFacilityA9_TunnelKeypad(const char[] output, int caller, int activator, float delay)
{
	int keypad = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "momentary_rot_button", "CLNumPad2");

	if (keypad == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find CLNumPad2 momentary_rot_button!");
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "lab_door3");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find lab_door3 func_door_rotating!");
		return;
	}

	HookSingleEntityOutput(door, "OnOpen", ZPOFacilityA9_Level3Switch, true);

	ZPOFacilityA9_ChatMsgSurvivors("The maintenance tunnel is open! Enter the code on the next keypad!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(keypad);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 3 - Level 3 switch
 * Summary: Press the switch that unlocks the Level 3 keypad.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The switch is pressed.
 */
static void ZPOFacilityA9_Level3Switch(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "switch");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find switch func_button!");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOFacilityA9_OpenLevel3Door, true);

	ZPOFacilityA9_ChatMsgSurvivors("Find the switch to unlock the Level 3 keypad!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 4 - Open Level 3 door
 * Summary: Enter the code on the Level 3 keypad again.
 * Entity: momentary_rot_button, func_door
 * Bot action: USE_BUTTON
 * Confirmation: The Level 3 blast door is fully open.
 */
static void ZPOFacilityA9_OpenLevel3Door(const char[] output, int caller, int activator, float delay)
{
	int keypad = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "momentary_rot_button", "CLNumPad3");

	if (keypad == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find CLNumPad3 momentary_rot_button!");
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "lvl3door");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find lvl3door func_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOFacilityA9_ElevatorKeypad, true);

	ZPOFacilityA9_ChatMsgSurvivors("The Level 3 keypad is unlocked! Open the blast door!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(keypad);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 5 - Elevator keypad
 * Summary: Enter the code on the elevator keypad.
 * Entity: momentary_rot_button, logic_relay
 * Bot action: USE_BUTTON
 * Confirmation: The code is rejected and the hack starts.
 */
static void ZPOFacilityA9_ElevatorKeypad(const char[] output, int caller, int activator, float delay)
{
	int keypad = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "momentary_rot_button", "CLNumPad4");

	if (keypad == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find CLNumPad4 momentary_rot_button!");
		return;
	}

	int relay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "HackRelay");

	if (relay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find HackRelay logic_relay!");
		return;
	}

	HookSingleEntityOutput(relay, "OnTrigger", ZPOFacilityA9_HackElevator, true);

	ZPOFacilityA9_ChatMsgSurvivors("The blast door is open! Enter the code on the elevator keypad!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(keypad);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 6 - Hack elevator
 * Summary: Wait while the elevator door is hacked.
 * Entity: func_door
 * Bot action: none
 * Confirmation: The elevator doors open.
 */
static void ZPOFacilityA9_HackElevator(const char[] output, int caller, int activator, float delay)
{
	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "FloorDoorsLeft2");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find FloorDoorsLeft2 func_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnOpen", ZPOFacilityA9_EnterElevator, true);

	ZPOFacilityA9_ChatMsgSurvivors("Hacking the elevator door! Hold on for about a minute!");

	NavBotZPSModInterface.ResetObjective();
}

/**
 * Phase: 7 - Enter elevator
 * Summary: Get into the elevator while a human closes the door.
 * Entity: func_button
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The elevator door button is pressed.
 */
static void ZPOFacilityA9_EnterElevator(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "ElevButton1");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find ElevButton1 func_button!");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOFacilityA9_ClimbToSurface, true);

	ZPOFacilityA9_ChatMsgSurvivors("The elevator is open! Get in and close the door!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 8 - Climb to surface
 * Summary: Climb the elevator shaft to the surface.
 * Entity: trigger_once
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: A survivor reaches the surface.
 */
static void ZPOFacilityA9_ClimbToSurface(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 442792;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", hammerid);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_facility_a9: Failed to find surface trigger_once! Hammer ID: %i", hammerid);
		return;
	}

	ZPOFacilityA9_ChatMsgSurvivors("The door is closed! Climb up to the surface!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}
