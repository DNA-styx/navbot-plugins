/**
 * zpo_murksville.sp
 *
 * NavBot ZPS objective support module for the zpo_murksville map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.11.2
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