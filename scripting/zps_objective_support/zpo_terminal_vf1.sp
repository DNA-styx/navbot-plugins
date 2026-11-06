/**
 * zpo_terminal_vf1.sp
 *
 * NavBot ZPS objective support module for the zpo_terminal_vf1 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.9.4
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: WIP. Search for and use Keycard. Find food. Find and guard Bus 
 *
 * Issues:
 */

static bool s_SearchComplete;
static int s_CaseNumber = -1;
static int s_CorpseOrder[5];
static bool s_CorpseCaptured[5];
static int s_CorpseIndex;
static int s_GateKeyTrigger = INVALID_ENT_REFERENCE;
static bool s_KeyDelivered;
static int s_FoodCase = -1;
static bool s_FoodStarted;
static bool s_FoodComplete;
static int s_FoodButtons[6];
static int s_FoodIndex;
static int s_FoodAreaTotal[3];
static int s_FoodAreaCount[3];
static int s_BusNumber = -1;
static bool s_GasDelivered;
static bool s_BusKeyDelivered;
static bool s_BarricadeDone;
static bool s_HumveeDone;
static bool s_GateDone;
static bool s_PlanB;

// hammerid[6] per case_food outcome.
static int s_FoodCaseButtons[5][6] =
{
	{ 679765, 679873, 530931, 530984, 531081, 680053 },
	{ 679765, 679873, 530914, 679984, 531247, 531283 },
	{ 707835, 707897, 530914, 679984, 531081, 680053 },
	{ 531081, 680053, 531247, 531283, 707835, 707897 },
	{ 531081, 680053, 707835, 707897, 679765, 679873 }
};

/**
 * Sets up Phase 0.
 */
void ZPOTerminal_Init()
{
	g_ThinkFunc = ZPOTerminal_Think;
	s_SearchComplete = false;
	s_CaseNumber = -1;
	s_CorpseIndex = 0;
	s_KeyDelivered = false;
	s_FoodCase = -1;
	s_FoodStarted = false;
	s_FoodComplete = false;
	s_FoodIndex = 0;
	s_BusNumber = -1;
	s_GasDelivered = false;
	s_BusKeyDelivered = false;
	s_BarricadeDone = false;
	s_HumveeDone = false;
	s_GateDone = false;
	s_PlanB = false;

	for (int i = 0; i < sizeof(s_FoodAreaTotal); i++)
	{
		s_FoodAreaTotal[i] = 0;
		s_FoodAreaCount[i] = 0;
	}

	ZPOTerminal_HookGuardKeyCase();
	ZPOTerminal_HookGuardKeyItem();
	ZPOTerminal_HookGateKeyTrigger();
	ZPOTerminal_HookFoodCase();
	ZPOTerminal_HookFoodCollected();
	ZPOTerminal_HookGatesOpen();
	ZPOTerminal_HookMainTerminal();
	ZPOTerminal_HookBusTemplates();
	ZPOTerminal_HookGasCase();
	ZPOTerminal_HookCabinGateButton();
	ZPOTerminal_HookBusDestroyed();
	ZPOTerminal_MoveToSearchTrigger();
}

static void ZPOTerminal_HookGuardKeyCase()
{
	int caseEntity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_case", "case_guardkey");

	if (caseEntity == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find case_guardkey logic_case!");
		return;
	}

	char outputName[16];

	for (int i = 1; i <= 5; i++)
	{
		Format(outputName, sizeof(outputName), "OnCase%02d", i);
		HookSingleEntityOutput(caseEntity, outputName, ZPOTerminal_OnGuardKeyCaseChosen, true);
	}
}

static void ZPOTerminal_HookGuardKeyItem()
{
	int item = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "guardkey");

	if (item == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find guardkey item_deliver!");
		return;
	}

	HookSingleEntityOutput(item, "OnItemTaken", ZPOTerminal_OnGuardKeyTaken, true);
}

static void ZPOTerminal_HookGateKeyTrigger()
{
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_useable", 482101);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find trigger_useable! Hammer ID: 482101");
		return;
	}

	s_GateKeyTrigger = EntIndexToEntRef(trigger);
	HookSingleEntityOutput(trigger, "OnUsed", ZPOTerminal_OnGateKeyUsed, true);
}

