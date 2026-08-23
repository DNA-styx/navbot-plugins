/**
 * zpo_terminal_vf1.sp
 *
 * NavBot ZPS objective support module for the zpo_terminal_vf1 map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.5.0
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
static bool s_FoodAreaAnnounced[3];
static int s_MainTerminal = INVALID_ENT_REFERENCE;

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

	for (int i = 0; i < sizeof(s_FoodAreaAnnounced); i++)
	{
		s_FoodAreaAnnounced[i] = false;
	}

	ZPOTerminal_HookGuardKeyCase();
	ZPOTerminal_HookGuardKeyItem();
	ZPOTerminal_HookGateKeyTrigger();
	ZPOTerminal_HookFoodCase();
	ZPOTerminal_HookFoodCollected();
	ZPOTerminal_HookGatesOpen();
	ZPOTerminal_HookMainTerminal();
	ZPOTerminal_MoveToSearchTrigger();
}

void ZPOTerminal_HookGuardKeyCase()
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

void ZPOTerminal_HookGuardKeyItem()
{
	int item = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "guardkey");

	if (item == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find guardkey item_deliver!");
		return;
	}

	HookSingleEntityOutput(item, "OnItemTaken", ZPOTerminal_OnGuardKeyTaken, true);
}

void ZPOTerminal_HookGateKeyTrigger()
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

void ZPOTerminal_HookFoodCase()
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

void ZPOTerminal_HookFoodCollected()
{
	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "math_food_collected");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find math_food_collected!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOTerminal_OnFoodCollected, true);
}

void ZPOTerminal_HookGatesOpen()
{
	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "math_keyused");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find math_keyused!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOTerminal_OnGatesOpen, true);
}

void ZPOTerminal_HookMainTerminal()
{
	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "mainterminal_capture");

	if (entity == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: Failed to find mainterminal_capture!");
		return;
	}

	s_MainTerminal = EntIndexToEntRef(entity);
	HookSingleEntityOutput(entity, "OnHumanCaptureCompleted", ZPOTerminal_OnMainTerminalCaptured, true);
}

/**
 * Phase: 0 - TriggerSearch
 * Summary: Walk to the gate to trigger the guard corpse search.
 * Entity: trigger_once (446724)
 * Bot action: MOVETO trigger origin
 * Confirmation: case_guardkey's OnCase01-05 (tells us which case was
 *   picked), then polling for that case's 5 entities to exist
 */
