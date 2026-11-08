#include <sourcemod>
#include <navbot>
#include <navbot_stocks>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "NavBot Quota System",
	author = "caxanga334",
	description = "Bot quota system for the NavBot extension.",
	version = "1.1.2",
	url = "https://github.com/caxanga334/navbot-plugins"
};

ConVar cv_quota_mode = null;
ConVar cv_quota_enabled = null;
ConVar cv_quota_ignore_others = null;
ConVar cv_quota_think_rate = null;
ConVar cv_quota_target = null;
ConVar cv_quota_dead_only = null;

enum QuotaMode
{
	QUOTA_MODE_NORMAL = 0,
	QUOTA_MODE_FILL,
	QUOTA_MODE_MATCH,

	MAX_QUOTA_MODES
}

QuotaMode g_mode;
int g_quotaTarget;
GlobalForward g_selectBotForward;
GlobalForward g_countPlayerForward;

#include "bot_quota/functions.sp"
#include "bot_quota/timer_callback.sp"
#include "bot_quota/commands.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("navbot_bot_quota");

	return APLRes_Success;
}

public void OnPluginStart()
{
	g_selectBotForward = new GlobalForward("NavBotQuota_SelectBotToKick", ET_Hook, Param_CellByRef);
	g_countPlayerForward = new GlobalForward("NavBotQuota_IsPlayerIgnored", ET_Hook, Param_Cell);

	RegAdminCmd("sm_navbot_quota_list_players", CMD_ListPlayers, ADMFLAG_GENERIC, "List players and bots in the server.");

	cv_quota_mode = CreateConVar("sm_navbot_quota_mode", "normal", "Bot quota mode.\nModes: \"normal\" \"fill\" \"match\" ");
	cv_quota_enabled = CreateConVar("sm_navbot_quota_enabled", "1", "Enable/Disables the bot quota system.");
	cv_quota_target = CreateConVar("sm_navbot_quota", "0", "Bot quota target.");
	cv_quota_ignore_others = CreateConVar("sm_navbot_quota_ignore_others", "0", "Should the bot quota system ignore other bots on the server?");
	cv_quota_think_rate = CreateConVar("sm_navbot_quota_think_rate", "5.0", "How frequently in seconds the bot quota system thinks.\nRequires map change to take effect.");
	cv_quota_dead_only = CreateConVar("sm_navbot_quota_only_kick_dead", "0", "If enabled, only kick dead bots.");
	g_mode = QUOTA_MODE_NORMAL;
	g_quotaTarget = 0;

	cv_quota_mode.AddChangeHook(OnQuotaModeChanged);
	cv_quota_target.AddChangeHook(OnBotQuotaTargetChanged);

	AutoExecConfig();
}

void OnQuotaModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "fill", false) == 0)
	{
		g_mode = QUOTA_MODE_FILL;
	}
	else if (strcmp(newValue, "match", false) == 0)
	{
		g_mode = QUOTA_MODE_MATCH;
	}
	else if (strcmp(newValue, "normal", false) == 0)
	{
		g_mode = QUOTA_MODE_NORMAL;
	}
	else
	{
		LogError("Unknown bot quota mode \"%s\". Using normal mode.", newValue);
		g_mode = QUOTA_MODE_NORMAL;
	}
}

void OnBotQuotaTargetChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_quotaTarget = convar.IntValue;
}

public void OnConfigsExecuted()
{
	CreateTimer(cv_quota_think_rate.FloatValue, Timer_QuotaSystemThink, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}
