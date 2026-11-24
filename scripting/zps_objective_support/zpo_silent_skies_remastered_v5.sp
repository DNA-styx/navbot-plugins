/**
 * zpo_silent_skies_remastered_v5.sp
 *
 * NavBot ZPS objective support module for the zpo_silent_skies_remastered_v5 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.15.0
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

static bool s_CansDone;
static int s_CarriedCanRef = INVALID_ENT_REFERENCE;
static int s_CanReceiverRef;

static const char s_CardNames[][] = { "KB1", "KB2", "KB3" };
static const char s_CodeColours[][][] = {
	{ "red", "blue", "green", "yellow" },
	{ "yellow", "green", "blue", "red" },
	{ "green", "yellow", "red", "blue" }
};
static int s_CardIndex;
static int s_CodeRefs[4];
static int s_CodeStep;
static bool s_CodeDone;
static bool s_SuppliesDone;
static bool s_TracksDone;
static const int s_BarrierIDs[] = { 7896152, 7896065 };
static int s_CarriedSuppliesRef = INVALID_ENT_REFERENCE;
static int s_CodeBotRef = INVALID_ENT_REFERENCE;
static float s_KeypadPos[3];

enum ZPOSilentSkiesRemasteredV5_Phase
{
	ZPOSilentSkiesRemasteredV5_Phase_None = 0,
	ZPOSilentSkiesRemasteredV5_Phase_EnterCode
};

// Objective set by Think() once bots have had time to drop leftover items.
enum ZPOSilentSkiesRemasteredV5_Pending
{
	ZPOSilentSkiesRemasteredV5_Pending_None = 0,
	ZPOSilentSkiesRemasteredV5_Pending_Radio,
	ZPOSilentSkiesRemasteredV5_Pending_Barrier
};

static ZPOSilentSkiesRemasteredV5_Pending s_PendingObjective = ZPOSilentSkiesRemasteredV5_Pending_None;
static float s_PendingTime;
static int s_PendingEntRef = INVALID_ENT_REFERENCE;
static int s_LastGroundRef[MAXPLAYERS + 1];

static ZPOSilentSkiesRemasteredV5_Phase s_CurrentPhase = ZPOSilentSkiesRemasteredV5_Phase_None;

void ZPOSilentSkiesRemasteredV5_Init()
{
	g_ThinkFunc = ZPOSilentSkiesRemasteredV5_Think;
	g_OnRoundEndFunc = ZPOSilentSkiesRemasteredV5_DebugRoundEnd;

	s_CurrentPhase = ZPOSilentSkiesRemasteredV5_Phase_None;
	s_PendingObjective = ZPOSilentSkiesRemasteredV5_Pending_None;

	for (int client = 0; client <= MaxClients; client++)
	{
		s_LastGroundRef[client] = INVALID_ENT_REFERENCE;
	}

	ZPOSilentSkiesRemasteredV5_WaitForStart();
}

void ZPOSilentSkiesRemasteredV5_Think()
{
	if (s_CurrentPhase == ZPOSilentSkiesRemasteredV5_Phase_EnterCode)
	{
		ZPOSilentSkiesRemasteredV5_UpdateCodeBots(true);
	}

	if (s_PendingObjective != ZPOSilentSkiesRemasteredV5_Pending_None && GetGameTime() >= s_PendingTime)
	{
		ZPOSilentSkiesRemasteredV5_Pending pending = s_PendingObjective;
		s_PendingObjective = ZPOSilentSkiesRemasteredV5_Pending_None;

		if (pending == ZPOSilentSkiesRemasteredV5_Pending_Radio)
		{
			int button = EntRefToEntIndex(s_PendingEntRef);

			if (button != INVALID_ENT_REFERENCE)
			{
				NavBotZPSModInterface.ResetObjective();
				NavBotZPSModInterface.SetObjectiveUseButton(button);
				NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
			}
		}
		else if (pending == ZPOSilentSkiesRemasteredV5_Pending_Barrier)
		{
			ZPOSilentSkiesRemasteredV5_TargetNextBarrier(INVALID_ENT_REFERENCE);
		}
	}

	ZPOSilentSkiesRemasteredV5_DebugElevators();
	ZPOSilentSkiesRemasteredV5_DebugCarrier();
}

// TEMPORARY DEBUG - every 5 seconds while a bot carries the current can,
// logs the carrier and dumps every bot's active task.
static void ZPOSilentSkiesRemasteredV5_DebugCarrier()
{
	static float s_NextDump;

	if (s_CansDone || GetGameTime() < s_NextDump)
	{
		return;
	}

	int can = EntRefToEntIndex(s_CarriedCanRef);

	if (can <= MaxClients)
	{
		return;
	}

	int owner = GetEntPropEnt(can, Prop_Send, "m_hOwner");

	if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
	{
		return;
	}

	s_NextDump = GetGameTime() + 5.0;

	float pos[3];
	GetClientAbsOrigin(owner, pos);

	LogDebugMessage("SilentSkies: Carrier %N has can %d at %.0f %.0f %.0f, armour %d", owner, can, pos[0], pos[1], pos[2], GetEntProp(owner, Prop_Send, "m_ArmorValue"));
	ServerCommand("sm_nbadmin_dump_behavior");
}

// Tells bots to drop every item_deliver they carry. Any follow-up objective
// is set by Think() after a short delay.
static void ZPOSilentSkiesRemasteredV5_DropAllItems(ZPOSilentSkiesRemasteredV5_Pending next, int entity)
{
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ALL_ITEMS);

	s_PendingObjective = next;
	s_PendingTime = GetGameTime() + 3.0;
	s_PendingEntRef = (entity == INVALID_ENT_REFERENCE) ? INVALID_ENT_REFERENCE : EntIndexToEntRef(entity);
}

// TEMPORARY DEBUG - logs survivor bots standing on a moving brush entity
// (elevators, lifts, trains) so elevator use shows in the log.
static void ZPOSilentSkiesRemasteredV5_DebugElevators()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 2 || !NavBotManager.IsNavBot(client))
		{
			continue;
		}

		int ground = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
		int groundRef = (ground > MaxClients) ? EntIndexToEntRef(ground) : INVALID_ENT_REFERENCE;

		if (groundRef == s_LastGroundRef[client])
		{
			continue;
		}

		s_LastGroundRef[client] = groundRef;

		if (groundRef == INVALID_ENT_REFERENCE)
		{
			continue;
		}

		char classname[64];
		GetEntityClassname(ground, classname, sizeof(classname));

		if (StrContains(classname, "func_", false) != 0 || StrEqual(classname, "func_brush") || StrEqual(classname, "func_detail"))
		{
			continue;
		}

		char name[64];
		GetEntPropString(ground, Prop_Data, "m_iName", name, sizeof(name));

		float pos[3];
		GetClientAbsOrigin(client, pos);

		LogDebugMessage("SilentSkies: Elevator - %N on %s \"%s\" (entity %d) at %.0f %.0f %.0f", client, classname, name, ground, pos[0], pos[1], pos[2]);
	}
}

// TEMPORARY DEBUG - remove once the full chain is confirmed working.
static void ZPOSilentSkiesRemasteredV5_DebugRoundEnd()
{
	int survivors = 0;
	int zombies = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client))
		{
			continue;
		}

		if (GetClientTeam(client) == 2)
		{
			survivors++;
		}
		else if (GetClientTeam(client) == 3)
		{
			zombies++;
		}
	}

	LogDebugMessage("SilentSkies: Round end - alive survivors %d, alive zombies %d", survivors, zombies);
}

static void ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors(const char[] msg)
{
	// TEMPORARY DEBUG - remove once the full chain is confirmed working.
	LogDebugMessage("SilentSkies: Phase message: %s", msg);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

// Gas can delivery shared by the gas can and generator phases. Bots search
// for ID1 cans; a bot pickup switches all bots to dropping that can at the
// current receiver; a human pickup leaves the bots searching.
static void ZPOSilentSkiesRemasteredV5_StartCanDelivery(int receiver)
{
	s_CansDone = false;
	s_CanReceiverRef = EntIndexToEntRef(receiver);

	HookSingleEntityOutput(receiver, "OnItemDelivered", ZPOSilentSkiesRemasteredV5_OnCanDelivered, true);

	int can = INVALID_ENT_REFERENCE;

	while ((can = FindNamedEntityOfClassname(can, "item_deliver", "ID1")) != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(can, "OnPlayerPickup", ZPOSilentSkiesRemasteredV5_OnCanPickup, true);
	}

	ZPOSilentSkiesRemasteredV5_SearchForCans();
}

static void ZPOSilentSkiesRemasteredV5_StopCanDelivery()
{
	s_CansDone = true;

	int can = INVALID_ENT_REFERENCE;

	while ((can = FindNamedEntityOfClassname(can, "item_deliver", "ID1")) != INVALID_ENT_REFERENCE)
	{
		UnhookSingleEntityOutput(can, "OnPlayerPickup", ZPOSilentSkiesRemasteredV5_OnCanPickup);
		UnhookSingleEntityOutput(can, "OnItemDropped", ZPOSilentSkiesRemasteredV5_OnCanDropped);
	}

	int receiver = EntRefToEntIndex(s_CanReceiverRef);

	if (receiver != INVALID_ENT_REFERENCE)
	{
		UnhookSingleEntityOutput(receiver, "OnItemDelivered", ZPOSilentSkiesRemasteredV5_OnCanDelivered);
	}
}

static void ZPOSilentSkiesRemasteredV5_SearchForCans()
{
	s_CarriedCanRef = INVALID_ENT_REFERENCE;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("ID1");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

static void ZPOSilentSkiesRemasteredV5_OnCanPickup(const char[] output, int caller, int activator, float delay)
{
	if (s_CansDone)
	{
		return;
	}

	HookSingleEntityOutput(caller, "OnItemDropped", ZPOSilentSkiesRemasteredV5_OnCanDropped, true);

	// TEMPORARY DEBUG - tracks gas can carriers.
	ZPOSilentSkiesRemasteredV5_DebugCan("picked up", caller, activator);

	if (activator < 1 || activator > MaxClients || !NavBotManager.IsNavBot(activator))
	{
		return;
	}

	int receiver = EntRefToEntIndex(s_CanReceiverRef);

	if (receiver == INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_CarriedCanRef = EntIndexToEntRef(caller);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("ID1");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(receiver);
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(caller);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(64.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM);
}

static void ZPOSilentSkiesRemasteredV5_OnCanDropped(const char[] output, int caller, int activator, float delay)
{
	if (s_CansDone)
	{
		return;
	}

	HookSingleEntityOutput(caller, "OnPlayerPickup", ZPOSilentSkiesRemasteredV5_OnCanPickup, true);

	// TEMPORARY DEBUG - tracks gas can carriers.
	ZPOSilentSkiesRemasteredV5_DebugCan("dropped", caller, activator);

	if (EntRefToEntIndex(s_CarriedCanRef) == caller)
	{
		ZPOSilentSkiesRemasteredV5_SearchForCans();
	}
}

// TEMPORARY DEBUG - logs a gas can pickup or drop with the player, their
// position, distance to the current receiver and their active task.
static void ZPOSilentSkiesRemasteredV5_DebugCan(const char[] action, int can, int activator)
{
	char who[MAX_NAME_LENGTH] = "unknown";
	float pos[3];
	float dist = -1.0;

	if (activator >= 1 && activator <= MaxClients && IsClientInGame(activator))
	{
		GetClientName(activator, who, sizeof(who));
	}

	GetEntPropVector(can, Prop_Data, "m_vecAbsOrigin", pos);

	int receiver = EntRefToEntIndex(s_CanReceiverRef);

	if (receiver != INVALID_ENT_REFERENCE)
	{
		float rpos[3];
		GetEntPropVector(receiver, Prop_Data, "m_vecAbsOrigin", rpos);
		dist = GetVectorDistance(pos, rpos);
	}

	LogDebugMessage("SilentSkies: Can %d %s by %s at %.0f %.0f %.0f (%.0f from receiver)", can, action, who, pos[0], pos[1], pos[2], dist);
}

static void ZPOSilentSkiesRemasteredV5_OnCanDelivered(const char[] output, int caller, int activator, float delay)
{
	if (s_CansDone)
	{
		return;
	}

	HookSingleEntityOutput(caller, "OnItemDelivered", ZPOSilentSkiesRemasteredV5_OnCanDelivered, true);

	// TEMPORARY DEBUG - remove once the full chain is confirmed working.
	LogDebugMessage("SilentSkies: Can delivered");

	ZPOSilentSkiesRemasteredV5_SearchForCans();
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

	HookSingleEntityOutput(track, "OnPass", ZPOSilentSkiesRemasteredV5_EnterFuelArea, true);
}

/**
 * Phase: 3 - Enter fuel area
 * Summary: Move through the gate into the gas can area.
 * Entity: trigger_multiple
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: A survivor touches the trigger.
 */
