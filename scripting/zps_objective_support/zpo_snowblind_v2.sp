/**
 * zpo_snowblind_v2.sp
 *
 * NavBot ZPS objective support module for the zpo_snowblind_v2 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.1.18
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: 
 *
 * Issues: 
 */

// s_CurrentPhase values
#define PHASE_LOBBY 0
#define PHASE_BASEMENT 1

static int s_CurrentPhase;
static bool s_LobbyDone;
static bool s_BasementDone;

void ZPOSnowblindV2_Init()
{
	g_ThinkFunc = ZPOSnowblindV2_Think;

	ZPOSnowblindV2_StartTentPhase();
}

void ZPOSnowblindV2_Think()
{
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

static void ZPOSnowblindV2_AdvanceParallelPhase()
{
	if (!s_LobbyDone)
	{
		ZPOSnowblindV2_StartLobbyPhase();
	}
	else if (!s_BasementDone)
	{
		ZPOSnowblindV2_StartBasementPhase();
	}
	else
	{
		NavBotZPSModInterface.ResetObjective();
		ZPOSnowblindV2_HookRadioPhase();
	}
}

/**
 * Phase: 0 - Tent
 * Summary: Hold the Supply Tent capture zone.
 * Entity: trigger_capturepoint_zp
 * Bot action: MOVETO
 * Confirmation: capture point's completion output
 */
static void ZPOSnowblindV2_StartTentPhase()
{
	int tentCapture = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "area_r01");

	if (tentCapture == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowblind_v2: Failed to find area_r01 trigger_capturepoint_zp!");
		return;
	}

	HookSingleEntityOutput(tentCapture, "OnHumanCaptureCompleted", ZPOSnowblindV2_OnTentCaptured, true);

	CreateTimer(3.0, ZPOSnowblindV2_Timer_AnnounceTent, .flags = TIMER_FLAG_NO_MAPCHANGE);

	float goal[3] = { -180.2, 469.5, -208.0 };
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOSnowblindV2_Timer_AnnounceTent(Handle timer)
{
	ZPOSnowblindV2_ChatMsgSurvivors("Secure the Supply Tent!");
}

static void ZPOSnowblindV2_OnTentCaptured(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowblindV2_StartLobbyBasementPhase();
}

static void ZPOSnowblindV2_StartLobbyBasementPhase()
{
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

	s_LobbyDone = false;
	s_BasementDone = false;

	if (GetRandomInt(0, 1) == 0)
	{
		ZPOSnowblindV2_StartLobbyPhase();
	}
	else
	{
		ZPOSnowblindV2_StartBasementPhase();
	}
}

/**
 * Phase: 1 - Lobby
 * Summary: Hold the Lobby capture zone.
 * Entity: trigger_capturepoint_zp
 * Bot action: MOVETO
 * Confirmation: capture point's completion output
 */
static void ZPOSnowblindV2_StartLobbyPhase()
{
	s_CurrentPhase = PHASE_LOBBY;
	ZPOSnowblindV2_ChatMsgSurvivors("Secure the Lobby!");

	float goal[3] = { -138.2, -150.5, -208.0 };
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 2 - Basement
 * Summary: Hold the Basement capture zone.
 * Entity: trigger_capturepoint_zp
 * Bot action: MOVETO
 * Confirmation: capture point's completion output
 */
static void ZPOSnowblindV2_StartBasementPhase()
{
	s_CurrentPhase = PHASE_BASEMENT;
	ZPOSnowblindV2_ChatMsgSurvivors("Secure the Basement!");

	float goal[3] = { 255.8, -250.5, -368.0 };
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOSnowblindV2_OnLobbyCaptured(const char[] output, int caller, int activator, float delay)
{
	s_LobbyDone = true;

	if (s_CurrentPhase != PHASE_LOBBY)
	{
		return;
	}

	ZPOSnowblindV2_AdvanceParallelPhase();
}

static void ZPOSnowblindV2_OnBasementCaptured(const char[] output, int caller, int activator, float delay)
{
	s_BasementDone = true;

	if (s_CurrentPhase != PHASE_BASEMENT)
	{
		return;
	}

	ZPOSnowblindV2_AdvanceParallelPhase();
}

static void ZPOSnowblindV2_HookRadioPhase()
{
	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "objcunt");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_snowblind_v2: Failed to find objcunt math_counter!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOSnowblindV2_OnRadioPhaseUnlocked, true);
}

/**
 * Phase: 3 - Radio Room
 * Summary: Hold the Radio Room capture zone.
 * Entity: math_counter / trigger_capturepoint_zp
 * Bot action: MOVETO
 * Confirmation: none, the round ends via the map's own win entity
 */
static void ZPOSnowblindV2_OnRadioPhaseUnlocked(const char[] output, int caller, int activator, float delay)
{
	ZPOSnowblindV2_ChatMsgSurvivors("The Radio Room is open, move in!");

	float goal[3] = { -100.2, -250.5, 64.0 };
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}
