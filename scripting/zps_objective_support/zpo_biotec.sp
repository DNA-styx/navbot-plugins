
static s_FoundKeys;

float ZPOBiotec_GetDetectionRadius()
{
	return g_DetectionRadius * 2.0;
}

void ZPOBiotec_OnLabChamberKeypadPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
}

void ZPOBiotec_OnLabKeypadPressed(const char[] output, int caller, int activator, float delay)
{
	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "buhl");

	if (entity != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(entity);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		HookSingleEntityOutput(entity, "OnPressed", ZPOBiotec_OnLabChamberKeypadPressed, true);
	}
}

void ZPOBiotec_OnLockdownDisabled(const char[] output, int caller, int activator, float delay)
{
	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "bul");

	if (entity != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(entity);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		HookSingleEntityOutput(entity, "OnPressed", ZPOBiotec_OnLabKeypadPressed, true);
	}
}

void ZPOBiotec_OnSecurityRoomKeyboardPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	float goal[3];
	// Note: bots won't stay on the trigger, they will defend the room, currently a human is required to complete this objective.
	goal[0] = 1263.0;
	goal[1] = 2400.0;
	goal[2] = 65.0;
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "dld");

	if (entity != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(entity, "OnUser1", ZPOBiotec_OnLockdownDisabled, true);
	}
}

void ZPOBiotec_OnSecurityRoomKeypadPressed(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "bh");

	if (button == INVALID_ENT_REFERENCE)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOBiotec_OnSecurityRoomKeyboardPressed, true);
}

void ZPOBiotec_OnPowerSwitchPressed(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 98827;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_biotec: Failed to find func_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOBiotec_OnSecurityRoomKeypadPressed, true);
}

void ZPOBiotec_OnBasementPadlockOpen(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 63483;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_biotec: Failed to find the basement power switch func_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOBiotec_OnPowerSwitchPressed, true);
}

void ZPOBiotec_OnBasementDoorOpen(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 1515789;
	int padlock = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_useable", hammerid);

	if (padlock == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_biotec: Failed to find the basement padlock trigger_useable! Hammer ID: %i", hammerid);
		return;
	}

	HookSingleEntityOutput(padlock, "OnUsed", ZPOBiotec_OnBasementPadlockOpen, true);
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(padlock);
	// Since the keys were already found at least once, allow bots to scan the entire map.
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
}

void ZPOBiotec_OnPickupKeys(const char[] output, int caller, int activator, float delay)
{
	if (s_FoundKeys) { return; }

	// basement door
	int target = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "dbt");

	if (target != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(target, "OnUsed", ZPOBiotec_OnBasementDoorOpen, true);
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
		NavBotZPSModInterface.SetObjectiveItemUseTarget(target);
		NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
	}
}

void ZPOBiotec_Think()
{

}

void ZPOBiotec_Init()
{
	g_ThinkFunc = ZPOBiotec_Think;
	s_FoundKeys = false;

	NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(ZPOBiotec_GetDetectionRadius());
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);

	HookNamedOutputOfAllEntities("item_deliver", "OnItemTaken", ZPOBiotec_OnPickupKeys, true);
}