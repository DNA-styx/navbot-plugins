
void RegisterDebugCommands()
{
	RegAdminCmd("sm_nbzpodebug_reset", DebugCommand_Reset, ADMFLAG_CHEATS, "Reset and sets the objective to none.");
	RegAdminCmd("sm_nbzpodebug_set_use_entity", DebugCommand_ForceUseEntityObjective, ADMFLAG_CHEATS, "Force change the objective to use entity.");
	RegAdminCmd("sm_nbzpodebug_set_destroy_entity", DebugCommand_ForceDestroyEntityObjective, ADMFLAG_CHEATS, "Force change the objective to destroy entity.");
}

Action DebugCommand_Reset(int client, int args)
{
	// ResetObjective already sets to NONE but doesn't trigger a change in behavior, so in this case SetCurrentObjective needs to be called first.
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_NONE);
	NavBotZPSModInterface.ResetObjective();
	ReplyToCommand(client, "Objective reset!");
	LogAction(client, -1, "%L forced the objective to reset.", client);

	return Plugin_Handled;
}

Action DebugCommand_ForceUseEntityObjective(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_nbzpodebug_set_use_entity <entity index>");
		return Plugin_Handled;
	}

	int entity = INVALID_ENT_REFERENCE;

	if (!GetCmdArgIntEx(1, entity))
	{
		return Plugin_Handled;
	}

	if (!IsValidEntity(entity))
	{
		ReplyToCommand(client, "Entity %i is not valid!", entity);
		return Plugin_Handled;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveGenericTargetEntity(entity);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_DESTROY_ENTITY);
	ReplyToCommand(client, "Objective changed to use entity %i!", entity);
	LogAction(client, -1, "%L forced the objective to be DESTROY_ENTITY (%i).", client, entity);

	return Plugin_Handled;
}

Action DebugCommand_ForceDestroyEntityObjective(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_nbzpodebug_set_use_entity <entity index>");
		return Plugin_Handled;
	}

	int entity = INVALID_ENT_REFERENCE;

	if (!GetCmdArgIntEx(1, entity))
	{
		return Plugin_Handled;
	}

	if (!IsValidEntity(entity))
	{
		ReplyToCommand(client, "Entity %i is not valid!", entity);
		return Plugin_Handled;
	}

	NavBotZPSModInterface.ResetObjective();
	NavBotZPSModInterface.SetObjectiveUseButton(entity);
	NavBotZPSModInterface.SetCurrentObjective(NAVBOT_ZPS_OBJECTIVE_USE_BUTTON);
	ReplyToCommand(client, "Objective changed to use entity %i!", entity);
	LogAction(client, -1, "%L forced the objective to be USE_BUTTON (%i).", client, entity);

	return Plugin_Handled;
}