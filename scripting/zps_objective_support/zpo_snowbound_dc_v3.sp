/**
 * zpo_snowbound_dc_v3.sp
 *
 * NavBot ZPS objective support module for the zpo_snowbound_dc_v3 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.3.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: WIP: up to the bots using the cable car
 *
 * Issues: Needs custom navmesh to stop bots leaving buildings
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

	HookSingleEntityOutput(filterradio, "OnPass", ZPOSnowboundDCv3_ActivateHoldPosition, true);

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
 * Phase: 2 - Guard the hunt
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

	HookSingleEntityOutput(timeblockCounter, "OnHitMax", ZPOSnowboundDCv3_ActivateLever, true);

	float goal[3] = { 8188.5, -200.0, 157.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 3 - ApproachLever
 * Summary: Bots move to the tram_timer_tr zone to force-spawn the CAR1 lever.
 * Entity: point_template
 * Bot action: MOVETO
 * Confirmation: tramlevers_temp fires OnEntitySpawned (Template01, tram1button).
 */
static void ZPOSnowboundDCv3_ActivateLever(const char[] output, int caller, int activator, float delay)
{
	const int tramleversTempHammerid = 897036;
	int tramleversTemp = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "point_template", tramleversTempHammerid);

	if (tramleversTemp == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tramlevers_temp! Hammer ID: %i", tramleversTempHammerid);
		return;
	}

	HookSingleEntityOutput(tramleversTemp, "OnEntitySpawned", ZPOSnowboundDCv3_ActivateUseLever, true);

	float goal[3] = { 5490.2, -507.3, 160.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 4 - UseLever
 * Summary: Bots pull the CAR1 lever to send the cable car down.
 * Entity: func_rot_button
 * Bot action: USE_BUTTON
 * Confirmation: tram1filter_delay fires OnPass.
 */
static void ZPOSnowboundDCv3_ActivateUseLever(const char[] output, int caller, int activator, float delay)
{
	const int filterdelayHammerid = 897371;
	int filterdelay = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "filter_activator_name", filterdelayHammerid);

	if (filterdelay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram1filter_delay! Hammer ID: %i", filterdelayHammerid);
		return;
	}

	HookSingleEntityOutput(filterdelay, "OnPass", ZPOSnowboundDCv3_ActivateTravel, true);

	const int leverHammerid = 776952;
	int lever = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_rot_button", leverHammerid);

	if (lever == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram1button! Hammer ID: %i", leverHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(lever);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 5 - Travel
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

	float goal[3] = { 5699.5, -900.5, 93.5 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOSnowboundDCv3_OnArrivedAtBottomStation(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// Next phase contents go here once confirmed.
}
