/**
 * zpo_shreddingfield.sp
 *
 * NavBot ZPS objective support module for the zpo_shreddingfield map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.2.6
 * Author: Claude.ai guided by DNA.styx
 *
 * Status:
 *
 * Issues:
 */

static bool s_bCartPushActive;
static bool s_bWaitingForCartUnlock;
static bool s_bFoodStarted;
static bool s_bFoodDone[3];
static bool s_bGasDone;
static bool s_bHoseDone;
static bool s_bCaptureEnabled;
static bool s_bGasCaptured;
static bool s_bRadioDone;
static bool s_bBlockadeDone;
static bool s_bAtBlockade;
static bool s_bLeg2Started;

void ZPOShreddingfield_Init()
{
	g_ThinkFunc = ZPOShreddingfield_Think;
	s_bCartPushActive = false;
	s_bWaitingForCartUnlock = false;
	s_bFoodStarted = false;
	s_bFoodDone[0] = false;
	s_bFoodDone[1] = false;
	s_bFoodDone[2] = false;
	s_bGasDone = false;
	s_bHoseDone = false;
	s_bCaptureEnabled = false;
	s_bGasCaptured = false;
	s_bRadioDone = false;
	s_bBlockadeDone = false;
	s_bAtBlockade = false;
	s_bLeg2Started = false;

	int barrel = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics_override", 2846015);

	if (barrel == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find bboom2! Hammer ID: 2846015");
	}
	else
	{
		HookSingleEntityOutput(barrel, "OnBreak", ZPOShreddingfield_OnBlockadeBroken, true);
	}

	ZPOShreddingfield_ActivateGearUp();
}

void ZPOShreddingfield_Think()
{
	if (s_bCartPushActive)
	{
		ZPOShreddingfield_UpdateCartPush();
	}

	if (s_bWaitingForCartUnlock)
	{
		ZPOShreddingfield_CheckCartUnlocked();
	}
}

// Polls ntt's disabled flag (no output fires on Enable) - see zpo_biotec.sp.
static void ZPOShreddingfield_CheckCartUnlocked()
{
	int ntt = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "ntt");

	if (ntt == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find ntt trigger_multiple!");
		s_bWaitingForCartUnlock = false;
		return;
	}

	bool disabled = GetEntProp(ntt, Prop_Data, "m_bDisabled") != 0;

	if (!disabled)
	{
		s_bWaitingForCartUnlock = false;
		ZPOShreddingfield_ActivateCartPushLeg1();
	}
}

// Shared by cart-push legs 5/7/9: re-targets bots at ntt's live position.
static void ZPOShreddingfield_UpdateCartPush()
{
	int ntt = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "ntt");

	if (ntt == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find ntt trigger_multiple!");
		s_bCartPushActive = false;
		return;
	}

	float pos[3];
	GetEntPropVector(ntt, Prop_Data, "m_vecAbsOrigin", pos);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(pos);
	CanAllBotsReachGoal(pos);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOShreddingfield_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

// bboom2 can be broken by players at any time after the parking lot trigger.
static void ZPOShreddingfield_OnBlockadeBroken(const char[] output, int caller, int activator, float delay)
{
	s_bBlockadeDone = true;

	if (s_bAtBlockade)
	{
		ZPOShreddingfield_ActivateCartPushLeg2();
	}
}

/**
 * Phase: 0 - GearUp
 * Summary: Move through the tunnel and wait at the entrance door until it opens.
 * Entity: prop_door_rotating
 * Bot action: MOVETO fixed position
 * Confirmation: the door opens
 */
static void ZPOShreddingfield_ActivateGearUp()
{
	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_door_rotating", 1150666);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find entrance door! Hammer ID: 1150666");
		return;
	}

	float goal[3] = { 2749.2, -431.4, -768.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	HookSingleEntityOutput(door, "OnOpen", ZPOShreddingfield_ActivateOpenWD, true);
}

