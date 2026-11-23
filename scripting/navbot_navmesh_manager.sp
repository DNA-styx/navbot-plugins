#include <sourcemod>
#include <navbot>
#undef REQUIRE_EXTENSIONS
#include <SteamWorks>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.2.0"
#define URL_MAX_LEN 4096

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
ConVar cvar_create_autodl_file = null;
ConVar cvar_verbose = null;
ConVar cvar_prefer_unique_names = null;
bool g_steamworks;
bool g_isparsingincludes;
bool g_urlset;
char g_downloadurl[URL_MAX_LEN + 1];
char g_modfolder[128];
int g_includesDownloaded;
ArrayList g_placeIncludes = null;

typedef OnDoneFunc = function void (EHTTPStatusCode statusCode, bool uniquename);

enum struct RequestData
{
	char downloadpath[PLATFORM_MAX_PATH]; // path to where the file will be written to
	bool uniquename; // true if the file is using unique workshop name
	Function ondone;
}

#include "navmesh_manager/parser.sp"
#include "navmesh_manager/functions.sp"
#include "navmesh_manager/frames.sp"
#include "navmesh_manager/http_callbacks.sp"

public void OnPluginStart()
{
	cvar_auto_download = CreateConVar("sm_nb_navmesh_manager_auto_download", "0", "If enabled, attempt to download missing nav mesh files from a HTTP mirror.");
	cvar_download_url = CreateConVar("sm_nb_navmesh_manager_download_url", "", "URL to the nav mesh HTTP mirror.", FCVAR_PROTECTED);
	cvar_auto_generate = CreateConVar("sm_nb_navmesh_manager_auto_gen", "0", "If enabled, automatically generates a nav mesh for maps that don't have one.");
	cvar_create_autodl_file = CreateConVar("sm_nb_navmesh_manager_create_autodl_file", "1", 
	"If enabled, creates a .autodownload file for downloaded nav meshes.\nUsed to mark which files were downloaded.");
	cvar_verbose = CreateConVar("sm_nb_navmesh_manager_verbose", "0", "Enables verbose logging.");
	AutoExecConfig(true);
	cvar_download_url.AddChangeHook(OnDownloadURLConVarChanged);
	g_placeIncludes = new ArrayList(ByteCountToCells(256));
}

public void OnAllPluginsLoaded()
{
	// this convar is created by the extension.
	cvar_prefer_unique_names = FindConVar("sm_navbot_prefer_unique_map_names");
	g_steamworks = LibraryExists("SteamWorks");
	NavBotModInterface.GetModFolder(g_modfolder, sizeof(g_modfolder));
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "SteamWorks") == 0)
	{
		g_steamworks = false;
	}
}

void OnDownloadURLConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_downloadurl, sizeof(g_downloadurl));
	g_urlset = strlen(g_downloadurl) > 3;
}

public void OnConfigsExecuted()
{
	cvar_download_url.GetString(g_downloadurl, sizeof(g_downloadurl));
	g_urlset = strlen(g_downloadurl) > 3;
	g_placeIncludes.Clear();
	CreateTimer(0.5, Timer_CheckNavMesh, _, TIMER_FLAG_NO_MAPCHANGE);
}

bool IsSteamWorksExtensionAvailable()
{
	return g_steamworks;
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

	if (IsSteamWorksExtensionAvailable() && cvar_auto_download.BoolValue)
	{
		if (!g_urlset)
		{
			LogError("Auto download enabled but no download URL was configured!");
			return;
		}

		DownloadNavMeshFromMirror();
		return;
	}

	GenerateNavMesh();
}