static void ZPOTerminal_HookFoodCase()
{
	int caseEntity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_case", "case_food");

	if (caseEntity == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find case_food logic_case!");
		return;
	}

	char outputName[16];

	for (int i = 1; i <= 5; i++)
	{
		Format(outputName, sizeof(outputName), "OnCase%02d", i);
		HookSingleEntityOutput(caseEntity, outputName, ZPOTerminal_OnFoodCaseChosen, true);
	}
}

static void ZPOTerminal_HookFoodCollected()
{
	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "math_food_collected");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find math_food_collected!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOTerminal_OnFoodCollected, true);
}

static void ZPOTerminal_HookGatesOpen()
{
	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "math_keyused");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find math_keyused!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOTerminal_OnGatesOpen, true);
}

static void ZPOTerminal_HookMainTerminal()
{
	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "mainterminal_capture");

	if (entity == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find mainterminal_capture!");
		return;
	}

	HookSingleEntityOutput(entity, "OnHumanCaptureCompleted", ZPOTerminal_OnMainTerminalCaptured, true);
}

static void ZPOTerminal_HookBusTemplates()
{
	char name[32];

	for (int i = 1; i <= 6; i++)
	{
		Format(name, sizeof(name), "template_bus%d", i);
		int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "point_template", name);

		if (entity == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_terminal_vf1: Failed to find %s point_template!", name);
			continue;
		}

		HookSingleEntityOutput(entity, "OnEntitySpawned", ZPOTerminal_OnBusSpawned, true);
	}
}

static void ZPOTerminal_HookGasCase()
{
	int caseEntity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_case", "case_gas");

	if (caseEntity == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find case_gas logic_case!");
		return;
	}

	char outputName[16];

	for (int i = 1; i <= 4; i++)
	{
		Format(outputName, sizeof(outputName), "OnCase%02d", i);
		HookSingleEntityOutput(caseEntity, outputName, ZPOTerminal_FindGas, true);
	}
}

static void ZPOTerminal_HookCabinGateButton()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "button_cabingates");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find button_cabingates func_button!");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOTerminal_Escape, true);
}

static void ZPOTerminal_HookBusDestroyed()
{
	int relay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "relay_busdestroyed");

	if (relay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find relay_busdestroyed logic_relay!");
		return;
	}

	HookSingleEntityOutput(relay, "OnTrigger", ZPOTerminal_OnBusDestroyed, true);
}

/**
 * Phase: 0 - TriggerSearch
 * Summary: Walk to the gate to trigger the guard corpse search.
 * Entity: trigger_once (446724)
 * Bot action: MOVETO trigger origin
 * Confirmation: case_guardkey's OnCase01-05 (tells us which case was
 *   picked), then polling for that case's 5 entities to exist
 */
static void ZPOTerminal_MoveToSearchTrigger()
{
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", 446724);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find trigger_once! Hammer ID: 446724");
		return;
	}

	float goal[3];
	GetEntPropVector(trigger, Prop_Data, "m_vecOrigin", goal);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

// output is "OnCase01".."OnCase05" - the digit tells us which case won.
static void ZPOTerminal_OnGuardKeyCaseChosen(const char[] output, int caller, int activator, float delay)
{
	s_CaseNumber = StringToInt(output[7]);
}

static void ZPOTerminal_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

void ZPOTerminal_Think()
{
	// Once case_guardkey has picked, poll until its 5 capture points exist.
	if (s_CaseNumber != -1 && !s_SearchComplete)
	{
		ZPOTerminal_UpdateTriggerSearchObjective();
	}

	// Once food collection has started, poll the current button until pressed.
	if (s_FoodStarted && !s_FoodComplete)
	{
		ZPOTerminal_UpdateFoodObjective();
	}
}

static void ZPOTerminal_ShuffleCorpseOrder()
{
	for (int i = 0; i < sizeof(s_CorpseOrder) - 1; i++)
	{
		int j = GetRandomInt(i, sizeof(s_CorpseOrder) - 1);
		int temp = s_CorpseOrder[i];
		s_CorpseOrder[i] = s_CorpseOrder[j];
		s_CorpseOrder[j] = temp;
	}
}

