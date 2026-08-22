
static bool s_FoundKeys;
static bool s_LabChamberPressed;
static bool s_LabDoorHacked;
static int s_LabDoorTrigger;

static float ZPOBiotec_GetDetectionRadius()
{
	return g_DetectionRadius * 2.0;
}

static void ZPOBiotec_OnAntiVirusTaken(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	float helipad[3] = { -2305.0, -1648.0, 256.0 };
	NavBotZPSModInterface.SetObjectiveMoveGoal(helipad);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOBiotec_OnAntiVirusKeypadPressed(const char[] output, int caller, int activator, float delay)
{
	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "anti-virus");

	if (entity != INVALID_ENT_REFERENCE)
	{
		// TO-DO
		HookSingleEntityOutput(entity, "OnItemTaken", ZPOBiotec_OnAntiVirusTaken, true);
	}
}

static void ZPOBiotec_OnLabArmoryUnlocked(const char[] output, int caller, int activator, float delay)
{
	if (s_LabChamberPressed)
	{
		return;
	}

	// chamber button
	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "buhl");

	if (entity != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(entity);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	}
}

static void ZPOBiotec_OnLabChamberKeypadPressed(const char[] output, int caller, int activator, float delay)
{
	s_LabChamberPressed = true;
	NavBotZPSModInterface.ResetObjective();

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "tad");

	if (trigger != INVALID_ENT_REFERENCE)
	{
		s_LabDoorTrigger = EntIndexToEntRef(trigger);
	}
}

static void ZPOBiotec_OnLabKeypadPressed(const char[] output, int caller, int activator, float delay)
{
	// lab security room, optional but contains supplies
	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_useable", "lbdt2");

	if (entity != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveItemUseTarget(entity);
		NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
		// Since the keys were already found at least once, allow bots to scan the entire map.
		NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
		HookSingleEntityOutput(entity, "OnUsed", ZPOBiotec_OnLabArmoryUnlocked, true);
	}

	// chamber button
	entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "buhl");

	if (entity != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(entity, "OnPressed", ZPOBiotec_OnLabChamberKeypadPressed, true);
	}
}

static void ZPOBiotec_OnLockdownDisabled(const char[] output, int caller, int activator, float delay)
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

static void ZPOBiotec_OnSecurityRoomKeyboardPressed(const char[] output, int caller, int activator, float delay)
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

static void ZPOBiotec_OnSecurityRoomKeypadPressed(const char[] output, int caller, int activator, float delay)
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

static void ZPOBiotec_OnPowerSwitchPressed(const char[] output, int caller, int activator, float delay)
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

static void ZPOBiotec_OnBasementFenceDoorOpen(const char[] output, int caller, int activator, float delay)
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

static void ZPOBiotec_OnBasementDoorOpen(const char[] output, int caller, int activator, float delay)
{
	// hook the door, it's more reliable since the padlock can be unlocked or broken with melee attacks.
	// the door also cannot be closed with +USE
	int fencedoor = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "dp");

	if (fencedoor == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_biotec: Failed to find the basement fence gate door!");
		return;
	}

	const int hammerid = 1515789;
	int padlock = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_useable", hammerid);

	if (padlock == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_biotec: Failed to find the basement padlock trigger_useable! Hammer ID: %i", hammerid);
		return;
	}

	HookSingleEntityOutput(fencedoor, "OnOpen", ZPOBiotec_OnBasementFenceDoorOpen, true);
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(padlock);
	// Since the keys were already found at least once, allow bots to scan the entire map.
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
}

static void ZPOBiotec_OnPickupKeys(const char[] output, int caller, int activator, float delay)
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

static void ZPOBiotec_CheckLabDoorHacked()
{
	if (s_LabChamberPressed && !s_LabDoorHacked)
	{
		int trigger = EntRefToEntIndex(s_LabDoorTrigger);

		if (trigger != INVALID_ENT_REFERENCE)
		{
			bool disabled = GetEntProp(trigger, Prop_Data, "m_bDisabled") != 0;

			if (!disabled)
			{
				LogDebugMessage("Biotec: Lab door trigger enabled, hack completed!");
				s_LabDoorHacked = true;
				s_LabDoorTrigger = INVALID_ENT_REFERENCE;

				NavBotZPSModInterface.ResetObjective();

				const int hammerid = 380672;
				int keypad = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

				if (keypad != INVALID_ENT_REFERENCE)
				{
					NavBotZPSModInterface.SetObjectiveUseButton(keypad);
					NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
					HookSingleEntityOutput(keypad, "OnPressed", ZPOBiotec_OnAntiVirusKeypadPressed, true);
				}
			}
		}
	}
}

void ZPOBiotec_Think()
{
	ZPOBiotec_CheckLabDoorHacked();
}

void ZPOBiotec_Init()
{
	g_ThinkFunc = ZPOBiotec_Think;
	s_FoundKeys = false;
	s_LabChamberPressed = false;
	s_LabDoorHacked = false;

	NavBotZPSModInterface.SetObjectiveItemSearchID("keys");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(ZPOBiotec_GetDetectionRadius());
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);

	HookNamedOutputOfAllEntities("item_deliver", "OnItemTaken", ZPOBiotec_OnPickupKeys, true);
}