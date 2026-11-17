#include <sourcemod>
#include <navbot>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "NavBot Callouts",
	author = "caxanga334",
	description = "Bots reports enemy positions to teammates via team chat.",
	version = "1.0.0",
	url = "https://github.com/caxanga334/navbot-plugins"
};

#define MAX_TEAMS 32
#define NO_PLACE 0

ConVar cv_callout_enabled = null;
ConVar cv_callout_per_bot_cooldown = null;
ConVar cv_callout_per_team_cooldown = null;
ConVar cv_callout_team_only = null;
ConVar cv_callout_players_only = null;

enum struct BotData
{
	float cooldown; // per bot cooldown

	bool IsInCooldown()
	{
		return this.cooldown >= GetGameTime();
	}

	void OnCallout()
	{
		this.cooldown = GetGameTime() + cv_callout_per_bot_cooldown.FloatValue;
	}

	void Clear()
	{
		this.cooldown = 0.0;
	}
}

enum struct TeamData
{
	float cooldown; // per team cooldown

	void OnCallout()
	{
		this.cooldown = GetGameTime() + cv_callout_per_team_cooldown.FloatValue;
	}

	void OnRoundStart()
	{
		this.cooldown = GetGameTime() + 10.0; // wait some time before sending callouts
	}

	void Clear()
	{
		this.cooldown = 0.0;
	}
}

BotData g_botData[MAXPLAYERS + 1];
TeamData g_teamData[MAX_TEAMS + 1];

public void OnPluginStart()
{
	cv_callout_enabled = CreateConVar("sm_navbot_callouts_enabled", "1", "Controls if the callout plugin is enabled.");
	cv_callout_per_bot_cooldown = CreateConVar("sm_navbot_callouts_per_bot_cooldown", "30.0", "Cooldown in seconds between callouts per individual bot.");
	cv_callout_per_team_cooldown = CreateConVar("sm_navbot_callouts_per_team_cooldown", "15.0", "Shared cooldown in seconds between callouts per team.");
	cv_callout_team_only = CreateConVar("sm_navbot_callouts_team_only", "-1", "If greater or equals to zero, only bots from this team can send callouts.");
	cv_callout_players_only = CreateConVar("sm_navbot_callouts_players_only", "0", "If enabled, only callout enemy players and ignore NPCs.");

	AutoExecConfig();
	LoadTranslations("navbot_callouts.phrases");
}

public void OnMapStart()
{
	for (int i = 0; i < MAXPLAYERS + 1; i++)
	{
		g_botData[i].Clear();
	}

	for (int i = 0; i < MAX_TEAMS + 1; i++)
	{
		g_teamData[i].Clear();
	}
}

bool IsTeamInCooldown(int team)
{
	return g_teamData[team].cooldown >= GetGameTime();
}

bool IsEntityAPlayer(int entity)
{
	return entity > 0 && entity <= MaxClients;
}

void CalloutEnemy(NavBot bot, int threat)
{
	if (!cv_callout_enabled.BoolValue)
	{
		return;
	}

	int team = bot.TeamNum;

	if (g_botData[bot.Index].IsInCooldown() || IsTeamInCooldown(team))
	{
		return;
	}

	int teamFilter = cv_callout_team_only.IntValue;

	if (teamFilter >= 0 && team != teamFilter)
	{
		return;
	}

	// This filters out any entity that doesn't derive from CBaseCombatCharacter
	if (!HasEntProp(threat, Prop_Send, "m_hActiveWeapon"))
	{
		PrintToServer("Callout %N: Not a combat char", bot.Index);
		return;
	}

	if (cv_callout_players_only.BoolValue && !IsEntityAPlayer(threat))
	{
		return;
	}

	float origin[3];
	GetEntPropVector(threat, Prop_Data, "m_vecAbsOrigin", origin);

	Address area = NavBotNavMesh.GetNearestNavArea(origin, 256.0, false, true, team);

	if (area == Address_Null)
	{
		return;
	}

	char placename[128];

	if (!NavBotNavArea.GetPlaceName(area, placename, sizeof(placename)))
	{
		return;
	}

	char classname[64];
	
	if (!GetEntityClassname(threat, classname, sizeof(classname)))
	{
		return;
	}

	char buffer[128];
	FormatEx(buffer, sizeof(buffer), "enemy_%s", classname);

	if (!TranslationPhraseExists(buffer))
	{
		return;
	}

	g_teamData[team].OnCallout();
	g_botData[bot.Index].OnCallout();

	char msg[256];
	FormatEx(msg, sizeof(msg), "%T", "Callout_Msg", LANG_SERVER, buffer, placename);
	FakeClientCommand(bot.Index, "say_team %s", msg);
}

public void OnNavBotModRoundRestart()
{
	for (int i = 0; i < MAX_TEAMS + 1; i++)
	{
		g_teamData[i].OnRoundStart();
	}
}

public void OnNavBotEnterCombat(NavBot bot, int threat, int activeWeapon)
{
	CalloutEnemy(bot, threat);
}

public void OnNavBotThreatVisible(NavBot bot, int threat, int activeWeapon)
{
	CalloutEnemy(bot, threat);
}