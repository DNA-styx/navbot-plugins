/**
 * zpo_snowblind_v2.sp
 *
 * NavBot ZPS objective support module for the zpo_snowblind_v2 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.2.5
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: 
 *
 * Issues: 
 */

// Zone indices for the Tent/Lobby/Basement pool.
#define ZONE_TENT 0
#define ZONE_LOBBY 1
#define ZONE_BASEMENT 2
#define ZONE_COUNT 3

static bool s_ZoneDone[ZONE_COUNT];
static int s_CurrentZone;
static bool s_WaitingForRadioDoor;

void ZPOSnowblindV2_Init()
{
	g_ThinkFunc = ZPOSnowblindV2_Think;
	s_ZoneDone[ZONE_TENT] = false;
	s_ZoneDone[ZONE_LOBBY] = false;
	s_ZoneDone[ZONE_BASEMENT] = false;
	s_WaitingForRadioDoor = false;

	int tentCapture = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "area_r01");

	if (tentCapture == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowblind_v2: Failed to find area_r01 trigger_capturepoint_zp!");
		return;
	}

	HookSingleEntityOutput(tentCapture, "OnHumanCaptureCompleted", ZPOSnowblindV2_OnTentCaptured, true);

	int lobbyCapture = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "area_r02");

	if (lobbyCapture == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowblind_v2: Failed to find area_r02 trigger_capturepoint_zp!");
		return;
	}

	HookSingleEntityOutput(lobbyCapture, "OnHumanCaptureCompleted", ZPOSnowblindV2_OnLobbyCaptured, true);

	int basementCapture = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "area_r03");

	if (basementCapture == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowblind_v2: Failed to find area_r03 trigger_capturepoint_zp!");
		return;
	}

	HookSingleEntityOutput(basementCapture, "OnHumanCaptureCompleted", ZPOSnowblindV2_OnBasementCaptured, true);

	CreateTimer(3.0, ZPOSnowblindV2_Timer_StartPool, .flags = TIMER_FLAG_NO_MAPCHANGE);

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "objcunt");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowblind_v2: Failed to find objcunt math_counter!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOSnowblindV2_OnRadioUnlocked, true);
}

void ZPOSnowblindV2_Think()
{
	if (!s_WaitingForRadioDoor)
	{
		return;
	}

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_door_rotating", "r_3rd_flr_door_new");

	if (door == INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_WaitingForRadioDoor = false;
	HookSingleEntityOutput(door, "OnFullyOpen", ZPOSnowblindV2_StartRadioPhase, true);
}

// Helpers used by more than one phase.

static void ZPOSnowblindV2_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

static void ZPOSnowblindV2_Timer_StartPool(Handle timer)
{
	ZPOSnowblindV2_AdvancePool();
}

static void ZPOSnowblindV2_OnZoneCaptured(int zone)
{
	s_ZoneDone[zone] = true;

	if (zone != s_CurrentZone)
	{
		return;
	}

	ZPOSnowblindV2_AdvancePool();
}

static void ZPOSnowblindV2_AdvancePool()
{
	int remaining[ZONE_COUNT];
	int remainingCount = 0;

	for (int i = 0; i < ZONE_COUNT; i++)
	{
		if (!s_ZoneDone[i])
		{
			remaining[remainingCount++] = i;
		}
	}

	if (remainingCount == 0)
	{
		NavBotZPSModInterface.ResetObjective();
		return;
	}

	s_CurrentZone = remaining[GetRandomInt(0, remainingCount - 1)];

	if (s_CurrentZone == ZONE_TENT)
	{
		ZPOSnowblindV2_StartTentPhase();
	}
	else if (s_CurrentZone == ZONE_LOBBY)
	{
		ZPOSnowblindV2_StartLobbyPhase();
	}
	else
	{
		ZPOSnowblindV2_StartBasementPhase();
	}
}

/**
 * Phase: 0 - Tent (Pool)
 * Summary: Hold the Supply Tent zone, one of a 3-way random pool with
 *   Lobby and Basement.
 * Entity: trigger_capturepoint_zp
 * Bot action: MOVETO
 * Confirmation: capture point's completion output
 */
static void ZPOSnowblindV2_StartTentPhase()
{
	ZPOSnowblindV2_ChatMsgSurvivors("We are securing the Supply Tent!");

	float goal[3] = { -183.0, 465.0, -192.0 };
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOSnowblindV2_OnTentCaptured(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowblindV2_OnZoneCaptured(ZONE_TENT);
}

/**
 * Phase: 1 - Lobby (Pool)
 * Summary: Hold the Lobby zone, one of a 3-way random pool with Tent
 *   and Basement.
 * Entity: trigger_capturepoint_zp
 * Bot action: MOVETO
 * Confirmation: capture point's completion output
 */
static void ZPOSnowblindV2_StartLobbyPhase()
{
	ZPOSnowblindV2_ChatMsgSurvivors("We are securing the Lobby!");

	float goal[3] = { -121.0, -150.0, -190.0 };
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOSnowblindV2_OnLobbyCaptured(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowblindV2_OnZoneCaptured(ZONE_LOBBY);
}

/**
 * Phase: 2 - Basement (Pool)
 * Summary: Hold the Basement zone, one of a 3-way random pool with
 *   Tent and Lobby.
 * Entity: trigger_capturepoint_zp
 * Bot action: MOVETO
 * Confirmation: capture point's completion output
 */
static void ZPOSnowblindV2_StartBasementPhase()
{
	ZPOSnowblindV2_ChatMsgSurvivors("We are securing the Basement!");

	float goal[3] = { 250.0, -251.0, -352.0 };
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOSnowblindV2_OnBasementCaptured(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowblindV2_OnZoneCaptured(ZONE_BASEMENT);
}

static void ZPOSnowblindV2_OnRadioUnlocked(const char[] output, int caller, int activator, float delay)
{
	s_WaitingForRadioDoor = true;
}

/**
 * Phase: 3 - Radio Room
 * Summary: Hold the Radio Room capture zone.
 * Entity: math_counter / prop_door_rotating / trigger_capturepoint_zp
 * Bot action: MOVETO
 * Confirmation: none, the round ends via the map's own win entity
 */
static void ZPOSnowblindV2_StartRadioPhase(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowblindV2_ChatMsgSurvivors("We are moving into the Radio Room!");

	float goal[3] = { -75.5, -220.8, 80.0 };
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}