static void ZPOTerminal_MoveToNextCorpse()
{
	while (s_CorpseIndex < sizeof(s_CorpseOrder) && s_CorpseCaptured[s_CorpseIndex])
	{
		s_CorpseIndex++;
	}

	if (s_CorpseIndex >= sizeof(s_CorpseOrder))
	{
		LogError("zpo_terminal_vf1: Went through all 5 guard corpses without finding the key!");
		return;
	}

	int entity = EntRefToEntIndex(s_CorpseOrder[s_CorpseIndex]);

	if (entity == INVALID_ENT_REFERENCE)
	{
		// Point already gone (e.g. removed by the map) - skip it.
		s_CorpseIndex++;
		ZPOTerminal_MoveToNextCorpse();
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}

// Finds this case's 5 capture points and hooks them all upfront.
static void ZPOTerminal_UpdateTriggerSearchObjective()
{
	char name[64];
	Format(name, sizeof(name), "corpsekeysearch%d_capture_a", s_CaseNumber);

	int entities[5];
	entities[0] = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", name);

	if (entities[0] == INVALID_ENT_REFERENCE)
	{
		return;
	}

	char letters[] = "bcde";

	for (int i = 0; i < strlen(letters); i++)
	{
		Format(name, sizeof(name), "corpsekeysearch%d_capture_%c", s_CaseNumber, letters[i]);
		entities[i + 1] = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", name);
	}

	for (int i = 0; i < sizeof(entities); i++)
	{
		s_CorpseOrder[i] = EntIndexToEntRef(entities[i]);
		s_CorpseCaptured[i] = false;
		HookSingleEntityOutput(entities[i], "OnHumanCaptureCompleted", ZPOTerminal_OnCorpseCaptured, true);
	}

	s_SearchComplete = true;
	ZPOTerminal_ShuffleCorpseOrder();
	s_CorpseIndex = 0;
	ZPOTerminal_MoveToNextCorpse();
}

/**
 * Phase: 1 - GuardCorpses
 * Summary: Captures the 5 guard corpse points to find the key.
 * Entity: 5x trigger_capturepoint_zp, corpsekeysearch{N}_capture_{a-e}
 * Bot action: MOVE_TO_ENTITY on each capture point in turn
 * Confirmation: paired point_teleport's "target" keyvalue
 */
static void ZPOTerminal_OnCorpseCaptured(const char[] output, int caller, int activator, float delay)
{
	int index = -1;

	for (int i = 0; i < sizeof(s_CorpseOrder); i++)
	{
		if (EntRefToEntIndex(s_CorpseOrder[i]) == caller)
		{
			index = i;
			break;
		}
	}

	if (index == -1)
	{
		LogError("zpo_terminal_vf1: Captured corpse point not found in s_CorpseOrder!");
		return;
	}

	s_CorpseCaptured[index] = true;

	char name[64];

	if (GetEntPropString(caller, Prop_Data, "m_iName", name, sizeof(name)) <= 0)
	{
		LogError("zpo_terminal_vf1: Captured corpse point has no targetname!");
		return;
	}

	// name is corpsekeysearch{N}_capture_{letter}
	char letter = name[strlen(name) - 1];

	char teleportName[32];
	Format(teleportName, sizeof(teleportName), "teleport_case%d%c", s_CaseNumber, letter);

	int teleport = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "point_teleport", teleportName);

	if (teleport == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find %s point_teleport!", teleportName);
		return;
	}

	char target[64];
	GetEntPropString(teleport, Prop_Data, "m_target", target, sizeof(target));

	if (strcmp(target, "guardkey", false) == 0)
	{
		ZPOTerminal_ChatMsgSurvivors("We've found the guard's key!");
		ZPOTerminal_FindGuardKey();
		return;
	}

	// Only redirect the bot if the captured point was its current target.
	if (index == s_CorpseIndex)
	{
		s_CorpseIndex++;
		ZPOTerminal_MoveToNextCorpse();
	}
}

/**
 * Phase: 2 - PickupKey
 * Summary: Pick up the guard key.
 * Entity: item_deliver "guardkey" (1049651)
 * Bot action: FIND_ITEM for itemid "guardkey"
 * Confirmation: guardkey's OnItemTaken
 */
