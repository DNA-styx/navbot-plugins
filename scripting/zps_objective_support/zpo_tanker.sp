/**
 * zpo_tanker.sp
 *
 * NavBot ZPS objective support module for the zpo_tanker map.
 * Intended to be #included by zps_objective_support.sp, alongside zpo_biotec.sp.
 *
 * Module version: 0.14.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase 1: "Investigate" objective.
 *   - MOVETO goal set to the Investigate-Trigger origin (trigger_once, hammer ID 8351).
 *   - On completion (Investigate-Trigger's OnStartTouch), directly hooks the three
 *     PCP-Breakable entities for Phase 2.
 *
 * Phase 2: "DestroyPCP" objective.
 *   - Uses NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY + SetObjectiveGenericTargetEntity, one
 *     breakable at a time (hammer IDs 7064, 332454, 332458). Order does not matter;
 *     each breakable's own OnBreak output re-targets the objective to the next
 *     surviving one. Once all three are destroyed, hooks PumpDoor1's OnOpen for
 *     Phase 3.
 *
 * Phase 3: "PlantC4" objective.
 *   - PumpDoor1 (looked up by name, classname prop_pumpdoor) is hooked
 *   - Two steps once PumpDoor1 opens: first a plain NAVBOT_ZPS_OBJECTIVE_USE_BUTTON
 *     on C4-Button, then on its OnPressed, a NAVBOT_ZPS_OBJECTIVE_MOVETO to a
 *     hardcoded position near it, bots have no way
 *     to hold position for the .as script's 21s arm duration, so successful
 *     arming may currently require a human.
 *   - No entity is hooked here for Phase 4: there's no output tied to a successful
 *     C4 arm (see Phase 4 notes below), so ZPOTanker_PollAccessCodeButton() listens
 *     for it independently instead.
 *
 * Phase 4: "FindAccessCode" objective.
 *   - AccessCode-Button does not exist until the .as script's FindAC() force-spawns it
 *     from a point_template ("-temp_ACB") roughly 5.55s after a successful C4 arm. There
 *     is no entity output tied to that spawn we can hook directly (the C4 arm success
 *     branch only fires input commands, not outputs), so ZPOTanker_Think() polls for the
 *     button's existence by name each tick instead of trying to detect arm success first.
 *   - AccessCode-Button (hammer ID 5038) also exists in the map from round start as a
 *     real, working func_button, never killed until pressed. The poll must skip this
 *     hammer ID and keep searching, or it latches onto the wrong instance immediately
 *     at round start and never re-checks. Keypad-Button (Phase 5) and Hatch-Button
 *     (Phase 6) have the same original-entity problem, at hammer IDs 205026 and 6922.
 *   - Once found, standard NAVBOT_ZPS_OBJECTIVE_USE_BUTTON + SetObjectiveUseButton is
 *     used, matching zpo_biotec.sp's pattern for its own named buttons.
 *
 * Phase 5: "EnterCode" objective.
 *   - Same shape as Phase 4: Keypad-Button doesn't exist until SpawnKeypadButton()
 *     force-spawns it (~2.25s after AccessCode-Button is pressed), so it's polled the
 *     same way, skipping the original entity at hammer ID 205026.
 *
 * Phase 6: "HitHatchRelease" objective.
 *   - Same shape again: Hatch-Button doesn't exist until SpawnHatchButton()
 *     force-spawns it (~40s after Keypad-Button is pressed), polled the same way,
 *     skipping the original entity at hammer ID 6922.
 *
 * Phase 7: "EscapeToBoats" objective.
 *   - Only lifeboat1_button (hammer ID 7783) is used.
 *   - Not a plain USE_BUTTON completion: OnPressed fires on every press attempt
 *     regardless of the .as script's lock state or its 45% success roll, so it
 *     can't tell a real launch apart from a failed one. On success, LifeBoat1()
 *     renames the button entity to "Zero" -- confirmed as success-only via two
 *     independent side effects in the same branch (this rename and a PlaySound
 *     call with no matching signal in the failure branch). ZPOTanker_Think()
 *     polls for that rename instead of hooking OnPressed at all.
 *   - Same known limitation as Phase 3: a failed press may end the bot's
 *     USE_BUTTON task without a retry.
 *
 * Phase 8: "ReachIsland" objective.
 *   - Island-Trigger (trigger_multiple, hammer ID 358625) is StartDisabled with no
 *     filtername at all so it's hooked directly the same "hook early, wait for enable + touch" way.
 *   - No new objective is set on reaching this phase: the bot is carried to the
 *     island by the lifeboat train's own movement, not by directed pathing.
 *   - This is the final implemented objective.
 */

