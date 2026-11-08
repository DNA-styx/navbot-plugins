
Action CMD_ListPlayers(int client, int args)
{
    ReplyToCommand(client, "Listing players:");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
        {
            continue;
        }

        int userid = GetClientUserId(i);

        if (IsFakeClient(i))
        {
            if (NavBotManager.IsNavBot(i))
            {
                ReplyToCommand(client, "%N [#%i] is a NavBot.", i, userid);
                continue;
            }

            ReplyToCommand(client, "%N [#%i] is a bot.", i, userid);
            continue;
        }

        ReplyToCommand(client, "%N [#%i] is a human.", i, userid);
    }

    return Plugin_Handled;
}

