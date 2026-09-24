/**
 * zpo_hoarfrost_b1_b2.sp
 *
 * NavBot ZPS objective support module for the zpo_hoarfrost_b1_b2 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.3.1
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

static int s_Generators[3];
static bool s_GeneratorPressed[3];

void ZPOHoarfrostB1B2_Init()
{
	g_ThinkFunc = ZPOHoarfrostB1B2_Think;

	for (int i = 0; i < 3; i++)
	{
		s_Generators[i] = INVALID_ENT_REFERENCE;
		s_GeneratorPressed[i] = false;
	}

	ZPOHoarfrostB1B2_ReachLibrary();
}

void ZPOHoarfrostB1B2_Think()
{
	// Left empty until a phase needs per-tick polling.
}

static void ZPOHoarfrostB1B2_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - Reach the library
 * Summary: Reach the library entrance.
 * Entity: trigger_once
 * Bot action: MOVETO
 * Confirmation: A survivor touches the library entrance trigger.
 */
static void ZPOHoarfrostB1B2_ReachLibrary()
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("Get to the library before we freeze!");

	const int hammerid = 150948;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", hammerid);

	if (trigger != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { 8.0, 464.0, 125.9 };

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		CanAllBotsReachGoal(goal);

		HookSingleEntityOutput(trigger, "OnStartTouch", ZPOHoarfrostB1B2_OnLibraryReached, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the library entrance trigger_once! Hammer ID: %i", hammerid);
	}
}

static void ZPOHoarfrostB1B2_OnLibraryReached(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_CollectWood();
}

/**
 * Phase: 1 - Collect wood
 * Summary: Guard the library while the wood is collected.
 * Entity: logic_relay
 * Bot action: MOVETO
 * Confirmation: The last fireplace is lit.
 */
static void ZPOHoarfrostB1B2_CollectWood()
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("Get the scrap wood! We'll guard!");

	int relay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "relay_firepalce03");

	if (relay != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { 10.8, 1473.3, 136.0 };

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		CanAllBotsReachGoal(goal);

		HookSingleEntityOutput(relay, "OnTrigger", ZPOHoarfrostB1B2_OnFireLit, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the last fireplace logic_relay!");
	}
}

static void ZPOHoarfrostB1B2_OnFireLit(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_FindBasement();
}

/**
 * Phase: 2 - Find the basement
 * Summary: Reach the basement.
 * Entity: trigger_once
 * Bot action: MOVETO
 * Confirmation: A survivor touches the basement entrance trigger.
 */
static void ZPOHoarfrostB1B2_FindBasement()
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("The fire is lit, let's find the basement!");

	const int hammerid = 235908;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", hammerid);

	if (trigger != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { 492.0, 1160.0, -248.0 };

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		CanAllBotsReachGoal(goal);

		HookSingleEntityOutput(trigger, "OnStartTouch", ZPOHoarfrostB1B2_OnBasementReached, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the basement entrance trigger_once! Hammer ID: %i", hammerid);
	}
}

static void ZPOHoarfrostB1B2_OnBasementReached(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_FindValve();
}

/**
 * Phase: 3 - Find the valve
 * Summary: Find the valve wheel.
 * Entity: item_deliver
 * Bot action: FIND_ITEM
 * Confirmation: The valve wheel is taken.
 */
static void ZPOHoarfrostB1B2_FindValve()
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("The basement is flooded, find the valve!");

	int valve = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "valve_item");

	if (valve != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemSearchID("valve_item");
		NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius * 2.0);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);

		HookSingleEntityOutput(valve, "OnItemTaken", ZPOHoarfrostB1B2_OnValveTaken, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the valve item_deliver!");
	}
}

static void ZPOHoarfrostB1B2_OnValveTaken(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_TurnValve();
}

/**
 * Phase: 4 - Turn the valve
 * Summary: Take the valve wheel to the valve and hold the area.
 * Entity: logic_timer
 * Bot action: MOVETO
 * Confirmation: The valve timer elapses.
 */
static void ZPOHoarfrostB1B2_TurnValve()
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("Valve found! Take it to the wheel and hold the area!");

	int timer = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_timer", "valve_timer");

	if (timer != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { -496.0, 1647.0, -180.0 };

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		CanAllBotsReachGoal(goal);

		HookSingleEntityOutput(timer, "OnTimer", ZPOHoarfrostB1B2_OnValveTurned, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the valve logic_timer!");
	}
}

static void ZPOHoarfrostB1B2_OnValveTurned(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_OpenGeneratorDoors();
}

/**
 * Phase: 5 - Open the generator doors
 * Summary: Press the button that opens the generator room doors.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The button is pressed.
 */
static void ZPOHoarfrostB1B2_OpenGeneratorDoors()
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("The water is draining, open the generator doors!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "flood_button");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

		HookSingleEntityOutput(button, "OnPressed", ZPOHoarfrostB1B2_OnGeneratorDoorsOpened, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the generator door func_button!");
	}
}

static void ZPOHoarfrostB1B2_OnGeneratorDoorsOpened(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_StartGenerators();
}

