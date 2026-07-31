/**
 * zpo_zomboeing.sp
 *
 * NavBot ZPS objective support module for the zpo_zomboeing map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.3.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase: 0 - FindSupplies
 * Summary: Three supply crates are scattered near the garage delivery
 *   point. Pickup requires the USE key, not touch, so the crates carry no
 *   itemid keyvalue in the compiled map -- Init() tags each one with its
 *   own unique itemid (its targetname) so FIND_ITEM can match them
 *   without ambiguity between the three. Bots are cycled through each
 *   crate in turn, then DROP_ITEM carries it to the delivery trigger.
 * Entity: cb4 / cb2 / cb_one (item_deliver, hammer IDs 7247950 / 7247987 /
 *   7247997) / cb_four_delzone (trigger_teleport, hammer ID 7157584) /
 *   delzone_counter (math_counter, hammer ID 7157748, max 3)
 * Bot action: FIND_ITEM for each crate's own itemid in turn, then
 *   DROP_ITEM at cb_four_delzone to deliver it.
 * Confirmation: each crate's OnItemTaken output, then cb_four_delzone's
 *   OnStartTouch output, repeated for all 3 crates.
 *
 * Further phases (DeactivateLockdownInTower onward) not yet implemented.
 *
 */

static char s_SupplyCrateNames[3][8] = { "cb4", "cb2", "cb_one" };
static int s_CrateIndex;

void ZPOZomboeing_OnAllSuppliesDelivered()
{
	NavBotZPSModInterface.ResetObjective();

	// TODO: Phase 1 - DeactivateLockdownInTower
}

void ZPOZomboeing_OnCrateDelivered(const char[] output, int caller, int activator, float delay)
{
	s_CrateIndex++;

	if (s_CrateIndex >= sizeof(s_SupplyCrateNames))
	{
		ZPOZomboeing_OnAllSuppliesDelivered();
		return;
	}

	ZPOZomboeing_MoveToNextCrate();
}

void ZPOZomboeing_MoveToDropzone()
{
	int dropzone = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_teleport", "cb_four_delzone");

	if (dropzone == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_zomboeing: Failed to find cb_four_delzone!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID(s_SupplyCrateNames[s_CrateIndex]);
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(dropzone);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM);

	HookSingleEntityOutput(dropzone, "OnStartTouch", ZPOZomboeing_OnCrateDelivered, true);
}

void ZPOZomboeing_OnCratePickedUp(const char[] output, int caller, int activator, float delay)
{
	ZPOZomboeing_MoveToDropzone();
}

void ZPOZomboeing_MoveToNextCrate()
{
	int crate = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", s_SupplyCrateNames[s_CrateIndex]);

	if (crate == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_zomboeing: Failed to find supply crate! Name: %s", s_SupplyCrateNames[s_CrateIndex]);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID(s_SupplyCrateNames[s_CrateIndex]);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);

	HookSingleEntityOutput(crate, "OnItemTaken", ZPOZomboeing_OnCratePickedUp, true);
}

void ZPOZomboeing_TagSupplyCrates()
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
	}
}

void ZPOZomboeing_Think()
{

}

void ZPOZomboeing_Init()
{
	g_ThinkFunc = ZPOZomboeing_Think;

	s_CrateIndex = 0;

	ZPOZomboeing_TagSupplyCrates();
	ZPOZomboeing_MoveToNextCrate();
}
