#include <sourcemod>
#include <sdktools>
#include <navbot>
#include <navbot_stocks>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Pathfinder",
	author = "caxanga334",
	description = "Allows players to find other players via pathfinding.",
	version = "1.0.0",
	url = "https://github.com/caxanga334/navbot-plugins"
};

enum struct PlayerData
{
	bool pathing; // true if pathing is enabled
	int target; // serial of the target player
	float nextupdatetime; // gametime of the next path update
	float commandcooldown; // cooldown to prevent command spam

	void Reset()
	{
		this.pathing = false;
		this.target = 0;
		this.nextupdatetime = 0.0;
		this.commandcooldown = 0.0;
	}

	void StopPathing()
	{
		this.pathing = false;
		this.target = 0;
		this.nextupdatetime = 0.0;
	}
	
	// Gets the target client, returns 0 if the target is invalid.
	int GetTargetClient()
	{
		int client = GetClientFromSerial(this.target);
		return client;
	}

	bool IsCommandInCooldown()
	{
		return this.commandcooldown >= GetGameTime();
	}

	bool ShouldUpdatePath()
	{
		return this.nextupdatetime < GetGameTime();
	}

	void SetNextUpdateTime(float delay)
	{
		this.nextupdatetime = GetGameTime() + delay;
	}
}

int g_laserSprite;
int g_haloSprite;
PlayerData g_data[MAXPLAYERS + 1];
NavBotNavAStarSearch g_pathsearch = null;
ConVar cvar_max_paths_per_cycle = null;
ConVar cvar_path_frequency = null;
ConVar cvar_think_frequency = null;
ConVar cvar_max_path_segments = null;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	RegAdminCmd("sm_pathfind", CMD_PathFind, ADMFLAG_CHEATS, "Enables pathfinding to a target player.");

	cvar_max_paths_per_cycle = CreateConVar("sm_pathfinder_max_per_cycle", "2", "Maximum number of players to update per cycle.", FCVAR_NONE, true, 1.0, true, 32.0);
	cvar_path_frequency = CreateConVar("sm_pathfinder_path_update_frequency", "2.0", "Update an individual player's path every this many seconds.", FCVAR_NONE, true, 0.5);
	cvar_think_frequency = CreateConVar("sm_pathfinder_think_frequency", "0.5", "Time in seconds between path update checks.", FCVAR_NONE, true, 0.1);
	cvar_max_path_segments = CreateConVar("sm_pathfinder_max_segments", "7", "Maximum number of path segments to draw in a single update.", FCVAR_NONE, true, 5.0, true, 15.0);

	AutoExecConfig();
}

public void OnMapStart()
{
	g_laserSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_haloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	CreateTimer(cvar_think_frequency.FloatValue, Timer_UpdatePath, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
	g_data[client].Reset();
}

public void OnClientDisconnect(int client)
{
	g_data[client].Reset();
}

static int s_pathingTeam; // team the player belongs to.

void PathCost_Init(int player)
{
	s_pathingTeam = GetClientTeam(player);
}

float PathCost_Player(Address toArea, Address fromArea, Address ladder, Address offmeshconn, Address elevator)
{
	if (fromArea == Address_Null)
	{
		// First area in the path, no cost.
		return 0.0;
	}

	if (NavBotNavArea.IsBlocked(toArea, s_pathingTeam))
	{
		return -1.0; // this area is blocked for the player's team
	}

	float dist = 0.0;

	if (offmeshconn != Address_Null)
	{
		dist = NavBotNavOffMeshConnection.GetConnectionLength(offmeshconn);
	}
	else
	{
		if (ladder == Address_Null && elevator == Address_Null)
		{
			// ground path, check heights
			float heightdiff = NavBotNavArea.ComputeAdjacentConnectionHeightChange(fromArea, toArea);

			if (heightdiff > 72.0)
			{
				return -1.0; // can't climb by crouch jumping
			}

			if (heightdiff <= -900.0)
			{
				return -1.0; // too high to fall
			}
		}

		// for now just use distance between the areas
		float v1[3];
		float v2[3];
		NavBotNavArea.GetCenter(toArea, v1);
		NavBotNavArea.GetCenter(fromArea, v2);
		dist = GetVectorDistance(v1, v2);
	}

	float cost = dist;
	return cost;
}

public void OnAllPluginsLoaded()
{
	g_pathsearch = new NavBotNavAStarSearch();
	g_pathsearch.GCostCallback = PathCost_Player;
	g_pathsearch.HCostCallback = NB_SimpleHCost; // use stock function
}

Action CMD_PathFind(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "This command can only be used in-game!");
		return Plugin_Handled;
	}

	if (g_data[client].IsCommandInCooldown())
	{
		ReplyToCommand(client, "The command is currently in cooldown!");
		return Plugin_Handled;
	}

	g_data[client].commandcooldown = GetGameTime() + 5.0;

	if (!NavBotNavMesh.IsLoaded())
	{
		ReplyToCommand(client, "Nav mesh not available for the current map!");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		if (g_data[client].pathing)
		{
			g_data[client].StopPathing();
			ReplyToCommand(client, "Pathing disabled!");
			return Plugin_Handled;
		}

		ReplyToCommand(client, "To enable pathing, use sm_pathfind <target name>. Call with no args to disable pathing.");
		return Plugin_Handled;
	}

	char arg1[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));

	int targets[32];
	char tgname[256];
	bool tn_is_ml = false;
	int num_targets = ProcessTargetString(arg1, client, targets, sizeof(targets), COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_CONNECTED | COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_IMMUNITY, tgname, sizeof(tgname), tn_is_ml);

	if (num_targets <= 0)
	{
		ReplyToTargetError(client, num_targets);
		return Plugin_Handled;
	}

	// sanity
	if (num_targets > 1)
	{
		ReplyToCommand(client, "Only a single target is allowed!");
		return Plugin_Handled;
	}

	// we only want one target
	g_data[client].target = GetClientSerial(targets[0]);
	g_data[client].pathing = true;
	g_data[client].nextupdatetime = GetGameTime() + 0.5;

	LogAction(client, targets[0], "%L enabled pathfinding to %L.", client, targets[0]);
	ShowActivity2(client, "[SM] ", "%N enabled pathfinding to %N.", client, targets[0]);
	return Plugin_Handled;
}