static void ZPOTerminal_FindGuardKey()
{
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("guardkey");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

static void ZPOTerminal_OnGuardKeyTaken(const char[] output, int caller, int activator, float delay)
{
	ZPOTerminal_UseGuardKey();
}

/**
 * Phase: 3 - DeliverKey
 * Summary: Use the key to unlock the gate
 * Entity: trigger_useable (482101)
 * Bot action: USE_ITEM targeting the trigger_useable
 * Confirmation: trigger_useable's OnUsed
 */
static void ZPOTerminal_UseGuardKey()
{
	int target = EntRefToEntIndex(s_GateKeyTrigger);

	if (target == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Gate key trigger_useable is gone!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("guardkey");
	NavBotZPSModInterface.SetObjectiveItemUseTarget(target);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_ITEM);
}

// Gates need food collection too (math_keyused) - join both here.
static void ZPOTerminal_OnGateKeyUsed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	s_KeyDelivered = true;
	ZPOTerminal_TryStartFoodCollection();
}

// output is "OnCase01".."OnCase05" - the digit tells us which case won.
// Tracking starts here regardless of key status, so human progress counts.
static void ZPOTerminal_OnFoodCaseChosen(const char[] output, int caller, int activator, float delay)
{
	s_FoodCase = StringToInt(output[7]);
	ZPOTerminal_TrackFoodButtons();
	ZPOTerminal_TryStartFoodCollection();
}

// Returns which area a food button hammerid belongs to: 0=Market, 1=Snacks, 2=Food Court.
static int ZPOTerminal_GetFoodArea(int hammerid)
{
	switch (hammerid)
	{
		case 679765, 679873: return 0;
		case 707835, 707897: return 1;
	}

	return 2;
}

// Populates s_FoodButtons and hooks every button's OnPressed, independent
// of key delivery, so human progress is tracked from the moment it unlocks.
static void ZPOTerminal_TrackFoodButtons()
{
	for (int i = 0; i < sizeof(s_FoodButtons); i++)
	{
		int hammerid = s_FoodCaseButtons[s_FoodCase - 1][i];
		int entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

		if (entity == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_terminal_vf1: Failed to find food button! Hammer ID: %i", hammerid);
			s_FoodButtons[i] = INVALID_ENT_REFERENCE;
			continue;
		}

		s_FoodButtons[i] = EntIndexToEntRef(entity);
		s_FoodAreaTotal[ZPOTerminal_GetFoodArea(hammerid)]++;
		HookSingleEntityOutput(entity, "OnPressed", ZPOTerminal_OnFoodButtonPressed, true);
	}
}

static void ZPOTerminal_TryStartFoodCollection()
{
	if (!s_KeyDelivered || s_FoodCase == -1 || s_FoodComplete)
	{
		return;
	}

	s_FoodStarted = true;
	s_FoodIndex = 0;
	ZPOTerminal_ChatMsgSurvivors("We are getting the food now!");
	ZPOTerminal_MoveToNextFoodButton();
}

/**
 * Phase: 4 - FoodCollection
 * Summary: Find and USE the 6 food buttons.
 * Entity: 6x func_button, see s_FoodCaseButtons hammerid table
 * Bot action: USE_BUTTON each in turn
 * Confirmation: math_food_collected's OnHitMax
 */
static void ZPOTerminal_MoveToNextFoodButton()
{
	while (s_FoodIndex < sizeof(s_FoodButtons) && EntRefToEntIndex(s_FoodButtons[s_FoodIndex]) == INVALID_ENT_REFERENCE)
	{
		s_FoodIndex++;
	}

	if (s_FoodIndex >= sizeof(s_FoodButtons))
	{
		return;
	}

	int entity = EntRefToEntIndex(s_FoodButtons[s_FoodIndex]);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(entity);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

static void ZPOTerminal_UpdateFoodObjective()
{
	if (s_FoodIndex >= sizeof(s_FoodButtons))
	{
		return;
	}

	if (EntRefToEntIndex(s_FoodButtons[s_FoodIndex]) == INVALID_ENT_REFERENCE)
	{
		ZPOTerminal_MoveToNextFoodButton();
	}
}

// Fires for every press, by anyone. Announces once an area's total is met.
static void ZPOTerminal_OnFoodButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int hammerid = GetEntProp(caller, Prop_Data, "m_iHammerID");
	int area = ZPOTerminal_GetFoodArea(hammerid);

	s_FoodAreaCount[area]++;

	if (s_FoodAreaCount[area] < s_FoodAreaTotal[area])
	{
		return;
	}

	char name[16];

	switch (area)
	{
		case 0: strcopy(name, sizeof(name), "the Market");
		case 1: strcopy(name, sizeof(name), "the Snacks area");
		default: strcopy(name, sizeof(name), "the Food Court");
	}

	char msg[64];
	Format(msg, sizeof(msg), "We've got all the food from %s!", name);
	ZPOTerminal_ChatMsgSurvivors(msg);
}

