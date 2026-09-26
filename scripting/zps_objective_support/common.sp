
// Each objective map gets a unique value here for the switch statement
enum ZPOMap
{
	MAP_UNKNOWN = 0,
	MAP_ZPO_BIOTEC,
	MAP_ZPO_TANKER,
	MAP_ZPO_CORPSINGTON,
	MAP_ZPO_KERETTI,
	MAP_ZPO_HARVEST,
	MAP_ZPO_MURKSVILLE,
	MAP_ZPO_ZOMBOEING,
	MAP_ZPO_TERMINAL_VF1,
	MAP_ZPO_REDQUEEN_R106,
	MAP_ZPO_GASDUMP_NF1,
	MAP_ZPO_AREA41_V7F,
	MAP_ZPO_DAYOFTHEDEAD_V3,
	MAP_ZPO_ABANDONED_BASE_R2,
	MAP_ZPO_BLACKBIRD_V4,
	MAP_ZPO_SNOWBLIND_V2,
	MAP_ZPO_SNOWBOUND_DC_V3,
	MAP_ZPO_NOEXIT_H2,
	MAP_ZPO_HOARFROST_B1_B2,
	MAP_ZPO_SHREDDINGFIELD,
}

static ZPOMap s_detectedMap = MAP_UNKNOWN;

// Detects if the current map is an objective map.
void DetectObjectiveMap()
{
	s_detectedMap = MAP_UNKNOWN;

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
		s_detectedMap = MAP_ZPO_TANKER;
	}
	else if (strcmp(map, "zpo_corpsington") == 0)
	{
		s_detectedMap = MAP_ZPO_CORPSINGTON;
	}
	else if (strcmp(map, "zpo_keretti") == 0)
	{
		s_detectedMap = MAP_ZPO_KERETTI;
	}
	else if (strcmp(map, "zpo_harvest") == 0)
	{
		s_detectedMap = MAP_ZPO_HARVEST;
	}
	else if (strcmp(map, "zpo_murksville") == 0)
	{
		s_detectedMap = MAP_ZPO_MURKSVILLE;
	}
	else if (strcmp(map, "zpo_zomboeing") == 0)
	{
		s_detectedMap = MAP_ZPO_ZOMBOEING;
	}
	else if (strcmp(map, "zpo_terminal_vf1") == 0)
	{
		s_detectedMap = MAP_ZPO_TERMINAL_VF1;
	}
	else if (strcmp(map, "zpo_redqueen_r106") == 0)
	{
		s_detectedMap = MAP_ZPO_REDQUEEN_R106;
	}
	else if (strcmp(map, "zpo_gasdump_nf1") == 0)
	{
		s_detectedMap = MAP_ZPO_GASDUMP_NF1;
	}
	else if (strcmp(map, "zpo_area41_v7f") == 0)
	{
		s_detectedMap = MAP_ZPO_AREA41_V7F;
	}
	else if (strcmp(map, "zpo_dayofthedead_v3") == 0)
	{
		s_detectedMap = MAP_ZPO_DAYOFTHEDEAD_V3;
	}
	else if (strcmp(map, "zpo_abandoned_base_r2") == 0)
	{
		s_detectedMap = MAP_ZPO_ABANDONED_BASE_R2;
	}
	else if (strcmp(map, "zpo_blackbird_v4") == 0)
	{
		s_detectedMap = MAP_ZPO_BLACKBIRD_V4;
	}
	else if (strcmp(map, "zpo_snowblind_v2") == 0)
	{
		s_detectedMap = MAP_ZPO_SNOWBLIND_V2;
	}
	else if (strcmp(map, "zpo_snowbound_dc_v3") == 0)
	{
		s_detectedMap = MAP_ZPO_SNOWBOUND_DC_V3;
	}
	else if (strcmp(map, "zpo_noexit_h2") == 0)
	{
		s_detectedMap = MAP_ZPO_NOEXIT_H2;
	}
	else if (strcmp(map, "zpo_hoarfrost_b1_b2") == 0)
	{
		s_detectedMap = MAP_ZPO_HOARFROST_B1_B2;
	}
	else if (strcmp(map, "zpo_shreddingfield") == 0)
	{
		s_detectedMap = MAP_ZPO_SHREDDINGFIELD;
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
		case MAP_ZPO_TANKER:
		{
			ZPOTanker_Init();
		}
		case MAP_ZPO_CORPSINGTON:
		{
			ZPOCorpsington_Init();
		}
		case MAP_ZPO_KERETTI:
		{
			ZPOKeretti_Init();
		}
		case MAP_ZPO_HARVEST:
		{
			ZPOHarvest_Init();
		}
		case MAP_ZPO_MURKSVILLE:
		{
			ZPOMurksville_Init();
		}
		case MAP_ZPO_ZOMBOEING:
		{
			ZPOZomboeing_Init();
		}
		case MAP_ZPO_TERMINAL_VF1:
		{
			ZPOTerminal_Init();
		}
		case MAP_ZPO_REDQUEEN_R106:
		{
			ZPORedQueenR106_Init();
		}
		case MAP_ZPO_GASDUMP_NF1:
		{
			ZPOGasdumpNF1_Init();
		}
		case MAP_ZPO_AREA41_V7F:
		{
			ZPOArea41V7F_Init();
		}
		case MAP_ZPO_DAYOFTHEDEAD_V3:
		{
			ZPODayOfTheDeadV3_Init();
		}
		case MAP_ZPO_ABANDONED_BASE_R2:
		{
			ZPOAbandonedBaseR2_Init();
		}
		case MAP_ZPO_BLACKBIRD_V4:
		{
			ZPOBlackbird_Init();
		}
		case MAP_ZPO_SNOWBLIND_V2:
		{
			ZPOSnowblindV2_Init();
		}
		case MAP_ZPO_SNOWBOUND_DC_V3:
		{
			ZPOSnowboundDCv3_Init();
		}
		case MAP_ZPO_NOEXIT_H2:
		{
			ZPONoexitH2_Init();
		}
		case MAP_ZPO_HOARFROST_B1_B2:
		{
			ZPOHoarfrostB1B2_Init();
		}
		case MAP_ZPO_SHREDDINGFIELD:
		{
			ZPOShreddingfield_Init();
		}
		default:
		{
			NavBotZPSModInterface.ResetObjective();
		}
	}
}