void Timer_UpdatePath(Handle timer)
{
	int limit = cvar_max_paths_per_cycle.IntValue;
	int n = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_data[i].pathing && IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (g_data[i].ShouldUpdatePath())
			{
				UpdatePathForClient(i);

				if (++n >= limit)
				{
					return;
				}
			}
		}
	}
}

void UpdatePathForClient(int client)
{
	int target = g_data[client].GetTargetClient();

	if (target == 0)
	{
		g_data[client].StopPathing();
		return;
	}

	float delay = cvar_path_frequency.FloatValue;

	if (!IsPlayerAlive(target))
	{
		g_data[client].SetNextUpdateTime(delay * 5.0);
		return;
	}

	NavBotBasePlayer player = NavBotManager.GetBasePlayer(client);

	if (player.IsNull)
	{
		// for sanity but this should never happen
		g_data[client].SetNextUpdateTime(delay * 5.0);
		return;
	}

	Address area = player.GetLastKnownNavArea();

	if (area == Address_Null)
	{
		g_data[client].SetNextUpdateTime(delay * 5.0);
		return;
	}

	float goal[3];
	GetClientAbsOrigin(target, goal);
	Address endArea = NavBotNavMesh.GetNearestNavArea(goal, 512.0, false, true, player.TeamNum);

	if (endArea == Address_Null)
	{
		g_data[client].SetNextUpdateTime(delay * 5.0);
		PrintToChat(client, "Could not get nav area near target!");
		return;
	}

	g_pathsearch.StartArea = area;
	g_pathsearch.SetGoalPosition(goal);
	PathCost_Init(client);
	g_pathsearch.RunSearch();

	if (g_pathsearch.FoundPath)
	{
		g_data[client].SetNextUpdateTime(delay);
	}
	else
	{
		g_data[client].SetNextUpdateTime(delay * 5.0);
		PrintToChat(client, "No path to the target was found!");
		return;
	}

	DrawPath(client, goal);
}

void CopyVector(const float source[3], float dest[3])
{
	dest[0] = source[0];
	dest[1] = source[1];
	dest[2] = source[2];
}

void DrawLine(int client, const float start[3], const float end[3], const float life)
{
	int colors[4] = { 255, 255, 0, 255 };

	TE_SetupBeamPoints(start, end, g_laserSprite, g_haloSprite, 0, 4, life, 1.0, 1.0, 1, 0.0, colors, 0);
	TE_SendToClient(client);
}

void DrawPath(int client, const float goal[3])
{
	NavBotNavAreaVector path = g_pathsearch.GetPath();

	if (path.IsEmpty())
	{
		delete path;
		return;
	}

	float life = cvar_path_frequency.FloatValue + 0.5;
	float first[3];
	GetClientAbsOrigin(client, first);

	if (path.Size == 1)
	{
		delete path;
		DrawLine(client, first, goal, life);
		return;
	}

	// the first vector element is the path's end
	// loop backwards to create a path from the start
	// the path start doesn't have a parent so we start from the second last element

	
	float second[3];
	int limit = cvar_max_path_segments.IntValue;
	int n = 0;

	for (int i = path.Size - 2; i >= 0; i--)
	{
		Address toArea = path.At(i);
		Address node = g_pathsearch.GetNodeForArea(toArea);
		NavBotNavTraverseType how = NavBotNavAStarSearchNode.GetTraverseType(node);
		Address fromArea = NavBotNavAStarSearchNode.GetArea(NavBotNavAStarSearchNode.GetParent(node));

		switch (how)
		{
			case NAVBOT_NAV_TT_GO_NORTH, NAVBOT_NAV_TT_GO_EAST, NAVBOT_NAV_TT_GO_SOUTH, NAVBOT_NAV_TT_GO_WEST:
			{
				// ground path
				NavBotNavArea.ComputeClosestPointInPortal(fromArea, toArea, view_as<NavBotNavDirType>(how), first, second);
				DrawLine(client, first, second, life);
			}
			default:
			{
				// everything else
				NavBotNavArea.GetCenter(toArea, second);
				DrawLine(client, first, second, life);
			}
		}

		CopyVector(second, first);

		if (n++ >= limit)
		{
			delete path;
			return;
		}
	}

	// n did not reach max path segments, draw a line to target
	DrawLine(client, first, goal, life);
	delete path;
}