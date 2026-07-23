/**
 * zpo_keretti.sp
 *
 * NavBot ZPS objective support module for the zpo_keretti map.
 * Intended to be #included by zps_objective_support.sp.
 *
 * Module version: 0.9.2
 * Author: Claude.ai guided by DNA.styx
 *
 * Phase order: MineDoor first for the numerical advantage, then Radio and
 * Files in a random order, then Finale.
 *
 * MineDoor is a two-button chain: mine_door_button unlocks button_mine_door.
 * Zombies can revert an in-progress (not yet fully open) door via
 * door_trigger_zombies. It re-enables door_trigger_survivors and fires
 * mine_door,Close. Its OnTrigger is hooked to reassign button_mine_door and
 * force a retry. door_trigger_survivors's OnTrigger (fires once a press
 * actually succeeds) is also hooked, to ResetObjective() so the bot stops
 * re-pressing button_mine_door while the door is mid-swing - without this
 * the bot has no signal to back off and just re-presses on the button's 3s
 * cooldown until OnFullyOpen.
 *
 * WarehouseDoor is a func_tracktrain with no completion output, so the bot
 * presses the button, roams (ResetObjective), then a 10s timer starts the
 * Radio phase - no wait for the door to actually finish opening. Only runs
 * ahead of Radio.
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

static bool s_FilesPhaseActive = false;
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
		ZPOKeretti_StartFinale();
		return;
	}

	ZPOKeretti_StartParallelPhase(s_ParallelOrder[s_ParallelIndex]);
}

void ZPOKeretti_OnFilesDestroyed(const char[] output, int caller, int activator, float delay)
{
	s_FilesPhaseActive = false;
	NavBotZPSModInterface.ResetObjective();
	ZPOKeretti_AdvanceParallelPhase();
}

void ZPOKeretti_UpdateFileObjective()
{
	static int s_CurrentFileRef = INVALID_ENT_REFERENCE;

	// Current target still alive, nothing to do.
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

	// No files left to target - completion is confirmed by
	// ZPOKeretti_OnFilesDestroyed, hooked in ZPOKeretti_StartFilesPhase.
	NavBotZPSModInterface.ResetObjective();
}

void ZPOKeretti_StartFilesPhase()
{
	ZPOKeretti_ChatMsgSurvivors("Quick! Destroy the files now!");

	int counter = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "math_counter", "destroy_stuff_counter");

	if (counter == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find destroy_stuff_counter math_counter!");
		return;
	}

	HookSingleEntityOutput(counter, "OnHitMax", ZPOKeretti_OnFilesDestroyed, true);
	s_FilesPhaseActive = true;
	ZPOKeretti_ShuffleFileOrder();
	ZPOKeretti_UpdateFileObjective();
}

void ZPOKeretti_OnRadioCaptureCompleted(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	ZPOKeretti_AdvanceParallelPhase();
}

void ZPOKeretti_OnRadioButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();

	float goal[3];
	goal[0] = -2160.0;
	goal[1] = 937.0;
	goal[2] = 320.0;

	NavBotZPSModInterface.SetObjectiveMoveGoal(goal);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_MOVETO);

	int capturepoint = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "trigger_capturepoint_zp", "RadioCapturePoint");

	if (capturepoint == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find RadioCapturePoint!");
		return;
	}

	HookSingleEntityOutput(capturepoint, "OnHumanCaptureCompleted", ZPOKeretti_OnRadioCaptureCompleted, true);
}

void ZPOKeretti_ActivateRadioButton()
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "obj2_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find obj2_button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOKeretti_OnRadioButtonPressed, true);
}

void ZPOKeretti_Timer_ActivateRadio(Handle timer)
{
	ZPOKeretti_ActivateRadioButton();
}

void ZPOKeretti_OnWarehouseDoorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	CreateTimer(10.0, ZPOKeretti_Timer_ActivateRadio, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

void ZPOKeretti_StartWarehouseDoorPhase()
{
	ZPOKeretti_ChatMsgSurvivors("Everyone get to the radio!");

	const int hammerid = 101494;
	int button = FindEntityOfHammerID(INVALID_ENT_REFERENCE, "func_button", hammerid);

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find WarehouseDoor func_button! Hammer ID: %i", hammerid);
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOKeretti_OnWarehouseDoorButtonPressed, true);
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

void ZPOKeretti_ReassignMineDoorButton()
{
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

void ZPOKeretti_OnMineDoorZombieRevert(const char[] output, int caller, int activator, float delay)
{
	ZPOKeretti_ReassignMineDoorButton();
}

void ZPOKeretti_OnMineDoorOpened(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
	ZPOKeretti_ShuffleParallelOrder();
	s_ParallelIndex = 0;
	ZPOKeretti_StartParallelPhase(s_ParallelOrder[0]);
}

void ZPOKeretti_OnMineDoorOpening(const char[] output, int caller, int activator, float delay)
{
	NavBotZPSModInterface.ResetObjective();
}

void ZPOKeretti_OnMineDoorButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "button_mine_door");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find button_mine_door func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);

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

	int relay = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "logic_relay", "door_trigger_zombies");

	if (relay == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find door_trigger_zombies logic_relay!");
		return;
	}

	HookSingleEntityOutput(relay, "OnTrigger", ZPOKeretti_OnMineDoorZombieRevert, false);
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

	ZPOKeretti_ChatMsgSurvivors("Let's close the mine door first");

	int button = FindNamedEntityOfClassname(INVALID_ENT_REFERENCE, "func_button", "mine_door_button");

	if (button == INVALID_ENT_REFERENCE)
	{
		LogError("zpo_keretti: Failed to find mine_door_button func_button!");
		return;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(button);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	HookSingleEntityOutput(button, "OnPressed", ZPOKeretti_OnMineDoorButtonPressed, true);
}
