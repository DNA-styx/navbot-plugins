/**
 * zpo_harvest.sp
 *
 * NavBot ZPS objective support module for the zpo_harvest map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.32.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: Usable
 *
 * Issues: None
 */

static bool s_bFuseItemHooked;
static bool s_bKeysItemHooked;

void ZPOHarvest_Init()
{
	g_ThinkFunc = ZPOHarvest_Think;
	s_bFuseItemHooked = false;
	s_bKeysItemHooked = false;

	ZPOHarvest_DefendTheHouse();
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

static void ZPOHarvest_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - DefendHouse
 * Summary: Move to a defense position until the basement door opens.
 * Entity: prop_door_rotating
 * Bot action: MOVETO
 * Confirmation: the door's OnOpen output
 */
static void ZPOHarvest_DefendTheHouse()
{
	ZPOHarvest_ChatMsgSurvivors("Defend the house!");

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_door_rotating", "bsmnt_door");

	if (door != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();

		float goal[3] = { 20.5, -88.2, 0.0 };

		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

		HookSingleEntityOutput(door, "OnOpen", ZPOHarvest_OnBasementDoorOpen, true);
	}
	else
	{
		LogError("zpo_harvest: Failed to find bsmnt_door!");
	}
}

/**
 * Phase: 1 - Basement Lights
 * Summary: Press the basement lighting button once the door opens.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
static void ZPOHarvest_OnBasementDoorOpen(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("Basement door is open!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "basementgen_lights");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

		HookSingleEntityOutput(button, "OnPressed", ZPOHarvest_OnBasementLightsPressed, true);
	}
	else
	{
		LogError("zpo_harvest: Failed to find basementgen_lights!");
	}
}

/**
 * Phase: 2 - Find Fuse
 * Summary: Find the fuse.
 * Entity: item_deliver
 * Bot action: FIND_ITEM
 * Confirmation: the item's OnItemTaken output
 */
static void ZPOHarvest_OnBasementLightsPressed(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("Find the fuse!");

	int socket = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "blastobj_setfuse");

	if (socket != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(socket, "OnUsed", ZPOHarvest_OnFusePlanted, true);

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemSearchID("fuse");
		NavBotZPSModInterface.SetObjectiveDetectionRadius(800.0);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
	}
	else
	{
		LogError("zpo_harvest: Failed to find blastobj_setfuse!");
	}
}

// Blast_Objective_Fuse doesn't exist until spawned at runtime, so poll for it.
static void ZPOHarvest_PollFuseItem()
{
	int item = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "Blast_Objective_Fuse");

	if (item != INVALID_ENT_REFERENCE)
	{
		s_bFuseItemHooked = true;
		HookSingleEntityOutput(item, "OnItemTaken", ZPOHarvest_OnFuseTaken, false);
	}
}

/**
 * Phase: 3 - Use Fuse
 * Summary: Plant the fuse.
 * Entity: trigger_useable
 * Bot action: USE_ITEM
 * Confirmation: the socket's OnUsed output
 */
static void ZPOHarvest_OnFuseTaken(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("The fuse has been found.");

	int c4 = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "blastobj_setfuse");

	if (c4 != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemSearchID("fuse");
		NavBotZPSModInterface.SetObjectiveItemUseTarget(c4);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
	}
	else
	{
		LogError("zpo_harvest: Failed to find blastobj_setfuse!");
	}
}

/**
 * Phase: 4 - Take Cover From The Blast
 * Summary: Move clear of the blast once the fuse is planted.
 * Entity: logic_relay
 * Bot action: MOVETO clear of the blast
 * Confirmation: the relay's OnTrigger output
 */
static void ZPOHarvest_OnFusePlanted(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("Fuse is set, take cover!");

	int relay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "C4Relay");

	if (relay != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();

		float goal[3] = { 452.3, 551.8, -552.0 };

		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

		HookSingleEntityOutput(relay, "OnTrigger", ZPOHarvest_OnBombDetonated, true);
	}
	else
	{
		LogError("zpo_harvest: Failed to find C4Relay!");
	}
}

/**
 * Phase: 5 - Move Down The Tunnel
 * Summary: Move through the tunnel opened by the blast.
 * Entity: trigger_once
 * Bot action: MOVETO tunnel end
 * Confirmation: the tunnel trigger's OnTrigger output
 */
