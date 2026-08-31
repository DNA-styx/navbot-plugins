
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
	else if (strcmp(map, "zpo_tanker") == 0)
	{
		ZPOTanker_Init();
	}
	else if (strcmp(map, "zpo_corpsington") == 0)
	{
		ZPOCorpsington_Init();
	}
	else if (strcmp(map, "zpo_keretti") == 0)
	{
		ZPOKeretti_Init();
	}
		else if (strcmp(map, "zpo_harvest") == 0)
	{
		ZPOHarvest_Init();
	}
		else if (strcmp(map, "zpo_murksville") == 0)
	{
		ZPOMurksville_Init();
	}
		else if (strcmp(map, "zpo_zomboeing") == 0)
	{
		ZPOZomboeing_Init();
	}
		else if (strcmp(map, "zpo_terminal_vf1") == 0)
	{
		ZPOTerminal_Init();
	}		
		else if (strcmp(map, "zpo_redqueen_r106") == 0)
	{
		ZPORedQueenR106_Init();
	}
		else if (strcmp(map, "zpo_gasdump_nf1") == 0)
	{
		ZPOGasdumpNF1_Init();
	}
		else if (strcmp(map, "zpo_area41_v7f") == 0)
	{
		ZPOArea41V7F_Init();
	}
		else if (strcmp(map, "zpo_dayofthedead_v3") == 0)
	{
		ZPODayOfTheDeadV3_Init();
	}
	else
	{
		LogMessage("Current map \"%s\" is not supported!", map);
		NavBotZPSModInterface.ResetObjective();
	}
}