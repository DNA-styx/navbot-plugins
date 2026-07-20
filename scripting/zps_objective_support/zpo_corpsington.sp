/*

	ZPO Corpsington - NavBot Objective Support Module
	Author: Claude.ai guided by DNA.styx

	Phase 1: BreakIntoOffice
	Destroy 3x wooden_barricade props to unlock breakdoor1 / breakdoor2.
	All 3 props share the same targetname, so they are resolved individually
	via Hammer ID and destroyed one at a time (DESTROY_ENTITY only supports
	a single target).

	Version: 0.1.0

*/

void ZPOCorpsington_UpdateBarricadeObjective()
{
	static int s_CurrentBarricadeRef = INVALID_ENT_REFERENCE;

	// Current target still alive, nothing to do.
	if (s_CurrentBarricadeRef != INVALID_ENT_REFERENCE && EntRefToEntIndex(s_CurrentBarricadeRef) != INVALID_ENT_REFERENCE)
	{
		return;
	}

	static const int barricadeHammerIDs[] = { 908234, 908281, 908312 };

	for (int i = 0; i < sizeof(barricadeHammerIDs); i++)
	{
		int entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics_multiplayer", barricadeHammerIDs[i]);

		if (entity != INVALID_ENT_REFERENCE)
		{
			s_CurrentBarricadeRef = EntIndexToEntRef(entity);
			NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
			NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
			return;
		}
	}

	// All 3 barricades destroyed, Phase 1 complete.
	s_CurrentBarricadeRef = INVALID_ENT_REFERENCE;
	LogDebugMessage("zpo_corpsington: Phase 1 (BreakIntoOffice) complete.");
	//TODO: Phase 2 - OpenWarehouse (wh_button)
}

void ZPOCorpsington_Think()
{
	ZPOCorpsington_UpdateBarricadeObjective();
}

void ZPOCorpsington_Init()
{
	g_ThinkFunc = ZPOCorpsington_Think;
	ZPOCorpsington_UpdateBarricadeObjective();
}
