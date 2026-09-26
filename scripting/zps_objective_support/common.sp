
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
		else if (strcmp(map, "zpo_abandoned_base_r2") == 0)
	{
		ZPOAbandonedBaseR2_Init();
	}
		else if (strcmp(map, "zpo_blackbird_v4") == 0)
	{
		ZPOBlackbird_Init();
	}
		else if (strcmp(map, "zpo_snowblind_v2") == 0)
	{
		ZPOSnowblindV2_Init();
	}
		else if (strcmp(map, "zpo_snowbound_dc_v3") == 0)
	{
		ZPOSnowboundDCv3_Init();
	}
		else if (strcmp(map, "zpo_noexit_h2") == 0)
	{
		ZPONoexitH2_Init();
	}
		else if (strcmp(map, "zpo_hoarfrost_b1_b2") == 0)
	{
		ZPOHoarfrostB1B2_Init();
	}
		else if (strcmp(map, "zpo_shreddingfield") == 0)
	{
		ZPOShreddingfield_Init();
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