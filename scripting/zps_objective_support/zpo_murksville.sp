/**
 * zpo_murksville.sp
 *
 * NavBot ZPS objective support module for the zpo_murksville map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.16.3
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: WIP
 *
 * Issues: Survivor bots not pushing cart reliably
 */

static bool s_bWaitingForBoatReady;

void ZPOMurksville_Init()
{
	g_ThinkFunc = ZPOMurksville_Think;
	s_bWaitingForBoatReady = false;

	ZPOMurksville_PushCart();
}

void ZPOMurksville_Think()
{
	if (s_bWaitingForBoatReady)
	{
		ZPOMurksville_CheckBoatReady();
	}
}

static void ZPOMurksville_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0a - DrainBoat (cart stage)
 * Summary: Push the cart.
 * Entity: trigger_multiple, func_door_rotating
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: the pump door's OnFullyOpen output
 */
static void ZPOMurksville_PushCart()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "push_pump_trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find push_pump_trigger!");
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "rotatepump");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find rotatepump!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("Push the cart!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOMurksville_PushPump, true);
}

/**
 * Phase: 0b - DrainBoat (pump stage)
 * Summary: Push the pump.
 * Entity: trigger_multiple, path_track
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: the end path_track's OnPass output
 */
static void ZPOMurksville_PushPump(const char[] output, int caller, int activator, float delay)
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "push_pump_trigger2");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find push_pump_trigger2!");
		return;
	}

	int pathEnd = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "pumppathEnd");

	if (pathEnd == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find pumppathEnd!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("Cart's in place, push the pump!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);

	HookSingleEntityOutput(pathEnd, "OnPass", ZPOMurksville_WaitForDrain, true);
}

/**
 * Phase: 0c - DrainBoat (draining)
 * Summary: Roam while the boat drains.
 * Entity: path_track
 * Bot action: none
 * Confirmation: the boat's path_track OnPass output
 */
static void ZPOMurksville_WaitForDrain(const char[] output, int caller, int activator, float delay)
{
	int boatPath = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "boatpath2");

	if (boatPath == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find boatpath2!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("Pump's running, hold out while the boat drains!");

	NavBotZPSModInterface.ResetObjective();

	HookSingleEntityOutput(boatPath, "OnPass", ZPOMurksville_PartsPlaceholder, true);
}

/**
 * Phase: 1-3 - FindBoatParts, RetoolParts, BringParts (placeholder)
 * Summary: Roam while players find, retool and deliver the parts.
 * Entity: env_entity_maker
 * Bot action: none
 * Confirmation: the battery maker's OnEntitySpawned output
 */
static void ZPOMurksville_PartsPlaceholder(const char[] output, int caller, int activator, float delay)
{
	int maker = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "env_entity_maker", "-MakerBattery");

	if (maker == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find -MakerBattery!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("Find the boat parts and get them retooled, we'll cover you!");

	NavBotZPSModInterface.ResetObjective();

	HookSingleEntityOutput(maker, "OnEntitySpawned", ZPOMurksville_GetBattery, true);
}

/**
 * Phase: 4 - FindBattery
 * Summary: Pick up the battery.
 * Entity: item_deliver, env_entity_maker
 * Bot action: USE_BUTTON
 * Confirmation: the battery's OnItemTaken output
 */
static void ZPOMurksville_GetBattery(const char[] output, int caller, int activator, float delay)
{
	int battery = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "BatteryDeliver");

	if (battery == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find BatteryDeliver!");
		return;
	}

	int maker = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "env_entity_maker", "-MakerKeys");

	if (maker == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find -MakerKeys!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("Get the battery!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(battery);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(battery, "OnItemTaken", ZPOMurksville_BringBattery, true);
	HookSingleEntityOutput(maker, "OnEntitySpawned", ZPOMurksville_GetKeys, true);
}

/**
 * Phase: 5 - BringBattery
 * Summary: Take the battery to the boat.
 * Entity: trigger_multiple
 * Bot action: USE_ITEM
 * Confirmation: the keys maker's OnEntitySpawned output
 */
static void ZPOMurksville_BringBattery(const char[] output, int caller, int activator, float delay)
{
	int boat = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "testBoat");

	if (boat == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find testBoat!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("Got the battery, take it to the boat!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("BatteryDeliver");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(boat);
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(caller);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
}

/**
 * Phase: 6 - FindKeys
 * Summary: Pick up the keys.
 * Entity: item_deliver, point_template
 * Bot action: USE_BUTTON
 * Confirmation: the gas station template's OnEntitySpawned output
 */
static void ZPOMurksville_GetKeys(const char[] output, int caller, int activator, float delay)
{
	int keys = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "KeysDeliver");

	if (keys == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find KeysDeliver!");
		return;
	}

	int temp = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "point_template", "-Temp_SDH");

	if (temp == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find -Temp_SDH!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("Get the keys!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(keys);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(temp, "OnEntitySpawned", ZPOMurksville_UnlockGasGate, true);
}

/**
 * Phase: 7a - RefuelBoat (gas gate)
 * Summary: Use the keys on the gas gate.
 * Entity: trigger_useable, func_door_rotating
 * Bot action: USE_ITEM
 * Confirmation: the gas door's OnFullyOpen output
 */
static void ZPOMurksville_UnlockGasGate(const char[] output, int caller, int activator, float delay)
{
	int keys = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "KeysDeliver");

	if (keys == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find KeysDeliver!");
		return;
	}

	int useable = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "gasDoorUseable");

	if (useable == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find gasDoorUseable!");
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "gasDoor");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find gasDoor!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("Got the keys, unlock the gas gate!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("KeysDeliver");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(useable);
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(keys);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOMurksville_Refuel, true);
}

/**
 * Phase: 7b - RefuelBoat (pump)
 * Summary: Start refuelling.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the gas button's OnPressed output
 */
static void ZPOMurksville_Refuel(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "gasButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find gasButton!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("Gate's open, start refuelling!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOMurksville_BoardBoat, true);
}

/**
 * Phase: 7c - RefuelBoat (board)
 * Summary: Board the boat while it refuels.
 * Entity: func_button
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: the boat button unlocks (polled)
 */
static void ZPOMurksville_BoardBoat(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "boatButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find boatButton!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("Refuelling, get on the boat!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);

	s_bWaitingForBoatReady = true;
}

static void ZPOMurksville_CheckBoatReady()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "boatButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find boatButton!");
		s_bWaitingForBoatReady = false;
		return;
	}

	if (GetEntProp(button, Prop_Data, "m_bLocked") == 0)
	{
		s_bWaitingForBoatReady = false;
		ZPOMurksville_StartBoat(button);
	}
}

/**
 * Phase: 8a - StartBoat
 * Summary: Start the boat.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the boat button's OnPressed output
 */
static void ZPOMurksville_StartBoat(int button)
{
	ZPOMurksville_ChatMsgSurvivors("Boat's ready, start it up!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOMurksville_Escape, true);
}

/**
 * Phase: 8b - Escape
 * Summary: Stay on the boat.
 * Entity: trigger_multiple
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: none (round ends)
 */
static void ZPOMurksville_Escape(const char[] output, int caller, int activator, float delay)
{
	int boat = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "testBoat");

	if (boat == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find testBoat!");
		return;
	}

	ZPOMurksville_ChatMsgSurvivors("We're leaving, stay on the boat!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(boat);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}
