/**
 * zpo_murksville.sp
 *
 * NavBot ZPS objective support module for the zpo_murksville map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.7.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase 0a: "DrainBoat" (cart stage).
 *   - push_pump_trigger (trigger_multiple, hammer ID 473433) is parented to
 *     pushCart, a func_tracktrain that only advances while players stand in the
 *     trigger (genSpeed() scales its speed by player count). There is no button
 *     here, so bots get a MOVETO to the trigger's live m_vecAbsOrigin, polled
 *     every Think() tick, so they keep pace with it as the cart moves. Bot
 *     presence contributes to the player count genSpeed() reads, but
 *     full-speed progress likely still needs humans.
 *   - Completion is confirmed via rotatepump's OnFullyOpen (func_door_rotating,
 *     hammer ID 768975) - a real, always-present entity the .as script's
 *     cartpath4 waypoint opens once the cart reaches the end of its track.
 *
 * Phase 0b: "DrainBoat" (pump stage).
 *   - Same shape as 0a: push_pump_trigger2 is parented to pushPump, another
 *     func_tracktrain. MOVETO its live m_vecAbsOrigin each Think() tick.
 *   - Completion is confirmed via pumppathEnd's OnPass (path_track, hammer ID
 *     473453), which the .as script's pumpFinish() is itself bound to.
 *
 * Phase 1: "FindBoatParts".
 *   - On Phase 0b completion, bots get an immediate MOVETO to a confirmed
 *     walkable position near the PartsProp spawn cluster (in-game:
 *     1199.93, 1945.92, -543.38, aka "the gas station"), since
 *     PartsDeliver doesn't exist for ~9.1s regardless. Chat message fired on the
 *     MOVETO via ZPOMurksville_ChatMsgSurvivors().
 *   - PartsProp (prop_physics_multiplayer, hammer ID 824760) is inert until the
 *     .as script's ShowFindPartsObj() fires its OnUser1 (~9.1s after
 *     DrainBoat completes, via internal Schedule::Task calls - no entity
 *     output to hook), which kills it and force-spawns PartsDeliver
 *     (item_deliver) at its position via the -MakerParts template. There's no
 *     output tied to that spawn either, so ZPOMurksville_PollPartsItem()
 *     polls for PartsDeliver by name each Think() tick. No skip-original
 *     complication here: PartsDeliver's static cfg entry is only the
 *     point_template's blueprint, never a live duplicate.
 *   - PartsDeliver required a map-side fix (Stripper:Source) to set its
 *     "itemid" keyvalue to "parts" - it had none in the original map, and
 *     NAVBOT_ZPS_OBJECTIVE_FIND_ITEM matches SetObjectiveItemSearchID()
 *     against that field.
 *   - Once found: NAVBOT_ZPS_OBJECTIVE_FIND_ITEM with item search ID "parts".
 *     Detection radius set to 999999.0 since the 6 possible spawn points
 *     are roughly 2700+ units from where bots are left after DrainBoat -
 *     well beyond the module's default detection radius.
 *   - Pickup confirmed via PartsDeliver's OnItemTaken, hooked persistently
 *     (not once) since it can be dropped and re-picked up by a different
 *     survivor, and this hook needs to fire again when that happens.
 *     OnItemDropped is hooked the same way: on drop, the .as script
 *     disables toolsTrig and clears its carrier tracking regardless of
 *     which sub-phase we're in, so bots are sent back to FIND_ITEM until
 *     it's picked up again. Both hooks stay live for PartsDeliver's whole
 *     lifetime, including through Phase 2 and beyond, since it still
 *     needs carrying to the boat afterward.
 *
 * Phase 2: "RetoolParts".
 *   - toolsTrig (trigger_multiple, hammer ID 473586) and toolButton
 *     (func_button, hammer ID 473583) both exist from round start, so no
 *     polling is needed to find them. iRetoolProgress (a 45s countdown) is
 *     set once at round start and only ever decremented - never reset -
 *     so an interrupted retool resumes where it left off, it doesn't
 *     restart from 45.
 *   - The actual gameplay gate (bAllowRetooling) is set by toolsTrig's
 *     OnStartTouch matching the carrier's player index - not by
 *     Lock/Unlock on toolButton, so polling toolButton's own locked state
 *     wouldn't work here; it's never actually locked/unlocked at all.
 *   - On PartsDeliver pickup: NAVBOT_ZPS_OBJECTIVE_USE_BUTTON on toolButton
 *     directly (its own pathing walks the carrier into toolsTrig, which
 *     sits right at its edge - no separate MOVETO needed to get there).
 *   - On toolButton's OnPressed (hooked persistently, not once - it can
 *     legitimately fire more than once across interruptions):
 *     NAVBOT_ZPS_OBJECTIVE_MOVETO to toolButton's exact origin (908,
 *     -3160, -589) to hold the carrier in place for the countdown, since
 *     there's no entity output for RetoolTimer()'s tick-by-tick countdown
 *     to hook.
 *   - toolsTrig's OnEndTouch (hooked persistently) re-issues USE_BUTTON on
 *     toolButton whenever the carrier leaves the trigger, whether that's
 *     before the first press or after leaving mid-hold - sending them
 *     back to press it again and resume the countdown from wherever
 *     iRetoolProgress currently sits.
 *   - Completion: RetoolDone() kills toolButton with no output fired, so
 *     ZPOMurksville_UpdateRetoolCompletion() polls each Think() tick for
 *     toolButton's continued existence once pressed; its disappearance
 *     confirms the retool finished.
 *   - Known limitation: since this objective is global
 *     (NavBotZPSModInterface), every bot on the team gets sent to press
 *     toolButton, not just the carrier - and our OnPressed hook fires for
 *     any presser, not just the actual carrier. bAllowRetooling still
 *     silently no-ops a wrong-bot press on the .as side, so this is
 *     harmless in practice, just not selective.
 *   - s_bRetoolDone gates PartsDeliver's persistent OnItemTaken/OnItemDropped
 *     hooks once retool finishes, so a later drop/re-pickup (Phase 3, once
 *     it exists) doesn't get routed back into the toolButton flow.
 *
 * Further phases (BringParts onward) not yet implemented.
 *
 */

