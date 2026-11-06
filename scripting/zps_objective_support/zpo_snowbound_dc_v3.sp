/**
 * zpo_snowbound_dc_v3.sp
 *
 * NavBot ZPS objective support module for the zpo_snowbound_dc_v3 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.7.4
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: {good / usable / partially complete / unusable}
 *
 * Issues: {description of things that do not work, or "none known"}
 */

// Only Init() and Think() are called from outside this file.

void ZPOSnowboundDCv3_Init()
{
	g_ThinkFunc = ZPOSnowboundDCv3_Think;

	ZPOSnowboundDCv3_ActivatePower();
}

void ZPOSnowboundDCv3_Think()
{
	// Left empty until a phase needs per-tick polling.
}

static void ZPOSnowboundDCv3_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}

	LogDebugMessage("SnowboundDCv3: %s", msg);
}

/**
 * Phase: 0 - Power
 * Summary: Bots restore power via the generator button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: filterswitch fires OnPass.
 */
static void ZPOSnowboundDCv3_ActivatePower()
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Turn on the power!");

	const int filterswitchHammerid = 160415;
	int filterswitch = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "filter_activator_team", filterswitchHammerid);

	if (filterswitch == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find filterswitch! Hammer ID: %i", filterswitchHammerid);
		return;
	}

	HookSingleEntityOutput(filterswitch, "OnPass", ZPOSnowboundDCv3_ActivateRadio, true);

	const int genButtonHammerid = 160480;
	int genButton = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", genButtonHammerid);

	if (genButton == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find gen_btn! Hammer ID: %i", genButtonHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(genButton);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 1 - Radio
 * Summary: Bots call for help via the radio button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: filterradio fires OnPass.
 */
static void ZPOSnowboundDCv3_ActivateRadio(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Power is on, radio for help!");

	const int filterradioHammerid = 160438;
	int filterradio = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "filter_activator_team", filterradioHammerid);

	if (filterradio == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find filterradio! Hammer ID: %i", filterradioHammerid);
		return;
	}

	HookSingleEntityOutput(filterradio, "OnPass", ZPOSnowboundDCv3_ActivateFindWood, true);

	const int radioButtonHammerid = 160402;
	int radioButton = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", radioButtonHammerid);

	if (radioButton == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find radio_button! Hammer ID: %i", radioButtonHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(radioButton);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 2 - FindWood
 * Summary: Search for and pick up item_wood.
 * Entity: item_deliver
 * Bot action: FIND_ITEM
 * Confirmation: item_wood fires OnItemTaken.
 */
static void ZPOSnowboundDCv3_ActivateFindWood(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Find the firewood!");

	const int itemWoodHammerid = 651120;
	int itemWood = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "item_deliver", itemWoodHammerid);

	if (itemWood == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find item_wood! Hammer ID: %i", itemWoodHammerid);
		return;
	}

	HookSingleEntityOutput(itemWood, "OnItemTaken", ZPOSnowboundDCv3_ActivateDeliverWood, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("item_wood");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

/**
 * Phase: 3 - DeliverWood
 * Summary: Carry item_wood to the fireplace and drop it.
 * Entity: trigger_itemreceiver
 * Bot action: DROP_ITEM
 * Confirmation: fireplace_item_reciever fires OnItemDelivered.
 */
static void ZPOSnowboundDCv3_ActivateDeliverWood(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Wood found! Get it to the fireplace!");

	const int fireplaceReceiverHammerid = 651252;
	int fireplaceReceiver = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_itemreceiver", fireplaceReceiverHammerid);

	if (fireplaceReceiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find fireplace_item_reciever! Hammer ID: %i", fireplaceReceiverHammerid);
		return;
	}

	HookSingleEntityOutput(fireplaceReceiver, "OnItemDelivered", ZPOSnowboundDCv3_ActivateHoldPosition, true);

	const int itemWoodHammerid = 651120;
	int itemWood = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "item_deliver", itemWoodHammerid);

	if (itemWood == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find item_wood! Hammer ID: %i", itemWoodHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("item_wood");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(fireplaceReceiver);
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(itemWood);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(128.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM);
}

/**
 * Phase: 4 - Guard the hunt
 * Summary: Bots move to and hold a position while the radio message sends.
 * Entity: math_counter
 * Bot action: MOVETO
 * Confirmation: timeblock_counter fires OnHitMax.
 */
static void ZPOSnowboundDCv3_ActivateHoldPosition(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Guard the cabin while the radio message gets through!");

	const int timeblockCounterHammerid = 901867;
	int timeblockCounter = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "math_counter", timeblockCounterHammerid);

	if (timeblockCounter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find timeblock_counter! Hammer ID: %i", timeblockCounterHammerid);
		return;
	}

	HookSingleEntityOutput(timeblockCounter, "OnHitMax", ZPOSnowboundDCv3_ActivateWaitForCar, true);

	float goal[3] = { 8188.5, -200.0, 157.0 };

	NavBotZPSModInterface.ResetObjective();
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 5 - WaitForCar
 * Summary: Wait near the cable cars until a player pulls the CAR1 lever.
 * Entity: filter_activator_name
 * Bot action: MOVETO
 * Confirmation: tram1filter_delay fires OnPass.
 */
static void ZPOSnowboundDCv3_ActivateWaitForCar(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Get to the cable cars! Pull the Car 1 lever, we will follow!");

	const int filterDelayHammerid = 897371;
	int filterDelay = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "filter_activator_name", filterDelayHammerid);

	if (filterDelay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram1filter_delay! Hammer ID: %i", filterDelayHammerid);
		return;
	}

	HookSingleEntityOutput(filterDelay, "OnPass", ZPOSnowboundDCv3_ActivateRideCar, true);

	float goal[3] = { 5767.3, -234.2, 160.0 };

	NavBotZPSModInterface.ResetObjective();
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 6 - RideCar
 * Summary: Move to the CAR1 lever and stay there for the ride down.
 * Entity: prop_dynamic
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: none yet (final phase).
 */
static void ZPOSnowboundDCv3_ActivateRideCar(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Car 1 is leaving, get on board!");

	const int leverPropHammerid = 18226;
	int leverProp = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_dynamic", leverPropHammerid);

	if (leverProp == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram1button_prop! Hammer ID: %i", leverPropHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(leverProp);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}
