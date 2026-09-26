/**
 * zpo_tanker.sp
 *
 * NavBot ZPS objective support module for the zpo_tanker map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.31.3
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: {good / usable / partially complete / unusable}
 *
 * Issues: PumpDoor1 (Phase 2) is sometimes not found by ActivatePlantC4,
 *   cause unconfirmed. GuardC4 (Phase 3) has no way to hold a bot in
 *   place, so a human is required to complete C4 arming.
 */

static bool s_bPCP1Destroyed;
static bool s_bPCP2Destroyed;
static bool s_bPCP3Destroyed;
static bool s_bAccessCodeButtonHooked;
static bool s_bKeypadButtonHooked;
static bool s_bHatchButtonHooked;
static bool s_bLifeboat1Launched;
static bool s_bZombiesKilled;
static int s_iRoundSerial;

void ZPOTanker_Init()
{
	g_ThinkFunc = ZPOTanker_Think;

	s_bPCP1Destroyed = false;
	s_bPCP2Destroyed = false;
	s_bPCP3Destroyed = false;
	s_bAccessCodeButtonHooked = false;
	s_bKeypadButtonHooked = false;
	s_bHatchButtonHooked = false;
	s_bLifeboat1Launched = false;
	s_bZombiesKilled = false;
	s_iRoundSerial++;

	ZPOTanker_HookHintKill();
	ZPOTanker_ActivateInvestigate();
}

void ZPOTanker_Think()
{
	ZPOTanker_PollAccessCodeButton();
	ZPOTanker_PollKeypadButton();
	ZPOTanker_PollHatchButton();
	ZPOTanker_PollLifeboat1Launch();
}

/**
 * Phase: 0 - Investigate
 * Summary: Bots are sent to the room's entrance
 * Entity: trigger_once
 * Bot action: MOVETO
 * Confirmation: OnStartTouch.
 */
static void ZPOTanker_ActivateInvestigate()
{
	float goal[3] = { 4124.0, -5782.0, 414.0 };

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "Investigate-Trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find Investigate-Trigger!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOTanker_ActivateDestroyPCP, true);
}

/**
 * Phase: 1 - DestroyPCP
 * Summary: Three panels need destroying
 * Entity: func_breakable
 * Bot action: DESTROY_ENTITY
 * Confirmation: each breakable's OnBreak.
 */
static const int PCP_HAMMERID_1 = 7064;
static const int PCP_HAMMERID_2 = 332454;
static const int PCP_HAMMERID_3 = 332458;

static void ZPOTanker_ActivateDestroyPCP(const char[] output, int caller, int activator, float delay)
{
	int breakable1 = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", PCP_HAMMERID_1);
	int breakable2 = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", PCP_HAMMERID_2);
	int breakable3 = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", PCP_HAMMERID_3);

	if (breakable1 == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find PCP-Breakable! Hammer ID: %i", PCP_HAMMERID_1);
	}
	else
	{
		HookSingleEntityOutput(breakable1, "OnBreak", ZPOTanker_OnPCPBreak, true);
	}

	if (breakable2 == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find PCP-Breakable! Hammer ID: %i", PCP_HAMMERID_2);
	}
	else
	{
		HookSingleEntityOutput(breakable2, "OnBreak", ZPOTanker_OnPCPBreak, true);
	}

	if (breakable3 == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find PCP-Breakable! Hammer ID: %i", PCP_HAMMERID_3);
	}
	else
	{
		HookSingleEntityOutput(breakable3, "OnBreak", ZPOTanker_OnPCPBreak, true);
	}

	ZPOTanker_TargetNextPCP();
}