enum
{
	ZPOMURK_PHASE_WAITFORCART = 0,
	ZPOMURK_PHASE_WAITFORPUMP,
	ZPOMURK_PHASE_FINDPARTS,
	ZPOMURK_PHASE_RETOOLING,
	ZPOMURK_PHASE_DONE
};

static int s_CurrentPhase = ZPOMURK_PHASE_WAITFORCART;
static bool s_bPartsItemHooked;
static bool s_bRetoolDone;

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

void ZPOMurksville_UpdateRetoolCompletion()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

	if (button != INVALID_ENT_REFERENCE)
	{
		return; // still retooling
	}

	NavBotZPSModInterface.ResetObjective();

	s_bRetoolDone = true;
	s_CurrentPhase = ZPOMURK_PHASE_DONE;

	//TODO: Phase 3 - BringParts
}

void ZPOMurksville_OnToolsTrigEndTouch(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		return; // already killed - retool finished
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

void ZPOMurksville_OnToolButtonPressed(const char[] output, int caller, int activator, float delay)
{
	// Holds the carrier at the button for the countdown - no entity output
	// fires per RetoolTimer() tick, so ZPOMurksville_UpdateRetoolCompletion()
	// polls for toolButton's disappearance instead.
	float goal[3];
	goal[0] = 908.0;
	goal[1] = -3160.0;
	goal[2] = -589.0;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	s_CurrentPhase = ZPOMURK_PHASE_RETOOLING;
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

	// Not "once" - PartsDeliver persists for the rest of the round (it still
	// needs carrying to the boat in Phase 3), and can be dropped/re-picked
	// up multiple times, e.g. if the carrier dies mid-retool or mid-carry.
	HookSingleEntityOutput(item, "OnItemTaken", ZPOMurksville_OnPartsPickedUp, false);
	HookSingleEntityOutput(item, "OnItemDropped", ZPOMurksville_OnPartsDropped, false);

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveItemSearchID("parts");
	NavBotZPSModInterface.SetObjectiveDetectionRadius(999999.0);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_FIND_ITEM);
}

void ZPOMurksville_OnPumpFinished(const char[] output, int caller, int activator, float delay)
{
	// PartsDeliver doesn't exist yet (~9.1s of Schedule::Task delays remain in
	// the .as script), but this staging position is a confirmed walkable spot
	// near the PartsProp spawn cluster - ZPOMurksville_PollPartsItem()
	// overrides this with FIND_ITEM the moment PartsDeliver is found.
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
		}
		case ZPOMURK_PHASE_RETOOLING:
		{
			ZPOMurksville_UpdateRetoolCompletion();
		}
	}
}

void ZPOMurksville_Init()
{
	g_ThinkFunc = ZPOMurksville_Think;
	s_CurrentPhase = ZPOMURK_PHASE_WAITFORCART;
	s_bPartsItemHooked = false;
	s_bRetoolDone = false;

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "rotatepump");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find the rotatepump func_door_rotating!");
	}
	else
	{
		HookSingleEntityOutput(door, "OnFullyOpen", ZPOMurksville_OnRotatePumpFullyOpen, true);
	}

	int pathEnd = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "path_track", "pumppathEnd");

	if (pathEnd == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find the pumppathEnd path_track!");
	}
	else
	{
		HookSingleEntityOutput(pathEnd, "OnPass", ZPOMurksville_OnPumpFinished, true);
	}

	int toolButton = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

	if (toolButton == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find the toolButton func_button!");
	}
	else
	{
		HookSingleEntityOutput(toolButton, "OnPressed", ZPOMurksville_OnToolButtonPressed, false);
	}

	int toolsTrig = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_multiple", "toolsTrig");

	if (toolsTrig == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_murksville: Failed to find the toolsTrig trigger_multiple!");
	}
	else
	{
		HookSingleEntityOutput(toolsTrig, "OnEndTouch", ZPOMurksville_OnToolsTrigEndTouch, false);
	}
}
