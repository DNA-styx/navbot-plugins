
/**
 * Counts the numbers of players. If the option is enabled, also skips the non NavBot bots (useful for TF2 MvM).
 * 
 * Note: Replay/SourceTV bots are always skipped
 */
void CountPlayers(int& player, int& navbots)
{
	bool includeOtherBots = cv_quota_ignore_others.BoolValue == false;

	player = 0;
	navbots = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}

		if (IsFakeClient(i))
		{
			// don't count replay/sourcetv bots
			if (IsClientReplay(i) || IsClientSourceTV(i))
			{
				continue;
			}

			// NavBot bot
			if (NavBotManager.IsNavBot(i))
			{
				navbots++;
				continue;
			}

			// Ignore bots is enabled
			if (!includeOtherBots)
			{
				continue;
			}
		}

		if (g_countPlayerForward.FunctionCount > 0)
		{
			Action result = Plugin_Continue;
			Call_StartForward(g_countPlayerForward);
			Call_PushCell(i);
			Call_Finish(result);

			if (result != Plugin_Continue)
			{
				// forward told us this player should be ignored
				continue;
			}
		}

		player++; // add to the count
	}
}

// Determines if bots should be added
bool ShouldAddBot()
{
	int n = MaxClients - GetClientCount(false);

	// Hardcoded to always keep at least 2 slots free for humans to join.
	return n > 2;
}

bool IsServerFull()
{
	return GetClientCount(false) == MaxClients;
}

static void KickRandomNavBot()
{
	int[] players = new int[MaxClients];
	int max = CollectNavBots(players, MaxClients);
	
	if (max == 0)
	{
		return;
	}

	int kicktarget = 0;

	if (max == 1)
	{
		kicktarget = players[0];
	}
	else
	{
		int idx = GetRandomInt(0, max - 1);
		kicktarget = players[idx];
	}

	KickClient(kicktarget, "Kicked by bot quota");
}

static void KickFirstDeadBot()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && !IsPlayerAlive(i) && NavBotManager.IsNavBot(i))
		{
			KickClient(i, "Kicked by bot quota");
			return;
		}
	}
}

void RemoveBot()
{
	if (g_selectBotForward.FunctionCount > 0)
	{
		int bot = 0;
		Action result = Plugin_Continue;

		Call_StartForward(g_selectBotForward);
		Call_PushCellRef(bot);
		Call_Finish(result);

		// don't kick any bots on Plugin_Stop
		if (result == Plugin_Stop)
		{
			return;
		}

		// If not continue
		if (result > Plugin_Continue)
		{
			// Kick the given bot and make sure it's a valid bot.
			if (bot > 0 && bot <= MaxClients && IsClientInGame(bot) && NavBotManager.IsNavBot(bot))
			{
				KickClient(bot, "Kicked by bot quota");
			}

			return;
		}
	}

	if (cv_quota_dead_only.BoolValue)
	{
		KickFirstDeadBot();
	}
	else
	{
		KickRandomNavBot();
	}
}

void AddBot()
{
	if (!ShouldAddBot())
	{
		return;
	}

	NavBot bot = NavBot();

	if (!bot.IsNull)
	{
		LogMessage("Bot \"%L\" added to the game.", bot.Index);
	}
}

