/**
 * zpo_gasdump_nf1.sp
 *
 * NavBot ZPS objective support module for the zpo_gasdump_nf1 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.16.2
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: {good / usable / partially complete / unusable}
 *
 * Issues: {description of things that do not work, or "none known"}
 */

// Requires the Stripper config zpo_gasdump_nf1.cfg (batteries and C4 packs
// noswitch 0), otherwise bots drop them when they switch weapon to fight.

static bool s_KeysFound;
static int s_Round;
static const int s_C4ReceiverIDs[5] = { 4303, 4314, 4326, 4336, 4410 };

// Current objective, kept so it can be reissued after the tornado.
static bool s_Tornado;
static NavBotZPSObjectiveTypes s_ObjType;
static char s_ObjItem[32];
static int s_ObjUseTarget;
static int s_ObjGeneric;
static int s_ObjButton;
static float s_ObjRadius;

void ZPOGasdumpNF1_Init()
{
	g_ThinkFunc = ZPOGasdumpNF1_Think;

	s_KeysFound = false;
	s_Round++;
	s_Tornado = false;
	s_ObjType = NAVBOT_ZPS_OBJECTIVE_NONE;

	int relay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "tornadorelay");

	if (relay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find logic_relay! Name: tornadorelay");
	}
	else
	{
		HookSingleEntityOutput(relay, "OnTrigger", ZPOGasdumpNF1_OnTornado, true);
	}

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

static int ZPOGasdumpNF1_ToRef(int entity)
{
	return entity > 0 ? EntIndexToEntRef(entity) : INVALID_ENT_REFERENCE;
}

static void ZPOGasdumpNF1_SetObjective(NavBotZPSObjectiveTypes type, const char[] item = "", int useTarget = -1, int generic = -1, float radius = 0.0, int button = -1)
{
	s_ObjType = type;
	strcopy(s_ObjItem, sizeof(s_ObjItem), item);
	s_ObjUseTarget = ZPOGasdumpNF1_ToRef(useTarget);
	s_ObjGeneric = ZPOGasdumpNF1_ToRef(generic);
	s_ObjButton = ZPOGasdumpNF1_ToRef(button);
	s_ObjRadius = radius;

	if (!s_Tornado)
	{
		ZPOGasdumpNF1_ApplyObjective();
	}
}

static void ZPOGasdumpNF1_ApplyObjective()
{
	NavBotZPSModInterface.ResetObjective();

	if (s_ObjType == NAVBOT_ZPS_OBJECTIVE_NONE)
	{
		return;
	}

	if (s_ObjItem[0] != '\0')
	{
		NavBotZPSModInterface.SetObjectiveItemSearchID(s_ObjItem);
	}

	int entity = EntRefToEntIndex(s_ObjUseTarget);

	if (entity != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.SetObjectiveItemUseTarget(entity);
	}

	entity = EntRefToEntIndex(s_ObjGeneric);

	if (entity != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
	}

	entity = EntRefToEntIndex(s_ObjButton);

	if (entity != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.SetObjectiveUseButton(entity);
	}

	if (s_ObjRadius > 0.0)
	{
		NavBotZPSModInterface.SetObjectiveDetectionRadius(s_ObjRadius);
	}

	NavBotZPSModInterface.SetCurrentObjective(s_ObjType);
}

// The tornado throws players around for 60 seconds; bots in the air can't
// path, so objectives are paused until it ends.
static void ZPOGasdumpNF1_OnTornado(const char[] output, int caller, int activator, float delay)
{
	LogDebugMessage("Gasdump: DEBUG tornado started");
	ZPOGasdumpNF1_ChatMsgSurvivors("Tornado! Hold on until it passes!");

	s_Tornado = true;

	// ResetObjective alone doesn't stop a running task; SetCurrentObjective
	// fires the change event to the bots.
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_NONE);
	NavBotZPSModInterface.ResetObjective();

	CreateTimer(61.0, ZPOGasdumpNF1_OnTornadoEnd, s_Round, TIMER_FLAG_NO_MAPCHANGE);
}

static Action ZPOGasdumpNF1_OnTornadoEnd(Handle timer, int round)
{
	if (round != s_Round)
	{
		return Plugin_Stop;
	}

	LogDebugMessage("Gasdump: DEBUG tornado ended");
	ZPOGasdumpNF1_ChatMsgSurvivors("The tornado has passed, back to it!");

	s_Tornado = false;
	ZPOGasdumpNF1_ApplyObjective();
	return Plugin_Stop;
}