/**
 * Phase: 1 - Open Supermarket Door
 * Summary: Randomly use either the wd button or the side door button then door.
 * Entity: func_button, prop_door_rotating
 * Bot action: USE_BUTTON
 * Confirmation: the wd button is pressed or the side door opens
 */
static void ZPOShreddingfield_ActivateOpenWD(const char[] output, int caller, int activator, float delay)
{
	int wdButton = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 3516314);
	int sideButton = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 6844470);
	int sideDoor = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_door_rotating", 690175);

	// Hook both routes so whichever entrance opens first starts the food phase.
	if (wdButton != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(wdButton, "OnPressed", ZPOShreddingfield_OnEntranceOpened, true);
	}

	if (sideDoor != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(sideDoor, "OnOpen", ZPOShreddingfield_OnEntranceOpened, true);
	}

	bool useSide = (sideButton != INVALID_ENT_REFERENCE && sideDoor != INVALID_ENT_REFERENCE);

	if (useSide && wdButton != INVALID_ENT_REFERENCE)
	{
		useSide = GetRandomInt(0, 1) == 1;
	}

	if (useSide)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(sideButton);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

		HookSingleEntityOutput(sideButton, "OnPressed", ZPOShreddingfield_OnSideButtonPressed, true);
		return;
	}

	if (wdButton != INVALID_ENT_REFERENCE)
	{
		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(wdButton);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		return;
	}

	// Both buttons already used, so the market is open.
	ZPOShreddingfield_StartFoodGathering();
}

