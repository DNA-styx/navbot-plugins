
void BuildPathToNavMeshFile(bool uniquemapname)
{
	char mapname[128];

	if (uniquemapname)
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_UNIQUE, mapname, sizeof(mapname));
	}
	else
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_CLEAN, mapname, sizeof(mapname));
	}

	BuildPath(Path_SM, g_navmeshfilepath, sizeof(g_navmeshfilepath), "data/navbot/%s/%s.smnav", g_modfolder, mapname);
}

void DeleteNavMeshFile()
{
	DeleteFile(g_navmeshfilepath, false);
}

void DeletePlaceDBFile()
{
	DeleteFile(g_placedbfilepath, false);
}

void DeleteNavSettingsFile()
{
	DeleteFile(g_settingsfilepath, false);
}

void DeletePlaceDBIncludeFile(const char[] file)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/navbot/%s/%s.cfg", g_modfolder, file);
	DeleteFile(path, false);
}

void BuildPathToPlaceDatabaseFile(bool uniquemapname)
{
	char mapname[128];

	if (uniquemapname)
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_UNIQUE, mapname, sizeof(mapname));
	}
	else
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_CLEAN, mapname, sizeof(mapname));
	}

	BuildPath(Path_SM, g_placedbfilepath, sizeof(g_placedbfilepath), "data/navbot/%s/%s_places.cfg", g_modfolder, mapname);
}

void BuildPathToSettingsFile(bool uniquemapname)
{
	char mapname[128];

	if (uniquemapname)
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_UNIQUE, mapname, sizeof(mapname));
	}
	else
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_CLEAN, mapname, sizeof(mapname));
	}

	BuildPath(Path_SM, g_settingsfilepath, sizeof(g_settingsfilepath), "data/navbot/%s/%s_settings.cfg", g_modfolder, mapname);
}

// Main function to download nav mesh files
void DownloadNavMeshFromMirror(bool skipunique = false)
{
	char url[512];
	cvar_download_url.GetString(url, sizeof(url));

	if (strlen(url) < 5)
	{
		LogError("Navmesh download is enabled but download URL is not set!");
		return;
	}

	char append[256];
	char map[128];
	g_wasuniquemap = false;

	// if the current mod uses workshop and the unique map preference is enabled, try downloading a unique map.
	if (!skipunique && NavBotManager.ModUsesWorkshopMaps() && cvar_prefer_unique_names != null && cvar_prefer_unique_names.BoolValue)
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_UNIQUE, map, sizeof(map));
		FormatEx(append, sizeof(append), "/%s/%s.smnav", g_modfolder, map);
		StrCat(url, sizeof(url), append);
		LogMessage("Nav mesh file not available locally, trying to download from \"%s\".", url);
		HTTPRequest request = new HTTPRequest(url);
		
		if (request != null)
		{
			BuildPathToNavMeshFile(true);
			g_wasuniquemap = true;
			request.DownloadFile(g_navmeshfilepath, OnNavMeshFileDownloadRequestCompleted);
		}

		return;
	}

	NavBotModInterface.GetCurrentMapName(MAPNAME_CLEAN, map, sizeof(map));
	FormatEx(append, sizeof(append), "/%s/%s.smnav", g_modfolder, map);
	StrCat(url, sizeof(url), append);
	LogMessage("Nav mesh file not available locally, trying to download from \"%s\".", url);
	HTTPRequest request = new HTTPRequest(url);
	
	if (request != null)
	{
		BuildPathToNavMeshFile(false);
		request.DownloadFile(g_navmeshfilepath, OnNavMeshFileDownloadRequestCompleted);
	}
}