static void ZPOSilentSkiesRemasteredV5_EnterFuelArea(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("The gate is open, move through!");

	const int triggerid = 3946802;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_multiple", triggerid);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find trigger_multiple! Hammer ID: %i", triggerid);
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOSilentSkiesRemasteredV5_DeliverGasCans, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 4 - Deliver gas cans
 * Summary: Carry gas cans to the doors one at a time.
 * Entity: item_deliver, trigger_itemreceiver, math_counter
 * Bot action: FIND_ITEM, DROP_ITEM
 * Confirmation: The gas can counter reaches its maximum.
 */
static void ZPOSilentSkiesRemasteredV5_DeliverGasCans(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Find the gas cans and drop them at the doors!");

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

	HookSingleEntityOutput(counter, "OnHitMax", ZPOSilentSkiesRemasteredV5_WaitForVIPDoor, true);

	ZPOSilentSkiesRemasteredV5_StartCanDelivery(receiver);
}

/**
 * Phase: 5 - Wait for VIP door
 * Summary: Wait for the doors to the VIP room to be blown open.
 * Entity: func_door_rotating
 * Bot action: DROP_ALL_ITEMS
 * Confirmation: The VIP room doors open.
 */
static void ZPOSilentSkiesRemasteredV5_WaitForVIPDoor(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_StopCanDelivery();

	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Stand back from the doors!");

	ZPOSilentSkiesRemasteredV5_DropAllItems(ZPOSilentSkiesRemasteredV5_Pending_None, INVALID_ENT_REFERENCE);

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "DA7");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find func_door_rotating! Name: DA7");
		return;
	}

	HookSingleEntityOutput(door, "OnOpen", ZPOSilentSkiesRemasteredV5_TakeVIPCard, true);
}

