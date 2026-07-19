#include <sourcemod>
#include <sdktools>
#include <navbot>

#pragma newdecls required
#pragma semicolon 1

// BUG: Spectator team isn't always team index 1 (IE: Insurgency Modern Infantry Combat)
#define TEAM_SPECTATOR 1

public Plugin myinfo =
{
	name = "NavBot Admin Debugging Tools",
	author = "caxanga334",
	description = "Tool plugin for server admins to debug bots.",
	version = "1.0.0",
	url = "https://github.com/caxanga334/navbot-plugins"
};

bool g_debugEnabled[MAXPLAYERS + 1];
int g_iLaserSprite;
int g_iHaloSprite;
Handle h_hudMsg1 = null;
Handle h_hudMsg2 = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (FindSendPropInfo("CBasePlayer", "m_hObserverTarget") <= 0)
	{
		strcopy(error, err_max, "This game is not supported!");
		return APLRes_SilentFailure;
	}

	h_hudMsg1 = CreateHudSynchronizer();
	h_hudMsg2 = CreateHudSynchronizer();

	if (h_hudMsg1 == null)
	{
		strcopy(error, err_max, "This game does not supports HUD messages!");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	RegAdminCmd("sm_nbadmin_toggle_debug", Command_ToggleDebug, ADMFLAG_CHEATS, "Toggles bot debugging for you.");
}

Action Command_ToggleDebug(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "This command can only be used in-game!");
		return Plugin_Handled;
	}

	g_debugEnabled[client] = !g_debugEnabled[client];

	if (g_debugEnabled[client])
	{
		ReplyToCommand(client, "Enabled bot debugging!");
	}
	else
	{
		ReplyToCommand(client, "Disabled bot debugging!");
	}

	return Plugin_Handled;
}

public void OnMapStart()
{
	// TO-DO: Get the sprite texture from gamedata.
	g_iLaserSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	CreateTimer(0.1, Timer_Think, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

	if (g_iLaserSprite == 0 || g_iHaloSprite == 0)
	{
		LogMessage("Could not precache tempent sprites. Path drawing will be disabled.");
	}
}

void Timer_Think(Handle timer)
{
	if (NavBotManager.GetNavBotCount() < 1)
	{
		return;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && g_debugEnabled[i])
		{
			CheckAndDraw(i);
		}
	}
}

void CheckAndDraw(int client)
{
	if (GetClientTeam(client) != TEAM_SPECTATOR)
	{
		return;
	}

	int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

	if (target == INVALID_ENT_REFERENCE)
	{
		return;
	}

	NavBot bot = NavBotManager.GetNavBotByIndex(target);

	if (bot.IsNull)
	{
		return;
	}

	DrawDebugHUD(client, bot);
	DrawPath(client, bot);
}

void DrawLine(int client, const float start[3], const float end[3])
{
	int colors[4] = { 255, 255, 0, 255 };

	TE_SetupBeamPoints(start, end, g_iLaserSprite, g_iHaloSprite, 0, 4, 0.2, 1.0, 1.0, 1, 0.0, colors, 0);
	TE_SendToClient(client);
}

void DrawDebugHUD(int client, NavBot bot)
{
	char text1[MAX_NAME_LENGTH];
	FormatEx(text1, sizeof(text1), "Debugging bot %N", bot.Index);

	SetHudTextParams(0.06, 0.3, 0.2, 255, 255, 0, 255);
	ShowSyncHudText(client, h_hudMsg1, "%s", text1);

	Address ptr = bot.GetBehaviorInterface();

	if (ptr != Address_Null)
	{
		char buffer[512];
		NavBotBehaviorInterface.GetTaskDebugString(ptr, buffer, sizeof(buffer));
		SetHudTextParams(0.06, 0.38, 0.2, 255, 255, 0, 255);
		ShowSyncHudText(client, h_hudMsg2, "%s", buffer);
	}
}

void DrawPath(int client, NavBot bot)
{
	if (g_iLaserSprite <= 0 || g_iHaloSprite <= 0) { return; }

	float x[8];
	float y[8];
	float z[8];
	int n = bot.GetCurrentPath(x, y, z, sizeof(x));

	if (n > 0)
	{
		float p1[3];
		float p2[3];

		for (int i = 1; i < n; i++)
		{
			int prev = i - 1;

			p1[0] = x[prev];
			p1[1] = y[prev];
			p1[2] = z[prev] + 4.0;
			p2[0] = x[i];
			p2[1] = y[i];
			p2[2] = z[i] + 4.0;

			DrawLine(client, p1, p2);
		}
	}
}