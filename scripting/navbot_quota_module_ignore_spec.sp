#include <sourcemod>
#include <sdktools>
#include <navbot>
#include <navbot_bot_quota>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Quota Module: Ignore Spec",
	author = "caxanga334",
	description = "Module for NavBot Bot Quota plugin. Makes spectators be ignored in the player count.",
	version = "1.0.0",
	url = "https://github.com/caxanga334/navbot-plugins"
};

ConVar cv_ignore_unassigned = null;
ConVar cv_ignore_spectator = null;
ConVar cv_unassigned_override = null;
ConVar cv_spectator_override = null;
int g_unassignedTeamIndex;
int g_spectatorTeamIndex;

public void OnPluginStart()
{
	cv_ignore_unassigned = CreateConVar("sm_navbot_quota_ignore_unassigned_team", "1", 
	"If enabled, players in the unassigned team doesn't count towards the number of players in the server.");
	cv_ignore_spectator = CreateConVar("sm_navbot_quota_ignore_spectator_team", "1", 
	"If enabled, players in the spectator team doesn't count towards the number of players in the server.");
	cv_unassigned_override = CreateConVar("sm_navbot_quota_unassigned_team_index_override", "-1", 
	"Overrides the automatic detection of the Unassigned team index to this value.\nSet to -1 to use auto detection", 
	FCVAR_NONE);
	cv_spectator_override = CreateConVar("sm_navbot_quota_spectator_team_index_override", "-1", 
	"Overrides the automatic detection of the Spectator team index to this value.\nSet to -1 to use auto detection", 
	FCVAR_NONE);

	cv_unassigned_override.AddChangeHook(TeamOverrideConVarChanged);
	cv_spectator_override.AddChangeHook(TeamOverrideConVarChanged);

	AutoExecConfig();

	g_unassignedTeamIndex = -1;
	g_spectatorTeamIndex = -1;
}

/* Causes the plugin to log an error on server shutdown.
Plugin is just going to sit doing nothing since the forward won't be invoked.
public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "navbot_bot_quota") == 0)
	{
		SetFailState("NavBot bot quota plugin unloaded.");
	}
}
*/

void TeamOverrideConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int unassigned = cv_unassigned_override.IntValue;
	int spec = cv_spectator_override.IntValue;

	if (unassigned < -1)
	{
		unassigned = -1;
	}

	if (spec < -1)
	{
		spec = -1;
	}

	g_unassignedTeamIndex = unassigned;
	g_spectatorTeamIndex = spec;
}

public void OnConfigsExecuted()
{
	CreateTimer(1.0, Timer_FindTeams, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

void Timer_FindTeams(Handle timer)
{
	if (g_unassignedTeamIndex < 0)
	{
		FindTeam("unassigned", g_unassignedTeamIndex);

		if (g_unassignedTeamIndex >= 0)
		{
			LogMessage("Found unassigned team index: %i", g_unassignedTeamIndex);
		}
	}

	if (g_spectatorTeamIndex < 0)
	{
		FindTeam("spectator", g_spectatorTeamIndex);

		if (g_spectatorTeamIndex >= 0)
		{
			LogMessage("Found spectator team index: %i", g_spectatorTeamIndex);
		}
	}
}

void FindTeam(const char[] pattern, int& out)
{
	int maxteams = GetTeamCount();

	for (int i = 0; i < maxteams; i++)
	{
		char name[256];
		GetTeamName(i, name, sizeof(name));
		// PrintToServer("[FIND TEAM DEBUG]: Team %i \"%s\"", i, name);

		if (StrContains(pattern, name, false) != -1)
		{
			out = i;
			return;
		}
	}

	out = -1;
}

public Action NavBotQuota_IsPlayerIgnored(int client)
{
	int team = GetClientTeam(client);

	if (cv_ignore_unassigned.BoolValue && g_unassignedTeamIndex >= 0 && team == g_unassignedTeamIndex)
	{
		return Plugin_Stop;
	}

	if (cv_ignore_spectator.BoolValue && g_spectatorTeamIndex >= 0 && team == g_spectatorTeamIndex)
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}