static void ZPOGasdumpNF1_ActivateFindBattery()
{
	ZPOGasdumpNF1_SetObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM, "battery", -1, -1, g_DetectionRadius);
}

/**
 * Phase: 0 - FindBatteries
 * Summary: Stock up for 30 seconds, then find and deliver the 3 batteries.
 * Entity: item_deliver x3; delivered at trigger_itemreceiver
 * Bot action: FIND_ITEM, then DROP_ITEM at the receiver once picked up
 * Confirmation: The battery counter reaches its maximum.
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

	int keys = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "keys_btn");

	if (keys == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find func_button! Name: keys_btn");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOGasdumpNF1_WaitForLift, true);
	HookSingleEntityOutput(receiver, "OnItemDelivered", ZPOGasdumpNF1_OnBatteryDelivered, true);
	HookSingleEntityOutput(keys, "OnPressed", ZPOGasdumpNF1_OnKeysFound, true);

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

	ZPOGasdumpNF1_SetObjective(NAVBOT_ZPS_OBJECTIVE_NONE);

	CreateTimer(30.0, ZPOGasdumpNF1_OnStockUpDone, s_Round, TIMER_FLAG_NO_MAPCHANGE);
}

static Action ZPOGasdumpNF1_OnStockUpDone(Handle timer, int round)
{
	if (round != s_Round)
	{
		return Plugin_Stop;
	}

	ZPOGasdumpNF1_ChatMsgSurvivors("Let's find the Batteries");

	ZPOGasdumpNF1_ActivateFindBattery();
	return Plugin_Stop;
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

	ZPOGasdumpNF1_SetObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM, "battery", receiver, caller, 64.0);
}

static void ZPOGasdumpNF1_OnBatteryDropped(const char[] output, int caller, int activator, float delay)
{
	HookSingleEntityOutput(caller, "OnItemTaken", ZPOGasdumpNF1_OnBatteryTaken, true);

	ZPOGasdumpNF1_ActivateFindBattery();
}

static void ZPOGasdumpNF1_OnBatteryDelivered(const char[] output, int caller, int activator, float delay)
{
	HookSingleEntityOutput(caller, "OnItemDelivered", ZPOGasdumpNF1_OnBatteryDelivered, true);

	LogDebugMessage("Gasdump: DEBUG battery delivered");
	ZPOGasdumpNF1_ChatMsgSurvivors("I've delivered a Battery.");

	ZPOGasdumpNF1_ActivateFindBattery();
}

static void ZPOGasdumpNF1_OnKeysFound(const char[] output, int caller, int activator, float delay)
{
	s_KeysFound = true;
}

/**
 * Phase: 1 - WaitForLift
 * Summary: Wait for the powered lift to reach the ground floor.
 * Entity: path_track
 * Bot action: none (roam)
 * Confirmation: The lift passes its bottom track node.
 */
static void ZPOGasdumpNF1_WaitForLift(const char[] output, int caller, int activator, float delay)
{
	int track = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "path_track_02");

	if (track == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find path_track! Name: path_track_02");
		return;
	}

	LogDebugMessage("Gasdump: DEBUG Phase 1 WaitForLift");

	ZPOGasdumpNF1_SetObjective(NAVBOT_ZPS_OBJECTIVE_NONE);

	HookSingleEntityOutput(track, "OnPass", ZPOGasdumpNF1_FindKeys, true);
}

/**
 * Phase: 2 - FindKeys
 * Summary: Find the storage room keys.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: The keys are picked up.
 */
static void ZPOGasdumpNF1_FindKeys(const char[] output, int caller, int activator, float delay)
{
	if (s_KeysFound)
	{
		ZPOGasdumpNF1_OpenStorageDoor();
		return;
	}

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "keys_btn");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find func_button! Name: keys_btn");
		return;
	}

	LogDebugMessage("Gasdump: DEBUG Phase 2 FindKeys");
	ZPOGasdumpNF1_ChatMsgSurvivors("Power is on, let's find the keys!");

	ZPOGasdumpNF1_SetObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON, "", -1, -1, 0.0, button);

	HookSingleEntityOutput(button, "OnPressed", ZPOGasdumpNF1_OpenStorageDoor, true);
}

/**
 * Phase: 3 - OpenStorageDoor
 * Summary: Open the storage room door.
 * Entity: prop_door_rotating
 * Bot action: USE_BUTTON
 * Confirmation: The door opens.
 */