static bool s_bPCP1Destroyed;
static bool s_bPCP2Destroyed;
static bool s_bPCP3Destroyed;

// doesn't exist at map start.
static bool s_bAccessCodeButtonHooked;
static bool s_bKeypadButtonHooked;
static bool s_bHatchButtonHooked;

// lifeboat1_button's OnPressed fires on every press attempt only 
// the "Zero" rename (SetEntityName in LifeBoat1()) confirms
// success -- polled here instead of hooked.
static bool s_bLifeboat1Launched;

void ZPOTanker_OnIslandReached(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// Phase 8 ends here. This is the final objective.
}

void ZPOTanker_PollLifeboat1Launch()
{

	if (s_bLifeboat1Launched)
	{
		return;
	}

	const int hammerid = 7783;
	int boat = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (boat == INVALID_ENT_REFERENCE)
	{
		return;
	}

	char name[32];
	GetEntPropString(boat, Prop_Data, "m_iName", name, sizeof(name));

	if (!StrEqual(name, "Zero"))
	{
		return;
	}

	s_bLifeboat1Launched = true;
	NavBotZPSModInterface.ResetObjective();

	// No new objective set here: the bot is carried to the island by the
	// lifeboat train's own movement, not by directed pathing. 
	const int islandHammerID = 358625;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_multiple", islandHammerID);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find Island-Trigger! Hammer ID: %i", islandHammerID);
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOTanker_OnIslandReached, true);
}

