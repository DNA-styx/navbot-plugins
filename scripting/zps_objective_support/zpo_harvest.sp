/**
 * zpo_harvest.sp
 *
 * NavBot ZPS objective support module for the zpo_harvest map.
 * Intended to be #included by zps_objective_support.sp, alongside zpo_biotec.sp.
 *
 * Module version: 0.9.2
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase 0: "DefendHouse" objective.
 *   - Passive. No bot task set; bots defend normally until the round script's
 *     TV announcement finishes and the basement door opens.
 *   - Hooks bsmnt_door's OnFullyOpen (prop_door_rotating) for the Phase 0 ->
 *     Phase 1 transition.
 *
 * Phase 1: basement lights.
 *   - Once bsmnt_door opens, survivors press basementgen_lights (func_button). Confirmed via full OnPressed output list. 
 *
 * Phase 2: "FindFuse" objective.
 *   - basementgen_lights' OnPressed hands off to NAVBOT_ZPS_OBJECTIVE_FIND_ITEM
 *     with item search ID "fuse".
 *   - The fuse item ("Blast_Objective_Fuse") does not exist at map load -- it's
 *     spawned at runtime by the .as script's Obj_FuseTeleport() (called as soon
 *     as the basement door opens). ZPOHarvest_PollFuseItem() polls for it
 *     by name each tick.
 *   - Once picked up (OnItemTaken): NAVBOT_ZPS_OBJECTIVE_USE_ITEM targeting
 *     blastobj_setfuse (trigger_useable).
 *   - Detection radius widened to 800.0 (default g_DetectionRadius is 512) --
 *     the farthest of the 9 possible fuse spawn locations is ~689 units from
 *     basementgen_lights, outside the default radius.
 *   - Once planted (blastobj_setfuse's OnUsed): NAVBOT_ZPS_OBJECTIVE_MOVETO to a
 *     hardcoded position clear of the blast radius.
 *     before the wall actually blows.
 *   - Wall detonation is confirmed via C4Relay (logic_relay), which is what the
 *     .as script's Obj_BombDetonate() is actually bound to
 *     (its OnTrigger output)..
 *
 * Phase 3: Barn Key / padlock.
 *   - C4Relay's OnTrigger also means Obj_BombDetonate() has spawned the Barn Key
 *     (genobj_lockkeys) far across the newly-opened tunnel. NAVBOT_ZPS_OBJECTIVE_MOVETO carries bots to the far end
 *     of the tunnel first (hardcoded position past genobj_powerout).
 *   - genobj_powerout (trigger_once, human-only filter) confirms
 *     arrival; hooking its OnTrigger hands off to NAVBOT_ZPS_OBJECTIVE_FIND_ITEM
 *     with item search ID "keys".
 *   - Same as the fuse: genobj_lockkeys does not exist at map load (spawned by
 *     Util_CreateBarnKey() at detonation time), so ZPOHarvest_PollKeysItem()
 *     polls for it by name each tick.
 *   - Once picked up (OnItemTaken): NAVBOT_ZPS_OBJECTIVE_USE_ITEM targeting
 *     trig_keys (trigger_useable), the padlock's usable socket. Its OnUsed
 *     calls the .as script's GenRoomUnlocked(), which opens genobj_door.
 *
 * Phase 4: "FireUpGenerator".
 *   - genobj_door opening clears the path to genobj_spot (func_button), the
 *     real FireUpGenerator button -- OnPressed on it is what the .as script
 *     binds to Obj_FireUpGeneratorEnd(). NAVBOT_ZPS_OBJECTIVE_USE_BUTTON.
 *
 * Phase 5: "RadioMilitary".
 *   - genobj_spot's OnPressed hands off directly to NAVBOT_ZPS_OBJECTIVE_
 *     USE_BUTTON on radioobj_radiobutton (func_button), whose OnPressed is
 *     bound to Obj_RadioMilitaryEnd(). The .as script only unlocks this button
 *     8.6s after the generator starts (Obj_RadioMilitaryStart()); no special
 *     handling needed on our end, the button's own locked state gates it.
 *
 * Phase 6: bridge (destroying it blocks a zombie route into the barn).
 *   - Placed after RadioMilitary, though source shows the
 *     beacon (beacon_obj3_bridge) actually turns on back at Obj_BombDetonate(),
 *     so it's technically available earlier -- not gating anything else in our
 *     chain either way.
 *   - Destroy target confirmed via BreakBrushT1 (func_breakable)'s own OnBreak
 *     output list.
 *     NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY + SetObjectiveGenericTargetEntity.
 *   - BreakBrushT1 is hooked once early, in Init(), purely to set
 *     s_bBridgeDestroyed if a human player breaks it before bots ever reach
 *     this phase. ZPOHarvest_OnRadioButton-
 *     Pressed() checks that flag (and re-checks by name, belt and braces)
 *     before assigning DESTROY_ENTITY, and skips straight to the next phase
 *     if it's already gone.
 *
 * Phase 7: "DefendBarn" / HitTheLights searchlight.
 *   - DefendBarn itself is passive (bots just defend) --
 *     Obj_DefendBarnEnd() is purely automatic, fired by the rescue truck's
 *     own path_track (rescuevehicle_path_2's OnPass).
 *   - Rather than hooking that path_track, ZPOHarvest_OnRadioButtonPressed()
 *     starts a plain SourcePawn CreateTimer(179.0, ...) the moment the radio
 *     is pressed. That number comes from the .as script's own schedule: 23s
 *     to Obj_DefendBarnStart, +157s (flTA) to the truck moving, +~7s driving
 , +4s to Obj_HitTheLightsStart unlocking the
 *     button = ~191s total. Firing at 179s gives bots a ~12s head start
 *     walking to searchlight_activbutton before it's actually unlockable.
 *   - NAVBOT_ZPS_OBJECTIVE_USE_BUTTON is set immediately at that point even
 *     though the button is still locked.
 *   - Uses TIMER_FLAG_NO_MAPCHANGE only, no stored Handle. An earlier version
 *     also stored the Handle and manually KillTimer()'d it in Init() --
 *     that threw "Invalid timer handle" in testing, since this server's
 *     round restart triggers whatever cleanup TIMER_FLAG_NO_MAPCHANGE reacts
 *     to, auto-killing the timer without clearing our stored reference, so
 *     Init()'s manual KillTimer() then hit an already-freed handle. The flag
 *     alone is sufficient.
 *
 */

