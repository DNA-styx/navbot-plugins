/**
 * zpo_redqueen_r106.sp
 *
 * NavBot ZPS objective support module for the zpo_redqueen_r106 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.8.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: WIP - Exit spawn, find keycard and open first door.
 *
 * Issues: Bots not restocking on ammo, not able to find keycard
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

void ZPORedQueenR106_Init()
{
	g_ThinkFunc = ZPORedQueenR106_Think;

	ZPORedQueenR106_WaitForSpawnDoor();
}

void ZPORedQueenR106_Think()
{
	// Left empty until a phase needs per-tick polling.
}

static void ZPORedQueenR106_ChatMsgSurvivors(const char[] msg)
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
 * Phase: 0 - WaitForSpawnDoor
 * Summary: Wait for the spawn door to open.
 * Entity: func_door
 * Bot action: none
 * Confirmation: spawn door fully open
 */
static void ZPORedQueenR106_WaitForSpawnDoor()
{
	ZPORedQueenR106_ChatMsgSurvivors("Wait for the spawn door to open!");

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "door1");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find door1 func_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPORedQueenR106_GetKeycard, true);
}

/**
 * Phase: 1 - GetKeycard
 * Summary: Fetch the keycard.
 * Entity: trigger_once
 * Bot action: MOVETO, plus MOVE_TO plugin command for one bot
 * Confirmation: keycard trigger touched
 */
static void ZPORedQueenR106_GetKeycard(const char[] output, int caller, int activator, float delay)
{
	ZPORedQueenR106_ChatMsgSurvivors("Door is open, one of us will fetch the keycard!");

	const int hammerid = 1326;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", hammerid);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find keycard trigger_once! Hammer ID: %i", hammerid);
		return;
	}

	float goal[3] = { 1364.0, -1613.7, -128.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	CanAllBotsReachGoal(goal);

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPORedQueenR106_UseKeycardOnDoor, true);

	int candidates[MAXPLAYERS + 1];
	int count = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 2)
		{
			candidates[count] = client;
			count++;
		}
	}

	if (count == 0)
	{
		return;
	}

	int chosen = candidates[GetRandomInt(0, count - 1)];
	float keycard[3] = { 1621.5, -248.5, -783.5 };

	NavBot bot = view_as<NavBot>(chosen);
	bot.SendPluginCommand(NAVBOT_PLUGINCMD_MOVE_TO, keycard);
}

/**
 * Phase: 2 - UseKeycardOnDoor
 * Summary: Use the keycard on the security door.
 * Entity: trigger_once, func_door
 * Bot action: MOVETO, then none
 * Confirmation: security door fully open
 */
static void ZPORedQueenR106_UseKeycardOnDoor(const char[] output, int caller, int activator, float delay)
{
	ZPORedQueenR106_ChatMsgSurvivors("Got the keycard, use it on the security door!");

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "door3tr");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find door3tr trigger_once!");
		return;
	}

	float goal[3] = { 1518.9, -1500.0, -127.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	CanAllBotsReachGoal(goal);

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPORedQueenR106_OnKeycardUsed, true);
}

static void ZPORedQueenR106_OnKeycardUsed(const char[] output, int caller, int activator, float delay)
{
	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "door3");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find door3 func_door!");
		return;
	}

	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_NONE);
	NavBotZPSModInterface.ResetObjective();

	HookSingleEntityOutput(door, "OnFullyOpen", ZPORedQueenR106_ActivateHackPanel, true);
}

/**
 * Phase: 3 - HackPanel
 * Summary: Hack the panel by holding the capture zone.
 * Entity: trigger_capturepoint_zp
 * Bot action: MOVETO
 * Confirmation: capture completed
 */
static void ZPORedQueenR106_ActivateHackPanel(const char[] output, int caller, int activator, float delay)
{
	ZPORedQueenR106_ChatMsgSurvivors("Security door is open, hack the panel!");

	const int hammerid = 1565;
	int capturepoint = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", hammerid);

	if (capturepoint == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find hack panel trigger_capturepoint_zp! Hammer ID: %i", hammerid);
		return;
	}

	float goal[3] = { 1813.1, -2807.8, -141.8 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	CanAllBotsReachGoal(goal);

	HookSingleEntityOutput(capturepoint, "OnHumanCaptureCompleted", ZPORedQueenR106_OnHackPanelCaptured, true);
}

static void ZPORedQueenR106_OnHackPanelCaptured(const char[] output, int caller, int activator, float delay)
{
	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "door4");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find door4 func_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPORedQueenR106_ApproachDoor4End, true);
}

/**
 * Phase: 4 - ApproachDoor4End
 * Summary: Wait at door4end until it opens.
 * Entity: func_door
 * Bot action: MOVETO
 * Confirmation: door4end fully open
 */
static void ZPORedQueenR106_ApproachDoor4End(const char[] output, int caller, int activator, float delay)
{
	ZPORedQueenR106_ChatMsgSurvivors("Panel hacked, head for the next door!");

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "door4end");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_redqueen_r106: Failed to find door4end func_door!");
		return;
	}

	float goal[3] = { 3056.1, -2915.5, -192.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	CanAllBotsReachGoal(goal);

	HookSingleEntityOutput(door, "OnFullyOpen", ZPORedQueenR106_MoveThroughDoor4End, true);
}

/**
 * Phase: 5 - MoveThroughDoor4End
 * Summary: Move through door4end.
 * Entity: none
 * Bot action: MOVETO
 * Confirmation: none yet
 */
static void ZPORedQueenR106_MoveThroughDoor4End(const char[] output, int caller, int activator, float delay)
{
	ZPORedQueenR106_ChatMsgSurvivors("The way is open, move through!");

	float goal[3] = { 3931.8, -1725.6, -192.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
	CanAllBotsReachGoal(goal);
}
