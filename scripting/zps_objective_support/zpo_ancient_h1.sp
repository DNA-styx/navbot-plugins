/**
 * zpo_ancient_h1.sp
 *
 * NavBot ZPS objective support module for the zpo_ancient_h1 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.4.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

#define ZPOANCIENTH1_BOARD_UPPER 383442
#define ZPOANCIENTH1_BOARD_LOWER 407128

void ZPOAncientH1_Init()
{
	g_ThinkFunc = ZPOAncientH1_Think;

	ZPOAncientH1_FindValve();
}

void ZPOAncientH1_Think()
{
	// Left empty until a phase needs per-tick polling.
}

static void ZPOAncientH1_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - Find valve (humans only)
 * Summary: Wait for a human to pick up the valve.
 * Entity: item_deliver, point_template
 * Bot action: none (bots cannot carry and drop the valve reliably)
 * Confirmation: The barricade props spawn, or the valve is picked up.
 */
static void ZPOAncientH1_FindValve()
{
	int valve = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "valve1");

	if (valve == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find valve1 item_deliver!");
		return;
	}

	int spawner = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "point_template", "temp_predicted_ent");

	if (spawner == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find temp_predicted_ent point_template!");
		return;
	}

	HookSingleEntityOutput(valve, "OnItemTaken", ZPOAncientH1_GreenDoor1, true);
	HookSingleEntityOutput(spawner, "OnEntitySpawned", ZPOAncientH1_BreakBarricades, true);

	ZPOAncientH1_ChatMsgSurvivors("Find the valve in the basement!");

	NavBotZPSModInterface.ResetObjective();
}

/**
 * Phase: 1 - Break barricades
 * Summary: Break the boards blocking the route to the valve.
 * Entity: prop_physics
 * Bot action: DESTROY_ENTITY
 * Confirmation: Each board breaks; the valve being picked up ends the phase.
 */
static void ZPOAncientH1_BreakBarricades(const char[] output, int caller, int activator, float delay)
{
	int board = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics", ZPOANCIENTH1_BOARD_UPPER);

	if (board == INVALID_ENT_REFERENCE)
	{
		board = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics", ZPOANCIENTH1_BOARD_LOWER);
	}

	if (board == INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		return;
	}

	HookSingleEntityOutput(board, "OnBreak", ZPOAncientH1_BreakBarricades, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(board);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
}

/**
 * Phase: 2 - Green Door 1
 * Summary: Wait at Green Door 1 while a human turns the valve.
 * Entity: trigger_once
 * Bot action: MOVETO (the valve needs +USE held; USE_ITEM presses once)
 * Confirmation: A survivor passes through Green Door 1.
 */
static void ZPOAncientH1_GreenDoor1(const char[] output, int caller, int activator, float delay)
{
	int upper = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics", ZPOANCIENTH1_BOARD_UPPER);

	if (upper != INVALID_ENT_REFERENCE)
	{
		UnhookSingleEntityOutput(upper, "OnBreak", ZPOAncientH1_BreakBarricades);
	}

	int lower = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics", ZPOANCIENTH1_BOARD_LOWER);

	if (lower != INVALID_ENT_REFERENCE)
	{
		UnhookSingleEntityOutput(lower, "OnBreak", ZPOAncientH1_BreakBarricades);
	}

	int spawner = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "point_template", "temp_predicted_ent");

	if (spawner != INVALID_ENT_REFERENCE)
	{
		UnhookSingleEntityOutput(spawner, "OnEntitySpawned", ZPOAncientH1_BreakBarricades);
	}

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "survivor_trigger1");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find survivor_trigger1 trigger_once!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOAncientH1_ReachLadderRoom, true);

	ZPOAncientH1_ChatMsgSurvivors("Valve found, take it to the Green Door and turn it!");

	float goal[3] = { -128.8, 226.6, 65.4 };

	NavBotZPSModInterface.ResetObjective();
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 3 - Reach ladder room
 * Summary: Head to the ladder room to start the fuse search.
 * Entity: trigger_once
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: A survivor enters the ladder room.
 */