void DownloadNavMeshPlaceDB(bool skipunique = false)
{
	char url[512];
	cvar_download_url.GetString(url, sizeof(url));
	char append[256];
	char map[128];
	g_wasuniquemap = false;

	// if the current mod uses workshop and the unique map preference is enabled, try downloading a unique map.
	if (!skipunique && NavBotManager.ModUsesWorkshopMaps() && cvar_prefer_unique_names != null && cvar_prefer_unique_names.BoolValue)
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_UNIQUE, map, sizeof(map));
		FormatEx(append, sizeof(append), "/%s/%s_places.cfg", g_modfolder, map);
		StrCat(url, sizeof(url), append);
		HTTPRequest request = new HTTPRequest(url);
		
		if (request != null)
		{
			BuildPathToPlaceDatabaseFile(true);
			g_wasuniquemap = true;
			request.DownloadFile(g_placedbfilepath, OnNavMeshPlaceDBFileDownloadRequestCompleted);
		}

		return;
	}

	NavBotModInterface.GetCurrentMapName(MAPNAME_CLEAN, map, sizeof(map));
	FormatEx(append, sizeof(append), "/%s/%s_places.cfg", g_modfolder, map);
	StrCat(url, sizeof(url), append);
	HTTPRequest request = new HTTPRequest(url);
	
	if (request != null)
	{
		BuildPathToPlaceDatabaseFile(false);
		request.DownloadFile(g_placedbfilepath, OnNavMeshPlaceDBFileDownloadRequestCompleted);
	}
}

void DownloadNavMeshPlaceDBIncludeFile(const char[] file, int index)
{
	char path[256];
	BuildPath(Path_SM, path, sizeof(path), "data/navbot/%s/%s.cfg", g_modfolder, file);

	// Include files may be used by multiple maps, don't download if one exists.
	if (FileExists(path, false))
	{
		return;
	}

	char url[512];
	cvar_download_url.GetString(url, sizeof(url));
	char append[256];

	FormatEx(append, sizeof(append), "/%s/%s.cfg", g_modfolder, file);
	StrCat(url, sizeof(url), append);
	HTTPRequest request = new HTTPRequest(url);
	
	if (request != null)
	{

		request.DownloadFile(path, OnNavMeshPlaceDBIncludeDownloadCompleted, view_as<any>(index));
	}
}

void DownloadNavMeshMapSettingsFile(bool skipunique = false)
{
	char url[512];
	cvar_download_url.GetString(url, sizeof(url));
	char append[256];
	char map[128];
	g_wasuniquemap = false;

	// if the current mod uses workshop and the unique map preference is enabled, try downloading a unique map.
	if (!skipunique && NavBotManager.ModUsesWorkshopMaps() && cvar_prefer_unique_names != null && cvar_prefer_unique_names.BoolValue)
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_UNIQUE, map, sizeof(map));
		FormatEx(append, sizeof(append), "/%s/%s_settings.cfg", g_modfolder, map);
		StrCat(url, sizeof(url), append);
		HTTPRequest request = new HTTPRequest(url);
		
		if (request != null)
		{
			BuildPathToSettingsFile(true);
			g_wasuniquemap = true;
			request.DownloadFile(g_settingsfilepath, OnNavMeshSettingsFileDownloadCompleted);
		}

		return;
	}

	NavBotModInterface.GetCurrentMapName(MAPNAME_CLEAN, map, sizeof(map));
	FormatEx(append, sizeof(append), "/%s/%s_settings.cfg", g_modfolder, map);
	StrCat(url, sizeof(url), append);
	HTTPRequest request = new HTTPRequest(url);
	
	if (request != null)
	{
		BuildPathToSettingsFile(false);
		request.DownloadFile(g_settingsfilepath, OnNavMeshSettingsFileDownloadCompleted);
	}
}

void CreateAutoDownloadFile()
{
	char map[128];

	if (g_wasuniquemap)
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_UNIQUE, map, sizeof(map));
	}
	else
	{
		NavBotModInterface.GetCurrentMapName(MAPNAME_CLEAN, map, sizeof(map));
	}

	char url[512];
	cvar_download_url.GetString(url, sizeof(url));
	char path[256];
	BuildPath(Path_SM, path, sizeof(path), "data/navbot/%s/%s.autodownload", g_modfolder, map);

	File file = OpenFile(path, "wt", false);

	if (file != null)
	{
		char time[128];
		FormatTime(time, sizeof(time), "%Y-%m-%d %H:%M:%S");

		file.WriteLine("Navbot Navigation Mesh Manager version %s", PLUGIN_VERSION);
		file.WriteLine("[%s]: Navigation Mesh file download from \"%s\"", time, url);
		file.Close();
	}
}