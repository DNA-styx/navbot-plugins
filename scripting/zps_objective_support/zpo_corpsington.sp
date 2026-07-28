/**
 * zpo_corpsington.sp
 *
 * NavBot ZPS objective support module for the zpo_corpsington map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.10.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase: 1 - BreakIntoOffice
 * Summary: Survivors destroy 3 barricades nailed across the office door.
 *   All 3 share one targetname, so bots are re-targeted to the next
 *   surviving one by hammer ID each tick until none remain.
 * Entity: wooden_barricade (prop_physics_multiplayer, 908234 / 908281 / 908312)
 * Bot action: DESTROY_ENTITY, re-targeted to the next surviving barricade
 *   each tick
 * Confirmation: breakdoor1's OnFullyOpen output (func_door_rotating, 34159)
 *   - the map opens this door once all 3 barricades are gone
 *
 * Phase: 2 - OpenWarehouse
 * Summary: Bots press wh_button to open the warehouse door.
 * Entity: wh_button (func_button, 54540)
 * Bot action: USE_BUTTON
 * Confirmation: wh_button's OnPressed output
 *
 * Phase: 3 - CutPower
 * Summary: Once the warehouse door finishes opening, bots destroy the fuse
 *   box to cut power and start the building's countdown sequence.
 * Entity: big_wh_door1 (func_door, 26975) / fuse_box_breakable
 *   (func_breakable, 928335)
 * Bot action: reset objective and wait until the door opens, then
 *   DESTROY_ENTITY on the fuse box
 * Confirmation: big_wh_door1's OnFullyOpen output starts this phase;
 *   fuse_box_breakable's OnBreak output ends it
 *
 * Phase: 4 - WaitForPowerToFail
 * Summary: Starts the map's own ~33 second countdown before the upper
 *   floor becomes reachable, with no entity output marking progress along
 *   the way. Bots are moved to a safe staging position and held there
 *   until a matching timer expires.
 * Entity: none (fixed staging position)
 * Bot action: MOVETO staging position (1800.841187 508.958191 288.142029)
 * Confirmation: 33s CreateTimer, matched to the map's own countdown length
 *
 * Phase: 5 - GetInsideUpperFloor
 * Summary: Bots move to and wait at the entry point into the upper floor,
 *   which only becomes touchable once the Phase 4 countdown finishes.
 * Entity: enter_2nd_floor (trigger_once, 34622)
 * Bot action: MOVETO enter_2nd_floor's origin
 * Confirmation: enter_2nd_floor's OnStartTouch output
 *
 * Phase: 6/7 - GetToStreet / PushGenerator
 * Summary: toolButton starts locked and is parented to the moving pushcart.
 *   Bots track its live position every tick while locked so they stay near
 *   it as it moves, then use it once the cart finishes its route and
 *   unlocks it. Actually pushing the cart still needs human players.
 * Entity: toolButton (func_button, 66092)
 * Bot action: MOVETO toolButton's live position while locked, then
 *   USE_BUTTON once unlocked
 * Confirmation: m_bLocked polled each tick; toolButton's OnPressed output
 *   ends the phase
 *
 * Phase: 8 - CloseDoors
 * Summary: Pressing toolButton starts a 6 second delay before
 *   safehouse_button unlocks, with no entity output marking that delay.
 * Entity: safehouse_button (func_button, 66545)
 * Bot action: USE_BUTTON once unlocked
 * Confirmation: m_bLocked polled each tick; safehouse_button's OnPressed
 *   output ends the phase
 *
 *
 */

enum
{
	ZPOCORP_PHASE_BREAKINTOOFFICE = 0,
	ZPOCORP_PHASE_WAITFORCART,
	ZPOCORP_PHASE_CLOSEDOORS,
	ZPOCORP_PHASE_DONE
};

static int s_CurrentPhase = ZPOCORP_PHASE_BREAKINTOOFFICE;

void ZPOCorpsington_OnSafehouseButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	//TODO: Phase 9
}

void ZPOCorpsington_UpdateCloseDoorsObjective()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "safehouse_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		return;
	}

	int locked = GetEntProp(button, Prop_Data, "m_bLocked", 1);

	if (locked != 0)
	{
		return; // still waiting on GenLever() to unlock it
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_OnSafehouseButtonPressed, true);

	s_CurrentPhase = ZPOCORP_PHASE_DONE;
}

void ZPOCorpsington_OnToolButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	s_CurrentPhase = ZPOCORP_PHASE_CLOSEDOORS;
}