static void ZPOAncientH1_ReachLadderRoom(const char[] output, int caller, int activator, float delay)
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "survivor_trigger8");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find survivor_trigger8 trigger_once!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOAncientH1_GoToFusebox, true);

	ZPOAncientH1_ChatMsgSurvivors("Green Door is open, keep moving to the ladder!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}

/**
 * Phase: 4 - Go to fusebox
 * Summary: Head to the fusebox.
 * Entity: prop_dynamic, env_entity_maker
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The fuse spawns.
 */
static void ZPOAncientH1_GoToFusebox(const char[] output, int caller, int activator, float delay)
{
	int fusebox = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_dynamic", "fusebox");

	if (fusebox == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find fusebox prop_dynamic!");
		return;
	}

	int maker = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "env_entity_maker", "maker_fuse1");

	if (maker == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find maker_fuse1 env_entity_maker!");
		return;
	}

	HookSingleEntityOutput(maker, "OnEntitySpawned", ZPOAncientH1_FindFuse, true);

	ZPOAncientH1_ChatMsgSurvivors("Get to the fusebox!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(fusebox);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}

/**
 * Phase: 5 - Find fuse
 * Summary: Find the new fuse.
 * Entity: item_deliver
 * Bot action: FIND_ITEM
 * Confirmation: The fuse is picked up.
 */
static void ZPOAncientH1_FindFuse(const char[] output, int caller, int activator, float delay)
{
	int fuse = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "fuse1");

	if (fuse == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find fuse1 item_deliver!");
		return;
	}

	HookSingleEntityOutput(fuse, "OnItemTaken", ZPOAncientH1_UseFuse, true);

	ZPOAncientH1_ChatMsgSurvivors("The fuse is broken, find a new one!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("fuse1");
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(fuse);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(1024.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

/**
 * Phase: 6 - Use fuse
 * Summary: Put the fuse in the fusebox.
 * Entity: item_deliver, trigger_useable, point_template
 * Bot action: USE_ITEM
 * Confirmation: The ladder lever spawns.
 */
static void ZPOAncientH1_UseFuse(const char[] output, int caller, int activator, float delay)
{
	int fuse = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "fuse1");

	if (fuse == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find fuse1 item_deliver!");
		return;
	}

	int useable = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "fusebox_button1");

	if (useable == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find fusebox_button1 trigger_useable!");
		return;
	}

	int lever = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "point_template", "temp_fusebox_button2");

	if (lever == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find temp_fusebox_button2 point_template!");
		return;
	}

	HookSingleEntityOutput(lever, "OnEntitySpawned", ZPOAncientH1_PullLever, true);

	ZPOAncientH1_ChatMsgSurvivors("Got the fuse, put it in the fusebox!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("fuse1");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(useable);
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(fuse);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
}

/**
 * Phase: 7 - Pull lever
 * Summary: Pull the fusebox lever to unlock the ladder.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The lever is pressed.
 */
static void ZPOAncientH1_PullLever(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "fusebox_button2");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find fusebox_button2 func_button!");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOAncientH1_GreenDoor2, true);

	ZPOAncientH1_ChatMsgSurvivors("Fuse is in, pull the lever!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 8 - Green Door 2 (humans only)
 * Summary: Wait for a human to bring the valve and turn it.
 * Entity: momentary_rot_button, trigger_once
 * Bot action: none (the valve needs +USE held; USE_ITEM presses once)
 * Confirmation: A survivor passes through Green Door 2.
 */
static void ZPOAncientH1_GreenDoor2(const char[] output, int caller, int activator, float delay)
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "survivor_trigger2");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find survivor_trigger2 trigger_once!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOAncientH1_TryExitDoor, true);

	ZPOAncientH1_ChatMsgSurvivors("Ladder is open, take the valve up and open the next Green Door!");

	NavBotZPSModInterface.ResetObjective();
}

/**
 * Phase: 9 - Try exit door
 * Summary: Try the locked exit door button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The locked button is used.
 */