static void ZPOTanker_TargetNextPCP()
{
	int entity = INVALID_ENT_REFERENCE;

	if (!s_bPCP1Destroyed)
	{
		entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", PCP_HAMMERID_1);
	}
	else if (!s_bPCP2Destroyed)
	{
		entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", PCP_HAMMERID_2);
	}
	else if (!s_bPCP3Destroyed)
	{
		entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", PCP_HAMMERID_3);
	}

	if (entity == INVALID_ENT_REFERENCE)
	{
		ZPOTanker_ActivatePlantC4();
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
}

static void ZPOTanker_OnPCPBreak(const char[] output, int caller, int activator, float delay)
{
	int hammerid = GetEntProp(caller, Prop_Data, "m_iHammerID");

	if (hammerid == PCP_HAMMERID_1)
	{
		s_bPCP1Destroyed = true;
	}
	else if (hammerid == PCP_HAMMERID_2)
	{
		s_bPCP2Destroyed = true;
	}
	else if (hammerid == PCP_HAMMERID_3)
	{
		s_bPCP3Destroyed = true;
	}

	ZPOTanker_TargetNextPCP();
}

/**
 * Phase: 2 - PlantC4
 * Summary: Bots press the button once the pump door opens.
 * Entity: func_button
 * Bot action: USE_BUTTON.
 * Confirmation: PumpDoor1's OnOpen starts the phase; C4-Button's OnPressed
 *   completes it.
 */
static void ZPOTanker_ActivatePlantC4()
{
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

	HookSingleEntityOutput(door, "OnOpen", ZPOTanker_OnPumpDoor1Open, true);
}

static void ZPOTanker_OnPumpDoor1Open(const char[] output, int caller, int activator, float delay)
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

/**
 * Phase: 3 - GuardC4
 * Summary: Bots hold a position near the button while arming runs.
 * Entity: n/a
 * Bot action: MOVETO
 * Confirmation: n/a
 */
static void ZPOTanker_OnC4ButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	float goal[3] = { 4332.3, -6540.3, 304.0 };

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 4 - FindAccessCode
 * Summary: Access code button needs pressed.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: found by name each tick.
 */
static void ZPOTanker_PollAccessCodeButton()
{
	if (s_bAccessCodeButtonHooked)
	{
		return;
	}

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

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 5 - EnterCode
 * Summary: Keypad Button needs pressed.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: found by name each tick.
 */
static void ZPOTanker_PollKeypadButton()
{
	if (s_bKeypadButtonHooked)
	{
		return;
	}

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

/**
 * Phase: 6 - Guard the Hatches
 * Summary: Bots hold a position near the hatches.
 * Entity: n/a
 * Bot action: MOVETO
 * Confirmation: n/a
 */
static void ZPOTanker_OnKeypadButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	float goal[3] = { 4881.6, -5851.5, 424.0 };

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 7 - HitHatchRelease
 * Summary: HitHatchRelease button needs pressed.
 * Entity: func_button
 * Bot action: USE_BUTTON.
 * Confirmation: OnPressed.
 */
static void ZPOTanker_PollHatchButton()
{
	if (s_bHatchButtonHooked)
	{
		return;
	}

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

static void ZPOTanker_OnHatchButtonPressed(const char[] output, int caller, int activator, float delay)
{
	ZPOTanker_ActivateEscapeToBoats();
}

/**
 * Phase: 8 - EscapeToBoats
 * Summary: Press lifeboat button until engine starts. Shortly after the
 *   first survivor touches Hint-Trigger, all zombies are killed so they
 *   respawn at the final deck spawns.
 * Entity: func_button / trigger_once
 * Bot action: USE_BUTTON
 * Confirmation: Button's name changing to "Zero".
 */
static void ZPOTanker_ActivateEscapeToBoats()
{
	int boat = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "lifeboat1_button");

	if (boat == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find lifeboat1_button!");
	}
	else
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(boat);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	}
}

// Hooked from Init() so the kill does not depend on Hatch-Button's OnPressed.
// The .as script switches to ZS-LowerDeck-Final / ZS-UppedDeck-Final 0.5s after
// the first survivor touches Hint-Trigger; the kill is delayed until after that.
static void ZPOTanker_HookHintKill()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "Hint-Trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find Hint-Trigger!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOTanker_OnHintTriggered, true);
}

static void ZPOTanker_OnHintTriggered(const char[] output, int caller, int activator, float delay)
{
	CreateTimer(2.0, ZPOTanker_Timer_KillZombies, s_iRoundSerial, TIMER_FLAG_NO_MAPCHANGE);
}

static Action ZPOTanker_Timer_KillZombies(Handle timer, int roundSerial)
{
	// Ignore a timer left over from a previous round.
	if (roundSerial != s_iRoundSerial || s_bZombiesKilled)
	{
		return Plugin_Stop;
	}

	s_bZombiesKilled = true;

	// Silence the per-player slay announcements, then restore the setting.
	ConVar showActivity = FindConVar("sm_show_activity");
	int oldActivity = (showActivity != null) ? showActivity.IntValue : 13;

	ServerCommand("sm_show_activity 0");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}

		if (GetClientTeam(i) != 3)
		{
			continue;
		}

		ServerCommand("sm_slay #%d", GetClientUserId(i));
	}

	ServerCommand("sm_show_activity %d", oldActivity);

	return Plugin_Stop;
}

static void ZPOTanker_PollLifeboat1Launch()
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

	ZPOTanker_ActivateReachIsland();
}

/**
 * Phase: 9 - ReachIsland
 * Summary: The bot is carried to the island automatically by the boat,
 *   then moves further inland.
 * Entity: trigger_multiple
 * Bot action: MOVETO once the island is reached.
 * Confirmation: OnStartTouch.
 */
static void ZPOTanker_ActivateReachIsland()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "Island-Trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find Island-Trigger!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOTanker_OnIslandReached, true);
}

static void ZPOTanker_OnIslandReached(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	float goal[3] = { 6352.1, 628.8, 503.2 };

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}