/**
 * Phase: 6 - Take VIP card
 * Summary: Take the VIP card.
 * Entity: func_rot_button
 * Bot action: USE_BUTTON
 * Confirmation: The card is pressed.
 */
static void ZPOSilentSkiesRemasteredV5_TakeVIPCard(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Find the VIP card!");

	s_CardIndex = -1;

	int card = INVALID_ENT_REFERENCE;

	for (int i = 0; i < sizeof(s_CardNames); i++)
	{
		card = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_rot_button", s_CardNames[i]);

		if (card != INVALID_ENT_REFERENCE)
		{
			s_CardIndex = i;
			break;
		}
	}

	if (card == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find func_rot_button! Name: KB1/KB2/KB3");
		return;
	}

	HookSingleEntityOutput(card, "OnPressed", ZPOSilentSkiesRemasteredV5_EnterCode, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(card);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 7 - Enter code
 * Summary: One survivor bot goes to the basement-side keypad and the module presses the code for it.
 * Entity: func_button, math_counter
 * Bot action: plugin commands MOVE_TO and WAIT; Press input on the current button
 * Confirmation: The code counter reaches its maximum.
 */
static void ZPOSilentSkiesRemasteredV5_EnterCode(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Enter the code on the keypad!");

	s_CodeDone = false;
	s_CodeStep = 0;
	s_CodeBotRef = INVALID_ENT_REFERENCE;

	NavBotZPSModInterface.ResetObjective();

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "M1");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find math_counter! Name: M1");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOSilentSkiesRemasteredV5_FuelGenerators, true);

	if (s_CardIndex < 0)
	{
		NavBotZPSModInterface.ResetObjective();
		return;
	}

	// Keypad B (opens Dbas3) is always used.
	float keypadB[3] = { -1379.0, -500.0, 75.0 };
	s_KeypadPos = keypadB;

	for (int i = 0; i < sizeof(s_CodeRefs); i++)
	{
		s_CodeRefs[i] = INVALID_ENT_REFERENCE;

		char name[16];

		Format(name, sizeof(name), "%s%d%d", s_CodeColours[s_CardIndex][i], s_CardIndex + 1, s_CardIndex + 1);

		int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", name);

		if (button == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_silent_skies_remastered_v5: Failed to find func_button! Name: %s", name);
			NavBotZPSModInterface.ResetObjective();
			return;
		}

		s_CodeRefs[i] = EntIndexToEntRef(button);
		HookSingleEntityOutput(button, "OnPressed", ZPOSilentSkiesRemasteredV5_OnCodePressed, true);

		// The final button has no reset outputs.
		if (i < sizeof(s_CodeRefs) - 1)
		{
			HookSingleEntityOutput(button, "OnUseLocked", ZPOSilentSkiesRemasteredV5_OnCodeReset, true);
		}
		else
		{
			HookSingleEntityOutput(button, "OnUseLocked", ZPOSilentSkiesRemasteredV5_DebugFinalLocked, false);
		}

		LogDebugMessage("SilentSkies: Code button %d is %s (entity %d)", i + 1, name, button);
	}

	s_CurrentPhase = ZPOSilentSkiesRemasteredV5_Phase_EnterCode;
	ZPOSilentSkiesRemasteredV5_UpdateCodeBots(false);
}

// Returns the alive survivor NavBot nearest the chosen keypad, or 0.
static int ZPOSilentSkiesRemasteredV5_FindCodeBot()
{
	int best = 0;
	float bestDist = 0.0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 2 || !NavBotManager.IsNavBot(client))
		{
			continue;
		}

		float pos[3];
		GetClientAbsOrigin(client, pos);
		float dist = GetVectorDistance(pos, s_KeypadPos);

		if (best == 0 || dist < bestDist)
		{
			best = client;
			bestDist = dist;
		}
	}

	return best;
}

