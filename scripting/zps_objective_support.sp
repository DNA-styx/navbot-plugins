#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <navbot>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "ZPS NavBot Objective Support Module",
	author = "caxanga334",
	description = "Adds supports for objective maps.",
	version = "1.0.0",
	url = "https://github.com/caxanga334/navbot-plugins"
};

Function g_ThinkFunc = null;
ConVar cvar_detradius = null;
ConVar cvar_debug = null;
float g_DetectionRadius;

#include "zps_objective_support/utils.sp"
#include "zps_objective_support/zpo_biotec.sp"
#include "zps_objective_support/zpo_tanker.sp"
#include "zps_objective_support/zpo_corpsington.sp"
#include "zps_objective_support/common.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char gamefolder[16];
	GetGameFolderName(gamefolder, sizeof(gamefolder));

	if (strcmp(gamefolder, "zps") == 0)
	{
		return APLRes_Success;
	}

	strcopy(error, err_max, "This plugin is for Zombie Panic! Source only!");
	return APLRes_SilentFailure;
}

public void OnPluginStart()
{
	cvar_detradius = CreateConVar("sm_navbot_zpo_support_detection_radius", "512.0", "Base detection radius for search objectives.");
	cvar_detradius.AddChangeHook(OnDetectionRadiusConvarChanged);
	cvar_debug = CreateConVar("sm_navbot_zpo_support_debug", "0", "If enabled, log debug messages.");

	HookEvent("endslate", Event_RoundEnd, EventHookMode_PostNoCopy);

	AutoExecConfig();
}

void OnDetectionRadiusConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_DetectionRadius = convar.FloatValue;

	if (g_DetectionRadius < 256.0)
	{
		g_DetectionRadius = 256.0;
	}
}

public void OnConfigsExecuted()
{
	g_DetectionRadius = cvar_detradius.FloatValue;

	if (g_DetectionRadius < 256.0)
	{
		g_DetectionRadius = 256.0;
	}

	NavBotZPSModInterface.ResetObjective();
	CreateTimer(1.0, Timer_CallThink, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public void OnNavBotModRoundRestart()
{
	RequestFrame(Frame_Init);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	NavBotZPSModInterface.ResetObjective();
}

void Timer_CallThink(Handle timer)
{
	if (g_ThinkFunc != null)
	{
		Call_StartFunction(null, g_ThinkFunc);
		Call_Finish();
	}
}