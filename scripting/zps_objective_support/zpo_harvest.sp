/**
 * zpo_harvest.sp
 *
 * NavBot ZPS objective support module for the zpo_harvest map.
 * Intended to be #included by zps_objective_support.sp, alongside zpo_biotec.sp.
 *
 * Module version: 0.3.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase 0: "DefendHouse" objective.
 *   - Passive. No bot task set; bots defend normally until the round script's
 *     TV announcement finishes and the basement door opens.
 *   - Hooks bsmnt_door's OnFullyOpen (prop_door_rotating) for the Phase 0 ->
 *     Phase 1 transition.
 *
 * Phase 1: "GetDownToBasement" / "FireUpGenerator" (partial).
 *   - Confirmed with DNA.styx that GetDownToBasement is not a discrete bot task
 *     on this map: once bsmnt_door opens, survivors walk straight to the
 *     generator and press it.
 *   - Skips directly to NAVBOT_ZPS_OBJECTIVE_USE_BUTTON on genobj_spot
 *     (func_button). Hooks its OnPressed for Phase 2.
 *
 * Phase 2: "FindFuse" objective.
 *   - The fuse item ("Blast_Objective_Fuse") does not exist at map load -- it's
 *     spawned at runtime by the .as script's Obj_FuseTeleport() (called as soon
 *     as the basement door opens), so it can't be hooked the way zpo_biotec.sp
 *     hooks its (map-start-static) keys. ZPOHarvest_PollFuseItem() polls for it
 *     by name each tick, same shape as zpo_tanker.sp's force-spawned buttons.
 *   - Once found: NAVBOT_ZPS_OBJECTIVE_FIND_ITEM with item search ID "fuse".
 *   - Once picked up (OnItemTaken): NAVBOT_ZPS_OBJECTIVE_USE_ITEM targeting
 *     blastobj_setfuse (trigger_useable).
 *   - Once planted (blastobj_setfuse's OnUsed): NAVBOT_ZPS_OBJECTIVE_MOVETO to a
 *     hardcoded position clear of the blast radius. The .as script's detonation
 *     sequence has a multi-second delay (spark travel along fuse_track_0-3)
 *     before the wall actually blows, giving bots time to clear.
 *   - Wall detonation is confirmed via C4Relay (logic_relay), which is what the
 *     .as script's Obj_BombDetonate() is actually bound to
 *     (its OnTrigger output) -- a real Hammer signal, no polling needed here.
 *
 * Phase 3: "FireUpGenerator" (Barn Key / padlock).
 *   - C4Relay's OnTrigger also means Obj_BombDetonate() has spawned the Barn Key
 *     (genobj_lockkeys) far across the newly-opened tunnel, well outside default
 *     detection radius. NAVBOT_ZPS_OBJECTIVE_MOVETO carries bots to the far end
 *     of the tunnel first (hardcoded position past genobj_powerout).
 *   - genobj_powerout (trigger_once, human-only filter -- confirmed this still
 *     fires for bots, since the whole objective chain depends on it) confirms
 *     arrival; hooking its OnTrigger hands off to NAVBOT_ZPS_OBJECTIVE_FIND_ITEM
 *     with item search ID "keys".
 *   - Same as the fuse: genobj_lockkeys does not exist at map load (spawned by
 *     Util_CreateBarnKey() at detonation time), so ZPOHarvest_PollKeysItem()
 *     polls for it by name each tick.
 *   - Once picked up (OnItemTaken): NAVBOT_ZPS_OBJECTIVE_USE_ITEM targeting
 *     trig_keys (trigger_useable), the padlock's usable socket. Its OnUsed
 *     calls the .as script's GenRoomUnlocked(), which opens genobj_door,
 *     clearing the path to genobj_spot (already handled by Phase 1).
 *
 * RadioMilitary onward: not yet implemented (TODO).
 */

static bool s_bFuseItemHooked;
static bool s_bKeysItemHooked;

void ZPOHarvest_OnKeysUsed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// TODO: RadioMilitary phase.
}

void ZPOHarvest_OnKeysItemTaken(const char[] output, int caller, int activator, float delay)
{
	int socket = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "trig_keys");

	if (socket == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find trig_keys!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(socket);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);

	HookSingleEntityOutput(socket, "OnUsed", ZPOHarvest_OnKeysUsed, true);
}

void ZPOHarvest_PollKeysItem()
{
	if (s_bKeysItemHooked)
	{
		return;
	}

	int item = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "genobj_lockkeys");

	if (item == INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_bKeysItemHooked = true;
	HookSingleEntityOutput(item, "OnItemTaken", ZPOHarvest_OnKeysItemTaken, true);
}

void ZPOHarvest_OnGeneratorAreaReached(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);

	s_bKeysItemHooked = false;
}

void ZPOHarvest_OnBombDetonated(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	float goal[3];
	goal[0] = 2395.857666;
	goal[1] = 395.710205;
	goal[2] = -596.968750;

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "genobj_powerout");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find genobj_powerout!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnTrigger", ZPOHarvest_OnGeneratorAreaReached, true);
}

void ZPOHarvest_OnFusePlanted(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	float goal[3];
	goal[0] = 452.259369;
	goal[1] = 551.809082;
	goal[2] = -551.968750;

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int relay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "C4Relay");

	if (relay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find C4Relay!");
		return;
	}

	HookSingleEntityOutput(relay, "OnTrigger", ZPOHarvest_OnBombDetonated, true);
}

void ZPOHarvest_OnFuseItemTaken(const char[] output, int caller, int activator, float delay)
{
	int socket = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "blastobj_setfuse");

	if (socket == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find blastobj_setfuse!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("fuse");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(socket);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);

	HookSingleEntityOutput(socket, "OnUsed", ZPOHarvest_OnFusePlanted, true);
}

void ZPOHarvest_PollFuseItem()
{
	if (s_bFuseItemHooked)
	{
		return;
	}

	int item = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "Blast_Objective_Fuse");

	if (item == INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_bFuseItemHooked = true;
	HookSingleEntityOutput(item, "OnItemTaken", ZPOHarvest_OnFuseItemTaken, true);
}

void ZPOHarvest_OnGeneratorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("fuse");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);

	s_bFuseItemHooked = false;
}

void ZPOHarvest_OnBasementDoorOpen(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "genobj_spot");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find genobj_spot!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOHarvest_OnGeneratorButtonPressed, true);
}

void ZPOHarvest_Think()
{
	ZPOHarvest_PollFuseItem();
	ZPOHarvest_PollKeysItem();
}

void ZPOHarvest_Init()
{
	g_ThinkFunc = ZPOHarvest_Think;
	s_bFuseItemHooked = false;
	s_bKeysItemHooked = false;

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_door_rotating", "bsmnt_door");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find bsmnt_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOHarvest_OnBasementDoorOpen, true);
}
