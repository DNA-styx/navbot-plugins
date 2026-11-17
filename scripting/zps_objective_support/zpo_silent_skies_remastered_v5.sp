/**
 * zpo_silent_skies_remastered_v5.sp
 *
 * NavBot ZPS objective support module for the zpo_silent_skies_remastered_v5 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.2.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

static const char s_CableNames[][] = { "x1b", "x2b", "x3b", "x4b", "x5b", "x6b" };
static int s_CableRefs[sizeof(s_CableNames)];

static const int s_GasCanIDs[] = { 8976799, 8977116, 8977131, 8977136, 8977171, 8977216 };
static bool s_GasCansDone;
static int s_CarriedCanRef;
static int s_GasReceiverRef;

void ZPOSilentSkiesRemasteredV5_Init()
{
	g_ThinkFunc = ZPOSilentSkiesRemasteredV5_Think;

	ZPOSilentSkiesRemasteredV5_WaitForStart();
}

void ZPOSilentSkiesRemasteredV5_Think()
{
	// Left empty until a phase needs per-tick polling.
}

static void ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - Wait for start
 * Summary: Wait for survivors to leave the spawn area.
 * Entity: trigger_once
 * Bot action: none
 * Confirmation: The start trigger fires.
 */
static void ZPOSilentSkiesRemasteredV5_WaitForStart()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "ObjTr");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find trigger_once! Name: ObjTr");
		return;
	}

	HookSingleEntityOutput(trigger, "OnTrigger", ZPOSilentSkiesRemasteredV5_FixCables, true);
}

/**
 * Phase: 1 - Fix cables
 * Summary: Fix the six broken cables.
 * Entity: func_button, math_counter
 * Bot action: USE_BUTTON
 * Confirmation: The cable counter reaches its maximum.
 */
static void ZPOSilentSkiesRemasteredV5_FixCables(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Fix the broken cables to open the gate!");

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "maths");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find math_counter! Name: maths");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOSilentSkiesRemasteredV5_WaitForGate, true);

	for (int i = 0; i < sizeof(s_CableNames); i++)
	{
		s_CableRefs[i] = INVALID_ENT_REFERENCE;

		int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", s_CableNames[i]);

		if (button == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_silent_skies_remastered_v5: Failed to find func_button! Name: %s", s_CableNames[i]);
			continue;
		}

		s_CableRefs[i] = EntIndexToEntRef(button);
		HookSingleEntityOutput(button, "OnPressed", ZPOSilentSkiesRemasteredV5_OnCablePressed, true);
	}

	ZPOSilentSkiesRemasteredV5_TargetNextCable(INVALID_ENT_REFERENCE);
}

// Sends bots to the first cable button still unpressed, skipping the one
// just pressed (it is removed by the map shortly after).
static void ZPOSilentSkiesRemasteredV5_TargetNextCable(int pressed)
{
	for (int i = 0; i < sizeof(s_CableRefs); i++)
	{
		int button = EntRefToEntIndex(s_CableRefs[i]);

		if (button == INVALID_ENT_REFERENCE || button == pressed)
		{
			continue;
		}

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		return;
	}
}

static void ZPOSilentSkiesRemasteredV5_OnCablePressed(const char[] output, int caller, int activator, float delay)
{
	for (int i = 0; i < sizeof(s_CableRefs); i++)
	{
		if (EntRefToEntIndex(s_CableRefs[i]) == caller)
		{
			s_CableRefs[i] = INVALID_ENT_REFERENCE;
		}
	}

	ZPOSilentSkiesRemasteredV5_TargetNextCable(caller);
}

/**
 * Phase: 2 - Wait for gate
 * Summary: Wait for the gate to fully open.
 * Entity: path_track
 * Bot action: none (objective reset)
 * Confirmation: The gate reaches the top of its track.
 */
static void ZPOSilentSkiesRemasteredV5_WaitForGate(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Wait for the gate to open!");

	NavBotZPSModInterface.ResetObjective();

	int track = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "DST");

	if (track == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find path_track! Name: DST");
		return;
	}

	HookSingleEntityOutput(track, "OnPass", ZPOSilentSkiesRemasteredV5_DeliverGasCans, true);
}

