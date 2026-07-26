/**
 * zpo_murksville.sp
 *
 * NavBot ZPS objective support module for the zpo_murksville map.
 * Intended to be #included by zps_objective_support.sp, alongside zpo_biotec.sp.
 *
 * Module version: 0.1.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase 0a: "DrainBoat" (cart stage).
 *   - push_pump_trigger (trigger_multiple, hammer ID 473433) is parented to
 *     pushCart, a func_tracktrain that only advances while players stand in the
 *     trigger (genSpeed() scales its speed by player count). There is no button
 *     here, so bots get a MOVETO to the trigger's live m_vecAbsOrigin, polled
 *     every Think() tick, so they keep pace with it as the cart moves - same
 *     shape as zpo_corpsington.sp's PushGenerator phase. Bot presence
 *     contributes to the player count genSpeed() reads, but full-speed
 *     progress likely still needs humans.
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
 * Further phases (FindBoatParts onward) not yet implemented.
 *
 */

enum
{
	ZPOMURK_PHASE_WAITFORCART = 0,
	ZPOMURK_PHASE_WAITFORPUMP,
	ZPOMURK_PHASE_DONE
};

static int s_CurrentPhase = ZPOMURK_PHASE_WAITFORCART;

void ZPOMurksville_OnPumpFinished(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	s_CurrentPhase = ZPOMURK_PHASE_DONE;

	//TODO: Phase 1 - FindBoatParts
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
	}
}

void ZPOMurksville_Init()
{
	g_ThinkFunc = ZPOMurksville_Think;
	s_CurrentPhase = ZPOMURK_PHASE_WAITFORCART;

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
}
