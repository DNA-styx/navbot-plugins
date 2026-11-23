/**
 * zpo_aquatica.sp
 *
 * NavBot ZPS objective support module for the zpo_aquatica map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.1.2
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: Unusable
 *
 * Issues: Survivor bots unable to ride lift
 */

// Only Init() and Think() are called from outside this file. Every other
// function is static void.

void ZPOAquatica_Init()
{
	g_ThinkFunc = ZPOAquatica_Think;

	ZPOAquatica_Start();
}

void ZPOAquatica_Think()
{
	// Left empty until a phase needs per-tick polling.
}

static void ZPOAquatica_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}

	LogDebugMessage("Aquatica: Phase message: %s", msg);
}

/**
 * Phase: 0 - Start
 * Summary: Wait for the round start trigger.
 * Entity: trigger_once
 * Bot action: none
 * Confirmation: start trigger fires OnTrigger.
 */
static void ZPOAquatica_Start()
{
	const int hammerid = 2906908;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", hammerid);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_aquatica: Failed to find start trigger_once! Hammer ID: %i", hammerid);
		return;
	}

	HookSingleEntityOutput(trigger, "OnTrigger", ZPOAquatica_GetInside, true);
}

/**
 * Phase: 1 - Get inside
 * Summary: Get inside the facility.
 * Entity: trigger_once, func_button
 * Bot action: MOVE_TO_ENTITY
 * Confirmation: inside trigger fires OnTrigger.
 */
static void ZPOAquatica_GetInside(const char[] output, int caller, int activator, float delay)
{
	const int triggerHammerID = 900783;
	int trigger = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "trigger_once", triggerHammerID);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_aquatica: Failed to find inside trigger_once! Hammer ID: %i", triggerHammerID);
		return;
	}

	const int buttonHammerID = 816863;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", buttonHammerID);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_aquatica: Failed to find documents func_button! Hammer ID: %i", buttonHammerID);
		return;
	}

	HookSingleEntityOutput(trigger, "OnTrigger", ZPOAquatica_FindDocuments, true);

	ZPOAquatica_ChatMsgSurvivors("Get inside the facility!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVE_TO_ENTITY);
}

/**
 * Phase: 2 - Find documents
 * Summary: Press the documents button.
 * Entity: func_button, filter_activator_team
 * Bot action: USE_BUTTON
 * Confirmation: survivor team filter fires OnPass.
 */
static void ZPOAquatica_FindDocuments(const char[] output, int caller, int activator, float delay)
{
	const int buttonHammerID = 816863;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", buttonHammerID);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_aquatica: Failed to find documents func_button! Hammer ID: %i", buttonHammerID);
		return;
	}

	const int filterHammerID = 4846667;
	int filter = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "filter_activator_team", filterHammerID);

	if (filter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_aquatica: Failed to find survivor filter_activator_team! Hammer ID: %i", filterHammerID);
		return;
	}

	HookSingleEntityOutput(filter, "OnPass", ZPOAquatica_Keycard, true);

	ZPOAquatica_ChatMsgSurvivors("Find the documents!");

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Phase: 3 - Keycard
 * Summary: Kill the zombie with the keycard.
 * Entity: n/a
 * Bot action: none (roam)
 * Confirmation: n/a
 */
static void ZPOAquatica_Keycard(const char[] output, int caller, int activator, float delay)
{
	LogDebugMessage("Aquatica: Documents taken by %N", activator > 0 && activator <= MaxClients ? activator : 0);

	NavBotZPSModInterface.ResetObjective();
}