static void ZPOTerminal_OnFoodCollected(const char[] output, int caller, int activator, float delay)
{
	s_FoodComplete = true;
	NavBotZPSModInterface.ResetObjective();
}

static void ZPOTerminal_OnGatesOpen(const char[] output, int caller, int activator, float delay)
{
	ZPOTerminal_ChatMsgSurvivors("We have unlocked the upper gate!");

	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", 482332);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find door_uppergateside3 func_door! Hammer ID: 482332");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOTerminal_MoveToMainTerminal, true);
}

/**
 * Phase: 5 - CaptureMainTerminal
 * Summary: Capture the main terminal zone to select a bus.
 * Entity: trigger_capturepoint_zp
 * Bot action: MOVETO position inside the zone
 * Confirmation: mainterminal_capture's OnHumanCaptureCompleted
 */
static void ZPOTerminal_MoveToMainTerminal(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	float goal[3] = { 2.5, -364.2, -768.0 };

	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOTerminal_OnMainTerminalCaptured(const char[] output, int caller, int activator, float delay)
{
	ZPOTerminal_ChatMsgSurvivors("We've captured the terminal");
	NavBotZPSModInterface.ResetObjective();
}

// caller is template_bus1..template_bus6 - the digit is the selected bus.
static void ZPOTerminal_OnBusSpawned(const char[] output, int caller, int activator, float delay)
{
	char name[32];
	GetEntPropString(caller, Prop_Data, "m_iName", name, sizeof(name));
	s_BusNumber = StringToInt(name[strlen(name) - 1]);

	Format(name, sizeof(name), "math_items_bus%d", s_BusNumber);
	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", name);

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find %s math_counter!", name);
	}
	else
	{
		HookSingleEntityOutput(counter, "OnHitMax", ZPOTerminal_DestroyBarricade, true);
	}

	Format(name, sizeof(name), "receivekey_bus%d", s_BusNumber);
	int receiver = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_itemreceiver", name);

	if (receiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find %s trigger_itemreceiver!", name);
		return;
	}

	HookSingleEntityOutput(receiver, "OnItemDelivered", ZPOTerminal_OnBusKeyDelivered, true);
}

/**
 * Phase: 6 - FindGas
 * Summary: Find the gas can.
 * Entity: item_deliver
 * Bot action: FIND_ITEM for "gas1"
 * Confirmation: gas1's OnPlayerPickup
 */
