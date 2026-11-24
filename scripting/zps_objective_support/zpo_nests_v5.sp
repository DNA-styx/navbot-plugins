/**
 * zpo_nests_v5.sp
 *
 * NavBot ZPS objective support module for the zpo_nests_v5 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.2.1
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

#define ZPONESTSV5_NEST_COUNT 7
#define ZPONESTSV5_UPDATE_INTERVAL 1.0
#define ZPONESTSV5_HOLD_RADIUS 96.0
#define ZPONESTSV5_HOLD_WAIT 5.0
#define ZPONESTSV5_RANDOM_REMOVE_TIME 5.0

// Hold nests 1, 2, 3, 6, 8, 9, 10: work trigger_multiple hammer IDs.
static const int s_NestTriggerIDs[ZPONESTSV5_NEST_COUNT] = { 159682, 54984, 86965, 139942, 154822, 258483, 265221 };

// Hold point per nest (the nest's working info_beacon origin).
static const float s_NestPoints[ZPONESTSV5_NEST_COUNT][3] = {
	{ -606.0, -504.0, 394.0 },
	{ 400.0, -370.0, 251.5 },
	{ -1276.0, -300.0, 366.0 },
	{ -1184.0, 880.0, -24.0 },
	{ -1859.0, 1280.0, 370.8 },
	{ -2991.0, 812.0, 242.0 },
	{ -1232.0, -148.0, 540.0 }
};

static int s_NestTriggerRefs[ZPONESTSV5_NEST_COUNT];
static bool s_bNestOpen[ZPONESTSV5_NEST_COUNT];
static int s_TargetNest;
static bool s_bHolding;
static float s_fNextUpdate;
static float s_fStartTime;

void ZPONestsV5_Init()
{
	g_ThinkFunc = ZPONestsV5_Think;
	s_TargetNest = -1;
	s_bHolding = false;
	s_fNextUpdate = 0.0;

	ZPONestsV5_WaitForStart();
}

void ZPONestsV5_Think()
{
	if (!s_bHolding || GetGameTime() < s_fNextUpdate)
	{
		return;
	}

	s_fNextUpdate = GetGameTime() + ZPONESTSV5_UPDATE_INTERVAL;
	ZPONestsV5_UpdateNests();
}

static void ZPONestsV5_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

static NavBot ZPONestsV5_GetSurvivorBot(int client)
{
	if (!IsClientInGame(client) || !NavBotManager.IsNavBot(client))
	{
		return NULL_NAVBOT;
	}

	if (GetClientTeam(client) != 2 || !IsPlayerAlive(client))
	{
		return NULL_NAVBOT;
	}

	return NavBotManager.GetNavBotByIndex(client);
}

// Returns true if the given survivor bot can build a path to the nest's hold point.
static bool ZPONestsV5_CanReachNest(NavBot bot, int nest)
{
	float goal[3];
	goal = s_NestPoints[nest];

	MeshNavigator nav = new MeshNavigator();
	bool reachable = nav.ComputeToPos(bot, goal, 0.0, false);
	delete nav;

	return reachable;
}

// Picks the open nest nearest to the average position of the survivor bots,
// skipping nests the first survivor bot cannot path to.
static int ZPONestsV5_PickNest()
{
	float centre[3];
	int bots = 0;
	NavBot pathBot = NULL_NAVBOT;

	for (int client = 1; client <= MaxClients; client++)
	{
		NavBot bot = ZPONestsV5_GetSurvivorBot(client);

		if (bot == NULL_NAVBOT)
		{
			continue;
		}

		if (pathBot == NULL_NAVBOT)
		{
			pathBot = bot;
		}

		float pos[3];
		GetClientAbsOrigin(client, pos);
		AddVectors(centre, pos, centre);
		bots++;
	}

	if (bots == 0)
	{
		return -1;
	}

	ScaleVector(centre, 1.0 / float(bots));

	int best = -1;
	float bestDist = 0.0;

	for (int i = 0; i < ZPONESTSV5_NEST_COUNT; i++)
	{
		if (!s_bNestOpen[i] || !ZPONestsV5_CanReachNest(pathBot, i))
		{
			continue;
		}

		float dist = GetVectorDistance(centre, s_NestPoints[i]);

		if (best == -1 || dist < bestDist)
		{
			best = i;
			bestDist = dist;
		}
	}

	return best;
}

static void ZPONestsV5_UpdateNests()
{
	bool anyOpen = false;

	for (int i = 0; i < ZPONESTSV5_NEST_COUNT; i++)
	{
		bool open = EntRefToEntIndex(s_NestTriggerRefs[i]) != INVALID_ENT_REFERENCE;

		// The map removes some nests at random just after the round starts.
		if (s_bNestOpen[i] && !open && GetGameTime() >= s_fStartTime + ZPONESTSV5_RANDOM_REMOVE_TIME)
		{
			ZPONestsV5_ChatMsgSurvivors("Nest closed, move to the next one!");
		}

		s_bNestOpen[i] = open;
		anyOpen = anyOpen || open;
	}

	bool retarget = s_TargetNest != -1 && !s_bNestOpen[s_TargetNest];

	if (!anyOpen)
	{
		s_bHolding = false;
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		NavBot bot = ZPONestsV5_GetSurvivorBot(client);

		if (bot == NULL_NAVBOT)
		{
			continue;
		}

		if (retarget || !anyOpen)
		{
			bot.SendPluginCommand(NAVBOT_PLUGINCMD_STOPCMD);
		}
	}

	if (!anyOpen)
	{
		return;
	}

	if (s_TargetNest != -1 && !retarget)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			NavBot bot = ZPONestsV5_GetSurvivorBot(client);

			if (bot == NULL_NAVBOT)
			{
				continue;
			}

			if (!ZPONestsV5_CanReachNest(bot, s_TargetNest))
			{
				retarget = true;
			}

			break;
		}
	}

	if (s_TargetNest == -1 || retarget)
	{
		s_TargetNest = ZPONestsV5_PickNest();

		if (s_TargetNest == -1)
		{
			return;
		}
	}

	float goal[3];
	goal = s_NestPoints[s_TargetNest];

	for (int client = 1; client <= MaxClients; client++)
	{
		NavBot bot = ZPONestsV5_GetSurvivorBot(client);

		if (bot == NULL_NAVBOT)
		{
			continue;
		}

		if (NavBotBehaviorInterface.IsRunningPluginCommand(bot.GetBehaviorInterface()))
		{
			continue;
		}

		float pos[3];
		GetClientAbsOrigin(client, pos);

		if (GetVectorDistance(pos, goal) <= ZPONESTSV5_HOLD_RADIUS)
		{
			bot.SendPluginCommand(NAVBOT_PLUGINCMD_WAIT, ZPONESTSV5_HOLD_WAIT);
		}
		else
		{
			bot.SendPluginCommand(NAVBOT_PLUGINCMD_MOVE_TO, goal);
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
static void ZPONestsV5_WaitForStart()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "StTr");

	// The start trigger is removed once it fires, so a missing trigger means the round has started.
	if (trigger == INVALID_ENT_REFERENCE)
	{
		ZPONestsV5_CloseNests("", INVALID_ENT_REFERENCE, INVALID_ENT_REFERENCE, 0.0);
		return;
	}

	HookSingleEntityOutput(trigger, "OnTrigger", ZPONestsV5_CloseNests, true);
}

/**
 * Phase: 1 - Close nests
 * Summary: Hold the nearest nest work zone as a team until every hold nest is closed.
 * Entity: trigger_multiple
 * Bot action: per-bot MOVE_TO and WAIT plugin commands
 * Confirmation: Every hold nest's work trigger is removed.
 */
static void ZPONestsV5_CloseNests(const char[] output, int caller, int activator, float delay)
{
	for (int i = 0; i < ZPONESTSV5_NEST_COUNT; i++)
	{
		s_NestTriggerRefs[i] = INVALID_ENT_REFERENCE;
		s_bNestOpen[i] = false;

		int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_multiple", s_NestTriggerIDs[i]);

		// The map removes some nests at random, so a missing work trigger is skipped.
		if (trigger == INVALID_ENT_REFERENCE)
		{
			continue;
		}

		s_NestTriggerRefs[i] = EntIndexToEntRef(trigger);
		s_bNestOpen[i] = true;
	}

	ZPONestsV5_ChatMsgSurvivors("Close the zombie nests! Stick together and hold each one!");

	NavBotZPSModInterface.ResetObjective();

	s_TargetNest = -1;
	s_bHolding = true;
	s_fNextUpdate = 0.0;
	s_fStartTime = GetGameTime();
}