void ZPOTerminal_MoveToSearchTrigger()
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
void ZPOTerminal_OnGuardKeyCaseChosen(const char[] output, int caller, int activator, float delay)
{
	s_CaseNumber = StringToInt(output[7]);
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

void ZPOTerminal_ShuffleCorpseOrder()
{
	for (int i = 0; i < sizeof(s_CorpseOrder) - 1; i++)
	{
		int j = GetRandomInt(i, sizeof(s_CorpseOrder) - 1);
		int temp = s_CorpseOrder[i];
		s_CorpseOrder[i] = s_CorpseOrder[j];
		s_CorpseOrder[j] = temp;
	}
}

void ZPOTerminal_MoveToNextCorpse()
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

	float goal[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", goal);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

// Finds this case's 5 capture points and hooks them all upfront.
void ZPOTerminal_UpdateTriggerSearchObjective()
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
 * Bot action: MOVETO each capture point in turn
 * Confirmation: paired point_teleport's "target" keyvalue
 */
void ZPOTerminal_OnCorpseCaptured(const char[] output, int caller, int activator, float delay)
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
		PrintToChatAll("\x04[NAV]\x01 We've found the guard's key!");
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
void ZPOTerminal_FindGuardKey()
{
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("guardkey");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(g_DetectionRadius);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

void ZPOTerminal_OnGuardKeyTaken(const char[] output, int caller, int activator, float delay)
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
void ZPOTerminal_UseGuardKey()
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
void ZPOTerminal_OnGateKeyUsed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	s_KeyDelivered = true;
	ZPOTerminal_TryStartFoodCollection();
}

// output is "OnCase01".."OnCase05" - the digit tells us which case won.
void ZPOTerminal_OnFoodCaseChosen(const char[] output, int caller, int activator, float delay)
{
	s_FoodCase = StringToInt(output[7]);
	ZPOTerminal_TryStartFoodCollection();
}

void ZPOTerminal_TryStartFoodCollection()
{
	if (!s_KeyDelivered || s_FoodCase == -1)
	{
		return;
	}

	for (int i = 0; i < sizeof(s_FoodButtons); i++)
	{
		int entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", s_FoodCaseButtons[s_FoodCase - 1][i]);

		if (entity == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_terminal_vf1: Failed to find food button! Hammer ID: %i", s_FoodCaseButtons[s_FoodCase - 1][i]);
			s_FoodButtons[i] = INVALID_ENT_REFERENCE;
			continue;
		}

		s_FoodButtons[i] = EntIndexToEntRef(entity);
		HookSingleEntityOutput(entity, "OnPressed", ZPOTerminal_OnFoodButtonPressed, true);
	}

	s_FoodStarted = true;
	s_FoodIndex = 0;
	PrintToChatAll("\x04[NAV]\x01 We are getting the food now!");
	ZPOTerminal_MoveToNextFoodButton();
}

/**
 * Phase: 4 - FoodCollection
 * Summary: Find nd USE the 6 food buttons.
 * Entity: 6x func_button, see s_FoodCaseButtons hammerid table
 * Bot action: USE_BUTTON each in turn
 * Confirmation: math_food_collected's OnHitMax
 */
void ZPOTerminal_MoveToNextFoodButton()
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

void ZPOTerminal_UpdateFoodObjective()
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

// Only announces when a bot pressed it, not a human.
void ZPOTerminal_OnFoodButtonPressed(const char[] output, int caller, int activator, float delay)
{
	if (!IsFakeClient(activator))
	{
		return;
	}

	int hammerid = GetEntProp(caller, Prop_Data, "m_iHammerID");
	ZPOTerminal_AnnounceFoodButtonUsed(hammerid);
}

// Announces the first time food is collected from an area, not every button.
void ZPOTerminal_AnnounceFoodButtonUsed(int hammerid)
{
	int area;
	char name[16];

	switch (hammerid)
	{
		case 679765, 679873:
		{
			area = 0;
			strcopy(name, sizeof(name), "the Market");
		}
		case 707835, 707897:
		{
			area = 1;
			strcopy(name, sizeof(name), "the Snacks area");
		}
		default:
		{
			area = 2;
			strcopy(name, sizeof(name), "the Food Court");
		}
	}

	if (s_FoodAreaAnnounced[area])
	{
		return;
	}

	s_FoodAreaAnnounced[area] = true;
	PrintToChatAll("\x04[NAV]\x01 We've got food from %s!", name);
}

void ZPOTerminal_OnFoodCollected(const char[] output, int caller, int activator, float delay)
{
	s_FoodComplete = true;
	NavBotZPSModInterface.ResetObjective();
}

void ZPOTerminal_OnGatesOpen(const char[] output, int caller, int activator, float delay)
{
	PrintToChatAll("\x04[NAV]\x01 We have unlocked the upper gate!");
	ZPOTerminal_MoveToMainTerminal();
}

/**
 * Phase: 5 - CaptureMainTerminal
 * Summary: Capture the main terminal zone to select a bus.
 * Entity: trigger_capturepoint_zp "mainterminal_capture" (482536)
 * Bot action: MOVETO zone origin
 * Confirmation: mainterminal_capture's OnHumanCaptureCompleted
 */
void ZPOTerminal_MoveToMainTerminal()
{
	int entity = EntRefToEntIndex(s_MainTerminal);

	if (entity == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_terminal_vf1: mainterminal_capture is gone!");
		return;
	}

	float goal[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", goal);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

// Further phases (bus selection, item delivery, cabin/path, escape) not
// yet implemented.
void ZPOTerminal_OnMainTerminalCaptured(const char[] output, int caller, int activator, float delay)
{
	PrintToChatAll("\x04[NAV]\x01 We've captured the bus");
		NavBotZPSModInterface.ResetObjective();
}
