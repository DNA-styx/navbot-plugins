/**
 * zpo_murksville.sp
 *
 * NavBot ZPS objective support module for the zpo_murksville map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.8.2
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase: 0a - DrainBoat (cart stage)
 * Summary: The cart advances based on how many players are standing in the
 *   trigger, so bots just need to be present in it.
 * Entity: push_pump_trigger (trigger_multiple, 473433), parented to pushCart
 * Bot action: MOVETO the trigger's live m_vecAbsOrigin every Think() tick
 * Confirmation: rotatepump's OnFullyOpen (func_door_rotating, 768975)
 *
 * Phase: 0b - DrainBoat (pump stage)
 * Summary: Same shape as 0a, second trigger/cart pair
 * Entity: push_pump_trigger2 (trigger_multiple), parented to pushPump
 * Bot action: MOVETO the trigger's live m_vecAbsOrigin every Think() tick
 * Confirmation: pumppathEnd's OnPass (path_track, 473453)
 *
 * Phase: 1 - FindBoatParts
 * Summary: PartsDeliver spawns from PartsProp ~9.1s in; polled by name
 *   each tick. Needed a Stripper:Source "itemid" fix. OnItemTaken/
 *   OnItemDropped hooked persistently through Phase 2+.
 * Entity: PartsDeliver (item_deliver), spawned via the -MakerParts template
 * Bot action: MOVETO the gas station (1199.93, 1945.92, -543.38) while
 *   waiting, then FIND_ITEM "parts" (radius 999999.0) once it exists
 * Confirmation: PartsDeliver's OnItemTaken
 *
 * Phase: 2 - RetoolParts
 * Summary: Carrier presses toolButton while in toolsTrig, starting a real
 *   45s countdown in-game. No entity output confirms that countdown
 *   finishing, so the press itself is treated as this phase's completion.
 * Entity: toolButton (func_button, 473583) / toolsTrig (trigger_multiple, 473586)
 * Bot action: USE_BUTTON on toolButton, re-issued if the carrier leaves
 *   toolsTrig before pressing it
 * Confirmation: toolButton's OnPressed
 *
 * Further phases (BringParts onward) not yet implemented.
 *
 */

enum
{
	ZPOMURK_PHASE_WAITFORCART = 0,
	ZPOMURK_PHASE_WAITFORPUMP,
	ZPOMURK_PHASE_FINDPARTS,
	ZPOMURK_PHASE_DONE
};

static int s_CurrentPhase = ZPOMURK_PHASE_WAITFORCART;
static bool s_bPartsItemHooked;
static bool s_bRetoolDone;
static bool s_bToolButtonHooked;
static bool s_bToolsTrigHooked;

void ZPOMurksville_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

void ZPOMurksville_OnToolsTrigEndTouch(const char[] output, int caller, int activator, float delay)
{
	if (s_bRetoolDone)
	{
		return;
	}

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

void ZPOMurksville_OnToolButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	s_bRetoolDone = true;
	s_CurrentPhase = ZPOMURK_PHASE_DONE;

	//TODO: Phase 3 - BringParts
}

void ZPOMurksville_OnPartsDropped(const char[] output, int caller, int activator, float delay)
{
	if (s_bRetoolDone)
	{
		//TODO: Phase 3 drop handling once BringParts exists
		return;
	}

	// Dropped (carrier died or dropped voluntarily) before retool finished -
	// the .as script disables toolsTrig and clears iIndexPartsGuy on this
	// same event, so whatever bot picks it up next re-enables toolsTrig
	// itself (OnEntityPickedUp handler). Send everyone back to searching.
	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("parts");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);

	s_CurrentPhase = ZPOMURK_PHASE_FINDPARTS;
}