static void ZPOShreddingfield_OnSideButtonPressed(const char[] output, int caller, int activator, float delay)
{
	if (s_bFoodStarted)
	{
		return;
	}

	int sideDoor = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_door_rotating", 690175);

	if (sideDoor == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find side door d! Hammer ID: 690175");
		return;
	}

	// The script unlocks d 0.4s after the press; bots retry until it opens.
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(sideDoor);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

static void ZPOShreddingfield_OnEntranceOpened(const char[] output, int caller, int activator, float delay)
{
	ZPOShreddingfield_StartFoodGathering();
}

/**
 * Phase: 2 - FoodGathering
 * Summary: Press the three food buttons in any order.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: all three buttons pressed or removed, then a 5s wait for se to unlock
 */
static const int FOOD_HAMMERIDS[3] = { 6530547, 6530533, 6530540 };

static void ZPOShreddingfield_StartFoodGathering()
{
	if (s_bFoodStarted)
	{
		return;
	}

	s_bFoodStarted = true;
	ZPOShreddingfield_ChatMsgSurvivors("Grab some food!");

	for (int i = 0; i < 3; i++)
	{
		int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", FOOD_HAMMERIDS[i]);

		if (button != INVALID_ENT_REFERENCE)
		{
			HookSingleEntityOutput(button, "OnPressed", ZPOShreddingfield_OnFoodPressed, true);
		}
	}

	ZPOShreddingfield_TargetNextFood();
}

static void ZPOShreddingfield_OnFoodPressed(const char[] output, int caller, int activator, float delay)
{
	int hammerid = GetEntProp(caller, Prop_Data, "m_iHammerID");

	for (int i = 0; i < 3; i++)
	{
		if (hammerid == FOOD_HAMMERIDS[i])
		{
			s_bFoodDone[i] = true;
		}
	}

	ZPOShreddingfield_TargetNextFood();
}

// A missing button counts as done (the map kills each button when pressed).
static void ZPOShreddingfield_TargetNextFood()
{
	for (int i = 0; i < 3; i++)
	{
		if (s_bFoodDone[i])
		{
			continue;
		}

		int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", FOOD_HAMMERIDS[i]);

		if (button == INVALID_ENT_REFERENCE)
		{
			s_bFoodDone[i] = true;
			continue;
		}

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveUseButton(button);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
		return;
	}

	// se is unlocked by the script 4s after food completes; nothing to hook.
	CreateTimer(5.0, ZPOShreddingfield_Timer_ExitUnlocked, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

static void ZPOShreddingfield_Timer_ExitUnlocked(Handle timer)
{
	ZPOShreddingfield_ActivateItemGathering();
}

/**
 * Phase: 3 - ItemGather
 * Summary: Collect gas and hose (any copy), press gb, hold the capture, grab the radio.
 * Entity: func_button, trigger_capturepoint_zp
 * Bot action: USE_BUTTON, MOVETO
 * Confirmation: gas captured and radio grabbed
 */
static const int GAS_HAMMERIDS[3] = { 2722157, 5282182, 5282195 };
static const int HOSE_HAMMERIDS[3] = { 2710032, 5282235, 5282215 };

static void ZPOShreddingfield_ActivateItemGathering()
{
	ZPOShreddingfield_ChatMsgSurvivors("Find the gascan, hose, and radio!");

	for (int i = 0; i < 3; i++)
	{
		int gas = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", GAS_HAMMERIDS[i]);

		if (gas != INVALID_ENT_REFERENCE)
		{
			HookSingleEntityOutput(gas, "OnPressed", ZPOShreddingfield_OnGasPressed, true);
		}

		int hose = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", HOSE_HAMMERIDS[i]);

		if (hose != INVALID_ENT_REFERENCE)
		{
			HookSingleEntityOutput(hose, "OnPressed", ZPOShreddingfield_OnHosePressed, true);
		}
	}

	int gb = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 2710199);

	if (gb != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(gb, "OnPressed", ZPOShreddingfield_OnGasCaptureEnabled, true);
	}

	int gcp = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", 6862582);

	if (gcp != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(gcp, "OnHumanCaptureCompleted", ZPOShreddingfield_OnGasCaptured, true);
	}

	int rb = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 7166925);

	if (rb != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(rb, "OnPressed", ZPOShreddingfield_OnRadioPressed, true);
	}

	ZPOShreddingfield_TargetNextItem();
}

static void ZPOShreddingfield_OnGasPressed(const char[] output, int caller, int activator, float delay)
{
	s_bGasDone = true;
	ZPOShreddingfield_TargetNextItem();
}

static void ZPOShreddingfield_OnHosePressed(const char[] output, int caller, int activator, float delay)
{
	s_bHoseDone = true;
	ZPOShreddingfield_TargetNextItem();
}

static void ZPOShreddingfield_OnGasCaptureEnabled(const char[] output, int caller, int activator, float delay)
{
	s_bCaptureEnabled = true;
	ZPOShreddingfield_TargetNextItem();
}

static void ZPOShreddingfield_OnGasCaptured(const char[] output, int caller, int activator, float delay)
{
	s_bGasCaptured = true;
	ZPOShreddingfield_TargetNextItem();
}

static void ZPOShreddingfield_OnRadioPressed(const char[] output, int caller, int activator, float delay)
{
	s_bRadioDone = true;
	ZPOShreddingfield_TargetNextItem();
}

// Returns the first surviving copy, or INVALID_ENT_REFERENCE if all are gone.
static int ZPOShreddingfield_FindFirstButton(const int[] hammerids, int count)
{
	for (int i = 0; i < count; i++)
	{
		int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerids[i]);

		if (button != INVALID_ENT_REFERENCE)
		{
			return button;
		}
	}

	return INVALID_ENT_REFERENCE;
}