// Keeps one survivor bot at the keypad and every other survivor bot waiting.
// Once the code bot is within use range, the current button is pressed for
// it (only from Think(), so the map's unlock of the next button has run).
// The bot never presses itself: the keypad buttons are too close together
// for its aim.
static void ZPOSilentSkiesRemasteredV5_UpdateCodeBots(bool allowPress)
{
	int button = EntRefToEntIndex(s_CodeRefs[s_CodeStep]);

	if (button == INVALID_ENT_REFERENCE)
	{
		return;
	}

	int codeBot = EntRefToEntIndex(s_CodeBotRef);

	if (codeBot == INVALID_ENT_REFERENCE || !IsClientInGame(codeBot) || !IsPlayerAlive(codeBot) || GetClientTeam(codeBot) != 2)
	{
		codeBot = ZPOSilentSkiesRemasteredV5_FindCodeBot();
		s_CodeBotRef = (codeBot == 0) ? INVALID_ENT_REFERENCE : EntIndexToEntRef(codeBot);

		// TEMPORARY DEBUG - remove once code entry is confirmed working.
		if (codeBot != 0)
		{
			LogDebugMessage("SilentSkies: Code bot is %N", codeBot);
		}
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 2 || !NavBotManager.IsNavBot(client))
		{
			continue;
		}

		NavBot bot = NavBotManager.GetNavBotByIndex(client);

		if (client != codeBot)
		{
			if (!NavBotBehaviorInterface.IsRunningPluginCommand(bot.GetBehaviorInterface()))
			{
				bot.SendPluginCommand(NAVBOT_PLUGINCMD_WAIT, 5.0);
			}

			continue;
		}

		float eyePos[3];
		float buttonPos[3];
		GetClientEyePosition(client, eyePos);
		GetEntPropVector(button, Prop_Data, "m_vecAbsOrigin", buttonPos);

		if (GetVectorDistance(eyePos, buttonPos) > 80.0)
		{
			if (!NavBotBehaviorInterface.IsRunningPluginCommand(bot.GetBehaviorInterface()))
			{
				bot.SendPluginCommand(NAVBOT_PLUGINCMD_MOVE_TO, s_KeypadPos);
			}

			continue;
		}

		if (!NavBotBehaviorInterface.IsRunningPluginCommand(bot.GetBehaviorInterface()))
		{
			bot.SendPluginCommand(NAVBOT_PLUGINCMD_WAIT, 5.0);
		}

		if (allowPress && GetEntProp(button, Prop_Data, "m_bLocked") == 0)
		{
			// TEMPORARY DEBUG - remove once code entry is confirmed working.
			LogDebugMessage("SilentSkies: Assisted press on code button %d for %N", s_CodeStep + 1, client);

			AcceptEntityInput(button, "Press", client, client);
		}
	}
}

