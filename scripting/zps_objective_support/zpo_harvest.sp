/**
 * zpo_harvest.sp
 *
 * NavBot ZPS objective support module for the zpo_harvest map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.14.3
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: Under review after file format update
 *
 * Issues: Previously bots sometimes didn't plant fuse. To be reviewed.
 */

static bool s_bBridgeDestroyed;

void ZPOHarvest_Init()
{
	g_ThinkFunc = ZPOHarvest_Think;
	s_bBridgeDestroyed = false;

	// Bridge (Phase 6) - hooked early to catch a human breaking it first.
	int bridge = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "BreakBrushT1");

	if (bridge == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find BreakBrushT1!");
	}
	else
	{
		HookSingleEntityOutput(bridge, "OnBreak", ZPOHarvest_OnBridgeDestroyedEarly, true);
	}

	// Phase 0 - basement door.
	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_door_rotating", "bsmnt_door");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find bsmnt_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOHarvest_OnBasementDoorOpen, true);
}

void ZPOHarvest_Think()
{

}

/**
 * Phase: 0 - DefendHouse
 * Summary: Bots defend passively until the basement door opens.
 * Entity: prop_door_rotating
 * Bot action: none (passive)
 * Confirmation: the door's OnFullyOpen output
 */
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

/**
 * Phase: 1 - Basement Lights
 * Summary: Survivors press a button that turns on basement lighting.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
void ZPOHarvest_OnBasementLightsPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	int socket = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "blastobj_setfuse");

	if (socket == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_harvest: Failed to find blastobj_setfuse!");
		return;
	}

	HookSingleEntityOutput(socket, "OnUsed", ZPOHarvest_OnFusePlanted, true);
}

/**
 * Phase: 2 - FindFuse
 * Summary: Bots roam/defend until a human plants the fuse.
 * Entity: trigger_useable / logic_relay
 * Bot action: none (passive) until planted, then MOVETO clear of the blast
 * Confirmation: the socket's OnUsed output, then the relay's OnTrigger
 */
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

/**
 * Phase: 3 - Barn Key / Padlock
 * Summary: Bots reach the tunnel then roam/defend until a human uses the
 *   padlock.
 * Entity: trigger_once / trigger_useable / func_button
 * Bot action: MOVETO tunnel end, then none (passive) until used, then
 *   USE_BUTTON
 * Confirmation: tunnel trigger's OnTrigger, padlock's OnUsed, button's
 *   OnPressed
 */
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

void ZPOHarvest_OnGeneratorAreaReached(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
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

/**
 * Phase: 4 - FireUpGenerator
 * Summary: With the generator room door unlocked, bots press the generator
 *   button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
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

/**
 * Phase: 5 - RadioMilitary
 * Summary: Once the generator starts, bots press the radio button; this also
 *   kicks off Phase 6 and starts the Phase 7 timer.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
void ZPOHarvest_OnRadioButtonPressed(const char[] output, int caller, int activator, float delay)
{
	// ~179s delay gives bots a head start to the searchlight button.
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

/**
 * Phase: 6 - Bridge
 * Summary: Bots destroy a breakable bridge section, cutting off a zombie
 *   route into the barn.
 * Entity: func_breakable
 * Bot action: DESTROY_ENTITY
 * Confirmation: the breakable's OnBreak output
 */
void ZPOHarvest_OnBridgeDestroyedEarly(const char[] output, int caller, int activator, float delay)
{
	s_bBridgeDestroyed = true;
}

void ZPOHarvest_OnBridgeDestroyed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
}

/**
 * Phase: 7 - DefendBarn / HitTheLights Searchlight
 * Summary: Bots defend passively until a timer sends them to the searchlight
 *   button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the timer, then the button's OnPressed output
 */
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

void ZPOHarvest_OnSearchlightPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// TODO: Escape phase.
}