static void ZPOShreddingfield_TargetButton(int button)
{
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

// Missing entities count as done (the map kills them once used).
static void ZPOShreddingfield_TargetNextItem()
{
	if (!s_bGasDone)
	{
		int gas = ZPOShreddingfield_FindFirstButton(GAS_HAMMERIDS, 3);

		if (gas != INVALID_ENT_REFERENCE)
		{
			ZPOShreddingfield_TargetButton(gas);
			return;
		}

		s_bGasDone = true;
	}

	if (!s_bHoseDone)
	{
		int hose = ZPOShreddingfield_FindFirstButton(HOSE_HAMMERIDS, 3);

		if (hose != INVALID_ENT_REFERENCE)
		{
			ZPOShreddingfield_TargetButton(hose);
			return;
		}

		s_bHoseDone = true;
	}

	if (!s_bGasCaptured)
	{
		int gb = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 2710199);

		// gas_obtained kills gb, so a missing gb means the capture is done.
		if (gb == INVALID_ENT_REFERENCE)
		{
			s_bGasCaptured = true;
		}
		else if (!s_bCaptureEnabled)
		{
			ZPOShreddingfield_TargetButton(gb);
			return;
		}
		else
		{
			float goal[3] = { 2253.9, -3538.5, -478.5 };

			NavBotZPSModInterface.ResetObjective();
			NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
			CanAllBotsReachGoal(goal);
			NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
			return;
		}
	}

	if (!s_bRadioDone)
	{
		int rb = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 7166925);

		if (rb != INVALID_ENT_REFERENCE)
		{
			ZPOShreddingfield_TargetButton(rb);
			return;
		}

		s_bRadioDone = true;
	}

	ZPOShreddingfield_ActivateParkinglotDefend();
}

/**
 * Phase: 4 - ParkinglotDefend
 * Summary: Hold near the capture point until the cart push unlocks.
 * Entity: trigger_multiple
 * Bot action: MOVETO
 * Confirmation: the push trigger becomes enabled (polled)
 */
static void ZPOShreddingfield_ActivateParkinglotDefend()
{
	ZPOShreddingfield_ChatMsgSurvivors("Hold this position!");

	float goal[3] = { 2253.9, -3538.5, -478.5 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	s_bWaitingForCartUnlock = true;
}

/**
 * Phase: 5 - CartPushLeg1
 * Summary: Push the cart until it is blocked by the barricade.
 * Entity: trigger_multiple, path_track
 * Bot action: MOVETO, held continuously
 * Confirmation: the cart passes the stop node
 */
static void ZPOShreddingfield_ActivateCartPushLeg1()
{
	ZPOShreddingfield_ChatMsgSurvivors("Push the cart!");

	int stopNode = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "path_track", 3239588);

	if (stopNode == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find n12! Hammer ID: 3239588");
		return;
	}

	HookSingleEntityOutput(stopNode, "OnPass", ZPOShreddingfield_OnCartBlockedByBarricade, true);
	s_bCartPushActive = true;
}

/**
 * Phase: 6 - Open Entrance
 * Summary: Press the button that opens the entrance door beside the barricade.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button is pressed, or it is already gone
 */
static void ZPOShreddingfield_OnCartBlockedByBarricade(const char[] output, int caller, int activator, float delay)
{
	s_bCartPushActive = false;
	s_bAtBlockade = true;

	if (s_bBlockadeDone)
	{
		ZPOShreddingfield_ActivateCartPushLeg2();
		return;
	}

	ZPOShreddingfield_ChatMsgSurvivors("Get past the barricade!");

	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 6620493);

	// The button kills itself when pressed.
	if (button == INVALID_ENT_REFERENCE)
	{
		ZPOShreddingfield_ActivateArmBarrels();
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOShreddingfield_OnEntrancePressed, true);
}

static void ZPOShreddingfield_OnEntrancePressed(const char[] output, int caller, int activator, float delay)
{
	ZPOShreddingfield_ActivateArmBarrels();
}

/**
 * Phase: 6.1 - Arm Barrels
 * Summary: Walk into the trigger that makes the blockade barrels breakable.
 * Entity: trigger_once
 * Bot action: MOVETO
 * Confirmation: the trigger fires, or it is already gone
 */
static void ZPOShreddingfield_ActivateArmBarrels()
{
	if (s_bBlockadeDone)
	{
		ZPOShreddingfield_ActivateCartPushLeg2();
		return;
	}

	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", 4641938);

	// trigger_once removes itself after firing.
	if (trigger == INVALID_ENT_REFERENCE)
	{
		ZPOShreddingfield_ActivateDestroyBlockade();
		return;
	}

	float goal[3] = { 3475.0, -3514.0, -410.0 };

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	HookSingleEntityOutput(trigger, "OnTrigger", ZPOShreddingfield_OnBarrelsArmed, true);
}

