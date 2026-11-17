
static int s_Players;
static int s_NavBots;

static void Think_Normal()
{
	// Normal mode, the number of bots in the server must match the quota target

	if (s_NavBots == g_quotaTarget)
	{
		return;
	}

	if (s_NavBots > g_quotaTarget)
	{
		RemoveBot();
	}
	else
	{
		AddBot();
	}
}

static void Think_Fill()
{
	// The server if filled with bots until the human + bot count matches the quota target
	// When a human disconnects, a bot is added to the count

	int total = s_Players + s_NavBots;

	if (total == g_quotaTarget)
	{
		return;
	}

	if (total > g_quotaTarget)
	{
		RemoveBot();
	}
	else
	{
		AddBot();
	}
}

static void Think_Match()
{
	// Number of bots is equal to the number of humans multiplied by the quota target.
	// IE: If the quota target is 1 and there are 6 humans, the number of bots must be 6.
	// If the quota target is 2, then the number of bots is 12

	int numBots = s_Players * g_quotaTarget;

	if (s_NavBots == numBots)
	{
		return;
	}

	if (s_NavBots > numBots)
	{
		RemoveBot();
	}
	else
	{
		AddBot();
	}
}

static void Think_RemoveAll()
{
	if (s_NavBots > 0)
	{
		RemoveBot();
	}
}

void Timer_QuotaSystemThink(Handle timer)
{
	if (!cv_quota_enabled.BoolValue)
	{
		return;
	}

	// update counts
	CountPlayers(s_Players, s_NavBots);

	if (IsServerFull() && s_NavBots == 0)
	{
		return;
	}
	
	if (g_quotaTarget <= 0)
	{
		Think_RemoveAll();
		return;
	}

	switch (g_mode)
	{
	case QUOTA_MODE_FILL:
	{
		Think_Fill();
	}
	case QUOTA_MODE_MATCH:
	{
		Think_Match();
	}
	default:
	{
		Think_Normal();
	}
	}
}
