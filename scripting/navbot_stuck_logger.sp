#include <sourcemod>
#include <sdktools>
#include <navbot>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "NavBot Stuck Logger",
	author = "caxanga334",
	description = "Logs bot stuck events to a file.",
	version = "1.0.0",
	url = "https://github.com/caxanga334/navbot-plugins"
};

ConVar cvar_file_per_map = null;
ConVar cvar_min_events = null;
char g_logfile[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
	cvar_file_per_map = CreateConVar("sm_navbot_stuck_logger_per_map", "0", "If enabled, creates one log file for each map.");
	cvar_min_events = CreateConVar("sm_navbot_stuck_logger_min_events", "0", "Minimum number of consecutive stuck events to start logging.");

	AutoExecConfig();
}

public void OnMapStart()
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
		BuildPath(Path_SM, g_logfile, sizeof(g_logfile), "logs/stucklog_%s_%s.log", map, timestamp);
	}
	else
	{
		BuildPath(Path_SM, g_logfile, sizeof(g_logfile), "logs/stucklog_%s.log", timestamp);
	}
}

public void OnNavBotStuck(NavBot bot, int count)
{
	if (count < cvar_min_events.IntValue)
	{
		return;
	}

	float origin[3];
	float eyePos[3];
	float eyeAngles[3];

	GetClientAbsOrigin(bot.Index, origin);
	GetClientEyePosition(bot.Index, eyePos);
	GetClientEyeAngles(bot.Index, eyeAngles);
	int lastArea = -1;
	Address areaPtr = bot.GetLastKnownNavArea();

	if (areaPtr != Address_Null)
	{
		lastArea = NavBotNavArea.GetID(areaPtr);
	}

	LogToFile(g_logfile, "Bot \"%L\" got stuck [%i] at <%f %f %f> Eye Position <%f %f %f> Eye Angles <%f %f %f> Last Known Nav Area ID <%i>", 
	bot.Index, count, origin[0], origin[1], origin[2], eyePos[0], eyePos[1], eyePos[2], eyeAngles[0], eyeAngles[1], eyeAngles[2], lastArea);
}