void ZPOTanker_OnHatchButtonPressed(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 7783;
	int boat = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (boat == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find lifeboat1_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(boat);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	// Note: a single press may fail the .as script's success roll (55% chance)
	// and the bot may not retry once its USE_BUTTON task completes -- 
	// Phase 7 completion is detected
	// independently by ZPOTanker_PollLifeboat1Launch() (see ZPOTanker_Think()).
}

void ZPOTanker_PollHatchButton()
{

	if (s_bHatchButtonHooked)
	{
		return;
	}

	// Hatch-Button (hammer ID 6922) exists in the map from round start and is
	// never killed until pressed -- it is not the copy the .as script force-spawns.
	// Skip it and keep searching for a different instance.
	const int originalHammerID = 6922;
	int button = INVALID_ENT_REFERENCE;

	while ((button = FindNamedEntityOfClassname(button, "func_button", "Hatch-Button")) != INVALID_ENT_REFERENCE)
	{
		if (GetEntProp(button, Prop_Data, "m_iHammerID") != originalHammerID)
		{
			break;
		}
	}

	if (button == INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_bHatchButtonHooked = true;
	HookSingleEntityOutput(button, "OnPressed", ZPOTanker_OnHatchButtonPressed, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

void ZPOTanker_OnKeypadButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// Phase 5 ends here. Phase 6 activation is handled independently by
	// ZPOTanker_PollHatchButton() (see ZPOTanker_Think()).
}

void ZPOTanker_PollKeypadButton()
{

	if (s_bKeypadButtonHooked)
	{
		return;
	}

	// Keypad-Button (hammer ID 205026) exists in the map from round start and is
	// never killed until pressed -- it is not the copy the .as script force-spawns.
	// Skip it and keep searching for a different instance.
	const int originalHammerID = 205026;
	int button = INVALID_ENT_REFERENCE;

	while ((button = FindNamedEntityOfClassname(button, "func_button", "Keypad-Button")) != INVALID_ENT_REFERENCE)
	{
		if (GetEntProp(button, Prop_Data, "m_iHammerID") != originalHammerID)
		{
			break;
		}
	}

	if (button == INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_bKeypadButtonHooked = true;
	HookSingleEntityOutput(button, "OnPressed", ZPOTanker_OnKeypadButtonPressed, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

void ZPOTanker_OnAccessCodeButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// Phase 4 ends here. Phase 5 activation is handled independently by
	// ZPOTanker_PollKeypadButton() (see ZPOTanker_Think()).
}

void ZPOTanker_PollAccessCodeButton()
{

	if (s_bAccessCodeButtonHooked)
	{
		return;
	}

	// AccessCode-Button (hammer ID 5038) exists in the map from round start and is
	// never killed until pressed -- it is not the copy FindAC() force-spawns. Skip
	// it and keep searching for a different instance.
	const int originalHammerID = 5038;
	int button = INVALID_ENT_REFERENCE;

	while ((button = FindNamedEntityOfClassname(button, "func_button", "AccessCode-Button")) != INVALID_ENT_REFERENCE)
	{
		if (GetEntProp(button, Prop_Data, "m_iHammerID") != originalHammerID)
		{
			break;
		}
	}

	if (button == INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_bAccessCodeButtonHooked = true;
	HookSingleEntityOutput(button, "OnPressed", ZPOTanker_OnAccessCodeButtonPressed, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

void ZPOTanker_OnC4ButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// Successful arming currently requires a human.
	float goal[3];
	goal[0] = 4332.271973;
	goal[1] = -6540.309082;
	goal[2] = 304.031250;

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	// No entity to hook here for the next objective using ZPOTanker_PollAccessCodeButton
}

void ZPOTanker_OnPumpDoor1Open(const char[] output, int caller, int activator, float delay)
{
	const int hammerid = 350317;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find C4-Button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOTanker_OnC4ButtonPressed, true);
}

void ZPOTanker_TargetNextPCP()
{
	int entity = INVALID_ENT_REFERENCE;

	if (!s_bPCP1Destroyed)
	{
		entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", 7064);
	}
	else if (!s_bPCP2Destroyed)
	{
		entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", 332454);
	}
	else if (!s_bPCP3Destroyed)
	{
		entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", 332458);
	}

	if (entity == INVALID_ENT_REFERENCE)
	{
		// All three destroyed then PumpDoor1 opens.
		int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "prop_pumpdoor", "PumpDoor1");

		if (door == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_tanker: Failed to find PumpDoor1!");
			return;
		}

		NavBotZPSModInterface.ResetObjective();
		HookSingleEntityOutput(door, "OnOpen", ZPOTanker_OnPumpDoor1Open, true);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
}

void ZPOTanker_OnPCP1Break(const char[] output, int caller, int activator, float delay)
{
	s_bPCP1Destroyed = true;
	ZPOTanker_TargetNextPCP();
}

void ZPOTanker_OnPCP2Break(const char[] output, int caller, int activator, float delay)
{
	s_bPCP2Destroyed = true;
	ZPOTanker_TargetNextPCP();
}

void ZPOTanker_OnPCP3Break(const char[] output, int caller, int activator, float delay)
{
	s_bPCP3Destroyed = true;
	ZPOTanker_TargetNextPCP();
}

void ZPOTanker_OnInvestigateTriggered(const char[] output, int caller, int activator, float delay)
{

	const int hammerid1 = 7064;
	const int hammerid2 = 332454;
	const int hammerid3 = 332458;

	int breakable1 = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", hammerid1);
	int breakable2 = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", hammerid2);
	int breakable3 = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", hammerid3);

	if (breakable1 == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find PCP-Breakable! Hammer ID: %i", hammerid1);
	}
	else
	{
		HookSingleEntityOutput(breakable1, "OnBreak", ZPOTanker_OnPCP1Break, true);
	}

	if (breakable2 == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find PCP-Breakable! Hammer ID: %i", hammerid2);
	}
	else
	{
		HookSingleEntityOutput(breakable2, "OnBreak", ZPOTanker_OnPCP2Break, true);
	}

	if (breakable3 == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find PCP-Breakable! Hammer ID: %i", hammerid3);
	}
	else
	{
		HookSingleEntityOutput(breakable3, "OnBreak", ZPOTanker_OnPCP3Break, true);
	}

	ZPOTanker_TargetNextPCP();
}

void ZPOTanker_ActivateInvestigate()
{
	NavBotZPSModInterface.ResetObjective();

	// MOVETO takes a raw world position, not an entity
	float goal[3];
	goal[0] = 4124.01;
	goal[1] = -5782.0;
	goal[2] = 414.0;

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	const int hammerid = 8351;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", hammerid);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find Investigate-Trigger! Hammer ID: %i", hammerid);
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOTanker_OnInvestigateTriggered, true);
}

void ZPOTanker_Think()
{
	ZPOTanker_PollAccessCodeButton();
	ZPOTanker_PollKeypadButton();
	ZPOTanker_PollHatchButton();
	ZPOTanker_PollLifeboat1Launch();
}

void ZPOTanker_Init()
{
	g_ThinkFunc = ZPOTanker_Think;

	// For tracking entities that do not spawn on map load.
	s_bPCP1Destroyed = false;
	s_bPCP2Destroyed = false;
	s_bPCP3Destroyed = false;
	s_bAccessCodeButtonHooked = false;
	s_bKeypadButtonHooked = false;
	s_bHatchButtonHooked = false;
	s_bLifeboat1Launched = false;

	ZPOTanker_ActivateInvestigate();
}
