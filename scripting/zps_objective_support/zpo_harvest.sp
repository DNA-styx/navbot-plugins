/**
 * zpo_harvest.sp
 *
 * NavBot ZPS objective support module for the zpo_harvest map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.11.2
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase: 0 - DefendHouse
 * Summary: Bots defend normally while the round script plays its TV
 *   announcement, then opens the basement door.
 * Entity: bsmnt_door (prop_door_rotating, 1412328)
 * Bot action: none (passive)
 * Confirmation: bsmnt_door's OnFullyOpen output
 *
 * Phase: 1 - Basement Lights
 * Summary: Survivors press a button that turns on basement lighting.
 * Entity: basementgen_lights (func_button, 382140)
 * Bot action: USE_BUTTON
 * Confirmation: basementgen_lights' OnPressed output
 *
 * Phase: 2 - FindFuse
 * Summary: If a human survivor is present, bots guard (ResetObjective) and
 *   let the human find/plant the fuse; otherwise bots search a basement-wide
 *   spawn and plant it themselves. Re-checked every tick until planted. All
 *   bots move clear of the blast once planted, regardless of mode.
 * Entity: Blast_Objective_Fuse (item_deliver, dynamically spawned, no static
 *   hammer ID) / blastobj_setfuse (trigger_useable, 415635) / C4Relay
 *   (logic_relay, 2371283)
 * Bot action: guard or FIND_ITEM "fuse" (radius 800.0) depending on human
 *   presence, then USE_ITEM on blastobj_setfuse, then MOVETO clear of blast
 * Confirmation: the item's OnItemTaken output (polled for by name each tick;
 *   see inline comments for the persistent-hook and guard-mode reasoning),
 *   then blastobj_setfuse's OnUsed output, then C4Relay's OnTrigger output
 *
 * Phase: 3 - Barn Key / Padlock
 * Summary: Same human-guard behavior as Phase 2, re-checked every tick until
 *   the padlock is used. Bots without a human to defer to move through the
 *   tunnel, find the Barn Key, and use it to unlock the generator room door.
 * Entity: genobj_powerout (trigger_once, 433008) / genobj_lockkeys
 *   (item_deliver, dynamically spawned, no static hammer ID) / trig_keys
 *   (trigger_useable, 1247884)
 * Bot action: MOVETO tunnel end, then guard or FIND_ITEM "keys" depending on
 *   human presence, then USE_ITEM on trig_keys
 * Confirmation: genobj_powerout's OnTrigger output, then the item's
 *   OnItemTaken output (polled for by name each tick), then trig_keys'
 *   OnUsed output
 *
 * Phase: 4 - FireUpGenerator
 * Summary: With the generator room door unlocked, bots press the generator
 *   button.
 * Entity: genobj_spot (func_button, 524864)
 * Bot action: USE_BUTTON
 * Confirmation: genobj_spot's OnPressed output
 *
 * Phase: 5 - RadioMilitary
 * Summary: Once the generator starts, bots press the radio button to call
 *   in the military. The button stays locked for 8.6s after the generator
 *   starts; no special handling needed since its own lock state gates it.
 * Entity: radioobj_radiobutton (func_button, 1660077)
 * Bot action: USE_BUTTON
 * Confirmation: radioobj_radiobutton's OnPressed output
 *
 * Phase: 6 - Bridge
 * Summary: Bots destroy a breakable bridge section, cutting off a zombie
 *   route into the barn. Also hooked early in Init(), independent of bot
 *   assignment, to catch a human player breaking it first.
 * Entity: BreakBrushT1 (func_breakable, 149735)
 * Bot action: DESTROY_ENTITY
 * Confirmation: BreakBrushT1's OnBreak output
 *
 * Phase: 7 - DefendBarn / HitTheLights Searchlight
 * Summary: Bots defend passively while a rescue truck drives toward the
 *   barn on the round script's own schedule. A timer started the moment the
 *   radio is pressed sends bots to the searchlight button ~12s before it
 *   unlocks, timed from that schedule rather than any hookable trigger.
 * Entity: searchlight_activbutton (func_button, 425132)
 * Bot action: USE_BUTTON, set immediately at timer fire (before the button
 *   actually unlocks)
 * Confirmation: 179s timer (TIMER_FLAG_NO_MAPCHANGE) started on radio press,
 *   then searchlight_activbutton's OnPressed output
 *
 * Further phases (Escape onward) not yet implemented.
 *
 */

static bool s_bFuseItemHooked;
static bool s_bKeysItemHooked;
static bool s_bBridgeDestroyed;
static bool s_bFuseSocketHooked;
static bool s_bKeysSocketHooked;
static bool s_bFusePhaseActive;
static bool s_bFuseHumanGuard;
static bool s_bKeysPhaseActive;
static bool s_bKeysHumanGuard;

void ZPOHarvest_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

