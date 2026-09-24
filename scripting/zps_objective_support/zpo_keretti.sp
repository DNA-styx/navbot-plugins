/**
 * zpo_keretti.sp
 *
 * NavBot ZPS objective support module for the zpo_keretti map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.12.3
 * Author: Claude.ai guided by DNA.styx
 *
 * Status: {good / usable / partially complete / unusable}
 *
 * Issues: {description of things that do not work, or "none known"}
 */

// s_CurrentPhase values
#define PHASE_MINEDOOR 0
#define PHASE_WAREHOUSE 1
#define PHASE_RADIO 2
#define PHASE_FILES 3
#define PHASE_FINALE 4

static bool s_FilesPhaseActive = false;
static int s_CurrentPhase = PHASE_MINEDOOR;
static bool s_MineDoorDone = false;
static bool s_WarehouseDoorDone = false;
static bool s_RadioButtonPressed = false;
static bool s_RadioDone = false;
static bool s_FilesDone = false;
static int s_ParallelOrder[2] = { 0, 1 }; // 0 = Radio, 1 = Files
static int s_ParallelIndex = 0;
static int s_FileHammerIDs[4] = { 269523, 269836, 269880, 269862 };

// Side-task step values
#define SIDETASK_NONE 0
#define SIDETASK_AT_BUTTON 1
#define SIDETASK_AT_DOOR 2

static bool s_SideTaskActive = false;
static int s_SideTaskStep = SIDETASK_NONE;
static int s_SideTaskBotRef = INVALID_ENT_REFERENCE;

void ZPOKeretti_Init()
{
	g_ThinkFunc = ZPOKeretti_Think;
	s_FilesPhaseActive = false;
	s_ParallelIndex = 0;
	s_CurrentPhase = PHASE_MINEDOOR;
	s_MineDoorDone = false;
	s_WarehouseDoorDone = false;
	s_RadioButtonPressed = false;
	s_RadioDone = false;
	s_FilesDone = false;
	s_SideTaskActive = false;
	s_SideTaskStep = SIDETASK_NONE;
	s_SideTaskBotRef = INVALID_ENT_REFERENCE;

	// Every completion/reversion signal is hooked here, before any
	// objective is assigned.

	// Phase 0 (MineDoor) completion.
	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "mine_door");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find mine_door func_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOKeretti_OnMineDoorOpened, true);

	// Phase 0 (MineDoor) back-off once a survivor press succeeds.
	int survivorRelay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "door_trigger_survivors");

	if (survivorRelay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find door_trigger_survivors logic_relay!");
		return;
	}

	HookSingleEntityOutput(survivorRelay, "OnTrigger", ZPOKeretti_OnMineDoorOpening, false);

	// Phase 0 (MineDoor) zombie reversion.
	int zombieRelay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "door_trigger_zombies");

	if (zombieRelay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find door_trigger_zombies logic_relay!");
		return;
	}

	HookSingleEntityOutput(zombieRelay, "OnTrigger", ZPOKeretti_ReassignMineDoorButton, false);

	// Phase 1 (WarehouseDoor) button press.
	int warehouseButton = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 101494);

	if (warehouseButton == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find WarehouseDoor func_button! Hammer ID: 101494");
		return;
	}

	HookSingleEntityOutput(warehouseButton, "OnPressed", ZPOKeretti_OnWarehouseDoorButtonPressed, true);

	// Phase 2 (Radio) button press.
	int radioButton = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "obj2_button");

	if (radioButton == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find obj2_button func_button!");
		return;
	}

	HookSingleEntityOutput(radioButton, "OnPressed", ZPOKeretti_OnRadioButtonPressed, true);

	// Phase 2 (Radio) capture completion.
	int capturepoint = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "RadioCapturePoint");

	if (capturepoint == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find RadioCapturePoint!");
		return;
	}

	HookSingleEntityOutput(capturepoint, "OnHumanCaptureCompleted", ZPOKeretti_OnRadioCaptureCompleted, true);

	// Phase 3 (Files) completion.
	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "destroy_stuff_counter");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find destroy_stuff_counter math_counter!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOKeretti_OnFilesDestroyed, true);

	// Delayed chat announcement and side task start.
	CreateTimer(3.0, ZPOKeretti_Timer_AnnounceMineDoor, .flags = TIMER_FLAG_NO_MAPCHANGE);

	// Phase 0 (MineDoor) starting objective.
	int mineDoorButton = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "mine_door_button");

	if (mineDoorButton == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find mine_door_button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(mineDoorButton);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(mineDoorButton, "OnPressed", ZPOKeretti_ReassignMineDoorButton, true);
}

void ZPOKeretti_Think()
{
	if (s_FilesPhaseActive)
	{
		ZPOKeretti_UpdateFileObjective();
	}

	if (s_SideTaskActive)
	{
		ZPOKeretti_UpdateSideTask();
	}
}

// Helpers used by more than one phase.

static void ZPOKeretti_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