static void ZPOTerminal_FindGas(const char[] output, int caller, int activator, float delay)
{
	if (s_PlanB)
	{
		return;
	}

	int gas = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "gas1");

	if (gas == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find gas1 item_deliver!");
		return;
	}

	HookSingleEntityOutput(gas, "OnPlayerPickup", ZPOTerminal_DeliverGas, true);
	ZPOTerminal_ChatMsgSurvivors("Let's find the gas can!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("gas1");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

/**
 * Phase: 7 - DeliverGas
 * Summary: Deliver the gas can to the bus.
 * Entity: item_deliver, trigger_itemreceiver
 * Bot action: DROP_ITEM "gas1" at the selected bus's gas receiver
 * Confirmation: receivegas1_bus{N}'s OnItemDelivered
 */
static void ZPOTerminal_DeliverGas(const char[] output, int caller, int activator, float delay)
{
	if (s_PlanB)
	{
		return;
	}

	char name[32];
	Format(name, sizeof(name), "receivegas1_bus%d", s_BusNumber);
	int receiver = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_itemreceiver", name);

	if (receiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find %s trigger_itemreceiver!", name);
		return;
	}

	HookSingleEntityOutput(receiver, "OnItemDelivered", ZPOTerminal_FindBusKey, true);
	LogDebugMessage("Terminal: DEBUG hooked %s (entity %d) OnItemDelivered", name, receiver);

	int item = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "gas1");

	if (item == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find gas1 item_deliver!");
		return;
	}

	ZPOTerminal_ChatMsgSurvivors("Take the gas to the bus!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("gas1");
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(item);
	NavBotZPSModInterface.SetObjectiveItemUseTarget(receiver);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(128.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM);
}

/**
 * Phase: 8 - FindBusKey
 * Summary: Find the bus keys.
 * Entity: item_deliver
 * Bot action: FIND_ITEM for "buskey"
 * Confirmation: buskey's OnPlayerPickup
 */
static void ZPOTerminal_FindBusKey(const char[] output, int caller, int activator, float delay)
{
	LogDebugMessage("Terminal: DEBUG FindBusKey called by entity %d. PlanB %d KeyDelivered %d", caller, s_PlanB, s_BusKeyDelivered);

	if (s_PlanB)
	{
		return;
	}

	s_GasDelivered = true;

	if (s_BusKeyDelivered)
	{
		NavBotZPSModInterface.ResetObjective();
		return;
	}

	int key = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "buskey");

	if (key == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find buskey item_deliver!");
		return;
	}

	HookSingleEntityOutput(key, "OnPlayerPickup", ZPOTerminal_DeliverBusKey, true);
	ZPOTerminal_ChatMsgSurvivors("Let's find the bus keys!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("buskey");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

/**
 * Phase: 9 - DeliverBusKey
 * Summary: Deliver the bus keys to the bus.
 * Entity: item_deliver, trigger_itemreceiver
 * Bot action: DROP_ITEM "buskey" at the selected bus's key receiver
 * Confirmation: receivekey_bus{N}'s OnItemDelivered
 */
static void ZPOTerminal_DeliverBusKey(const char[] output, int caller, int activator, float delay)
{
	if (s_PlanB)
	{
		return;
	}

	char name[32];
	Format(name, sizeof(name), "receivekey_bus%d", s_BusNumber);
	int receiver = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_itemreceiver", name);

	if (receiver == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find %s trigger_itemreceiver!", name);
		return;
	}

	int item = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "buskey");

	if (item == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find buskey item_deliver!");
		return;
	}

	ZPOTerminal_ChatMsgSurvivors("Take the keys to the bus!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("buskey");
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(item);
	NavBotZPSModInterface.SetObjectiveItemUseTarget(receiver);
	NavBotZPSModInterface.SetObjectiveDetectionRadius(128.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DROP_ITEM);
}

static void ZPOTerminal_OnBusKeyDelivered(const char[] output, int caller, int activator, float delay)
{
	s_BusKeyDelivered = true;

	if (s_PlanB || !s_GasDelivered)
	{
		return;
	}

	ZPOTerminal_ChatMsgSurvivors("The bus has gas and keys, someone bring the food!");
	NavBotZPSModInterface.ResetObjective();
}

/**
 * Phase: 10 - DestroyBarricade
 * Summary: Break the barricade on the selected bus's route.
 * Entity: func_breakable
 * Bot action: DESTROY_ENTITY on the barricade
 * Confirmation: barricade's OnBreak
 */
static void ZPOTerminal_DestroyBarricade(const char[] output, int caller, int activator, float delay)
{
	if (s_PlanB)
	{
		return;
	}

	char name[32];

	switch (s_BusNumber)
	{
		case 2, 3, 6: strcopy(name, sizeof(name), "breakable_barricadeconcret1");
		default: strcopy(name, sizeof(name), "breakable_barricadeconcret2");
	}

	int barricade = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", name);

	if (barricade == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find %s func_breakable!", name);
		return;
	}

	int path = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "path_humv7");

	if (path == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find path_humv7 path_track!");
		return;
	}

	HookSingleEntityOutput(barricade, "OnBreak", ZPOTerminal_PushHumvee, true);
	HookSingleEntityOutput(path, "OnPass", ZPOTerminal_OpenCabinGate, true);
	ZPOTerminal_ChatMsgSurvivors("Break down the barricade!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(barricade);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
}

/**
 * Phase: 11 - PushHumvee
 * Summary: Push the humvee out of the way.
 * Entity: trigger_multiple
 * Bot action: MOVE_TO_ENTITY on the humvee's push trigger
 * Confirmation: path_humv7's OnPass
 */
static void ZPOTerminal_PushHumvee(const char[] output, int caller, int activator, float delay)
{
	s_BarricadeDone = true;

	if (s_PlanB)
	{
		return;
	}

	if (s_HumveeDone)
	{
		ZPOTerminal_OpenCabinGate(output, caller, activator, delay);
		return;
	}

	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "trigger_pushumv");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find trigger_pushumv trigger_multiple!");
		return;
	}

	ZPOTerminal_ChatMsgSurvivors("Push the humvee out of the way!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}

/**
 * Phase: 12 - OpenCabinGate
 * Summary: Press the button to open the cabin gates.
 * Entity: func_button
 * Bot action: USE_BUTTON on button_cabingates
 * Confirmation: button_cabingates's OnPressed
 */
static void ZPOTerminal_OpenCabinGate(const char[] output, int caller, int activator, float delay)
{
	s_HumveeDone = true;

	if (s_PlanB || !s_BarricadeDone)
	{
		return;
	}

	if (s_GateDone)
	{
		ZPOTerminal_Escape(output, caller, activator, delay);
		return;
	}

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "button_cabingates");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find button_cabingates func_button!");
		return;
	}

	ZPOTerminal_ChatMsgSurvivors("Open the gates!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 13 - Escape
 * Summary: Get to the bus and escape.
 * Entity: trigger_escape
 * Bot action: MOVE_TO_ENTITY on the selected bus's escape trigger
 * Confirmation: none - round ends on escape
 */
static void ZPOTerminal_Escape(const char[] output, int caller, int activator, float delay)
{
	s_GateDone = true;

	if (s_PlanB || !s_BarricadeDone || !s_HumveeDone)
	{
		return;
	}

	char name[32];
	Format(name, sizeof(name), "triggerescape_bus%d", s_BusNumber);
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_escape", name);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find %s trigger_escape!", name);
		return;
	}

	ZPOTerminal_ChatMsgSurvivors("The path is clear, get on the bus!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(trigger);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}

// Bus destroyed - case_planb picks a zombie win or the metro escape.
static void ZPOTerminal_OnBusDestroyed(const char[] output, int caller, int activator, float delay)
{
	s_PlanB = true;
	NavBotZPSModInterface.ResetObjective();

	int door = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_door", 869282);

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find door_sidebuildingates_planb func_door! Hammer ID: 869282");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOTerminal_PressMetroButton, true);
}

/**
 * Phase: B1 - PressMetroButton
 * Summary: Press the metro cabin button.
 * Entity: func_button
 * Bot action: USE_BUTTON on the first metro cabin button
 * Confirmation: button's OnPressed
 */
static void ZPOTerminal_PressMetroButton(const char[] output, int caller, int activator, float delay)
{
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 968464);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find metro cabin func_button! Hammer ID: 968464");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOTerminal_PressCabinButton, true);
	ZPOTerminal_ChatMsgSurvivors("The bus is gone, head for the metro!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: B2 - PressCabinButton
 * Summary: Press the cabin button to call the train.
 * Entity: func_button
 * Bot action: USE_BUTTON on button_planb_cabin
 * Confirmation: button_planb_cabin's OnPressed
 */
static void ZPOTerminal_PressCabinButton(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "button_planb_cabin");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find button_planb_cabin func_button!");
		return;
	}

	HookSingleEntityOutput(button, "OnPressed", ZPOTerminal_BoardTrain, true);
	ZPOTerminal_ChatMsgSurvivors("Call the train!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: B3 - BoardTrain
 * Summary: Board the train and ride it out.
 * Entity: info_beacon
 * Bot action: MOVE_TO_ENTITY on the train's beacon
 * Confirmation: none - round ends on escape
 */
static void ZPOTerminal_BoardTrain(const char[] output, int caller, int activator, float delay)
{
	int beacon = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "info_beacon", "beacon_planb_train");

	if (beacon == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find beacon_planb_train info_beacon!");
		return;
	}

	ZPOTerminal_ChatMsgSurvivors("Get on the train!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(beacon);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_MOVE_TO_ENTITY);
}
