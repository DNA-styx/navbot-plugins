/**
 * zpo_gasdump_nf1.sp
 *
 * NavBot ZPS objective support module for the zpo_gasdump_nf1 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.7.2
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: Working: Find battery room. WIP: Find batteries
 *
 * Issues: Bots don't collect guns before going to first objective
 *          tend to return back to restock.
 */

enum
{
	ZPOGASDUMPNF1_PHASE_DESTROYCRATES = 0,
	ZPOGASDUMPNF1_PHASE_WAITFORCRATES,
	ZPOGASDUMPNF1_PHASE_ENTERSTATION,
	ZPOGASDUMPNF1_PHASE_FINDBATTERIES
};

static int s_CurrentPhase;
static int s_CurrentCrateRef = INVALID_ENT_REFERENCE;

void ZPOGasdumpNF1_Init()
{
	g_ThinkFunc = ZPOGasdumpNF1_Think;
	s_CurrentPhase = ZPOGASDUMPNF1_PHASE_DESTROYCRATES;
	s_CurrentCrateRef = INVALID_ENT_REFERENCE;

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "bat_zaehler");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find bat_zaehler!");
	}
	else
	{
		HookSingleEntityOutput(counter, "OnHitMax", ZPOGasdumpNF1_OnAllBatteriesDelivered, true);
	}

	ZPOGasdumpNF1_ActivateDestroyCrates();
}

void ZPOGasdumpNF1_Think()
{
	switch (s_CurrentPhase)
	{
		case ZPOGASDUMPNF1_PHASE_DESTROYCRATES:
		{
			ZPOGasdumpNF1_UpdateDestroyCrates();
		}
	}
}

void ZPOGasdumpNF1_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

static const int s_CrateHammerIDs[9] = { 3570, 3571, 3572, 3573, 3835, 4620, 4685, 218211, 218225 };

/**
 * Phase: 0 - DestroyCrates
 * Summary: Bots break the 9 item crates near survivor spawn, one at a
 *   time. Any crate already gone when checked (broken by a human) is
 *   skipped. A 10 second wait follows once none remain, before the next
 *   phase starts.
 * Entity: prop_itemcrate x9
 * Bot action: DESTROY_ENTITY
 * Confirmation: polled each tick; phase ends once none remain
 */
void ZPOGasdumpNF1_ActivateDestroyCrates()
{
	ZPOGasdumpNF1_UpdateDestroyCrates();
}

void ZPOGasdumpNF1_UpdateDestroyCrates()
{
	if (s_CurrentCrateRef != INVALID_ENT_REFERENCE && EntRefToEntIndex(s_CurrentCrateRef) != INVALID_ENT_REFERENCE)
	{
		return;
	}

	for (int i = 0; i < sizeof(s_CrateHammerIDs); i++)
	{
		int crate = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_itemcrate", s_CrateHammerIDs[i]);

		if (crate != INVALID_ENT_REFERENCE)
		{
			s_CurrentCrateRef = EntIndexToEntRef(crate);

			NavBotZPSModInterface.ResetObjective();
			NavBotZPSModInterface.SetObjectiveGenericTargetEntity(crate);
			NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
			return;
		}
	}

	s_CurrentPhase = ZPOGASDUMPNF1_PHASE_WAITFORCRATES;
	CreateTimer(10.0, ZPOGasdumpNF1_OnAllCratesDestroyedWait, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

Action ZPOGasdumpNF1_OnAllCratesDestroyedWait(Handle timer)
{
	ZPOGasdumpNF1_ActivateEnterStation();
	return Plugin_Stop;
}

/**
 * Phase: 1 - EnterStation
 * Summary: Survivors touch an unnamed trigger to enter the gas station.
 * Entity: trigger_once
 * Bot action: MOVETO trigger
 * Confirmation: trigger's OnStartTouch output
 */
void ZPOGasdumpNF1_ActivateEnterStation()
{
	s_CurrentPhase = ZPOGASDUMPNF1_PHASE_ENTERSTATION;

	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", 4256);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find the hammer ID 4256 trigger_once!");
		return;
	}

	ZPOGasdumpNF1_ChatMsgSurvivors("Let's get to the Gas Station");

	float pos[3];
	GetEntPropVector(trigger, Prop_Data, "m_vecAbsOrigin", pos);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(pos);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOGasdumpNF1_OnEnteredStation, true);
}

void ZPOGasdumpNF1_OnEnteredStation(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	s_CurrentPhase = ZPOGASDUMPNF1_PHASE_FINDBATTERIES;

	ZPOGasdumpNF1_ChatMsgSurvivors("Let's find the Batteries");

	ZPOGasdumpNF1_ActivateFindBattery();
}

/**
 * Phase: 2 - FindBatteries
 * Summary: Bots find and deliver 3 batteries, in any order, using a
 *   shared item ID.
 * Entity: item_deliver x3; delivered at trigger_itemreceiver
 * Bot action: FIND_ITEM, then DROP_ITEM at the receiver once picked up
 * Confirmation: OnItemDelivered per battery; OnHitMax ends the phase
 */
void ZPOGasdumpNF1_ActivateFindBattery()
{
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("battery");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);

	HookNamedOutputOfAllEntities("item_deliver", "OnItemTaken", ZPOGasdumpNF1_OnBatteryTaken, true);
	HookNamedOutputOfAllEntities("item_deliver", "OnItemDropped", ZPOGasdumpNF1_OnBatteryDropped, true);
}

void ZPOGasdumpNF1_OnBatteryTaken(const char[] output, int caller, int activator, float delay)
{
	ZPOGasdumpNF1_ChatMsgSurvivors("I've found a Battery");

	int receiver = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_itemreceiver", "bat_t_receiver");

	if (receiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find bat_t_receiver!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("battery");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(receiver);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM);

	HookSingleEntityOutput(receiver, "OnItemDelivered", ZPOGasdumpNF1_OnBatteryDelivered, true);
}

void ZPOGasdumpNF1_OnBatteryDropped(const char[] output, int caller, int activator, float delay)
{
	ZPOGasdumpNF1_ActivateFindBattery();
}

void ZPOGasdumpNF1_OnBatteryDelivered(const char[] output, int caller, int activator, float delay)
{
	ZPOGasdumpNF1_ChatMsgSurvivors("I've delivered a Battery.");

	ZPOGasdumpNF1_ActivateFindBattery();
}

void ZPOGasdumpNF1_OnAllBatteriesDelivered(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	//TODO: Phase 3 - Use elevator to get to the second floor
}
