
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
 * This should not be used for warning/errors. This is for verbose logging.
 * 
 * @param format		Format parameters.
 * @param ...			Format args.
 */
void LogDebugMessage(const char[] format, any ...)
{
	if (!cvar_debug.BoolValue) { return; }

	char buffer[4096];

#if defined __sourcepawn2
	FormatEx(buffer, sizeof(buffer), format, ...);
#else
	VFormat(buffer, sizeof(buffer), format, 2);
#endif

	LogMessage("[DEBUG] %s", buffer);
}

/**
 * Checks if every alive survivor NavBot can path to the given position.
 * Logs each bot once until it can reach a goal again.
 * Call via the CanAllBotsReachGoal macro so the caller's file and line are logged.
 *
 * @param goal      World position to test.
 * @param file      Caller file name.
 * @param line      Caller line number.
 * @return          True if every alive survivor NavBot can reach the goal, false if at least one cannot.
 */
static bool s_bUnreachableLogged[MAXPLAYERS + 1];

#define CanAllBotsReachGoal(%1) CanAllBotsReachGoalAt(%1, __FILE_NAME__, __LINE__)

bool CanAllBotsReachGoalAt(const float goal[3], const char[] file, int line)
{
	bool allReachable = true;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !NavBotManager.IsNavBot(client))
		{
			continue;
		}

		if (GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		{
			continue;
		}

		NavBot bot = NavBotManager.GetNavBotByIndex(client);

		if (bot == NULL_NAVBOT)
		{
			continue;
		}

		MeshNavigator nav = new MeshNavigator();
		bool reachable = nav.ComputeToPos(bot, goal, 0.0, false);
		delete nav;

		if (reachable)
		{
			s_bUnreachableLogged[client] = false;
			continue;
		}

		allReachable = false;

		if (!s_bUnreachableLogged[client])
		{
			s_bUnreachableLogged[client] = true;

			float pos[3];
			GetClientAbsOrigin(client, pos);
			LogError("MOVETO goal unreachable for bot \"%N\" (client %i) at %s:%i. Bot: %.1f %.1f %.1f Goal: %.1f %.1f %.1f", client, client, file, line, pos[0], pos[1], pos[2], goal[0], goal[1], goal[2]);
		}
	}

	return allReachable;
}