/**
 * Phase: 3 - Deliver gas cans
 * Summary: Carry gas cans to the doors one at a time.
 * Entity: item_deliver, trigger_itemreceiver, math_counter
 * Bot action: FIND_ITEM, DROP_ITEM
 * Confirmation: The gas can counter reaches its maximum.
 */
static void ZPOSilentSkiesRemasteredV5_DeliverGasCans(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Find the gas cans and drop them at the doors!");

	s_GasCansDone = false;
	s_CarriedCanRef = INVALID_ENT_REFERENCE;
	s_GasReceiverRef = INVALID_ENT_REFERENCE;

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "M2");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find math_counter! Name: M2");
		return;
	}

	const int receiverid = 8977016;
	int receiver = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_itemreceiver", receiverid);

	if (receiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find trigger_itemreceiver! Hammer ID: %i", receiverid);
		return;
	}

	s_GasReceiverRef = EntIndexToEntRef(receiver);
	HookSingleEntityOutput(counter, "OnHitMax", ZPOSilentSkiesRemasteredV5_WaitForVIPDoor, true);
	HookSingleEntityOutput(receiver, "OnItemDelivered", ZPOSilentSkiesRemasteredV5_OnGasCanDelivered, true);

	for (int i = 0; i < sizeof(s_GasCanIDs); i++)
	{
		int can = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "item_deliver", s_GasCanIDs[i]);

		if (can == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_silent_skies_remastered_v5: Failed to find item_deliver! Hammer ID: %i", s_GasCanIDs[i]);
			continue;
		}

		HookSingleEntityOutput(can, "OnPlayerPickup", ZPOSilentSkiesRemasteredV5_OnGasCanPickup, true);
	}

	ZPOSilentSkiesRemasteredV5_SearchForGasCans();
}

static void ZPOSilentSkiesRemasteredV5_SearchForGasCans()
{
	s_CarriedCanRef = INVALID_ENT_REFERENCE;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("ID1");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

// A bot pickup switches all bots to delivering that can; a human pickup
// leaves the bots searching for the remaining cans.
static void ZPOSilentSkiesRemasteredV5_OnGasCanPickup(const char[] output, int caller, int activator, float delay)
{
	if (s_GasCansDone)
	{
		return;
	}

	HookSingleEntityOutput(caller, "OnItemDropped", ZPOSilentSkiesRemasteredV5_OnGasCanDropped, true);

	if (activator < 1 || activator > MaxClients || !NavBotManager.IsNavBot(activator))
	{
		return;
	}

	int receiver = EntRefToEntIndex(s_GasReceiverRef);

	if (receiver == INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_CarriedCanRef = EntIndexToEntRef(caller);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("ID1");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(receiver);
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(caller);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(256.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM);
}

static void ZPOSilentSkiesRemasteredV5_OnGasCanDropped(const char[] output, int caller, int activator, float delay)
{
	if (s_GasCansDone)
	{
		return;
	}

	HookSingleEntityOutput(caller, "OnPlayerPickup", ZPOSilentSkiesRemasteredV5_OnGasCanPickup, true);

	if (EntRefToEntIndex(s_CarriedCanRef) == caller)
	{
		ZPOSilentSkiesRemasteredV5_SearchForGasCans();
	}
}

static void ZPOSilentSkiesRemasteredV5_OnGasCanDelivered(const char[] output, int caller, int activator, float delay)
{
	if (s_GasCansDone)
	{
		return;
	}

	HookSingleEntityOutput(caller, "OnItemDelivered", ZPOSilentSkiesRemasteredV5_OnGasCanDelivered, true);
	ZPOSilentSkiesRemasteredV5_SearchForGasCans();
}

/**
 * Phase: 4 - Wait for VIP door
 * Summary: Wait for the doors to the VIP room to be blown open.
 * Entity: math_counter
 * Bot action: none (objective reset)
 * Confirmation: Not yet hooked; the VIP card phase will follow.
 */
static void ZPOSilentSkiesRemasteredV5_WaitForVIPDoor(const char[] output, int caller, int activator, float delay)
{
	s_GasCansDone = true;

	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Stand back from the doors!");

	NavBotZPSModInterface.ResetObjective();
}
