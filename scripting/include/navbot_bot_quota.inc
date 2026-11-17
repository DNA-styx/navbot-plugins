#if defined _navbot_bot_quota_included
 #endinput
#endif
#define _navbot_bot_quota_included

/**
 * Called before selecting a bot to kick.
 * Allows for custom bot kick target selection implementation.
 * 
 * @param targetbot			Index of the bot to kick.
 * @return					Action to take, see below.
 * 
 * What happens on each return type:
 * Plugin_Continue: The bot quota plugin handles kick target selection.
 * Plugin_Changed and Plugin_Handled: The client index passed to "targetbot" gets kicked.
 * Plugin_Stop: Returns early and doesn't kick any bots.
 */
forward Action NavBotQuota_SelectBotToKick(int& targetbot);

/**
 * Called when counting the number of players in-game.
 * 
 * @param client			Client index (guaranteed to be in-game).
 * @return					Plugin_Continue to count this player. Anything else to not count.
 */
forward Action NavBotQuota_IsPlayerIgnored(int client);

public SharedPlugin __pl_navbot_bot_quota = 
{
	name = "navbot_bot_quota",
	file = "navbot_bot_quota.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
 
#if !defined REQUIRE_PLUGIN
public void __pl_navbot_bot_quota_SetNTVOptional()
{

}
#endif