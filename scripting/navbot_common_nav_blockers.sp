#include <sourcemod>
#include <sdktools>
#include <navbot>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "NavBot Common Entities Nav Blocker Module",
	author = "caxanga334",
	description = "Implements Nav Auto Blockers for common entities.",
	version = "1.0.1",
	url = "https://github.com/caxanga334/navbot-plugins"
};

// https://github.com/ValveSoftware/source-sdk-2013/blob/c98767b329f07c086281d787cc0e1c4d9a6b1410/src/public/const.h#L252
const int FSOLID_NOT_SOLID = 0x0004;
const float HALF_PLAYER_HULL_WIDTH = 16.0;
const float STEP_HEIGHT = 18.0;

ConVar cvar_block_wall_toggle = null;
Handle g_RoundRestartTimer = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	return APLRes_Success;
}

public void OnPluginStart()
{
	cvar_block_wall_toggle = CreateConVar("sm_nav_blockers_wall_toggle", "1", "If enabled, create auto nav blockers for func_wall_toggle entities.");
	AutoExecConfig();
}

void StartTimer(bool force = false)
{
	if (g_RoundRestartTimer != null)
	{
		if (!force)
		{
			return;
		}

		delete g_RoundRestartTimer;
		g_RoundRestartTimer = null;
	}

	g_RoundRestartTimer = CreateTimer(12.0, Timer_OnRoundRestarted, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
	g_RoundRestartTimer = null;
}

// For when the nav mesh gets reloaded (IE: When being edited)
public void OnNavBotNavMeshLoaded()
{
	StartTimer(false);
}

void Timer_OnRoundRestarted(Handle timer, any data)
{
	g_RoundRestartTimer = null;
	OnRoundRestart();
}

void OnRoundRestart()
{
	SetupBlockers();
}

bool SharedBlocker_Init(NavBotNavBlocker blocker)
{
	int entity = blocker.Entity;

	if (entity == INVALID_ENT_REFERENCE)
	{
		return false;
	}

	NavBotNavAreaVector vec = NavBotNavMesh.CollectAreasTouchingEntity(entity);

	if (vec.IsEmpty())
	{
		delete vec;
		return false;
	}

	blocker.AddAreas(vec);
	delete vec;
	return true;
}


bool WallBlocker_Update(NavBotNavBlocker blocker)
{
	int entity = blocker.Entity;

	if (entity == INVALID_ENT_REFERENCE)
	{
		return false;
	}

	int solidFlags = GetEntProp(entity, Prop_Data, "m_usSolidFlags");

	if ((solidFlags & FSOLID_NOT_SOLID) != 0)
	{
		blocker.UpdateBlockedStatus(NAVBOT_NAV_TEAM_ANY, false);
	}
	else
	{
		blocker.UpdateBlockedStatus(NAVBOT_NAV_TEAM_ANY, true);
	}

	return true;
}

bool SharedBlocker_OnRoundRestart(NavBotNavBlocker blocker)
{
	StartTimer(false); // nav mesh onroundrestar events may come from nav mesh reloads
	return false;
}

void SetupBlockers()
{
	SetupWallToggleBlockers();
}

void SetupWallToggleBlockers()
{
	if (!cvar_block_wall_toggle.BoolValue)
	{
		return;
	}

	int entity = INVALID_ENT_REFERENCE;

	while ((entity = FindEntityByClassname(entity, "func_wall_toggle")) != INVALID_ENT_REFERENCE)
	{
		NavBotNavBlocker blocker = new NavBotNavBlocker(SharedBlocker_Init, WallBlocker_Update, "WallToggleBlocker");
		blocker.Entity = entity;
		blocker.OnRoundRestart = SharedBlocker_OnRoundRestart;
	}
}