void ZPOMurksville_OnPartsPickedUp(const char[] output, int caller, int activator, float delay)
{
	if (s_bRetoolDone)
	{
		NavBotZPSModInterface.ResetObjective();

		//TODO: Phase 3 - BringParts (re-pickup after retool already done)
		return;
	}

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find the toolButton func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

void ZPOMurksville_PollPartsItem()
{
	if (s_bPartsItemHooked)
	{
		return;
	}

	int item = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "item_deliver", "PartsDeliver");

	if (item == INVALID_ENT_REFERENCE)
	{
		return;
	}

	s_bPartsItemHooked = true;

	// Hooked persistently - PartsDeliver persists for the rest of the round
	// (it still needs carrying to the boat in Phase 3), and can be dropped
	// and re-picked up multiple times, e.g. if the carrier dies mid-retool
	// or mid-carry.
	HookSingleEntityOutput(item, "OnItemTaken", ZPOMurksville_OnPartsPickedUp, false);
	HookSingleEntityOutput(item, "OnItemDropped", ZPOMurksville_OnPartsDropped, false);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("parts");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

void ZPOMurksville_PollGarageEntities()
{
	if (s_bToolButtonHooked && s_bToolsTrigHooked)
	{
		return;
	}

	if (!s_bToolButtonHooked)
	{
		int toolButton = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

		if (toolButton != INVALID_ENT_REFERENCE)
		{
			s_bToolButtonHooked = true;
			HookSingleEntityOutput(toolButton, "OnPressed", ZPOMurksville_OnToolButtonPressed, false);
		}
	}

	if (!s_bToolsTrigHooked)
	{
		int toolsTrig = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "toolsTrig");

		if (toolsTrig != INVALID_ENT_REFERENCE)
		{
			s_bToolsTrigHooked = true;
			HookSingleEntityOutput(toolsTrig, "OnEndTouch", ZPOMurksville_OnToolsTrigEndTouch, false);
		}
	}
}

void ZPOMurksville_OnPumpFinished(const char[] output, int caller, int activator, float delay)
{
	// PartsDeliver spawns ~9.1s later via the .as script's own Schedule::Task
	// delays. This staging position is a confirmed walkable spot near the
	// PartsProp spawn cluster - ZPOMurksville_PollPartsItem() overrides this
	// with FIND_ITEM the moment PartsDeliver is found.
	float goal[3];
	goal[0] = 1199.932739;
	goal[1] = 1945.923706;
	goal[2] = -543.382751;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	ZPOMurksville_ChatMsgSurvivors("We're going to search the gas station");

	s_CurrentPhase = ZPOMURK_PHASE_FINDPARTS;
}

void ZPOMurksville_UpdatePumpTriggerObjective()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "push_pump_trigger2");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		return;
	}

	float pos[3];
	GetEntPropVector(trigger, Prop_Data, "m_vecAbsOrigin", pos);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(pos);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

void ZPOMurksville_OnRotatePumpFullyOpen(const char[] output, int caller, int activator, float delay)
{
	s_CurrentPhase = ZPOMURK_PHASE_WAITFORPUMP;

	int pathEnd = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "pumppathEnd");

	if (pathEnd == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find the pumppathEnd path_track!");
		return;
	}

	HookSingleEntityOutput(pathEnd, "OnPass", ZPOMurksville_OnPumpFinished, true);
}

void ZPOMurksville_UpdateCartTriggerObjective()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "push_pump_trigger");

	if (trigger == INVALID_ENT_REFERENCE)
	{
		return;
	}

	float pos[3];
	GetEntPropVector(trigger, Prop_Data, "m_vecAbsOrigin", pos);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(pos);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

void ZPOMurksville_Think()
{
	switch (s_CurrentPhase)
	{
		case ZPOMURK_PHASE_WAITFORCART:
		{
			ZPOMurksville_UpdateCartTriggerObjective();
		}
		case ZPOMURK_PHASE_WAITFORPUMP:
		{
			ZPOMurksville_UpdatePumpTriggerObjective();
		}
		case ZPOMURK_PHASE_FINDPARTS:
		{
			ZPOMurksville_PollPartsItem();
			ZPOMurksville_PollGarageEntities();
		}
	}
}

void ZPOMurksville_Init()
{
	g_ThinkFunc = ZPOMurksville_Think;
	s_CurrentPhase = ZPOMURK_PHASE_WAITFORCART;
	s_bPartsItemHooked = false;
	s_bRetoolDone = false;
	s_bToolButtonHooked = false;
	s_bToolsTrigHooked = false;

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "rotatepump");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find the rotatepump func_door_rotating!");
	}
	else
	{
		HookSingleEntityOutput(door, "OnFullyOpen", ZPOMurksville_OnRotatePumpFullyOpen, true);
	}
}
