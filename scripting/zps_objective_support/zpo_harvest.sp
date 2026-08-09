/**
 * zpo_harvest.sp
 *
 * NavBot ZPS objective support module for the zpo_harvest map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.13.6
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
 * Summary: Bots can't reliably USE_ITEM the fuse (confirmed in testing: they
 *   walk right up to blastobj_setfuse and just stand there). Until that's
 *   fixed upstream, bots just roam/defend here -- a human has to find the
 *   fuse and plant it. blastobj_setfuse's OnUsed is hooked in
 *   ZPOHarvest_OnBasementLightsPressed (bots press that button
 *   unconditionally, so it's a reliable early gate), so the chain still
 *   advances once a human plants it, and bots move clear of the blast.
 * Entity: blastobj_setfuse (trigger_useable, 415635) / C4Relay (logic_relay,
 *   2371283)
 * Bot action: none (passive) until planted, then MOVETO clear of the blast
 * Confirmation: blastobj_setfuse's OnUsed output, then C4Relay's OnTrigger
 *   output
 *
 * Phase: 3 - Barn Key / Padlock
 * Summary: Bots never get far enough to test USE_ITEM on trig_keys (see
 *   Phase 2 -- they never get past planting the fuse). Disabled as a
 *   precaution rather than confirmed broken; bots just roam/defend until a
 *   human finds the Barn Key and uses it on trig_keys. trig_keys is only
 *   reachable after the blast opens the tunnel, so it's hooked progressively
 *   in ZPOHarvest_OnBombDetonated rather than early in Init() (unlike
 *   blastobj_setfuse, which a human can reach directly).
 * Entity: genobj_powerout (trigger_once, 433008) / trig_keys (trigger_
 *   useable, 1247884)
 * Bot action: MOVETO tunnel end (unconditional positioning), then none
 *   (passive) until the padlock is used
 * Confirmation: trig_keys' OnUsed output
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

void ZPOHarvest_OnGeneratorAreaReached(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// Disabled as a precaution rather than confirmed broken;
	// bots just roam/defend here until that's revisited. A human has to find
	// the Barn Key and use it on trig_keys themselves in the meantime.
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

	int keysSocket = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "trig_keys");

	if (keysSocket == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find trig_keys!");
		return;
	}

	HookSingleEntityOutput(keysSocket, "OnUsed", ZPOHarvest_OnKeysUsed, true);
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

void ZPOHarvest_OnBasementLightsPressed(const char[] output, int caller, int activator, float delay)
{

	// Bots can't reliably USE_ITEM the fuse on blastobj_setfuse (confirmed in
	// testing: they walk right up to it and just stand there). Until that's fixed bots just roam/defend here.
	NavBotZPSModInterface.ResetObjective();

	int socket = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "blastobj_setfuse");

	if (socket == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find blastobj_setfuse!");
		return;
	}

	HookSingleEntityOutput(socket, "OnUsed", ZPOHarvest_OnFusePlanted, true);
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

}

void ZPOHarvest_Init()
{
	g_ThinkFunc = ZPOHarvest_Think;
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