static void ZPOShreddingfield_OnBarrelsArmed(const char[] output, int caller, int activator, float delay)
{
	ZPOShreddingfield_ActivateDestroyBlockade();
}

/**
 * Phase: 6.2 - Destroy Blockade
 * Summary: Shoot the blockade barrel.
 * Entity: prop_physics_override
 * Bot action: DESTROY_ENTITY
 * Confirmation: the barrel breaks (hooked in Init)
 */
static void ZPOShreddingfield_ActivateDestroyBlockade()
{
	if (s_bBlockadeDone)
	{
		ZPOShreddingfield_ActivateCartPushLeg2();
		return;
	}

	ZPOShreddingfield_ChatMsgSurvivors("Blow up the barricade!");

	int barrel = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics_override", 2846015);

	if (barrel == INVALID_ENT_REFERENCE)
	{
		s_bBlockadeDone = true;
		ZPOShreddingfield_ActivateCartPushLeg2();
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(barrel);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
}

/**
 * Phase: 7 - CartPushLeg2
 * Summary: Push the cart to the garage entrance.
 * Entity: trigger_multiple, path_track
 * Bot action: MOVETO, held continuously
 * Confirmation: the cart passes the stop node
 */
static void ZPOShreddingfield_ActivateCartPushLeg2()
{
	// Several blockade paths can reach here; only start once.
	if (s_bLeg2Started)
	{
		return;
	}

	s_bLeg2Started = true;
	ZPOShreddingfield_ChatMsgSurvivors("Push the cart!");

	int stopNode = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "path_track", 3239843);

	if (stopNode == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find n26! Hammer ID: 3239843");
		return;
	}

	HookSingleEntityOutput(stopNode, "OnPass", ZPOShreddingfield_ActivateGenerator, true);
	s_bCartPushActive = true;
}

/**
 * Phase: 8 - Generator
 * Summary: Start the generator.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button is pressed
 */
static void ZPOShreddingfield_ActivateGenerator(const char[] output, int caller, int activator, float delay)
{
	s_bCartPushActive = false;
	ZPOShreddingfield_ChatMsgSurvivors("Start the generator!");

	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 3375362);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find the generator func_button! Hammer ID: 3375362");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOShreddingfield_ActivateGarageDoor, true);
}

/**
 * Phase: 8.1 - GarageDoor
 * Summary: Open the garage door.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: the button is pressed
 */
static void ZPOShreddingfield_ActivateGarageDoor(const char[] output, int caller, int activator, float delay)
{
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 724597);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find pdd! Hammer ID: 724597");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

	HookSingleEntityOutput(button, "OnPressed", ZPOShreddingfield_ActivateCartPushLeg3, true);
}

/**
 * Phase: 9 - CartPushLeg3
 * Summary: Push the cart the rest of the way to the elevator.
 * Entity: trigger_multiple, path_track
 * Bot action: MOVETO, held continuously
 * Confirmation: the cart passes the stop node
 */
static void ZPOShreddingfield_ActivateCartPushLeg3(const char[] output, int caller, int activator, float delay)
{
	ZPOShreddingfield_ChatMsgSurvivors("Push the cart!");

	int stopNode = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "path_track", 3375246);

	if (stopNode == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find n39! Hammer ID: 3375246");
		return;
	}

	HookSingleEntityOutput(stopNode, "OnPass", ZPOShreddingfield_ActivateElevator, true);
	s_bCartPushActive = true;
}

/**
 * Phase: 10 - Elevator
 * Summary: Call the freight elevator.
 * Entity: prop_dynamic_override
 * Bot action: USE_BUTTON
 * Confirmation: the button is pressed
 */
static void ZPOShreddingfield_ActivateElevator(const char[] output, int caller, int activator, float delay)
{
	s_bCartPushActive = false;
	ZPOShreddingfield_ChatMsgSurvivors("Call the elevator!");

	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_dynamic_override", 3375101);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_shreddingfield: Failed to find eb! Hammer ID: 3375101");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}
