/**
 * zpo_tommipanic_zb_v12.sp
 *
 * NavBot ZPS objective support module for the zpo_tommipanic_zb_v12 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.4.2
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: Unusable
 *
 * Issues: Can't get bots into the pool effectively
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

static const char s_SupplyButtons[][] = {
	"battery1", "cable1", "cable2", "gas1", "gas2", "map1", "map2",
	"supplies1", "supplies2", "supplies3", "boatb"
};

void ZPOTommiPanic_Init()
{
	g_ThinkFunc = ZPOTommiPanic_Think;

	ZPOTommiPanic_FindKeys();
}

void ZPOTommiPanic_Think()
{
	// Left empty until a phase needs per-tick polling.
}

static void ZPOTommiPanic_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - Find keys
 * Summary: Find the roof keys.
 * Entity: item_deliver
 * Bot action: FIND_ITEM
 * Confirmation: The keys are picked up.
 */
static void ZPOTommiPanic_FindKeys()
{
	int keys = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "roof_key");

	if (keys == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tommipanic_zb_v12: Failed to find roof_key item_deliver!");
		return;
	}

	HookSingleEntityOutput(keys, "OnItemTaken", ZPOTommiPanic_UnlockRoofDoor, true);

	ZPOTommiPanic_ChatMsgSurvivors("Find the keys to the roof!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius * 2.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

/**
 * Phase: 1 - Roof door
 * Summary: Unlock the roof door.
 * Entity: trigger_useable
 * Bot action: USE_ITEM when a bot holds the keys, otherwise follow players
 * Confirmation: The keys are used on the roof door.
 */
static void ZPOTommiPanic_UnlockRoofDoor(const char[] output, int caller, int activator, float delay)
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "roof_door_usable");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_GoToRooftops("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	HookSingleEntityOutput(trigger, "OnUsed", ZPOTommiPanic_GoToRooftops, true);

	ZPOTommiPanic_ChatMsgSurvivors("Keys found, unlock the roof door!");

	NavBotZPSModInterface.ResetObjective();

	if (activator < 1 || activator > MaxClients || !NavBotManager.IsNavBot(activator))
	{
		return;
	}

	NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(trigger);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
}

/**
 * Phase: 2 - Rooftops
 * Summary: Go to the rooftops.
 * Entity: trigger_once
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: A survivor reaches the roof.
 */