static void ZPOSilentSkiesRemasteredV5_OnCodePressed(const char[] output, int caller, int activator, float delay)
{
	if (s_CodeDone)
	{
		return;
	}

	HookSingleEntityOutput(caller, "OnPressed", ZPOSilentSkiesRemasteredV5_OnCodePressed, true);

	ZPOSilentSkiesRemasteredV5_DebugCodePress("OnPressed", caller, activator);

	for (int i = 0; i < sizeof(s_CodeRefs) - 1; i++)
	{
		if (EntRefToEntIndex(s_CodeRefs[i]) == caller)
		{
			s_CodeStep = i + 1;
			ZPOSilentSkiesRemasteredV5_UpdateCodeBots(false);
			return;
		}
	}
}

// A wrong press resets the keypad to its first button.
static void ZPOSilentSkiesRemasteredV5_OnCodeReset(const char[] output, int caller, int activator, float delay)
{
	if (s_CodeDone)
	{
		return;
	}

	HookSingleEntityOutput(caller, "OnUseLocked", ZPOSilentSkiesRemasteredV5_OnCodeReset, true);

	ZPOSilentSkiesRemasteredV5_DebugCodePress("OnUseLocked (reset)", caller, activator);

	s_CodeStep = 0;
	ZPOSilentSkiesRemasteredV5_UpdateCodeBots(false);
}