/**
 * Phase: 6 - Start the generators
 * Summary: Press the three generator buttons in any order.
 * Entity: func_button, math_counter, logic_relay
 * Bot action: USE_BUTTON
 * Confirmation: The power is restored.
 */
static void ZPOHoarfrostB1B2_StartGenerators()
{
	char name[32];
	int first = INVALID_ENT_REFERENCE;

	for (int i = 0; i < 3; i++)
	{
		FormatEx(name, sizeof(name), "gen_button_%i", i + 1);
		int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", name);

		if (button != INVALID_ENT_REFERENCE)
		{
			s_Generators[i] = EntIndexToEntRef(button);
			HookSingleEntityOutput(button, "OnPressed", ZPOHoarfrostB1B2_OnGeneratorPressed, true);

			if (first == INVALID_ENT_REFERENCE)
			{
				first = button;
			}
		}
		else
		{
			LogError("zpo_hoarfrost_b1_b2: Failed to find the generator func_button! Name: %s", name);
		}
	}

	if (first != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(first);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	}

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "gen_math");

	if (counter != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(counter, "OnHitMax", ZPOHoarfrostB1B2_OnGeneratorsStarted, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the generator math_counter!");
	}

	int relay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "relay_lights_on");

	if (relay != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(relay, "OnTrigger", ZPOHoarfrostB1B2_OnPowerRestored, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the power restored logic_relay!");
	}
}

static void ZPOHoarfrostB1B2_OnGeneratorPressed(const char[] output, int caller, int activator, float delay)
{
	for (int i = 0; i < 3; i++)
	{
		if (EntRefToEntIndex(s_Generators[i]) == caller)
		{
			s_GeneratorPressed[i] = true;
		}
	}

	for (int i = 0; i < 3; i++)
	{
		int button = EntRefToEntIndex(s_Generators[i]);

		if (!s_GeneratorPressed[i] && button != INVALID_ENT_REFERENCE)
		{
			NavBotZPSModInterface.ResetObjective();
			NavBotZPSModInterface.SetObjectiveUseButton(button);
			NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
			break;
		}
	}
}

static void ZPOHoarfrostB1B2_OnGeneratorsStarted(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("The generators are running, power is coming back!");
}

static void ZPOHoarfrostB1B2_OnPowerRestored(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_FindBattery();
}

/**
 * Phase: 7 - Find the battery
 * Summary: Find the battery.
 * Entity: item_deliver
 * Bot action: FIND_ITEM
 * Confirmation: The battery is taken.
 */
static void ZPOHoarfrostB1B2_FindBattery()
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("Power is on, find the battery upstairs!");

	int battery = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "battery");

	if (battery != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemSearchID("battery");
		NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);

		HookSingleEntityOutput(battery, "OnItemTaken", ZPOHoarfrostB1B2_OnBatteryTaken, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the battery item_deliver!");
	}
}

static void ZPOHoarfrostB1B2_OnBatteryTaken(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_DeliverBattery();
}

/**
 * Phase: 8 - Deliver the battery
 * Summary: Take the battery to the boat.
 * Entity: trigger_itemreceiver
 * Bot action: MOVETO
 * Confirmation: The battery is delivered.
 */
static void ZPOHoarfrostB1B2_DeliverBattery()
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("Battery found! Take it to the boat!");

	int receiver = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_itemreceiver", "batter_useable");

	if (receiver != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { 1022.0, 232.0, -1212.0 };

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		CanAllBotsReachGoal(goal);

		HookSingleEntityOutput(receiver, "OnItemDelivered", ZPOHoarfrostB1B2_OnBatteryDelivered, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the battery trigger_itemreceiver!");
	}
}

static void ZPOHoarfrostB1B2_OnBatteryDelivered(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_HoldBoat();
}

/**
 * Phase: 9 - Hold the boat
 * Summary: Hold the boat while the engine starts.
 * Entity: logic_timer
 * Bot action: MOVETO
 * Confirmation: The engine timer elapses.
 */
static void ZPOHoarfrostB1B2_HoldBoat()
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("The engine is starting, survive!");

	int timer = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_timer", "battery_timer");

	if (timer != INVALID_ENT_REFERENCE)
	{
		float goal[3] = { 1247.2, 341.9, -1168.0 };

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		CanAllBotsReachGoal(goal);

		HookSingleEntityOutput(timer, "OnTimer", ZPOHoarfrostB1B2_OnEngineStarted, true);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the engine logic_timer!");
	}
}

static void ZPOHoarfrostB1B2_OnEngineStarted(const char[] output, int caller, int activator, float delay)
{
	ZPOHoarfrostB1B2_PullLever();
}

/**
 * Phase: 10 - Pull the lever
 * Summary: Pull the boat lever.
 * Entity: func_rot_button
 * Bot action: USE_BUTTON
 * Confirmation: The round ends.
 */
static void ZPOHoarfrostB1B2_PullLever()
{
	ZPOHoarfrostB1B2_ChatMsgSurvivors("The engine is running, pull the lever!");

	int lever = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_rot_button", "boat_lever");

	if (lever != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(lever);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	}
	else
	{
		LogError("zpo_hoarfrost_b1_b2: Failed to find the boat func_rot_button!");
	}
}
