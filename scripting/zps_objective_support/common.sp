
// Each objective map gets a unique value here for the switch statement
enum ZPOMap
{
	MAP_UNKNOWN = 0,
	MAP_ZPO_BIOTEC,
}

static ZPOMap s_detectedMap = MAP_UNKNOWN;

// Detects if the current map is an objective map.
void DetectObjectiveMap()
{
	s_detectedMap = MAP_UNKNOWN

	char map[128];
	GetCurrentMap(map, sizeof(map));
	GetMapDisplayName(map, map, sizeof(map));

	if (strncmp(map, "zpo_", 4) != 0)
	{
		LogMessage("Current map is an objective map, skipping!");
		return;
	}

	// detection of supported maps.
	if (strcmp(map, "zpo_biotec") == 0)
	{
		s_detectedMap = MAP_ZPO_BIOTEC;
	}
	else
	{
		LogMessage("Current map \"%s\" is not supported!", map);
		NavBotZPSModInterface.ResetObjective();
	}
}

void Frame_Init()
{
	InitObjectives();
}

void InitObjectives()
{
	if (s_detectedMap == MAP_UNKNOWN)
	{
		return;
	}

	g_ThinkFunc = null;

	// Perf: This gets called on every round restart, this is faster than strcmp the map every time.
	switch (s_detectedMap)
	{
		case MAP_ZPO_BIOTEC:
		{
			ZPOBiotec_Init();
		}
		default:
		{
			NavBotZPSModInterface.ResetObjective();
		}
	}
}