static void ZPOAncientH1_TryExitDoor(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "final_door_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find final_door_button func_button!");
		return;
	}

	HookSingleEntityOutput(button, "OnUseLocked", ZPOAncientH1_PushGenerator, true);

	ZPOAncientH1_ChatMsgSurvivors("Get to the exit door!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 10 - Push generator
 * Summary: Push the generator to the exit door.
 * Entity: trigger_multiple, path_track
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The generator reaches the end of its track.
 */
static void ZPOAncientH1_PushGenerator(const char[] output, int caller, int activator, float delay)
{
	int pushTrigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "generator_pushtrigger");

	if (pushTrigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find generator_pushtrigger trigger_multiple!");
		return;
	}

	int trackEnd = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "g_track13");

	if (trackEnd == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find g_track13 path_track!");
		return;
	}

	HookSingleEntityOutput(trackEnd, "OnPass", ZPOAncientH1_Refuel, true);

	ZPOAncientH1_ChatMsgSurvivors("No power! Push the generator to the exit door!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(pushTrigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}

/**
 * Phase: 11 - Refuel (humans only)
 * Summary: Wait for a human to fetch the fuel can and refuel the generator.
 * Entity: math_counter
 * Bot action: none (bots cannot carry and drop the fuel can reliably; refuelling needs +USE held)
 * Confirmation: The generator is full of fuel.
 */
static void ZPOAncientH1_Refuel(const char[] output, int caller, int activator, float delay)
{
	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "ggf_fuel_counter");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find ggf_fuel_counter math_counter!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOAncientH1_GeneratorOn, true);

	ZPOAncientH1_ChatMsgSurvivors("The generator is empty, get the fuel can from the storage room and fill it up!");

	NavBotZPSModInterface.ResetObjective();
}

/**
 * Phase: 12 - Generator on
 * Summary: Turn the generator on.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The generator button is pressed.
 */
static void ZPOAncientH1_GeneratorOn(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "generator_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find generator_button func_button!");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOAncientH1_OpenGate, true);

	ZPOAncientH1_ChatMsgSurvivors("Generator is full, turn it on!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 13 - Open gate
 * Summary: Open the gate to the elevator.
 * Entity: func_button, func_movelinear
 * Bot action: USE_BUTTON
 * Confirmation: The gate is fully open.
 */
static void ZPOAncientH1_OpenGate(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "final_door_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find final_door_button func_button!");
		return;
	}

	int gate = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_movelinear", "final_door");

	if (gate == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find final_door func_movelinear!");
		return;
	}

	HookSingleEntityOutput(gate, "OnFullyOpen", ZPOAncientH1_CloseGate, true);

	ZPOAncientH1_ChatMsgSurvivors("Power is on, open the gate!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 14 - Close gate
 * Summary: Close the gate behind the survivors.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The gate button is pressed out.
 */
static void ZPOAncientH1_CloseGate(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "final_door_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find final_door_button func_button!");
		return;
	}

	HookSingleEntityOutput(button, "OnOut", ZPOAncientH1_CallElevator, true);

	ZPOAncientH1_ChatMsgSurvivors("Gate is open, get through and close it!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 15 - Call elevator
 * Summary: Call the elevator.
 * Entity: func_button, logic_timer
 * Bot action: USE_BUTTON
 * Confirmation: The elevator arrives.
 */
static void ZPOAncientH1_CallElevator(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "call_elevator_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find call_elevator_button func_button!");
		return;
	}

	int timer = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_timer", "timer_final_button");

	if (timer == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find timer_final_button logic_timer!");
		return;
	}

	HookSingleEntityOutput(timer, "OnTimer", ZPOAncientH1_CloseElevatorDoors, true);

	ZPOAncientH1_ChatMsgSurvivors("Call the elevator!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 16 - Close elevator doors
 * Summary: Get in and close the elevator doors.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The door button is pressed.
 */
static void ZPOAncientH1_CloseElevatorDoors(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "doors1_button2");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_ancient_h1: Failed to find doors1_button2 func_button!");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOAncientH1_RideElevator, true);

	ZPOAncientH1_ChatMsgSurvivors("Elevator is here, get in and close the doors!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 17 - Ride elevator
 * Summary: Ride the elevator to the top.
 * Entity: func_tracktrain
 * Bot action: none
 * Confirmation: The round ends.
 */
static void ZPOAncientH1_RideElevator(const char[] output, int caller, int activator, float delay)
{
	ZPOAncientH1_ChatMsgSurvivors("Doors are closing, hold on!");

	NavBotZPSModInterface.ResetObjective();
}
