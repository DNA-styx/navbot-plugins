
void HookNamedOutputOfAllEntities(const char[] classname, const char[] output, EntityOutput callback, bool once = false)
{
	int entity = INVALID_ENT_REFERENCE;

	while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(entity, output, callback, once);
	}
}

int FindNamedEntityOfClassname(int startent, const char[] classname, const char[] targetname)
{
	int entity = startent;

	while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
	{
		char name[256];
		
		if (GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name)) > 0)
		{
			if (strcmp(name, targetname, false) == 0)
			{
				return entity;
			}
		}
	}

	return INVALID_ENT_REFERENCE;
}

int FindEntityOfHammerID(int startent, const char[] classname, const int hammerid)
{
	int entity = startent;

	while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
	{
		int id = GetEntProp(entity, Prop_Data, "m_iHammerID");

		if (id == hammerid)
		{
			return entity;
		}
	}

	return INVALID_ENT_REFERENCE;
}

/**
 * Logs a debug message if debugging is enabled.
 * 
 * @param format		Format parameters.
 * @param ...			Format args.
 */
void LogDebugMessage(const char[] format, any ...)
{
	if (!cvar_debug.BoolValue) { return; }

	char buffer[4096];
	VFormat(buffer, sizeof(buffer), format, 2);

	LogMessage("[DEBUG] %s", buffer);
}

/**
 * Checks if every active NavBot can currently path to the given position.
 * Logs (debug-gated) each bot that can't reach it.
 *
 * @param goal      World position to test.
 * @return          True if every active NavBot can reach the goal, false if at least one cannot.
 */

bool CanAllBotsReachGoal(const float goal[3])
{
	bool allReachable = true;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !NavBotManager.IsNavBot(client))
		{
			continue;
		}

		NavBot bot = NavBotManager.GetNavBotByIndex(client);

		if (bot == NULL_NAVBOT)
		{
			continue;
		}

		MeshNavigator nav = new MeshNavigator();
		bool reachable = nav.ComputeToPos(bot, goal);
		delete nav;

		if (!reachable)
		{
			allReachable = false;
			LogDebugMessage("MOVETO goal unreachable for bot \"%N\" (client %i). Goal: %.1f %.1f %.1f", client, client, goal[0], goal[1], goal[2]);
		}
	}

	return allReachable;
}