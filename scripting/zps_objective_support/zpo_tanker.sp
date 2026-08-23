/**
 * zpo_tanker.sp
 *
 * NavBot ZPS objective support module for the zpo_tanker map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.17.5
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: Under review after file format change
 *
 * Issues: Bots can plant C4 but don't stand at it
 */

enum ZPOTankerPhase
{
	ZPOTankerPhase_None = 0,
	ZPOTankerPhase_FindAccessCode,
	ZPOTankerPhase_EnterCode,
	ZPOTankerPhase_HitHatchRelease,
	ZPOTankerPhase_EscapeToBoats
};

static bool s_bPCP1Destroyed;
static bool s_bPCP2Destroyed;
static bool s_bPCP3Destroyed;
static ZPOTankerPhase s_CurrentPhase;

void ZPOTanker_Init()
{
	g_ThinkFunc = ZPOTanker_Think;

	s_bPCP1Destroyed = false;
	s_bPCP2Destroyed = false;
	s_bPCP3Destroyed = false;
	s_CurrentPhase = ZPOTankerPhase_None;

	ZPOTanker_ActivateInvestigate();
}

void ZPOTanker_Think()
{
	switch (s_CurrentPhase)
	{
		case ZPOTankerPhase_FindAccessCode:
		{
			ZPOTanker_PollAccessCodeButton();
		}
		case ZPOTankerPhase_EnterCode:
		{
			ZPOTanker_PollKeypadButton();
		}
		case ZPOTankerPhase_HitHatchRelease:
		{
			ZPOTanker_PollHatchButton();
		}
		case ZPOTankerPhase_EscapeToBoats:
		{
			ZPOTanker_PollLifeboat1Launch();
		}
	}
}

/**
 * Phase: 0 - Investigate
 * Summary: Bots are sent to the room's entrance
 * Entity: trigger_once
 * Bot action: MOVETO
 * Confirmation: OnStartTouch.
 */
void ZPOTanker_ActivateInvestigate()
{
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

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOTanker_ActivateDestroyPCP, true);
}

/**
 * Phase: 1 - DestroyPCP
 * Summary: Three panels need destroying
 * Entity: func_breakable
 * Bot action: DESTROY_ENTITY
 * Confirmation: each breakable's OnBreak.
 */
void ZPOTanker_ActivateDestroyPCP(const char[] output, int caller, int activator, float delay)
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
		ZPOTanker_ActivatePlantC4();
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

/**
 * Phase: 2 - PlantC4
 * Summary: Bots press the button then move near it while arming runs.
 * Entity: func_button
 * Bot action: USE_BUTTON, then MOVETO.
 * Confirmation: PumpDoor1's OnOpen starts the phase; C4-Button's OnPressed
 *   advances to MOVETO.
 */
void ZPOTanker_ActivatePlantC4()
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

	s_CurrentPhase = ZPOTankerPhase_FindAccessCode;
}

void ZPOTanker_OnC4ButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	float goal[3];
	goal[0] = 4332.271973;
	goal[1] = -6540.309082;
	goal[2] = 304.031250;

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

/**
 * Phase: 3 - FindAccessCode
 * Summary: Access code button needs pressed.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: OnPressed
 */
void ZPOTanker_PollAccessCodeButton()
{
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

	s_CurrentPhase = ZPOTankerPhase_None;
	HookSingleEntityOutput(button, "OnPressed", ZPOTanker_OnAccessCodeButtonPressed, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

void ZPOTanker_OnAccessCodeButtonPressed(const char[] output, int caller, int activator, float delay)
{
	s_CurrentPhase = ZPOTankerPhase_EnterCode;
}

/**
 * Phase: 4 - EnterCode
 * Summary: Keypad Button needs pressed.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: OnPressed.
 */
void ZPOTanker_PollKeypadButton()
{
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

	s_CurrentPhase = ZPOTankerPhase_None;
	HookSingleEntityOutput(button, "OnPressed", ZPOTanker_OnKeypadButtonPressed, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

void ZPOTanker_OnKeypadButtonPressed(const char[] output, int caller, int activator, float delay)
{
	s_CurrentPhase = ZPOTankerPhase_HitHatchRelease;
}

/**
 * Phase: 5 - HitHatchRelease
 * Summary: HitHatchRelease button needs pressed.
 * Entity: func_button
 * Bot action: USE_BUTTON.
 * Confirmation: OnPressed.
 */
void ZPOTanker_PollHatchButton()
{
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

	s_CurrentPhase = ZPOTankerPhase_None;
	HookSingleEntityOutput(button, "OnPressed", ZPOTanker_OnHatchButtonPressed, true);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

void ZPOTanker_OnHatchButtonPressed(const char[] output, int caller, int activator, float delay)
{
	ZPOTanker_ActivateEscapeToBoats();
}

/**
 * Phase: 6 - EscapeToBoats
 * Summary: Press lifeboat button until engine starts
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: Button's name changing to "Zero".
 */
void ZPOTanker_ActivateEscapeToBoats()
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

	s_CurrentPhase = ZPOTankerPhase_EscapeToBoats;
}

void ZPOTanker_PollLifeboat1Launch()
{
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

	s_CurrentPhase = ZPOTankerPhase_None;

	ZPOTanker_ActivateReachIsland();
}

/**
 * Phase: 7 - ReachIsland
 * Summary: The bot is carried to the island automatically by the boat,
 *   then moves further inland.
 * Entity: trigger_multiple
 * Bot action: MOVETO once the island is reached.
 * Confirmation: OnStartTouch.
 */
void ZPOTanker_ActivateReachIsland()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "Island-Trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_tanker: Failed to find Island-Trigger!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOTanker_OnIslandReached, true);
}

void ZPOTanker_OnIslandReached(const char[] output, int caller, int activator, float delay)
{
	float goal[3];
	goal[0] = 6352.106445;
	goal[1] = 628.758606;
	goal[2] = 503.162079;

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}