static void ZPOGasdumpNF1_OpenStorageDoor(const char[] output = "", int caller = -1, int activator = -1, float delay = 0.0)
{
	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_door_rotating", "armory_door");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find prop_door_rotating! Name: armory_door");
		return;
	}

	LogDebugMessage("Gasdump: DEBUG Phase 3 OpenStorageDoor");
	ZPOGasdumpNF1_ChatMsgSurvivors("Keys found! Let's open the storage room!");

	ZPOGasdumpNF1_SetObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON, "", -1, -1, 0.0, door);

	HookSingleEntityOutput(door, "OnOpen", ZPOGasdumpNF1_FindC4, true);
}

/**
 * Phase: 4 - FindC4
 * Summary: Find the C4 packs and plant them at the bomb spots.
 * Entity: item_deliver, trigger_itemreceiver x5, math_counter
 * Bot action: FIND_ITEM, then DROP_ITEM at the nearest bomb spot
 * Confirmation: The C4 counter reaches its maximum.
 */
static void ZPOGasdumpNF1_FindC4(const char[] output, int caller, int activator, float delay)
{
	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "c4_counter");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_gasdump_nf1: Failed to find math_counter! Name: c4_counter");
		return;
	}

	LogDebugMessage("Gasdump: DEBUG Phase 4 FindC4");
	ZPOGasdumpNF1_ChatMsgSurvivors("Door's open! Grab the C4 and plant it!");

	HookSingleEntityOutput(counter, "OnHitMax", ZPOGasdumpNF1_OnC4Planted, true);

	for (int i = 0; i < sizeof(s_C4ReceiverIDs); i++)
	{
		int receiver = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_itemreceiver", s_C4ReceiverIDs[i]);

		if (receiver == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_gasdump_nf1: Failed to find trigger_itemreceiver! Hammer ID: %i", s_C4ReceiverIDs[i]);
			continue;
		}

		HookSingleEntityOutput(receiver, "OnItemDelivered", ZPOGasdumpNF1_OnC4Delivered, true);
	}

	int item = INVALID_ENT_REFERENCE;

	while ((item = FindNamedEntityOfClassname(item, "item_deliver", "c4pack_01")) != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(item, "OnItemTaken", ZPOGasdumpNF1_OnC4Taken, true);
	}

	ZPOGasdumpNF1_ActivateFindC4();
}

static void ZPOGasdumpNF1_ActivateFindC4()
{
	ZPOGasdumpNF1_SetObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM, "c4pack_01", -1, -1, g_DetectionRadius * 4.0);
}

static void ZPOGasdumpNF1_OnC4Taken(const char[] output, int caller, int activator, float delay)
{
	HookSingleEntityOutput(caller, "OnItemDropped", ZPOGasdumpNF1_OnC4Dropped, true);

	float origin[3];
	GetEntPropVector(caller, Prop_Data, "m_vecAbsOrigin", origin);

	int nearest = INVALID_ENT_REFERENCE;
	float nearestDist;

	for (int i = 0; i < sizeof(s_C4ReceiverIDs); i++)
	{
		int receiver = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_itemreceiver", s_C4ReceiverIDs[i]);

		if (receiver == INVALID_ENT_REFERENCE)
		{
			continue;
		}

		float pos[3];
		GetEntPropVector(receiver, Prop_Data, "m_vecAbsOrigin", pos);
		float dist = GetVectorDistance(origin, pos);

		if (nearest == INVALID_ENT_REFERENCE || dist < nearestDist)
		{
			nearest = receiver;
			nearestDist = dist;
		}
	}

	if (nearest == INVALID_ENT_REFERENCE)
	{
		return;
	}

	ZPOGasdumpNF1_ChatMsgSurvivors("I've got the C4");

	ZPOGasdumpNF1_SetObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM, "c4pack_01", nearest, caller, 64.0);
}

static void ZPOGasdumpNF1_OnC4Dropped(const char[] output, int caller, int activator, float delay)
{
	HookSingleEntityOutput(caller, "OnItemTaken", ZPOGasdumpNF1_OnC4Taken, true);

	ZPOGasdumpNF1_ActivateFindC4();
}

static void ZPOGasdumpNF1_OnC4Delivered(const char[] output, int caller, int activator, float delay)
{
	LogDebugMessage("Gasdump: DEBUG C4 planted");
	ZPOGasdumpNF1_ChatMsgSurvivors("C4 planted!");

	ZPOGasdumpNF1_ActivateFindC4();
}

static void ZPOGasdumpNF1_OnC4Planted(const char[] output, int caller, int activator, float delay)
{
	ZPOGasdumpNF1_SetObjective(NAVBOT_ZPS_OBJECTIVE_NONE);

	LogDebugMessage("Gasdump: DEBUG all C4 planted");

	//TODO: Phase 5 - Defend the truck
}
