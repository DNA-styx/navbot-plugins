
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