static void ZPOKeretti_ShuffleIntArray(int[] arr, int size)
{
	for (int i = 0; i < size - 1; i++)
	{
		int j = GetRandomInt(i, size - 1);
		int temp = arr[i];
		arr[i] = arr[j];
		arr[j] = temp;
	}
}

static void ZPOKeretti_StartParallelPhase(int which)
{
	if (which == 0)
	{
		ZPOKeretti_StartWarehouseDoorPhase();
	}
	else
	{
		ZPOKeretti_StartFilesPhase();
	}
}

static void ZPOKeretti_AdvanceParallelPhase()
{
	s_ParallelIndex++;

	if (s_ParallelIndex >= sizeof(s_ParallelOrder))
	{
		s_CurrentPhase = PHASE_FINALE;
		ZPOKeretti_StartFinale();
		return;
	}

	ZPOKeretti_StartParallelPhase(s_ParallelOrder[s_ParallelIndex]);
}

/**
 * Phase: 0 - MineDoor
 * Summary: Open the mine door.
 * Entity: func_button / func_button / func_door
 * Bot action: USE_BUTTON, then USE_BUTTON
 * Confirmation: door's OnFullyOpen output
 */
static void ZPOKeretti_ReassignMineDoorButton(const char[] output, int caller, int activator, float delay)
{
	if (s_CurrentPhase != PHASE_MINEDOOR || s_MineDoorDone)
	{
		return;
	}

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "button_mine_door");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find button_mine_door func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