void ZPOCorpsington_UpdateToolButtonObjective()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "toolButton");

	if (button == INVALID_ENT_REFERENCE)
	{
		return;
	}

	int locked = GetEntProp(button, Prop_Data, "m_bLocked", 1);

	if (locked != 0)
	{
		// Still locked - toolButton is parented to the moving cart, so track its
		// live world position each tick rather than a one-time hardcoded goal.
		float pos[3];
		GetEntPropVector(button, Prop_Data, "m_vecAbsOrigin", pos);

		NavBotZPSModInterface.ResetObjective();
		NavBotZPSModInterface.SetObjectiveMoveGoal(pos);
		NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_OnToolButtonPressed, true);

	s_CurrentPhase = ZPOCORP_PHASE_DONE;
}

void ZPOCorpsington_OnEnteredSecondFloor(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	s_CurrentPhase = ZPOCORP_PHASE_WAITFORCART;
}

void ZPOCorpsington_ActivateEnterSecondFloor()
{
	int trigger = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_once", "enter_2nd_floor");

	float goal[3];
	goal[0] = 1904.0;
	goal[1] = 1120.0;
	goal[2] = 288.0;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	if (trigger == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the enter_2nd_floor trigger_once!");
		return;
	}

	HookSingleEntityOutput(trigger, "OnStartTouch", ZPOCorpsington_OnEnteredSecondFloor, true);
}

void ZPOCorpsington_Timer_EnterSecondFloor(Handle timer)
{
	ZPOCorpsington_ActivateEnterSecondFloor();
}

void ZPOCorpsington_OnFuseBoxBroken(const char[] output, int caller, int activator, float delay)
{
	float goal[3];
	goal[0] = 1800.841187;
	goal[1] = 508.958191;
	goal[2] = 288.142029;

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	CreateTimer(33.0, ZPOCorpsington_Timer_EnterSecondFloor, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

void ZPOCorpsington_OnWarehouseDoorOpened(const char[] output, int caller, int activator, float delay)
{
	int entity = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_breakable", "fuse_box_breakable");

	if (entity == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the fuse_box_breakable func_breakable!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
	HookSingleEntityOutput(entity, "OnBreak", ZPOCorpsington_OnFuseBoxBroken, true);
}

void ZPOCorpsington_OnWarehouseButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "big_wh_door1");

	if (door != INVALID_ENT_REFERENCE)
	{
		HookSingleEntityOutput(door, "OnFullyOpen", ZPOCorpsington_OnWarehouseDoorOpened, true);
	}
}

void ZPOCorpsington_OnBreakdoorsOpened(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "wh_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the wh_button func_button!");
		s_CurrentPhase = ZPOCORP_PHASE_DONE;
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOCorpsington_OnWarehouseButtonPressed, true);

	s_CurrentPhase = ZPOCORP_PHASE_DONE;
}

void ZPOCorpsington_UpdateBarricadeObjective()
{
	static int s_CurrentBarricadeRef = INVALID_ENT_REFERENCE;

	// Current target still alive, nothing to do.
	if (s_CurrentBarricadeRef != INVALID_ENT_REFERENCE && EntRefToEntIndex(s_CurrentBarricadeRef) != INVALID_ENT_REFERENCE)
	{
		return;
	}

	static const int barricadeHammerIDs[] = { 908234, 908281, 908312 };

	for (int i = 0; i < sizeof(barricadeHammerIDs); i++)
	{
		int entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "prop_physics_multiplayer", barricadeHammerIDs[i]);

		if (entity != INVALID_ENT_REFERENCE)
		{
			s_CurrentBarricadeRef = EntIndexToEntRef(entity);
			NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
			NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
			return;
		}
	}

	// No barricades left to target - Phase 1 completion is confirmed by
	// ZPOCorpsington_OnBreakdoorsOpened, hooked in Init().
	NavBotZPSModInterface.ResetObjective();
}

void ZPOCorpsington_Think()
{
	switch (s_CurrentPhase)
	{
		case ZPOCORP_PHASE_BREAKINTOOFFICE:
		{
			ZPOCorpsington_UpdateBarricadeObjective();
		}
		case ZPOCORP_PHASE_WAITFORCART:
		{
			ZPOCorpsington_UpdateToolButtonObjective();
		}
		case ZPOCORP_PHASE_CLOSEDOORS:
		{
			ZPOCorpsington_UpdateCloseDoorsObjective();
		}
	}
}

void ZPOCorpsington_Init()
{
	g_ThinkFunc = ZPOCorpsington_Think;
	s_CurrentPhase = ZPOCORP_PHASE_BREAKINTOOFFICE;

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "breakdoor1");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_corpsington: Failed to find the breakdoor1 func_door_rotating!");
	}
	else
	{
		HookSingleEntityOutput(door, "OnFullyOpen", ZPOCorpsington_OnBreakdoorsOpened, true);
	}

	ZPOCorpsington_UpdateBarricadeObjective();
}
