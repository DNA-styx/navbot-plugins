/**
 * zpo_zomboeing.sp
 *
 * NavBot ZPS objective support module for the zpo_zomboeing map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.10.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase: 0 - FindSupplies
 * Summary: 3 supply crates, tagged with unique itemids so FIND_ITEM can
 *   target one at a time. delzone_counter is the source of truth for
 *   progress, so real players grabbing crates independently is handled
 *   correctly. First search waits for human_start_trigger_once (bots
 *   reliably reach it) plus a buffer for the crates to reposition.
 * Bot action: FIND_ITEM for the next outstanding crate, then DROP_ITEM
 *   (via SetObjectiveItemUseTarget, per upstream c708eb8) at
 *   cb_four_delzone.
 * Confirmation: delzone_counter's OnHitMax ends the phase.
 *
 * Further phases (DeactivateLockdownInTower onward) not yet implemented.
 *
 */

static char s_SupplyCrateNames[3][8] = { "cb4", "cb2", "cb_one" };
static int s_CrateEntRefs[3];
static bool s_CrateTaken[3];

void ZPOZomboeing_OnAllSuppliesDelivered(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// TODO: Phase 1 - DeactivateLockdownInTower
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

	// Every crate has already been taken (and possibly delivered) -- nothing left to search for.
	NavBotZPSModInterface.ResetObjective();
}

void ZPOZomboeing_OnCrateDelivered(const char[] output, int caller, int activator, float delay)
{
	// delzone_counter's own OnHitMax (hooked separately) handles the finished case.
	// This just moves bots on to whichever crate is still outstanding.
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
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM);
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

	// Bots were already searching for whichever crate was outstanding -- if this is
	// the one they were pointed at, move on to the delivery step. If a different
	// crate was taken independently (e.g. by a real player), no action needed here.
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

	// Re-issues FIND_ITEM, whether this crate was the active target or picking back
	// up after having been exhausted (all others already taken).
	ZPOZomboeing_PickNextCrate();
}

void ZPOZomboeing_OnStartDelayExpired(Handle timer)
{
	ZPOZomboeing_PickNextCrate();
}

void ZPOZomboeing_OnHumanStartTriggerTouched(const char[] output, int caller, int activator, float delay)
{
	// H_Start()'s randomParcel chain needs to finish repositioning the
	// crates before FIND_ITEM starts searching for them.
	CreateTimer(4.0, ZPOZomboeing_OnStartDelayExpired, .flags = TIMER_FLAG_NO_MAPCHANGE);
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

void ZPOZomboeing_Think()
{

}

void ZPOZomboeing_Init()
{
	g_ThinkFunc = ZPOZomboeing_Think;

	ZPOZomboeing_TagAndHookSupplyCrates();

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
