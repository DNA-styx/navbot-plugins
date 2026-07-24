/**
 * zpo_keretti.sp
 *
 * NavBot ZPS objective support module for the zpo_keretti map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.10.0
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase order: MineDoor first for the numerical advantage, then Radio and
 * Files in a random order, then Finale.
 *
 * Real players can complete any of MineDoor/WarehouseDoor/Radio/Files
 * independently of the bot script, so every completion/reversion signal
 * (mine_door, door_trigger_survivors, door_trigger_zombies, WarehouseDoor
 * button, obj2_button, RadioCapturePoint, destroy_stuff_counter) is hooked
 * upfront in Init(), not lazily when the script reaches that phase. Each
 * hook callback records a s_*Done flag regardless of what phase the script
 * currently thinks it's in, and only calls ResetObjective()/reassigns the
 * bot's current objective when s_CurrentPhase matches - otherwise a human
 * finishing something out of order would yank the bot off whatever it's
 * actually doing. Each StartX phase function checks its own s_*Done flag
 * before assigning the bot to work on it, and skips straight to the next
 * step if it's already done. WarehouseDoor specifically needs this: its
 * button has "wait" "-1" (one-shot, confirmed from source), so a hook
 * registered late would simply miss an early human press for good.
 *
 * MineDoor is a two-button chain: mine_door_button unlocks button_mine_door.
 * Zombies can revert an in-progress (not yet fully open) door via
 * door_trigger_zombies. It re-enables door_trigger_survivors and fires
 * mine_door,Close. Both door_trigger_zombies's OnTrigger and
 * mine_door_button's OnPressed are hooked to the same
 * ZPOKeretti_ReassignMineDoorButton, since both cases just need
 * button_mine_door (re)assigned. door_trigger_survivors's OnTrigger (fires
 * once a press actually succeeds) backs the bot off (ResetObjective) while
 * the door is mid-swing, instead of it re-pressing on the button's 3s
 * cooldown until OnFullyOpen.
 *
 * WarehouseDoor is a func_tracktrain with no completion output, so once its
 * button is pressed the bot roams (ResetObjective), then a 10s timer starts
 * the Radio phase - no wait for the door to actually finish opening. Only
 * runs ahead of Radio.
 *
 * RadioCapturePoint is a hold-in-zone capture (allowdrain 1), approximated
 * as a single MOVETO.
 *
 * Files is 4x func_breakable file cabinets, resolved by Hammer ID and
 * destroyed one at a time, polled every Think() tick while active.
 * Completion is confirmed via destroy_stuff_counter's OnHitMax. The target
 * order is shuffled once when the phase starts.
 *
 * Finale: button_fire_me starts locked - it's only unlocked once
 * zombiecage_1_trap_1_flamejet_wheel_1 (a func_door_rotating valve wheel,
 * not a func_button) is fully opened. Targets the wheel directly with
 * USE_BUTTON, hooks its OnFullyOpen, then reassigns to button_fire_me - now
 * genuinely unlocked by the map's own I/O. No further hook needed after
 * that press; it cascades into game_win_human,EndGame on the map's own I/O.
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
static bool s_RadioDone = false;
static bool s_FilesDone = false;
static int s_ParallelOrder[2] = { 0, 1 }; // 0 = Radio, 1 = Files
static int s_ParallelIndex = 0;
static int s_FileHammerIDs[4] = { 269523, 269836, 269880, 269862 };

void ZPOKeretti_ChatMsgSurvivors(const char[] msg)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			PrintToChat(client, "\x04[NAV]\x01 %s", msg);
		}
	}
}

void ZPOKeretti_ShuffleFileOrder()
{
	for (int i = 0; i < sizeof(s_FileHammerIDs) - 1; i++)
	{
		int j = GetRandomInt(i, sizeof(s_FileHammerIDs) - 1);
		int temp = s_FileHammerIDs[i];
		s_FileHammerIDs[i] = s_FileHammerIDs[j];
		s_FileHammerIDs[j] = temp;
	}
}

void ZPOKeretti_ShuffleParallelOrder()
{
	for (int i = 0; i < sizeof(s_ParallelOrder) - 1; i++)
	{
		int j = GetRandomInt(i, sizeof(s_ParallelOrder) - 1);
		int temp = s_ParallelOrder[i];
		s_ParallelOrder[i] = s_ParallelOrder[j];
		s_ParallelOrder[j] = temp;
	}
}

void ZPOKeretti_OnFinaleWheelOpened(const char[] output, int caller, int activator, float delay)
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

void ZPOKeretti_StartFinale()
{
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

void ZPOKeretti_AdvanceParallelPhase()
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

void ZPOKeretti_OnFilesDestroyed(const char[] output, int caller, int activator, float delay)
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

void ZPOKeretti_UpdateFileObjective()
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

void ZPOKeretti_StartFilesPhase()
{
	if (s_FilesDone)
	{
		ZPOKeretti_AdvanceParallelPhase();
		return;
	}

	s_CurrentPhase = PHASE_FILES;
	ZPOKeretti_ChatMsgSurvivors("Quick! Destroy the files now!");
	s_FilesPhaseActive = true;
	ZPOKeretti_ShuffleFileOrder();
	ZPOKeretti_UpdateFileObjective();
}

void ZPOKeretti_OnRadioCaptureCompleted(const char[] output, int caller, int activator, float delay)
{
	s_RadioDone = true;

	if (s_CurrentPhase != PHASE_RADIO)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	ZPOKeretti_AdvanceParallelPhase();
}

void ZPOKeretti_OnRadioButtonPressed(const char[] output, int caller, int activator, float delay)
{
	if (s_CurrentPhase != PHASE_RADIO)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();

	float goal[3];
	goal[0] = -2160.0;
	goal[1] = 937.0;
	goal[2] = 320.0;

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);
}

void ZPOKeretti_ActivateRadioButton()
{
	if (s_RadioDone)
	{
		ZPOKeretti_AdvanceParallelPhase();
		return;
	}

	s_CurrentPhase = PHASE_RADIO;

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

void ZPOKeretti_Timer_ActivateRadio(Handle timer)
{
	ZPOKeretti_ActivateRadioButton();
}

void ZPOKeretti_OnWarehouseDoorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	s_WarehouseDoorDone = true;

	if (s_CurrentPhase != PHASE_WAREHOUSE)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	CreateTimer(10.0, ZPOKeretti_Timer_ActivateRadio, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

void ZPOKeretti_StartWarehouseDoorPhase()
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

void ZPOKeretti_StartParallelPhase(int which)
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

void ZPOKeretti_OnMineDoorOpening(const char[] output, int caller, int activator, float delay)
{
	if (s_CurrentPhase != PHASE_MINEDOOR)
	{
		return;
	}

	NavBotZPSModInterface.ResetObjective();
}

void ZPOKeretti_OnMineDoorOpened(const char[] output, int caller, int activator, float delay)
{
	s_MineDoorDone = true;

	if (s_CurrentPhase == PHASE_MINEDOOR)
	{
		NavBotZPSModInterface.ResetObjective();
	}

	ZPOKeretti_ShuffleParallelOrder();
	s_ParallelIndex = 0;
	ZPOKeretti_StartParallelPhase(s_ParallelOrder[0]);
}

void ZPOKeretti_ReassignMineDoorButton(const char[] output, int caller, int activator, float delay)
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

void ZPOKeretti_Think()
{
	if (s_FilesPhaseActive)
	{
		ZPOKeretti_UpdateFileObjective();
	}
}

void ZPOKeretti_Init()
{
	g_ThinkFunc = ZPOKeretti_Think;
	s_FilesPhaseActive = false;
	s_ParallelIndex = 0;
	s_CurrentPhase = PHASE_MINEDOOR;
	s_MineDoorDone = false;
	s_WarehouseDoorDone = false;
	s_RadioDone = false;
	s_FilesDone = false;

	int door = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_door", "mine_door");

	if (door == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find mine_door func_door!");
		return;
	}

	HookSingleEntityOutput(door, "OnFullyOpen", ZPOKeretti_OnMineDoorOpened, true);

	int survivorRelay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "door_trigger_survivors");

	if (survivorRelay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find door_trigger_survivors logic_relay!");
		return;
	}

	HookSingleEntityOutput(survivorRelay, "OnTrigger", ZPOKeretti_OnMineDoorOpening, false);

	int zombieRelay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "door_trigger_zombies");

	if (zombieRelay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find door_trigger_zombies logic_relay!");
		return;
	}

	HookSingleEntityOutput(zombieRelay, "OnTrigger", ZPOKeretti_ReassignMineDoorButton, false);

	int warehouseButton = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", 101494);

	if (warehouseButton == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find WarehouseDoor func_button! Hammer ID: 101494");
		return;
	}

	HookSingleEntityOutput(warehouseButton, "OnPressed", ZPOKeretti_OnWarehouseDoorButtonPressed, true);

	int radioButton = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "obj2_button");

	if (radioButton == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find obj2_button func_button!");
		return;
	}

	HookSingleEntityOutput(radioButton, "OnPressed", ZPOKeretti_OnRadioButtonPressed, true);

	int capturepoint = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "RadioCapturePoint");

	if (capturepoint == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find RadioCapturePoint!");
		return;
	}

	HookSingleEntityOutput(capturepoint, "OnHumanCaptureCompleted", ZPOKeretti_OnRadioCaptureCompleted, true);

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "destroy_stuff_counter");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find destroy_stuff_counter math_counter!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOKeretti_OnFilesDestroyed, true);

	ZPOKeretti_ChatMsgSurvivors("We're closing the mine door first");

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
