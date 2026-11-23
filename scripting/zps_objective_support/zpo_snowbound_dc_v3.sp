/**
 * zpo_snowbound_dc_v3.sp
 *
 * NavBot ZPS objective support module for the zpo_snowbound_dc_v3 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.13.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: {good / usable / partially complete / unusable}
 *
 * Issues: {description of things that do not work, or "none known"}
 */

// Only Init() and Think() are called from outside this file.

// Cable car chosen at random each round: 0 = CAR1, 1 = CAR2.
static int s_Car;

static const int s_SeatsHammerid[2] = { 761376, 761222 };
static const int s_FilterDelayHammerid[2] = { 897371, 897378 };
static const int s_LeverHammerid[2] = { 776952, 777072 };
static const int s_TramHammerid[2] = { 12459, 249112 };
static const int s_ArrivalHammerid[2] = { 163124, 163531 };

void ZPOSnowboundDCv3_Init()
{
	g_ThinkFunc = ZPOSnowboundDCv3_Think;

	ZPOSnowboundDCv3_ActivatePadlock();
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
 * Phase: 0 - Padlock
 * Summary: Break the padlock on the control room door.
 * Entity: prop_physics
 * Bot action: DESTROY_ENTITY
 * Confirmation: padlock fires OnTakeDamage.
 */
static void ZPOSnowboundDCv3_ActivatePadlock()
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Break the padlock on the control room door!");

	const int padlockHammerid = 13546;
	int padlock = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics", padlockHammerid);

	if (padlock == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find padlock! Hammer ID: %i", padlockHammerid);
		return;
	}

	HookSingleEntityOutput(padlock, "OnTakeDamage", ZPOSnowboundDCv3_ActivatePower, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(padlock);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
}

/**
 * Phase: 1 - Power
 * Summary: Bots restore power via the generator button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: filterswitch fires OnPass.
 */
static void ZPOSnowboundDCv3_ActivatePower(const char[] output, int caller, int activator, float delay)
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
 * Phase: 2 - Radio
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
 * Phase: 3 - Guard the hunt
 * Summary: Bots move to and hold a position while the radio message sends.
 * Entity: logic_relay
 * Bot action: MOVETO
 * Confirmation: runcase fires OnTrigger.
 */
static void ZPOSnowboundDCv3_ActivateHoldPosition(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Guard the cabin while the radio message gets through!");

	const int runcaseHammerid = 416126;
	int runcase = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "logic_relay", runcaseHammerid);

	if (runcase == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find runcase! Hammer ID: %i", runcaseHammerid);
		return;
	}

	HookSingleEntityOutput(runcase, "OnTrigger", ZPOSnowboundDCv3_ActivateWaitForCar, true);

	float goal[3] = { 8188.5, -200.0, 157.0 };

	NavBotZPSModInterface.ResetObjective();
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 4 - WaitForCar
 * Summary: Pick a cable car at random, move to its seats and wait for the levers to spawn.
 * Entity: point_template, func_door
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: tramlevers_temp fires OnEntitySpawned.
 */
static void ZPOSnowboundDCv3_ActivateWaitForCar(const char[] output, int caller, int activator, float delay)
{
	s_Car = GetRandomInt(0, 1);

	char msg[64];
	Format(msg, sizeof(msg), "Get to cable car %i!", s_Car + 1);
	ZPOSnowboundDCv3_ChatMsgSurvivors(msg);

	const int tramleversTempHammerid = 897036;
	int tramleversTemp = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "point_template", tramleversTempHammerid);

	if (tramleversTemp == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tramlevers_temp! Hammer ID: %i", tramleversTempHammerid);
		return;
	}

	HookSingleEntityOutput(tramleversTemp, "OnEntitySpawned", ZPOSnowboundDCv3_ActivatePullLever, true);

	int seats = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", s_SeatsHammerid[s_Car]);

	if (seats == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram%i_seats! Hammer ID: %i", s_Car + 1, s_SeatsHammerid[s_Car]);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(seats);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 5 - PullLever
 * Summary: Pull the chosen car's lever to send it down.
 * Entity: func_rot_button, filter_activator_name
 * Bot action: USE_BUTTON
 * Confirmation: the chosen car's filter_delay fires OnPass.
 */
static void ZPOSnowboundDCv3_ActivatePullLever(const char[] output, int caller, int activator, float delay)
{
	char msg[64];
	Format(msg, sizeof(msg), "The Car %i lever is ready, pull it!", s_Car + 1);
	ZPOSnowboundDCv3_ChatMsgSurvivors(msg);

	int filterDelay = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "filter_activator_name", s_FilterDelayHammerid[s_Car]);

	if (filterDelay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram%ifilter_delay! Hammer ID: %i", s_Car + 1, s_FilterDelayHammerid[s_Car]);
		return;
	}

	HookSingleEntityOutput(filterDelay, "OnPass", ZPOSnowboundDCv3_ActivateRideCar, true);

	int lever = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_rot_button", s_LeverHammerid[s_Car]);

	if (lever == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram%ibutton! Hammer ID: %i", s_Car + 1, s_LeverHammerid[s_Car]);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(lever);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 6 - RideCar
 * Summary: Move to the chosen car's seats to board before it leaves.
 * Entity: func_door, func_tracktrain
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: the chosen car fires OnStart.
 */
static void ZPOSnowboundDCv3_ActivateRideCar(const char[] output, int caller, int activator, float delay)
{
	char msg[64];
	Format(msg, sizeof(msg), "Car %i is leaving, get on board!", s_Car + 1);
	ZPOSnowboundDCv3_ChatMsgSurvivors(msg);

	int tram = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_tracktrain", s_TramHammerid[s_Car]);

	if (tram == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram%i! Hammer ID: %i", s_Car + 1, s_TramHammerid[s_Car]);
		return;
	}

	HookSingleEntityOutput(tram, "OnStart", ZPOSnowboundDCv3_ActivateDescend, true);

	int seats = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", s_SeatsHammerid[s_Car]);

	if (seats == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find tram%i_seats! Hammer ID: %i", s_Car + 1, s_SeatsHammerid[s_Car]);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(seats);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 7 - Descend
 * Summary: Ride the chosen car down with no objective set.
 * Entity: path_track
 * Bot action: none (ResetObjective only)
 * Confirmation: the chosen car's bottom path_track fires OnPass on arrival.
 */
static void ZPOSnowboundDCv3_ActivateDescend(const char[] output, int caller, int activator, float delay)
{
	int arrivalNode = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "path_track", s_ArrivalHammerid[s_Car]);

	if (arrivalNode == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find train%i 3 path_track! Hammer ID: %i", s_Car + 1, s_ArrivalHammerid[s_Car]);
		return;
	}

	HookSingleEntityOutput(arrivalNode, "OnPass", ZPOSnowboundDCv3_ActivatePushBarricade, true);

	NavBotZPSModInterface.ResetObjective();
}

/**
 * Phase: 8 - PushBarricade
 * Summary: Move into the barricade push zone at the bottom station.
 * Entity: trigger_multiple
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: barricadepusher fires OnStartTouchAll.
 */
static void ZPOSnowboundDCv3_ActivatePushBarricade(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("The cable car has reached the bottom station!");

	const int pusherHammerid = 387177;
	int pusher = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_multiple", pusherHammerid);

	if (pusher == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find barricadepusher! Hammer ID: %i", pusherHammerid);
		return;
	}

	HookSingleEntityOutput(pusher, "OnStartTouchAll", ZPOSnowboundDCv3_ActivatePushing, true);

	const int barricadeEndHammerid = 387155;
	int barricadeEnd = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "path_track", barricadeEndHammerid);

	if (barricadeEnd == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find b2 path_track! Hammer ID: %i", barricadeEndHammerid);
		return;
	}

	HookSingleEntityOutput(barricadeEnd, "OnPass", ZPOSnowboundDCv3_ActivateDestroyWreckage, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(pusher);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 9 - Pushing
 * Summary: Keep pushing the barricade clear of the door.
 * Entity: trigger_multiple
 * Bot action: none (MOVE_TO_ENTITY from Phase 8 continues)
 * Confirmation: b2 path_track fires OnPass (hooked in Phase 8).
 */
static void ZPOSnowboundDCv3_ActivatePushing(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Pushing the barricade, keep it moving!");
}

/**
 * Phase: 10 - DestroyWreckage
 * Summary: Destroy car_wreckage_3 to clear the route.
 * Entity: func_breakable
 * Bot action: DESTROY_ENTITY
 * Confirmation: car_wreckage_3 fires OnBreak.
 */
static void ZPOSnowboundDCv3_ActivateDestroyWreckage(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Barricade cleared! Destroy the car wreckage!");

	const int wreckageHammerid = 344313;
	int wreckage = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", wreckageHammerid);

	if (wreckage == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find car_wreckage_3! Hammer ID: %i", wreckageHammerid);
		return;
	}

	HookSingleEntityOutput(wreckage, "OnBreak", ZPOSnowboundDCv3_ActivateEscape, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(wreckage);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
}

/**
 * Phase: 11 - Escape
 * Summary: Move into the escape zone.
 * Entity: trigger_escape
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: none (final phase).
 */
static void ZPOSnowboundDCv3_ActivateEscape(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowboundDCv3_ChatMsgSurvivors("Wreckage destroyed, get to the escape!");

	const int escapeHammerid = 178286;
	int escape = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_escape", escapeHammerid);

	if (escape == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowbound_dc_v3: Failed to find trigger_escape! Hammer ID: %i", escapeHammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(escape);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}
