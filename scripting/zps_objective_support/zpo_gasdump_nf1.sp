/**
 * zpo_gasdump_nf1.sp
 *
 * NavBot ZPS objective support module for the zpo_gasdump_nf1 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.9.3
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: {good / usable / partially complete / unusable}
 *
 * Issues: {description of things that do not work, or "none known"}
 */

void ZPOGasdumpNF1_Init()
{
	g_ThinkFunc = ZPOGasdumpNF1_Think;

	ZPOGasdumpNF1_FindBatteries();
}

void ZPOGasdumpNF1_Think()
{
	// Left empty until a phase needs per-tick polling.
}

static void ZPOGasdumpNF1_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

static void ZPOGasdumpNF1_ActivateFindBattery()
{
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("battery");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

/**
 * Phase: 0 - FindBatteries
 * Summary: Find and deliver the 3 batteries.
 * Entity: item_deliver x3; delivered at trigger_itemreceiver
 * Bot action: FIND_ITEM, then DROP_ITEM at the receiver once picked up
 * Confirmation: OnItemDelivered per battery; OnHitMax ends the phase
 */
static void ZPOGasdumpNF1_FindBatteries()
{
	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "bat_zaehler");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find math_counter! Name: bat_zaehler");
		return;
	}

	int receiver = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_itemreceiver", "bat_t_receiver");

	if (receiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find trigger_itemreceiver! Name: bat_t_receiver");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOGasdumpNF1_OnAllBatteriesDelivered, true);
	HookSingleEntityOutput(receiver, "OnItemDelivered", ZPOGasdumpNF1_OnBatteryDelivered, true);

	int item = INVALID_ENT_REFERENCE;
	char name[64];

	while ((item = FindEntityByClassname(item, "item_deliver")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropString(item, Prop_Data, "m_iName", name, sizeof(name));

		if (strncmp(name, "battery", 7, false) == 0)
		{
			HookSingleEntityOutput(item, "OnItemTaken", ZPOGasdumpNF1_OnBatteryTaken, true);
		}
	}

	ZPOGasdumpNF1_ChatMsgSurvivors("Let's find the Batteries");

	ZPOGasdumpNF1_ActivateFindBattery();
}

static void ZPOGasdumpNF1_OnBatteryTaken(const char[] output, int caller, int activator, float delay)
{
	HookSingleEntityOutput(caller, "OnItemDropped", ZPOGasdumpNF1_OnBatteryDropped, true);

	ZPOGasdumpNF1_ChatMsgSurvivors("I've found a Battery");

	int receiver = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_itemreceiver", "bat_t_receiver");

	if (receiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find trigger_itemreceiver! Name: bat_t_receiver");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("battery");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(receiver);
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(caller);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(128.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM);
}

static void ZPOGasdumpNF1_OnBatteryDropped(const char[] output, int caller, int activator, float delay)
{
	HookSingleEntityOutput(caller, "OnItemTaken", ZPOGasdumpNF1_OnBatteryTaken, true);

	ZPOGasdumpNF1_ActivateFindBattery();
}

static void ZPOGasdumpNF1_OnBatteryDelivered(const char[] output, int caller, int activator, float delay)
{
	HookSingleEntityOutput(caller, "OnItemDelivered", ZPOGasdumpNF1_OnBatteryDelivered, true);

	ZPOGasdumpNF1_ChatMsgSurvivors("I've delivered a Battery.");

	ZPOGasdumpNF1_ActivateFindBattery();
}

static void ZPOGasdumpNF1_OnAllBatteriesDelivered(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	//TODO: Phase 1 - Use elevator to get to the second floor
}