// TEMPORARY DEBUG - remove once code entry is confirmed working.
static void ZPOSilentSkiesRemasteredV5_DebugFinalLocked(const char[] output, int caller, int activator, float delay)
{
	if (s_CodeDone)
	{
		return;
	}

	ZPOSilentSkiesRemasteredV5_DebugCodePress("OnUseLocked (final)", caller, activator);
}

// TEMPORARY DEBUG - remove once code entry is confirmed working.
static void ZPOSilentSkiesRemasteredV5_DebugCodePress(const char[] output, int caller, int activator)
{
	char name[32];
	GetEntPropString(caller, Prop_Data, "m_iName", name, sizeof(name));

	char who[MAX_NAME_LENGTH] = "unknown";

	if (activator >= 1 && activator <= MaxClients && IsClientInGame(activator))
	{
		GetClientName(activator, who, sizeof(who));
	}

	LogDebugMessage("SilentSkies: %s on %s by %s (target step %d)", output, name, who, s_CodeStep + 1);
}

/**
 * Phase: 8 - Fuel generators
 * Summary: Carry gas cans to the generators one at a time.
 * Entity: logic_case
 * Bot action: none (placeholder - objective reset)
 * Confirmation: Both generators are fuelled.
 *
 * PLACEHOLDER: bots carrying cans are pulled away by the scenario task's
 * weapon/ammo/health/armour searches, because ObjectiveDropItem does not
 * answer ShouldHurry. Restore StartCanDelivery() with the "BT" receiver once
 * NavBot is fixed.
 */
static void ZPOSilentSkiesRemasteredV5_FuelGenerators(const char[] output, int caller, int activator, float delay)
{
	s_CodeDone = true;
	s_CurrentPhase = ZPOSilentSkiesRemasteredV5_Phase_None;

	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Find gas cans and fuel the generators!");

	NavBotZPSModInterface.ResetObjective();

	int fuelcase = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_case", "Lo0");

	if (fuelcase == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find logic_case! Name: Lo0");
		return;
	}

	HookSingleEntityOutput(fuelcase, "OnCase06", ZPOSilentSkiesRemasteredV5_TurnOnRadio, true);

	// TEMPORARY DEBUG - logs each generator fuel step.
	static const char cases[][] = { "OnCase01", "OnCase02", "OnCase03", "OnCase04", "OnCase05", "OnCase06" };

	for (int i = 0; i < sizeof(cases); i++)
	{
		HookSingleEntityOutput(fuelcase, cases[i], ZPOSilentSkiesRemasteredV5_DebugFuelCase, true);
	}
}

// TEMPORARY DEBUG - logs each generator fuel step.
static void ZPOSilentSkiesRemasteredV5_DebugFuelCase(const char[] output, int caller, int activator, float delay)
{
	LogDebugMessage("SilentSkies: Fuel logic_case Lo0 %s", output);
}

