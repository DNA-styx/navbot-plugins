
void Frame_Init()
{
	InitObjectives();
}

void InitObjectives()
{
	char map[128];
	GetCurrentMap(map, sizeof(map));
	GetMapDisplayName(map, map, sizeof(map));

	if (strncmp(map, "zpo_", 4) != 0)
	{
		LogMessage("Current map is an objective map, skipping!");
		return;
	}

	g_ThinkFunc = null;

	// add supported maps here
	if (strcmp(map, "zpo_biotec") == 0)
	{
		ZPOBiotec_Init();
	}
	else
	{
		LogMessage("Current map \"%s\" is not supported!", map);
		NavBotZPSModInterface.ResetObjective();
	}
}