static void ZPOKeretti_OnMineDoorOpening(const char[] output, int caller, int activator, float delay)
{
	if (s_CurrentPhase != PHASE_MINEDOOR)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();

	float goal[3] = { 2052.2, -205.1, 328.0 };

	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOKeretti_OnMineDoorOpened(const char[] output, int caller, int activator, float delay)
{
	s_MineDoorDone = true;

	if (s_CurrentPhase == PHASE_MINEDOOR)
	{
		NavBotZPSModInterface.ResetObjective();
	}

	ZPOKeretti_ShuffleIntArray(s_ParallelOrder, sizeof(s_ParallelOrder));
	s_ParallelIndex = 0;
	ZPOKeretti_StartParallelPhase(s_ParallelOrder[0]);
}

/**
 * Phase: 1 - WarehouseDoor
 * Summary: Open the warehouse door.
 * Entity: func_button
 * Bot action: USE_BUTTON
 * Confirmation: fixed timer after the button press
 */
static void ZPOKeretti_StartWarehouseDoorPhase()
{
	if (s_RadioDone)
	{
		ZPOKeretti_AdvanceParallelPhase();
		return;
	}

	if (s_WarehouseDoorDone)
	{
		ZPOKeretti_ActivateRadioButton();
		return;
	}

	s_CurrentPhase = PHASE_WAREHOUSE;
	ZPOKeretti_ChatMsgSurvivors("Everyone get to the radio!");

	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 101494);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find WarehouseDoor func_button! Hammer ID: 101494");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

static void ZPOKeretti_OnWarehouseDoorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	s_WarehouseDoorDone = true;

	if (s_CurrentPhase != PHASE_WAREHOUSE)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	CreateTimer(10.0, ZPOKeretti_Timer_ActivateRadio, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

static void ZPOKeretti_Timer_ActivateRadio(Handle timer)
{
	ZPOKeretti_ActivateRadioButton();
}

/**
 * Phase: 2 - Radio
 * Summary: Call for help on the radio.
 * Entity: func_button / trigger_capturepoint_zp
 * Bot action: USE_BUTTON, then MOVETO
 * Confirmation: capture point's completion output
 */
static void ZPOKeretti_ActivateRadioButton()
{
	if (s_RadioDone)
	{
		ZPOKeretti_AdvanceParallelPhase();
		return;
	}

	s_CurrentPhase = PHASE_RADIO;

	if (s_RadioButtonPressed)
	{
		ZPOKeretti_MoveToRadioCaptureZone();
		return;
	}

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "obj2_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find obj2_button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

static void ZPOKeretti_MoveToRadioCaptureZone()
{
	NavBotZPSModInterface.ResetObjective();

	float goal[3] = { -2160.0, 937.0, 320.0 };

	CanAllBotsReachGoal(goal);
	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

static void ZPOKeretti_OnRadioButtonPressed(const char[] output, int caller, int activator, float delay)
{
	s_RadioButtonPressed = true;

	if (s_CurrentPhase != PHASE_RADIO)
	{
		return;
	}

	ZPOKeretti_MoveToRadioCaptureZone();
}

static void ZPOKeretti_OnRadioCaptureCompleted(const char[] output, int caller, int activator, float delay)
{
	s_RadioDone = true;

	if (s_CurrentPhase != PHASE_RADIO)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	ZPOKeretti_AdvanceParallelPhase();
}

/**
 * Phase: 3 - Files
 * Summary: Destroy the company files.
 * Entity: func_breakable (x4) / math_counter
 * Bot action: DESTROY_ENTITY, repeated
 * Confirmation: counter's OnHitMax output
 */
static void ZPOKeretti_StartFilesPhase()
{
	if (s_FilesDone)
	{
		ZPOKeretti_AdvanceParallelPhase();
		return;
	}

	s_CurrentPhase = PHASE_FILES;
	ZPOKeretti_ChatMsgSurvivors("Quick! Destroy the files now!");
	s_FilesPhaseActive = true;
	ZPOKeretti_ShuffleIntArray(s_FileHammerIDs, sizeof(s_FileHammerIDs));
	ZPOKeretti_UpdateFileObjective();
}

static void ZPOKeretti_UpdateFileObjective()
{
	static int s_CurrentFileRef = INVALID_ENT_REFERENCE;

	if (s_CurrentFileRef != INVALID_ENT_REFERENCE && EntRefToEntIndex(s_CurrentFileRef) != INVALID_ENT_REFERENCE)
	{
		return;
	}

	for (int i = 0; i < sizeof(s_FileHammerIDs); i++)
	{
		int entity = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_breakable", s_FileHammerIDs[i]);

		if (entity != INVALID_ENT_REFERENCE)
		{
			s_CurrentFileRef = EntIndexToEntRef(entity);
			NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
			NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
			return;
		}
	}

	NavBotZPSModInterface.ResetObjective();
}

static void ZPOKeretti_OnFilesDestroyed(const char[] output, int caller, int activator, float delay)
{
	s_FilesPhaseActive = false;
	s_FilesDone = true;

	if (s_CurrentPhase != PHASE_FILES)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	ZPOKeretti_AdvanceParallelPhase();
}

/**
 * Phase: 4 - Finale
 * Summary: Turn the wheel and hit the button.
 * Entity: func_door_rotating / func_button
 * Bot action: USE_BUTTON, then USE_BUTTON
 * Confirmation: wheel's OnFullyOpen output
 */
static void ZPOKeretti_StartFinale()
{
	ZPOKeretti_ChatMsgSurvivors("This is it, turn the wheel and hit the button!");

	int wheel = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "zombiecage_1_trap_1_flamejet_wheel_1");

	if (wheel == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find zombiecage_1_trap_1_flamejet_wheel_1 func_door_rotating!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(wheel);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(wheel, "OnFullyOpen", ZPOKeretti_OnFinaleWheelOpened, true);
}

static void ZPOKeretti_OnFinaleWheelOpened(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "button_fire_me");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find button_fire_me func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
}

/**
 * Side task (not a scored objective, runs alongside the phases above)
 * Summary: Grab the hidden weapons and ammo.
 * Entity: func_button / func_door_rotating
 * Bot action: NAVBOT_PLUGINCMD_USE_ENTITY, then again
 * Confirmation: polled command-running state
 */
static void ZPOKeretti_Timer_AnnounceMineDoor(Handle timer)
{
	ZPOKeretti_ChatMsgSurvivors("Let's close the mine door first");
	ZPOKeretti_StartSideTask();
}

static void ZPOKeretti_StartSideTask()
{
	int candidates[MAXPLAYERS + 1];
	int count = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 2)
		{
			candidates[count] = client;
			count++;
		}
	}

	if (count == 0)
	{
		// No survivor bots in game yet, skip the side task entirely.
		return;
	}

	int chosen = candidates[GetRandomInt(0, count - 1)];

	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 372483);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find hidden_door unlock func_button! Hammer ID: 372483");
		return;
	}

	NavBot bot = view_as<NavBot>(chosen);
	bot.SendPluginCommand(NAVBOT_PLUGINCMD_USE_ENTITY, button);

	s_SideTaskBotRef = EntIndexToEntRef(chosen);
	s_SideTaskStep = SIDETASK_AT_BUTTON;
	s_SideTaskActive = true;
}

static void ZPOKeretti_UpdateSideTask()
{
	int client = EntRefToEntIndex(s_SideTaskBotRef);

	if (client == INVALID_ENT_REFERENCE || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		s_SideTaskActive = false;
		return;
	}

	NavBot bot = view_as<NavBot>(client);
	Address behavior = bot.GetBehaviorInterface();

	if (NavBotBehaviorInterface.IsRunningPluginCommand(behavior))
	{
		// Still walking to / using the current target, check again next tick.
		return;
	}

	if (s_SideTaskStep == SIDETASK_AT_BUTTON)
	{
		int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door_rotating", "hidden_door");

		if (door == INVALID_ENT_REFERENCE)
		{
			LogError("zpo_keretti: Failed to find hidden_door func_door_rotating!");
			s_SideTaskActive = false;
			return;
		}

		bot.SendPluginCommand(NAVBOT_PLUGINCMD_USE_ENTITY, door);
		s_SideTaskStep = SIDETASK_AT_DOOR;
		return;
	}

	// SIDETASK_AT_DOOR finished - side task is done, no further action needed.
	s_SideTaskActive = false;
}
