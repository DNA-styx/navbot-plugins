/**
 * zpo_tanker.sp
 *
 * NavBot ZPS objective support module for the zpo_tanker map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.16.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase: 1 - Investigate
 * Summary: Bots are sent to the doorway leading into the objective room.
 *   Touching the trigger there kicks off the objective chain.
 * Entity: Investigate-Trigger (trigger_once, hammer ID 8351)
 * Bot action: MOVETO to the trigger's origin.
 * Confirmation: Investigate-Trigger's OnStartTouch.
 *
 * Phase: 2 - DestroyPCP
 * Summary: Three panels need destroying. Walking to any of them passes
 *   through the room's only doorway, which is what the .as script itself
 *   uses to arm their health, so no separate handling is needed for that.
 * Entity: PCP-Breakable (func_breakable, hammer IDs 7064 / 332454 / 332458)
 * Bot action: DESTROY_ENTITY, targeting one breakable at a time.
 * Confirmation: each breakable's OnBreak. The last one destroyed hooks
 *   PumpDoor1 for Phase 3.
 *
 * Phase: 3 - PlantC4
 * Summary: PumpDoor1 opening is the .as script's own signal that arming is
 *   about to become available, ~1s before it enables the touch trigger.
 *   Bots are sent to press the button, then held near it while arming
 *   runs -- this doesn't cover the bot walking off mid-arm. PumpDoor1 is
 *   found by targetname across all entities, not by classname: a
 *   logic_auto entity is meant to swap it from prop_door_rotating to a
 *   ZPS-custom prop_pumpdoor at round start, but per DNA.styx that swap
 *   isn't reliable, and both classnames have failed to match live.
 * Entity: PumpDoor1 (classname unreliable -- see above, hammer ID 181948) /
 *   C4-Button (func_button, hammer ID 350317)
 * Bot action: USE_BUTTON on C4-Button, then MOVETO to a fixed point near
 *   it once pressed.
 * Confirmation: PumpDoor1's OnOpen starts the phase; C4-Button's OnPressed
 *   advances to the MOVETO step. No output exists for arming success
 *   itself, so Phase 4 detection is handled independently.
 *
 * Phase: 4 - FindAccessCode
 * Summary: The real button is force-spawned partway through the round. A
 *   duplicate with the same name already exists in the map from round
 *   start and must be skipped, or the search latches onto it permanently.
 * Entity: AccessCode-Button (func_button, hammer ID 5038 for the
 *   pre-existing duplicate to skip)
 * Bot action: USE_BUTTON once the real copy is found.
 * Confirmation: polled by name each tick, skipping hammer ID 5038; then
 *   OnPressed on the real copy.
 *
 * Phase: 5 - EnterCode
 * Summary: Same shape as Phase 4 -- force-spawned after AccessCode-Button
 *   is pressed, with the same pre-existing duplicate to skip.
 * Entity: Keypad-Button (func_button, hammer ID 205026 for the duplicate
 *   to skip)
 * Bot action: USE_BUTTON once found.
 * Confirmation: polled by name, skipping hammer ID 205026; then OnPressed.
 *
 * Phase: 6 - HitHatchRelease
 * Summary: Same shape again -- force-spawned after Keypad-Button is
 *   pressed, same duplicate-skip requirement.
 * Entity: Hatch-Button (func_button, hammer ID 6922 for the duplicate to
 *   skip)
 * Bot action: USE_BUTTON once found.
 * Confirmation: polled by name, skipping hammer ID 6922; then OnPressed.
 *
 * Phase: 7 - EscapeToBoats
 * Summary: Pressing the button doesn't guarantee the boat launches -- the
 *   .as script rolls a chance and can reject the attempt, so a press alone
 *   isn't proof of success. A real launch renames the button entity to
 *   "Zero".
 * Entity: lifeboat1_button (func_button, hammer ID 7783)
 * Bot action: USE_BUTTON on lifeboat1_button.
 * Confirmation: polled each tick for the button's name changing to "Zero",
 *   not OnPressed.
 *
 * Phase: 8 - ReachIsland
 * Summary: Once the boat launches, the bot is carried to the island
 *   automatically by the boat's own movement. No bot action is needed to
 *   get there.
 * Entity: Island-Trigger (trigger_multiple, hammer ID 358625)
 * Bot action: none -- the objective is reset with nothing new set.
 * Confirmation: Island-Trigger's OnStartTouch.
 *
 * Further phases (none -- ReachIsland is the last objective in the .as
 * script's own chain) not yet implemented.
 *
 */

static bool s_bPCP1Destroyed;
static bool s_bPCP2Destroyed;
static bool s_bPCP3Destroyed;

// AccessCode-Button doesn't exist at map start.
static bool s_bAccessCodeButtonHooked;

// Keypad-Button doesn't exist at map start.
static bool s_bKeypadButtonHooked;

// Hatch-Button doesn't exist at map start.
static bool s_bHatchButtonHooked;

// lifeboat1_button's OnPressed fires on every press attempt regardless of the
// .as script's lock state or its success roll, so it can't be used to detect a
// genuine launch. Only the "Zero" rename (SetEntityName in LifeBoat1()) confirms
// success -- polled here instead of hooked.
static bool s_bLifeboat1Launched;

void ZPOTanker_OnIslandReached(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	// Phase 8 ends here. This is the final objective in the .as script's chain.
}

void ZPOTanker_PollLifeboat1Launch()
{

	if (s_bLifeboat1Launched)
	{
		return;
	}

	int boat = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "lifeboat1_button");

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
	// lifeboat train's own movement, not by directed pathing. Same known
	// limitation as Phases 3/7 -- NavBot's default combat behavior on a nearby
	// threat could still pull a bot off the moving boat.
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "Island-Trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find Island-Trigger!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOTanker_OnIslandReached, true);
}

void ZPOTanker_OnHatchButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int boat = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "lifeboat1_button");

	if (boat == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find lifeboat1_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(boat);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	// Note: a single press may fail the .as script's success roll (55% chance)
	// and the bot may not retry once its USE_BUTTON task completes -- same known
	// limitation as Phase 3's C4 arming. Phase 7 completion is detected
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
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "C4-Button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find C4-Button!");
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
		// All three destroyed. PumpDoor1 opens via the .as script's OpenLower(),
		// ~1s before C4-ArmTrigger is enabled -- hook that instead of the trigger.
		// Classname search unreliable here: a logic_auto entity fires OnMapSpawn
		// at round start and uses AddOutput to swap PumpDoor1/PumpDoor2's
		// classname from prop_door_rotating to a ZPS-custom prop_pumpdoor (same
		// pattern used for DoorSeal1-5 -> prop_doorseal and TowerDoor1-2 ->
		// prop_towerdoor), but per DNA.styx this AddOutput swap isn't guaranteed
		// reliable, and both classnames have already failed to match on the live
		// server. Searching by targetname only, across every entity, sidesteps
		// classname entirely.
		int door = INVALID_ENT_REFERENCE;
		int maxEntities = GetMaxEntities();

		for (int i = 1; i <= maxEntities; i++)
		{
			if (!IsValidEntity(i))
			{
				continue;
			}

			char name[32];
			GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));

			if (StrEqual(name, "PumpDoor1"))
			{
				door = i;
				break;
			}
		}

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

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "Investigate-Trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find Investigate-Trigger!");
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