int ZPOHarvest_CountHumanSurvivors()
{
	int count = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2)
		{
			count++;
		}
	}

	return count;
}

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
	s_bKeysPhaseActive = false;

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
	if (s_bKeysHumanGuard)
	{
		// A human is expected to be carrying it -- bots stay on guard duty,
		// don't reassign them to USE_ITEM.
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("keys");

	int socket = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "trig_keys");

	if (socket == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find trig_keys!");
		return;
	}

	NavBotZPSModInterface.SetObjectiveItemUseTarget(socket);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);

	if (!s_bKeysSocketHooked)
	{
		s_bKeysSocketHooked = true;
		HookSingleEntityOutput(socket, "OnUsed", ZPOHarvest_OnKeysUsed, true);
	}
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
	// Same reasoning as the fuse: persistent hook so a re-pickup after the
	// carrying bot dies still gets a USE_ITEM objective assigned.
	HookSingleEntityOutput(item, "OnItemTaken", ZPOHarvest_OnKeysItemTaken, false);
}

void ZPOHarvest_ApplyKeysAssignment(bool guard)
{
	NavBotZPSModInterface.ResetObjective();

	if (guard)
	{
		ZPOHarvest_ChatMsgSurvivors("We'll guard here - go find the keys!");
		return;
	}

	NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

void ZPOHarvest_UpdateKeysGuardStatus()
{
	if (!s_bKeysPhaseActive)
	{
		return;
	}

	bool humansPresent = (ZPOHarvest_CountHumanSurvivors() > 0);

	if (humansPresent != s_bKeysHumanGuard)
	{
		s_bKeysHumanGuard = humansPresent;
		ZPOHarvest_ApplyKeysAssignment(s_bKeysHumanGuard);
	}
}

void ZPOHarvest_OnGeneratorAreaReached(const char[] output, int caller, int activator, float delay)
{
	s_bKeysItemHooked = false;
	s_bKeysPhaseActive = true;
	s_bKeysHumanGuard = (ZPOHarvest_CountHumanSurvivors() > 0);
	ZPOHarvest_ApplyKeysAssignment(s_bKeysHumanGuard);
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
	s_bFusePhaseActive = false;

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
	if (s_bFuseHumanGuard)
	{
		// A human is expected to be carrying it -- bots stay on guard duty,
		// don't reassign them to USE_ITEM.
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("fuse");

	int socket = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "blastobj_setfuse");

	if (socket == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find blastobj_setfuse!");
		return;
	}

	NavBotZPSModInterface.SetObjectiveItemUseTarget(socket);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);

	if (!s_bFuseSocketHooked)
	{
		s_bFuseSocketHooked = true;
		HookSingleEntityOutput(socket, "OnUsed", ZPOHarvest_OnFusePlanted, true);
	}
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
	// Persistent hook (not once-only): if the carrying bot dies before
	// reaching blastobj_setfuse, ZPS drops the fuse for another bot to pick
	// up -- a once-only hook would miss that re-pickup and leave the new
	// carrier without a USE_ITEM objective.
	HookSingleEntityOutput(item, "OnItemTaken", ZPOHarvest_OnFuseItemTaken, false);
}

void ZPOHarvest_ApplyFuseAssignment(bool guard)
{
	NavBotZPSModInterface.ResetObjective();

	if (guard)
	{
		ZPOHarvest_ChatMsgSurvivors("We'll guard here - go find the fuse!");
		return;
	}

	NavBotZPSModInterface.SetObjectiveItemSearchID("fuse");
	// g_vecFuseLocations' farthest point is ~689 units from here -- wider than
	// the default g_DetectionRadius (512).
	NavBotZPSModInterface.SetObjectiveDetectionRadius(800.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

void ZPOHarvest_UpdateFuseGuardStatus()
{
	if (!s_bFusePhaseActive)
	{
		return;
	}

	bool humansPresent = (ZPOHarvest_CountHumanSurvivors() > 0);

	if (humansPresent != s_bFuseHumanGuard)
	{
		s_bFuseHumanGuard = humansPresent;
		ZPOHarvest_ApplyFuseAssignment(s_bFuseHumanGuard);
	}
}

void ZPOHarvest_OnBasementLightsPressed(const char[] output, int caller, int activator, float delay)
{
	s_bFuseItemHooked = false;
	s_bFusePhaseActive = true;
	s_bFuseHumanGuard = (ZPOHarvest_CountHumanSurvivors() > 0);
	ZPOHarvest_ApplyFuseAssignment(s_bFuseHumanGuard);
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

	ZPOHarvest_UpdateFuseGuardStatus();
	ZPOHarvest_UpdateKeysGuardStatus();
}

void ZPOHarvest_Init()
{
	g_ThinkFunc = ZPOHarvest_Think;
	s_bFuseItemHooked = false;
	s_bKeysItemHooked = false;
	s_bBridgeDestroyed = false;
	s_bFuseSocketHooked = false;
	s_bKeysSocketHooked = false;
	s_bFusePhaseActive = false;
	s_bFuseHumanGuard = false;
	s_bKeysPhaseActive = false;
	s_bKeysHumanGuard = false;

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
