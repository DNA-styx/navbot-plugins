#include <sourcemod>
#include <navbot>

public Plugin myinfo =
{
	name = "NavBot Auto Bot Skill Refresh",
	author = "caxanga334",
	description = "Updates the bot skill profiles when the skill ConVar changes.",
	version = "1.0.0",
	url = "https://github.com/caxanga334/navbot-plugins"
};

ConVar cvar_skill = null;

public void OnAllPluginsLoaded()
{
	cvar_skill = FindConVar("sm_navbot_skill_level");

	if (cvar_skill == null)
	{
		SetFailState("Failed to find the \"sm_navbot_skill_level\" ConVar!");
	}

	cvar_skill.AddChangeHook(OnSkillConVarChanged);
}

void OnSkillConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (NavBotManager.GetNavBotCount() > 0)
	{
		int skill = convar.IntValue;

		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && IsFakeClient(client))
			{
				NavBot bot = NavBotManager.GetNavBotByIndex(client);

				if (!bot.IsNull)
				{
					bot.SetSkillLevel(skill);
				}
			}
		}
	}
}