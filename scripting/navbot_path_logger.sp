#include <sourcemod>
#include <sdktools>
#include <navbot>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "NavBot Path Logger",
	author = "caxanga334",
	description = "Logs bot pathing events to a log file.",
	version = "1.0.0",
	url = "https://github.com/caxanga334/navbot-plugins"
};

ConVar cvar_file_per_map = null;
char g_logfile[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
	cvar_file_per_map = CreateConVar("sm_navbot_path_logger_per_map", "0", "If enabled, creates one log file for each map.");

	AutoExecConfig();
}

public void OnConfigsExecuted()
{
	BuildLogFilePath();
}

void BuildMapName(char[] buffer, int size)
{
	char tmp[128];
	GetCurrentMap(tmp, sizeof(tmp));
	GetMapDisplayName(tmp, buffer, size);
}

void BuildLogFilePath()
{
	char timestamp[64];
	FormatTime(timestamp, sizeof(timestamp), "%Y%m%d");


	if (cvar_file_per_map.BoolValue)
	{
		char map[128];
		BuildMapName(map, sizeof(map));
		BuildPath(Path_SM, g_logfile, sizeof(g_logfile), "logs/navbot_pathlog_%s_%s.log", map, timestamp);
	}
	else
	{
		BuildPath(Path_SM, g_logfile, sizeof(g_logfile), "logs/navbot_pathlog_%s.log", timestamp);
	}
}

public void OnNavBotComputePathFailed(NavBot bot, const float goal[3], const float adjustedZ, NavBotComputePathFailureReason reason)
{
	float origin[3];
	bot.GetAbsOrigin(origin);
	Address area = bot.GetLastKnownNavArea();
	char szarea[16];

	if (area == Address_Null)
	{
		strcopy(szarea, sizeof(szarea), "NULL");
	}
	else
	{
		int id = NavBotNavArea.GetID(area);
		FormatEx(szarea, sizeof(szarea), "#%i", id);
	}

	char szreason[32];

	switch (reason)
	{
		case NAVBOT_COMPUTEPATH_FAILURE_NULL_START_AREA:
		{
			strcopy(szreason, sizeof(szreason), "NULL start area!");
		}
		case NAVBOT_COMPUTEPATH_FAILURE_INCOMPLETE_PATH:
		{
			strcopy(szreason, sizeof(szreason), "Incomplete path!");
		}
		default:
		{
			strcopy(szreason, sizeof(szreason), "Unknown!");
		}
	}

	LogToFile(g_logfile, "[%3.2f] Compute path failed for NavBot \"%L\" Team %i Origin <%f %f %f>. Goal: <%f %f %f> (%f) Start Nav Area %s Reason: %s", 
		GetGameTime(),
		bot.Index,
		bot.TeamNum,
		origin[0],
		origin[1],
		origin[2],
		goal[0],
		goal[1],
		goal[2],
		adjustedZ,
		szarea,
		szreason
	);
}