/**
 * Phase: 9 - Turn on radio
 * Summary: Turn on the radio at the top of the ATC tower.
 * Entity: func_button, filter_activator_team
 * Bot action: DROP_ALL_ITEMS, then USE_BUTTON
 * Confirmation: A survivor press of the radio button is accepted.
 */
static void ZPOSilentSkiesRemasteredV5_TurnOnRadio(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_StopCanDelivery();

	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Climb the ATC tower and turn on the radio!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "BTT");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find func_button! Name: BTT");
		return;
	}

	int filter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "filter_activator_team", "FH");

	if (filter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find filter_activator_team! Name: FH");
		return;
	}

	HookSingleEntityOutput(filter, "OnPass", ZPOSilentSkiesRemasteredV5_DefendRadio, true);

	ZPOSilentSkiesRemasteredV5_DropAllItems(ZPOSilentSkiesRemasteredV5_Pending_Radio, button);
}

/**
 * Phase: 10 - Defend radio
 * Summary: Hold the radio room while the signal is sent.
 * Entity: point_template
 * Bot action: MOVETO
 * Confirmation: The supplies are spawned.
 */
static void ZPOSilentSkiesRemasteredV5_DefendRadio(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Defend the radio!");

	s_PendingObjective = ZPOSilentSkiesRemasteredV5_Pending_None;

	float goal[3] = { -131.7, -37.4, 1826.0 };

	NavBotZPSModInterface.ResetObjective();
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int spawner = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "point_template", "temp");

	if (spawner == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find point_template! Name: temp");
		return;
	}

	HookSingleEntityOutput(spawner, "OnEntitySpawned", ZPOSilentSkiesRemasteredV5_DeliverSupplies, true);
}

/**
 * Phase: 11 - Deliver supplies
 * Summary: Carry the supplies onto the subway train.
 * Entity: item_deliver, trigger_itemreceiver, math_counter
 * Bot action: FIND_ITEM, MOVE_TO_ENTITY
 * Confirmation: The train objective counter changes.
 */
static void ZPOSilentSkiesRemasteredV5_DeliverSupplies(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Find the supplies and take them to the subway train!");

	s_SuppliesDone = false;
	s_CarriedSuppliesRef = INVALID_ENT_REFERENCE;

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "M3");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find math_counter! Name: M3");
		return;
	}

	HookSingleEntityOutput(counter, "OutValue", ZPOSilentSkiesRemasteredV5_ClearTracks, true);

	// TEMPORARY DEBUG - checks whether trigger_itemreceiver output hooks fire.
	int receiver = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_itemreceiver", "TT");

	if (receiver != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(receiver, "OnItemDelivered", ZPOSilentSkiesRemasteredV5_DebugSuppliesReceiver, true);
	}

	int box = INVALID_ENT_REFERENCE;

	while ((box = FindNamedEntityOfClassname(box, "item_deliver", "ID2")) != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(box, "OnPlayerPickup", ZPOSilentSkiesRemasteredV5_OnSuppliesPickup, true);
	}

	ZPOSilentSkiesRemasteredV5_SearchForSupplies();
}