static void ZPOHarvest_OnBombDetonated(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("Blast went off, let's move through the tunnel!");

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "genobj_powerout");

	if (trigger != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();

		float goal[3] = { 2395.9, 395.7, -597.0 };

		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

		HookSingleEntityOutput(trigger, "OnTrigger", ZPOHarvest_OnBarnReached, true);
	}
	else
	{
		LogError("zpo_harvest: Failed to find genobj_powerout!");
	}
}

/**
 * Phase: 6 - Find Key
 * Summary: Find the keys.
 * Entity: item_deliver / trigger_useable
 * Bot action: FIND_ITEM
 * Confirmation: the item's OnItemTaken output
 */
static void ZPOHarvest_OnBarnReached(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("Find the keys!");

	int keysSocket = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "trig_keys");

	if (keysSocket != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(keysSocket, "OnUsed", ZPOHarvest_OnKeysUsed, true);

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
		NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
	}
	else
	{
		LogError("zpo_harvest: Failed to find trig_keys!");
	}
}

// genobj_lockkeys doesn't exist until spawned at runtime, so poll for it.
static void ZPOHarvest_PollKeysItem()
{
	int item = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "genobj_lockkeys");

	if (item != INVALID_ENT_REFERENCE)
	{
		s_bKeysItemHooked = true;
		HookSingleEntityOutput(item, "OnItemTaken", ZPOHarvest_OnKeysTaken, false);
	}
}

/**
 * Phase: 7 - Use Key
 * Summary: Use the keys on the padlock.
 * Entity: trigger_useable
 * Bot action: USE_ITEM
 * Confirmation: the socket's OnUsed output
 */
static void ZPOHarvest_OnKeysTaken(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("Keys found, let's unlock the door!");

	int padlock = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "trig_keys");

	if (padlock != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
		NavBotZPSModInterface.SetObjectiveItemUseTarget(padlock);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
	}
	else
	{
		LogError("zpo_harvest: Failed to find trig_keys!");
	}
}

/**
 * Phase: 8 - Start Generator
 * Summary: Press the generator button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
static void ZPOHarvest_OnKeysUsed(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("Door's unlocked, start the generator!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "genobj_spot");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

		HookSingleEntityOutput(button, "OnPressed", ZPOHarvest_OnGeneratorButtonPressed, true);
	}
	else
	{
		LogError("zpo_harvest: Failed to find genobj_spot!");
	}
}

/**
 * Phase: 9 - RadioMilitary
 * Summary: Press the radio button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
static void ZPOHarvest_OnGeneratorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("Generator's running, call it in on the radio!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "radioobj_radiobutton");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

		HookSingleEntityOutput(button, "OnPressed", ZPOHarvest_OnRadioButtonPressed, true);
	}
	else
	{
		LogError("zpo_harvest: Failed to find radioobj_radiobutton!");
	}
}

/**
 * Phase: 10 - DefendBarn
 * Summary: Move to the barn defense position and wait for the rescue truck.
 * Entity: path_track
 * Bot action: MOVETO barn defense position
 * Confirmation: the path_track's OnPass output
 */
static void ZPOHarvest_OnRadioButtonPressed(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("Military's on the way, let's defend the barn!");

	int track = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "rescuevehicle_path_2");

	if (track != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();

		float goal[3] = { 2223.7, 353.0, -284.0 };

		CanAllBotsReachGoal(goal);
		NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

		HookSingleEntityOutput(track, "OnPass", ZPOHarvest_OnDefendBarnEnd, true);
	}
	else
	{
		LogError("zpo_harvest: Failed to find rescuevehicle_path_2!");
	}
}

/**
 * Phase: 11 - HitTheLights Searchlight
 * Summary: Press the searchlight button.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button's OnPressed output
 */
static void ZPOHarvest_OnDefendBarnEnd(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("The rescue truck is getting close!");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "searchlight_activbutton");

	if (button != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

		HookSingleEntityOutput(button, "OnPressed", ZPOHarvest_OnSearchlightPressed, true);
	}
	else
	{
		LogError("zpo_harvest: Failed to find searchlight_activbutton!");
	}
}

/**
 * Phase: 12 - Escape
 * Summary: Move to the pickup point for the human-win condition.
 * Entity: game_win_human
 * Bot action: MOVETO the win trigger's position
 * Confirmation: none (round ends once the rescue truck passes with
 *   survivors present)
 */
static void ZPOHarvest_OnSearchlightPressed(const char[] output, int caller, int activator, float delay)
{
	ZPOHarvest_ChatMsgSurvivors("Lights are on, let's move!");

	NavBotZPSModInterface.ResetObjective();

	float goal[3] = { 3432.0, -1027.0, -477.0 };

	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}