static bool s_bFuseItemHooked;
static bool s_bKeysItemHooked;
static bool s_bBridgeDestroyed;

void ZPOHarvest_OnSearchlightPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// TODO: Escape phase.
}

Action ZPOHarvest_OnSearchlightTimer(Handle timer)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "searchlight_activbutton");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find searchlight_activbutton!");
		return Plugin_Stop;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOHarvest_OnSearchlightPressed, true);

	return Plugin_Stop;
}

void ZPOHarvest_OnBridgeDestroyedEarly(const char[] output, int caller, int activator, float delay)
{
	// May fire before bots are ever assigned this phase (e.g. a human player
	// breaks it during an earlier phase). Just record it -- ZPOHarvest_On-
	// RadioButtonPressed checks this flag before assigning DESTROY_ENTITY.
	s_bBridgeDestroyed = true;
}

void ZPOHarvest_OnBridgeDestroyed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// Passive -- bots just defend normally until ZPOHarvest_OnSearchlightTimer
	// (started in ZPOHarvest_OnRadioButtonPressed) sends them to the button.
}

void ZPOHarvest_OnRadioButtonPressed(const char[] output, int caller, int activator, float delay)
{
	// .as timeline from here: 23s -> Obj_DefendBarnStart, +157s (flTA) ->
	// truck starts moving, +~7s drive (250 u/s over ~1756 units of track) ->
	// Obj_DefendBarnEnd, +4s -> Obj_HitTheLightsStart unlocks the button.
	// ~191s total. Firing at 179s gives bots a ~12s head start walking over,
	// approximate per DNA.styx (doesn't need to be exact).
	CreateTimer(179.0, ZPOHarvest_OnSearchlightTimer, .flags = TIMER_FLAG_NO_MAPCHANGE);

	if (s_bBridgeDestroyed)
	{
		ZPOHarvest_OnBridgeDestroyed(output, caller, activator, delay);
		return;
	}

	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "BreakBrushT1");

	if (entity == INVALID_ENT_REFERENCE)
	{
		// Already broken (s_bBridgeDestroyed missed it, e.g. hook order at
		// round start) -- treat the same as the flag check above.
		ZPOHarvest_OnBridgeDestroyed(output, caller, activator, delay);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);

	HookSingleEntityOutput(entity, "OnBreak", ZPOHarvest_OnBridgeDestroyed, true);
}

void ZPOHarvest_OnGeneratorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "radioobj_radiobutton");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find radioobj_radiobutton!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOHarvest_OnRadioButtonPressed, true);
}

void ZPOHarvest_OnKeysUsed(const char[] output, int caller, int activator, float delay)
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

void ZPOHarvest_OnBasementLightsPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("fuse");
	// g_vecFuseLocations' farthest point is ~689 units from here -- wider than
	// the default g_DetectionRadius (512).
	NavBotZPSModInterface.SetObjectiveDetectionRadius(800.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);

	s_bFuseItemHooked = false;
}

void ZPOHarvest_OnBasementDoorOpen(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "basementgen_lights");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find basementgen_lights!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOHarvest_OnBasementLightsPressed, true);
}

void ZPOHarvest_Think()
{
	if (!s_bFuseItemHooked)
	{
		ZPOHarvest_PollFuseItem();
	}

	if (!s_bKeysItemHooked)
	{
		ZPOHarvest_PollKeysItem();
	}
}

void ZPOHarvest_Init()
{
	g_ThinkFunc = ZPOHarvest_Think;
	s_bFuseItemHooked = false;
	s_bKeysItemHooked = false;
	s_bBridgeDestroyed = false;

	int bridge = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "BreakBrushT1");

	if (bridge == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find BreakBrushT1!");
	}
	else
	{
		HookSingleEntityOutput(bridge, "OnBreak", ZPOHarvest_OnBridgeDestroyedEarly, true);
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_door_rotating", "bsmnt_door");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find bsmnt_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOHarvest_OnBasementDoorOpen, true);
}