static void ZPOSilentSkiesRemasteredV5_SearchForSupplies()
{
	s_CarriedSuppliesRef = INVALID_ENT_REFERENCE;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("ID2");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

// A bot pickup sends all bots to the train with the carrier; a human
// pickup leaves the bots searching for the spare boxes.
static void ZPOSilentSkiesRemasteredV5_OnSuppliesPickup(const char[] output, int caller, int activator, float delay)
{
	if (s_SuppliesDone)
	{
		return;
	}

	HookSingleEntityOutput(caller, "OnItemDropped", ZPOSilentSkiesRemasteredV5_OnSuppliesDropped, true);

	if (activator < 1 || activator > MaxClients || !NavBotManager.IsNavBot(activator))
	{
		return;
	}

	int receiver = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_itemreceiver", "TT");

	if (receiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find trigger_itemreceiver! Name: TT");
		return;
	}

	s_CarriedSuppliesRef = EntIndexToEntRef(caller);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(receiver);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

static void ZPOSilentSkiesRemasteredV5_OnSuppliesDropped(const char[] output, int caller, int activator, float delay)
{
	if (s_SuppliesDone)
	{
		return;
	}

	HookSingleEntityOutput(caller, "OnPlayerPickup", ZPOSilentSkiesRemasteredV5_OnSuppliesPickup, true);

	if (EntRefToEntIndex(s_CarriedSuppliesRef) == caller)
	{
		ZPOSilentSkiesRemasteredV5_SearchForSupplies();
	}
}

// TEMPORARY DEBUG - checks whether trigger_itemreceiver output hooks fire.
static void ZPOSilentSkiesRemasteredV5_DebugSuppliesReceiver(const char[] output, int caller, int activator, float delay)
{
	LogDebugMessage("SilentSkies: TT OnItemDelivered hook fired");
}

/**
 * Phase: 12 - Clear the tracks
 * Summary: Break the two subway barriers.
 * Entity: func_breakable, math_counter
 * Bot action: DROP_ALL_ITEMS, then DESTROY_ENTITY
 * Confirmation: The barrier counter reaches its maximum.
 */
static void ZPOSilentSkiesRemasteredV5_ClearTracks(const char[] output, int caller, int activator, float delay)
{
	s_SuppliesDone = true;
	s_TracksDone = false;

	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Supplies delivered! Clear the tracks!");

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "M9");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find math_counter! Name: M9");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOSilentSkiesRemasteredV5_WaitForDeparture, true);

	for (int i = 0; i < sizeof(s_BarrierIDs); i++)
	{
		int barrier = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", s_BarrierIDs[i]);

		if (barrier == INVALID_ENT_REFERENCE)
		{
			continue;
		}

		HookSingleEntityOutput(barrier, "OnBreak", ZPOSilentSkiesRemasteredV5_OnBarrierBroken, true);
	}

	ZPOSilentSkiesRemasteredV5_DropAllItems(ZPOSilentSkiesRemasteredV5_Pending_Barrier, INVALID_ENT_REFERENCE);
}

// Sends bots to the first barrier still standing, skipping the one just
// broken (it is removed by the engine shortly after).
static void ZPOSilentSkiesRemasteredV5_TargetNextBarrier(int broken)
{
	for (int i = 0; i < sizeof(s_BarrierIDs); i++)
	{
		int barrier = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", s_BarrierIDs[i]);

		if (barrier == INVALID_ENT_REFERENCE || barrier == broken)
		{
			continue;
		}

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveGenericTargetEntity(barrier);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
		return;
	}
}

static void ZPOSilentSkiesRemasteredV5_OnBarrierBroken(const char[] output, int caller, int activator, float delay)
{
	if (s_TracksDone)
	{
		return;
	}

	ZPOSilentSkiesRemasteredV5_TargetNextBarrier(caller);
}

/**
 * Phase: 13 - Wait for departure
 * Summary: Wait for the train to be ready to leave.
 * Entity: math_counter
 * Bot action: none (objective reset)
 * Confirmation: The train counter reaches its maximum.
 */
static void ZPOSilentSkiesRemasteredV5_WaitForDeparture(const char[] output, int caller, int activator, float delay)
{
	s_TracksDone = true;
	s_PendingObjective = ZPOSilentSkiesRemasteredV5_Pending_None;

	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Tracks clear! Wait for the green signal!");

	NavBotZPSModInterface.ResetObjective();

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "M8");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find math_counter! Name: M8");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOSilentSkiesRemasteredV5_BoardTrain, true);
}

/**
 * Phase: 14 - Board the train
 * Summary: Get on the subway train.
 * Entity: trigger_multiple, logic_relay
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: The train departs.
 */
static void ZPOSilentSkiesRemasteredV5_BoardTrain(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("Get on the train!");

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "ST");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find trigger_multiple! Name: ST");
		return;
	}

	int relay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "LR1");

	if (relay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_silent_skies_remastered_v5: Failed to find logic_relay! Name: LR1");
		return;
	}

	HookSingleEntityOutput(relay, "OnTrigger", ZPOSilentSkiesRemasteredV5_TrainDeparted, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 15 - Train departed
 * Summary: The train has left; the map ends.
 * Entity: logic_relay
 * Bot action: none (objective reset)
 * Confirmation: None; final phase.
 */
static void ZPOSilentSkiesRemasteredV5_TrainDeparted(const char[] output, int caller, int activator, float delay)
{
	ZPOSilentSkiesRemasteredV5_ChatMsgSurvivors("The train is leaving!");

	NavBotZPSModInterface.ResetObjective();
}