static void ZPOTommiPanic_GoToRooftops(const char[] output, int caller, int activator, float delay)
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "waytext trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_WaitForBarrels("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	HookSingleEntityOutput(trigger, "OnTrigger", ZPOTommiPanic_WaitForBarrels, true);

	ZPOTommiPanic_ChatMsgSurvivors("Get to the rooftops!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 3 - Barrels
 * Summary: Wait for the barrels by the pool to explode.
 * Entity: prop_physics_override, prop_physics_multiplayer
 * Bot action: MOVE_TO_ENTITY (hold on the roof)
 * Confirmation: Either barrel breaks.
 */
static void ZPOTommiPanic_WaitForBarrels(const char[] output, int caller, int activator, float delay)
{
	int barrel1 = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_physics_override", "pool explosives");
	int barrel2 = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_physics_override", "pool explosives2");

	if (barrel1 == INVALID_ENT_REFERENCE && barrel2 == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_JumpInPool("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	if (barrel1 != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(barrel1, "OnBreak", ZPOTommiPanic_JumpInPool, true);
	}

	if (barrel2 != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(barrel2, "OnBreak", ZPOTommiPanic_JumpInPool, true);
	}

	const int hammerid = 3096;
	int crate = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics_multiplayer", hammerid);

	if (crate == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tommipanic_zb_v12: Failed to find the roof crate prop_physics_multiplayer! Hammer ID: %i", hammerid);
		return;
	}

	ZPOTommiPanic_ChatMsgSurvivors("Blow up the barrels by the pool!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(crate);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 4 - Pool
 * Summary: Jump in the pool.
 * Entity: trigger_once
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: A survivor gets out past the pool.
 */
static void ZPOTommiPanic_JumpInPool(const char[] output, int caller, int activator, float delay)
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "after_pool_trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_OpenSewers("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	HookSingleEntityOutput(trigger, "OnTrigger", ZPOTommiPanic_OpenSewers, true);

	ZPOTommiPanic_ChatMsgSurvivors("Jump in the pool!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 5 - Sewer cover
 * Summary: Open the sewer cover.
 * Entity: func_button, path_track
 * Bot action: USE_BUTTON
 * Confirmation: The cover reaches its fully open position.
 */
static void ZPOTommiPanic_OpenSewers(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "sewer button 2");

	if (button == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_EnterSewers("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	int track = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "sewer first track 2");

	if (track == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tommipanic_zb_v12: Failed to find sewer first track 2 path_track!");
		return;
	}

	HookSingleEntityOutput(track, "OnPass", ZPOTommiPanic_EnterSewers, true);

	ZPOTommiPanic_ChatMsgSurvivors("Open the sewers!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 6 - Sewers
 * Summary: Enter the sewers.
 * Entity: trigger_once
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: A player reaches the sewer floor.
 */
static void ZPOTommiPanic_EnterSewers(const char[] output, int caller, int activator, float delay)
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "post_sewers_spawn_trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_SearchSupplies("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	HookSingleEntityOutput(trigger, "OnTrigger", ZPOTommiPanic_SearchSupplies, true);

	ZPOTommiPanic_ChatMsgSurvivors("Into the sewers!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 7 - Search
 * Summary: Find the supplies, nearest to the sewer exit first.
 * Entity: func_button, prop_physics_override
 * Bot action: USE_BUTTON, DESTROY_ENTITY for the freezer padlock
 * Confirmation: No supply buttons remain.
 */
static void ZPOTommiPanic_SearchSupplies(const char[] output, int caller, int activator, float delay)
{
	float sewerExit[3] = { -285.5, 737.5, -6.5 };
	int nearest = INVALID_ENT_REFERENCE;
	float nearestDist = -1.0;
	bool nearestIsBoatKeys = false;

	for (int i = 0; i < sizeof(s_SupplyButtons); i++)
	{
		int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", s_SupplyButtons[i]);

		if (button == INVALID_ENT_REFERENCE)
		{
			continue;
		}

		float pos[3];
		GetEntPropVector(button, Prop_Data, "m_vecAbsOrigin", pos);
		float dist = GetVectorDistance(sewerExit, pos);

		if (nearestDist < 0.0 || dist < nearestDist)
		{
			nearest = button;
			nearestDist = dist;
			nearestIsBoatKeys = (strcmp(s_SupplyButtons[i], "boatb") == 0);
		}
	}

	if (nearest == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_FillGascan();
		return;
	}

	if (nearestIsBoatKeys)
	{
		int padlock = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_physics_override", "freezelock1");

		if (padlock != INVALID_ENT_REFERENCE)
		{
			HookSingleEntityOutput(padlock, "OnBreak", ZPOTommiPanic_SearchSupplies, true);

			ZPOTommiPanic_ChatMsgSurvivors("Break the freezer lock at the gas station!");

			NavBotZPSModInterface.ResetObjective();
			NavBotZPSModInterface.SetObjectiveGenericTargetEntity(padlock);
			NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
			return;
		}
	}

	HookSingleEntityOutput(nearest, "OnPressed", ZPOTommiPanic_SearchSupplies, true);

	ZPOTommiPanic_ChatMsgSurvivors("Search for the supplies!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(nearest);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 8 - Fill gascan
 * Summary: Fill the gascan at the pump.
 * Entity: prop_dynamic, logic_timer
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The fill timer completes.
 */
static void ZPOTommiPanic_FillGascan()
{
	int timer = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_timer", "pumptime");

	if (timer == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_PickUpGascan("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	int gascan = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_dynamic", "pumpgas");

	if (gascan == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tommipanic_zb_v12: Failed to find pumpgas prop_dynamic!");
		return;
	}

	HookSingleEntityOutput(timer, "OnTimer", ZPOTommiPanic_PickUpGascan, true);

	ZPOTommiPanic_ChatMsgSurvivors("Fill the gascan at the pump!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(gascan);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 9 - Pick up gascan
 * Summary: Pick up the filled gascan.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The gascan is picked up.
 */
static void ZPOTommiPanic_PickUpGascan(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "pumpgasb2");

	if (button == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_WaitForBoatBlocks("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOTommiPanic_WaitForBoatBlocks, true);

	ZPOTommiPanic_ChatMsgSurvivors("Pick up the gascan!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 10 - Boat blocks
 * Summary: Wait for the way to the boat to open.
 * Entity: func_breakable
 * Bot action: none (roam)
 * Confirmation: The boat blockers break.
 */
static void ZPOTommiPanic_WaitForBoatBlocks(const char[] output, int caller, int activator, float delay)
{
	int block = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "boat_block_01");

	if (block == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_FuelBoat("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	HookSingleEntityOutput(block, "OnBreak", ZPOTommiPanic_FuelBoat, true);

	NavBotZPSModInterface.ResetObjective();
}

/**
 * Phase: 11 - Fuel boat
 * Summary: Fuel the boat.
 * Entity: prop_dynamic_override, logic_timer
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The fuel timer completes.
 */
static void ZPOTommiPanic_FuelBoat(const char[] output, int caller, int activator, float delay)
{
	int timer = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_timer", "gastime");

	if (timer == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_ChargeBattery("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	int gascan = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_dynamic_override", "boatgas");

	if (gascan == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tommipanic_zb_v12: Failed to find boatgas prop_dynamic_override!");
		return;
	}

	HookSingleEntityOutput(timer, "OnTimer", ZPOTommiPanic_ChargeBattery, true);

	ZPOTommiPanic_ChatMsgSurvivors("Get to the boat and fuel it!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(gascan);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 12 - Charge battery
 * Summary: Charge the boat battery.
 * Entity: prop_dynamic_override, logic_timer
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The charge timer completes.
 */
static void ZPOTommiPanic_ChargeBattery(const char[] output, int caller, int activator, float delay)
{
	int timer = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_timer", "batime");

	if (timer == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_CutRope("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	int battery = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_dynamic_override", "Bba");

	if (battery == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tommipanic_zb_v12: Failed to find Bba prop_dynamic_override!");
		return;
	}

	HookSingleEntityOutput(timer, "OnTimer", ZPOTommiPanic_CutRope, true);

	ZPOTommiPanic_ChatMsgSurvivors("Charge the battery on the boat!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(battery);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 13 - Cut rope
 * Summary: Cut the boat rope.
 * Entity: func_breakable
 * Bot action: DESTROY_ENTITY
 * Confirmation: The rope breaks.
 */
static void ZPOTommiPanic_CutRope(const char[] output, int caller, int activator, float delay)
{
	int rope = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "ropebrush");

	if (rope == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_StartBoat("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	HookSingleEntityOutput(rope, "OnBreak", ZPOTommiPanic_StartBoat, true);

	ZPOTommiPanic_ChatMsgSurvivors("Cut the rope!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(rope);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
}

/**
 * Phase: 14 - Start boat
 * Summary: Start the boat.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The start button is pressed.
 */
static void ZPOTommiPanic_StartBoat(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "bstart");

	if (button == INVALID_ENT_REFERENCE)
	{
		ZPOTommiPanic_RideBoat("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOTommiPanic_RideBoat, true);

	ZPOTommiPanic_ChatMsgSurvivors("Start the boat!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 15 - Ride boat
 * Summary: Get on the boat before it leaves.
 * Entity: prop_dynamic_override
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: None, the round ends.
 */
static void ZPOTommiPanic_RideBoat(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 2860464;
	int seat = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_dynamic_override", hammerid);

	if (seat == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tommipanic_zb_v12: Failed to find the boat armchair prop_dynamic_override! Hammer ID: %i", hammerid);
		return;
	}

	ZPOTommiPanic_ChatMsgSurvivors("Get on the boat!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(seat);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}
