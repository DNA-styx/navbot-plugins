#include <sourcemod>
#include <navbot>
#undef REQUIRE_EXTENSIONS
#include <ripext>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.1.0"

public Plugin myinfo =
{
	name = "NavBot NavMesh Manager",
	author = "caxanga334",
	description = "Manages navigation mesh files.",
	version = PLUGIN_VERSION,
	url = "https://github.com/caxanga334/navbot-plugins"
};

ConVar cvar_auto_download = null;
ConVar cvar_download_url = null;
ConVar cvar_auto_generate = null;
ConVar cvar_prefer_unique_names = null;
bool g_ripext_available;
bool g_wasuniquemap;
bool g_isparsingincludes;
char g_modfolder[128];
char g_navmeshfilepath[PLATFORM_MAX_PATH];
char g_placedbfilepath[PLATFORM_MAX_PATH];
char g_settingsfilepath[PLATFORM_MAX_PATH];
int g_includesDownloaded;
ArrayList g_placeIncludes = null;

#include "navmesh_manager/parser.sp"
#include "navmesh_manager/functions.sp"
#include "navmesh_manager/frames.sp"
#include "navmesh_manager/http_callbacks.sp"

public void OnPluginStart()
{
	cvar_auto_download = CreateConVar("sm_nb_navmesh_manager_auto_download", "0", "If enabled, attempt to download missing nav mesh files from a HTTP mirror.");
	cvar_download_url = CreateConVar("sm_nb_navmesh_manager_download_url", "", "URL to the nav mesh HTTP mirror.", FCVAR_PROTECTED);
	cvar_auto_generate = CreateConVar("sm_nb_navmesh_manager_auto_gen", "0", "If enabled, automatically generates a nav mesh for maps that don't have one.");
	AutoExecConfig(true);
	g_placeIncludes = new ArrayList(ByteCountToCells(256));
}

public void OnAllPluginsLoaded()
{
	// this convar is created by the extension.
	cvar_prefer_unique_names = FindConVar("sm_navbot_prefer_unique_map_names");
	g_ripext_available = LibraryExists("ripext");
	NavBotModInterface.GetModFolder(g_modfolder, sizeof(g_modfolder));
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "navbot") == 0)
	{
		SetFailState("NavBot unloaded!");
	}

	if (strcmp(name, "ripext") == 0)
	{
		g_ripext_available = false;
	}
}

public void OnConfigsExecuted()
{
	g_placeIncludes.Clear();
	CreateTimer(0.5, Timer_CheckNavMesh, _, TIMER_FLAG_NO_MAPCHANGE);
}

void Timer_CheckNavMesh(Handle timer)
{
	if (NavBotNavMesh.IsLoaded())
	{
		return; // already loaded, nothing needs to be done here.
	}

	NavBotNavErrorType loadResult = NavBotNavMesh.GetLastLoadResult();

	if (loadResult != NAVBOT_NAV_CANT_ACCESS_FILE)
	{
		return; // a file already exists but is invalid, leave this to the server ops to fix it.
	}

	// file is missing

	if (g_ripext_available && cvar_auto_download.BoolValue)
	{
		DownloadNavMeshFromMirror();
		return;
	}

	if (cvar_auto_generate.BoolValue)
	{
		LogMessage("Navmesh not available, generating one.");
		NavBotNavMesh.Generate();
	}
}

