/*

	ZPO Corpsington - NavBot Objective Support Module
	Author: Claude.ai guided by DNA.styx

	Phase 1: BreakIntoOffice
	Destroy 3x wooden_barricade props to unlock breakdoor1 / breakdoor2.
	All 3 props share the same targetname, so they are resolved individually
	via Hammer ID and destroyed one at a time (DESTROY_ENTITY only supports
	a single target) - this is the one case in the file that needs
	FindEntityOfHammerID rather than FindNamedEntityOfClassname. Completion
	is confirmed via breakdoor1's OnFullyOpen output (hooked in Init())
	rather than inferred from the barricade poll finding nothing left -
	breakdoor1 is unique and always present, so it's a more reliable signal
	than our own inference.

	Phase 2: OpenWarehouse
	Press wh_button, then wait (objective reset, no goal set) until
	big_wh_door1 is fully open.

	Phase 3: CutPower
	Once big_wh_door1 is fully open, destroy fuse_box_breakable.

	Phase 4: WaitForPowerToFail
	The floor into the upper area isn't there yet - CutPowerTimer() in the
	.as script runs a ~33 second internal countdown with no entity I/O to
	hook. Bots are moved to a safe staging position immediately, then a
	matching 33s timer moves them toward enter_2nd_floor.

	Phase 5: GetInsideUpperFloor
	MOVETO enter_2nd_floor's origin (StartDisabled until the .as timer
	finishes) and hook its OnStartTouch directly - no further guessed
	delay needed once bots are standing on it.

	Phase 6/7: GetToStreet / PushGenerator
	street_test and blockcart_trigger are not used. toolButton (parented to
	pushcart_model, which moves with pushcart_train along the track) is
	polled every Think() tick: while m_bLocked is set, bots get a MOVETO
	to its current m_vecAbsOrigin (not m_vecOrigin, since that's local to
	its parent for a parented entity) so they stay near it as the cart
	moves - they aren't expected to actually push it, PCSpeed() scaling by
	player count still requires humans. Once PCFinish() clears m_bLocked,
	bots are assigned USE_BUTTON and press it themselves.

	Phase 8: CloseDoors
	GenLever() unlocks safehouse_button 6 seconds after toolButton is used,
	with no entity I/O fired in between. Think() polls m_bLocked until it
	clears, then assigns USE_BUTTON.

	Version: 0.10.0

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
