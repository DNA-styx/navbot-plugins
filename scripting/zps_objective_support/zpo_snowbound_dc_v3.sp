/**
 * zpo_snowbound_dc_v3.sp
 *
 * NavBot ZPS objective support module for the zpo_snowbound_dc_v3 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.4.6
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

/**
 * Phase: 0 - Power
 * Summary: Bots restore power via the generator button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: filterswitch fires OnPass.
 */
static void ZPOSnowboundDCv3_ActivatePower()
{
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
	const int fireplaceReceiverHammerid = 651252;
	int fireplaceReceiver = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_itemreceiver", fireplaceReceiverHammerid);

	if (fireplaceReceiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find fireplace_item_reciever! Hammer ID: %i", fireplaceReceiverHammerid);
		return;
	}

	HookSingleEntityOutput(fireplaceReceiver, "OnItemDelivered", ZPOSnowboundDCv3_ActivateHoldPosition, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("item_wood");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(fireplaceReceiver);
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
	const int timeblockCounterHammerid = 901867;
	int timeblockCounter = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "math_counter", timeblockCounterHammerid);

	if (timeblockCounter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find timeblock_counter! Hammer ID: %i", timeblockCounterHammerid);
		return;
	}

	HookSingleEntityOutput(timeblockCounter, "OnHitMax", ZPOSnowboundDCv3_ActivateApproachLever, true);

	float goal[3] = { 8188.5, -200.0, 157.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 5 - ApproachLever
 * Summary: Wait for cable_car_brush to clear before approaching the lever zone.
 * Entity: logic_relay
 * Bot action: none (ResetObjective only; bots roam/follow until the brush clears)
 * Confirmation: tram_delay_0 or tram_delay_1 fires OnTrigger (the map picks one at runtime).
 */
static void ZPOSnowboundDCv3_ActivateApproachLever(const char[] output, int caller, int activator, float delay)
{
	const int tramDelay0Hammerid = 889151;
	int tramDelay0 = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "logic_relay", tramDelay0Hammerid);

	if (tramDelay0 == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram_delay_0! Hammer ID: %i", tramDelay0Hammerid);
		return;
	}

	HookSingleEntityOutput(tramDelay0, "OnTrigger", ZPOSnowboundDCv3_ActivateApproachLeverZone, true);

	const int tramDelay1Hammerid = 889157;
	int tramDelay1 = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "logic_relay", tramDelay1Hammerid);

	if (tramDelay1 == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram_delay_1! Hammer ID: %i", tramDelay1Hammerid);
		return;
	}

	HookSingleEntityOutput(tramDelay1, "OnTrigger", ZPOSnowboundDCv3_ActivateApproachLeverZoneDelayed, true);

	NavBotZPSModInterface.ResetObjective();
}

/**
 * Phase: 6 - ApproachLeverZone
 * Summary: Move into the tram_timer_tr zone now that cable_car_brush is clear.
 * Entity: point_template
 * Bot action: MOVETO
 * Confirmation: tramlevers_temp fires OnEntitySpawned (Template01, tram1button).
 */
static void ZPOSnowboundDCv3_ActivateApproachLeverZone(const char[] output, int caller, int activator, float delay)
{
	const int tramleversTempHammerid = 897036;
	int tramleversTemp = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "point_template", tramleversTempHammerid);

	if (tramleversTemp == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tramlevers_temp! Hammer ID: %i", tramleversTempHammerid);
		return;
	}

	HookSingleEntityOutput(tramleversTemp, "OnEntitySpawned", ZPOSnowboundDCv3_ActivateUseLever, true);

	float goal[3] = { 5864.6, -878.0, 93.5 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

// tram_delay_1's path disables cable_car_brush 6 seconds after OnTrigger (tram_delay_0's is immediate).
static void ZPOSnowboundDCv3_ActivateApproachLeverZoneDelayed(const char[] output, int caller, int activator, float delay)
{
	CreateTimer(6.0, ZPOSnowboundDCv3_OnApproachLeverZoneDelayExpired, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

static Action ZPOSnowboundDCv3_OnApproachLeverZoneDelayExpired(Handle timer)
{
	const int tramleversTempHammerid = 897036;
	int tramleversTemp = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "point_template", tramleversTempHammerid);

	if (tramleversTemp == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tramlevers_temp! Hammer ID: %i", tramleversTempHammerid);
		return Plugin_Stop;
	}

	HookSingleEntityOutput(tramleversTemp, "OnEntitySpawned", ZPOSnowboundDCv3_ActivateUseLever, true);

	float goal[3] = { 5864.6, -878.0, 93.5 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	return Plugin_Stop;
}

/**
 * Phase: 7 - UseLever
 * Summary: Pull the CAR1 lever to send the cable car down.
 * Entity: func_rot_button
 * Bot action: USE_BUTTON
 * Confirmation: tram1button fires OnPressed.
 */
static void ZPOSnowboundDCv3_ActivateUseLever(const char[] output, int caller, int activator, float delay)
{
	const int leverHammerid = 776952;
	int lever = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_rot_button", leverHammerid);

	if (lever == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram1button! Hammer ID: %i", leverHammerid);
		return;
	}

	HookSingleEntityOutput(lever, "OnPressed", ZPOSnowboundDCv3_ActivateTravel, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(lever);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 8 - Travel
 * Summary: Bots move to and hold a position while the cable car descends.
 * Entity: path_track
 * Bot action: MOVETO
 * Confirmation: train1 3 path_track fires OnPass on arrival.
 */
static void ZPOSnowboundDCv3_ActivateTravel(const char[] output, int caller, int activator, float delay)
{
	const int arrivalHammerid = 163124;
	int arrivalNode = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "path_track", arrivalHammerid);

	if (arrivalNode == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find train1 3 path_track! Hammer ID: %i", arrivalHammerid);
		return;
	}

	HookSingleEntityOutput(arrivalNode, "OnPass", ZPOSnowboundDCv3_OnArrivedAtBottomStation, true);

	float goal[3] = { 5687.9, -872.9, 93.5 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOSnowboundDCv3_OnArrivedAtBottomStation(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// Next phase contents go here once confirmed.
}
