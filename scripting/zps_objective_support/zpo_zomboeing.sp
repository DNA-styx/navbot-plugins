/**
 * zpo_zomboeing.sp
 *
 * NavBot ZPS objective support module for the zpo_zomboeing map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.13.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: unusable
 *
 * Issues: There is a trigger that players activate as they join. I don't
 *   think bots do, so the third package never spawns (or gets sent
 *   straight to the collection point). Will revisit.
 */

enum
{
	ZPOZOMBOEING_PHASE_FINDSUPPLIES = 0,
	ZPOZOMBOEING_PHASE_DONE
};

static int s_CurrentPhase = ZPOZOMBOEING_PHASE_FINDSUPPLIES;
static char s_SupplyCrateNames[3][8] = { "cb4", "cb2", "cb_one" };
static int s_CrateEntRefs[3];
static bool s_CrateTaken[3];

void ZPOZomboeing_Init()
{
	g_ThinkFunc = ZPOZomboeing_Think;
	s_CurrentPhase = ZPOZOMBOEING_PHASE_FINDSUPPLIES;

	int dropzone = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_teleport", "cb_four_delzone");

	if (dropzone == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_zomboeing: Failed to find cb_four_delzone!");
		return;
	}

	HookSingleEntityOutput(dropzone, "OnStartTouch", ZPOZomboeing_OnCrateDelivered, false);

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "delzone_counter");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_zomboeing: Failed to find delzone_counter!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOZomboeing_OnAllSuppliesDelivered, true);

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "human_start_trigger_once");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_zomboeing: Failed to find human_start_trigger_once!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOZomboeing_OnHumanStartTriggerTouched, true);
}

void ZPOZomboeing_Think()
{

}

/**
 * Phase: 0 - FindSupplies
 * Summary: 3 crates, unique itemids so FIND_ITEM targets one at a time.
 *   delzone_counter is the source of truth for progress. First search
 *   waits for human_start_trigger_once plus a reposition buffer -- see
 *   Issues above.
 * Entity: cb4 / cb2 / cb_one (item_deliver, hammer IDs 7247950 / 7247987 /
 *   7247997) / cb_four_delzone (trigger_teleport, hammer ID 7157584) /
 *   delzone_counter (math_counter, hammer ID 7157748, max 3) /
 *   human_start_trigger_once (trigger_once, hammer ID 5665647)
 * Bot action: FIND_ITEM for the next outstanding crate, then DROP_ITEM
 *   (via SetObjectiveItemUseTarget, per upstream c708eb8) at
 *   cb_four_delzone.
 * Confirmation: delzone_counter's OnHitMax ends the phase.
 */
void ZPOZomboeing_OnHumanStartTriggerTouched(const char[] output, int caller, int activator, float delay)
{
	// randomParcel chain needs time to reposition the crates first.
	CreateTimer(4.0, ZPOZomboeing_OnStartDelayExpired, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

void ZPOZomboeing_OnStartDelayExpired(Handle timer)
{
	// Re-hook after repositioning, not at Init(), to avoid stale entity refs.
	ZPOZomboeing_TagAndHookSupplyCrates();
	ZPOZomboeing_PickNextCrate();
}

void ZPOZomboeing_TagAndHookSupplyCrates()
{
	for (int i = 0; i < sizeof(s_SupplyCrateNames); i++)
	{
		int crate = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", s_SupplyCrateNames[i]);

		if (crate == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_zomboeing: Failed to find supply crate to tag! Name: %s", s_SupplyCrateNames[i]);
			continue;
		}

		SetEntPropString(crate, Prop_Data, "m_strItemID", s_SupplyCrateNames[i]);

		s_CrateEntRefs[i] = EntIndexToEntRef(crate);
		s_CrateTaken[i] = false;

		HookSingleEntityOutput(crate, "OnItemTaken", ZPOZomboeing_OnCratePickedUp, false);
		HookSingleEntityOutput(crate, "OnItemDropped", ZPOZomboeing_OnCrateDropped, false);
	}
}

void ZPOZomboeing_PickNextCrate()
{
	if (s_CurrentPhase != ZPOZOMBOEING_PHASE_FINDSUPPLIES)
	{
		return;
	}

	for (int i = 0; i < sizeof(s_CrateTaken); i++)
	{
		if (!s_CrateTaken[i])
		{
			NavBotZPSModInterface.ResetObjective();
			NavBotZPSModInterface.SetObjectiveItemSearchID(s_SupplyCrateNames[i]);
			NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
			NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
			return;
		}
	}

	// Nothing left to search for.
	NavBotZPSModInterface.ResetObjective();
}

int ZPOZomboeing_FindCrateIndex(int entity)
{
	for (int i = 0; i < sizeof(s_CrateEntRefs); i++)
	{
		if (EntRefToEntIndex(s_CrateEntRefs[i]) == entity)
		{
			return i;
		}
	}

	return -1;
}

void ZPOZomboeing_OnCratePickedUp(const char[] output, int caller, int activator, float delay)
{
	int index = ZPOZomboeing_FindCrateIndex(caller);

	if (index == -1)
	{
		return;
	}

	s_CrateTaken[index] = true;

	// Proceed if this was the tracked crate; ignore if a different one
	// (e.g. a real player) took it independently.
	ZPOZomboeing_MoveToDropzone(index);
}

void ZPOZomboeing_OnCrateDropped(const char[] output, int caller, int activator, float delay)
{
	int index = ZPOZomboeing_FindCrateIndex(caller);

	if (index == -1)
	{
		return;
	}

	s_CrateTaken[index] = false;

	// Re-search for this crate.
	ZPOZomboeing_PickNextCrate();
}

void ZPOZomboeing_MoveToDropzone(int crateIndex)
{
	int dropzone = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_teleport", "cb_four_delzone");

	if (dropzone == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_zomboeing: Failed to find cb_four_delzone!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID(s_SupplyCrateNames[crateIndex]);
	NavBotZPSModInterface.SetObjectiveItemUseTarget(dropzone);
	// 128.0 is the native's hard minimum.
	NavBotZPSModInterface.SetObjectiveDetectionRadius(128.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM);
}

void ZPOZomboeing_OnCrateDelivered(const char[] output, int caller, int activator, float delay)
{
	// OnHitMax (hooked separately) handles the finished case.
	ZPOZomboeing_PickNextCrate();
}

void ZPOZomboeing_OnAllSuppliesDelivered(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	s_CurrentPhase = ZPOZOMBOEING_PHASE_DONE;

	// TODO: Phase 1 - DeactivateLockdownInTower
}
