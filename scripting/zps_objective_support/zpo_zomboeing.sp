/**
 * zpo_zomboeing.sp
 *
 * NavBot ZPS objective support module for the zpo_zomboeing map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.14.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: Unusable
 *
 * Issues: only two crates spawn when bots play. Player counting trigger?
 *  
 */

static char s_SupplyCrateNames[3][8] = { "cb4", "cb2", "cb_one" };
static int s_CrateEntRefs[3];
static bool s_CrateTaken[3];

void ZPOZomboeing_Init()
{
	g_ThinkFunc = ZPOZomboeing_Think;

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
 * Summary: Bots search for and deliver 3 supply crates one at a time.
 * Entity: item_deliver / trigger_teleport / math_counter / trigger_once
 * Bot action: FIND_ITEM, then DROP_ITEM
 * Confirmation: all crates delivered
 */
void ZPOZomboeing_OnHumanStartTriggerTouched(const char[] output, int caller, int activator, float delay)
{
	// Buffer for the randomParcel reposition.
	CreateTimer(4.0, ZPOZomboeing_OnStartDelayExpired, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

void ZPOZomboeing_OnStartDelayExpired(Handle timer)
{
	// Re-hook after repositioning.
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

	// TODO: Phase 1 - DeactivateLockdownInTower
}
