
void VerboseLog(const char[] fmt, any ...)
{
	if (cvar_verbose.BoolValue)
	{
		char buffer[4096];
		FormatEx(buffer, buffer.size, fmt, ...);
		LogMessage("%s", buffer);
	}
}

/**
 * @brief Sends an HTTP request.
 * 
 * @param urlappend			String to append at the end of the base URL. (Do not add '/' at the start)
 * @param data				HTTP request data.
 */
void SendHTTPRequest(const char[] urlappend, RequestData data)
{
	char[] finalurl = new char[URL_MAX_LEN + 1];
	FormatEx(finalurl, finalurl.size, "%s/%s", g_downloadurl, urlappend);

	SteamWorksHTTPRequest request = new SteamWorksHTTPRequest(k_EHTTPMethodGET, finalurl);

	if (request != null)
	{
		char info[128];
		FormatEx(info, info.size, "NavBot Nav Mesh Manager Plugin/%s", PLUGIN_VERSION);
		DataPack dp = new DataPack();
		dp.WriteString(data.downloadpath);
		dp.WriteCell(data.uniquename);
		dp.WriteFunction(data.ondone);

		request.SetUserAgentInfo(info);
		request.SetContextValue(dp);
		request.SetNetworkActivityTimeout(10);
		request.SetCallbacks(OnHTTPRequestCompleted);
		request.Send();
	}
}

void OnDoneDownloadingPlaceInclude()
{
	g_includesDownloaded++;

	if (g_includesDownloaded >= g_placeIncludes.Length)
	{
		RequestFrame(Frame_LoadNavMesh);
	}
}

// returns true if unique map file names for workshop maps are allowed
bool ShouldTryDownloadingUniqueFile()
{
	return NavBotManager.ModUsesWorkshopMaps() && cvar_prefer_unique_names != null && cvar_prefer_unique_names.BoolValue;
}

void FormatNavMeshFile(NavBotMapNameType type, char[] buffer, const int size)
{
	char mapname[128];
	NavBotModInterface.GetCurrentMapName(type, mapname, sizeof(mapname));
	FormatEx(buffer, size, "%s.smnav", mapname);
}

void FormatNavMeshPlaceDBFile(NavBotMapNameType type, char[] buffer, const int size)
{
	char mapname[128];
	NavBotModInterface.GetCurrentMapName(type, mapname, sizeof(mapname));
	FormatEx(buffer, size, "%s_places.cfg", mapname);
}

void OnDoneDownloadingNavMesh(EHTTPStatusCode statusCode, bool uniquename)
{
	if (statusCode == k_EHTTPStatusCode404NotFound && uniquename)
	{
		// we tried to download a map with unique name, try again using the clean name without workshop ID.
		DownloadNavMeshFromMirror(true);
		return;
	}

	if (statusCode == k_EHTTPStatusCode200OK)
	{
		CreateAutoDownloadFile(uniquename ? MAPNAME_UNIQUE : MAPNAME_CLEAN);
		DownloadNavMeshMapSettingsFile();
	}
	else if (statusCode == k_EHTTPStatusCode404NotFound)
	{
		// No nav mesh found in mirror, generate one if available.
		GenerateNavMesh();
	}
}

void OnDoneDownloadingNavMeshSettingsFile(EHTTPStatusCode statusCode, bool uniquename)
{
	if (statusCode == k_EHTTPStatusCode404NotFound && uniquename)
	{
		// we tried to download a map with unique name, try again using the clean name without workshop ID.
		DownloadNavMeshMapSettingsFile(true);
		return;
	}

	DownloadNavMeshPlaceDB();
}

void OnDoneDownloadingNavMeshPlaceIncludeDB(EHTTPStatusCode statusCode, bool uniquename)
{
	OnDoneDownloadingPlaceInclude();
}

void OnDoneDownloadingNavMeshPlaceDB(EHTTPStatusCode statusCode, bool uniquename)
{
	if (statusCode == k_EHTTPStatusCode404NotFound && uniquename)
	{
		// we tried to download a map with unique name, try again using the clean name without workshop ID.
		DownloadNavMeshPlaceDB(true);
		return;
	}

	if (statusCode == k_EHTTPStatusCode200OK)
	{
		char file[128];
		NavBotMapNameType type = uniquename ? MAPNAME_UNIQUE : MAPNAME_CLEAN;
		FormatNavMeshPlaceDBFile(type, file, file.size);
		char path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, path.size, "data/navbot/%s/%s", g_modfolder, file);

		DataPack dp = new DataPack();
		dp.WriteString(path);

		// Parse and download any needed place include file
		RequestFrame(Frame_ParsePlaceDBFile, dp);
	}
	else
	{
		// Just load the nav mesh
		RequestFrame(Frame_LoadNavMesh);
	}
}

// Main function to download nav mesh files
void DownloadNavMeshFromMirror(bool skipunique = false)
{
	char navmeshfile[PLATFORM_MAX_PATH];
	NavBotMapNameType type = (!skipunique && ShouldTryDownloadingUniqueFile()) ? MAPNAME_UNIQUE : MAPNAME_CLEAN;
	FormatNavMeshFile(type, navmeshfile, navmeshfile.size);
	char buffer[512];
	FormatEx(buffer, buffer.size, "%s/%s", g_modfolder, navmeshfile);
	RequestData data;
	data.uniquename = type == MAPNAME_UNIQUE;
	BuildPath(Path_SM, data.downloadpath, data.downloadpath.size, "data/navbot/%s", buffer);
	data.ondone = OnDoneDownloadingNavMesh;
	SendHTTPRequest(buffer, data);
}

void DownloadNavMeshPlaceDB(bool skipunique = false)
{
	char file[128];
	NavBotMapNameType type = (!skipunique && ShouldTryDownloadingUniqueFile()) ? MAPNAME_UNIQUE : MAPNAME_CLEAN;
	FormatNavMeshPlaceDBFile(type, file, file.size);
	char buffer[PLATFORM_MAX_PATH];
	FormatEx(buffer, buffer.size, "%s/%s", g_modfolder, file);
	RequestData data;
	data.uniquename = type == MAPNAME_UNIQUE;
	BuildPath(Path_SM, data.downloadpath, data.downloadpath.size, "data/navbot/%s", buffer);
	data.ondone = OnDoneDownloadingNavMeshPlaceDB;
	SendHTTPRequest(buffer, data);
}

void DownloadNavMeshPlaceDBIncludeFile(const char[] file)
{
	char buffer[PLATFORM_MAX_PATH];
	FormatEx(buffer, buffer.size, "%s/%s.cfg", g_modfolder, file);
	RequestData data;
	BuildPath(Path_SM, data.downloadpath, data.downloadpath.size, "data/navbot/%s", buffer);

	// Include files may be used by multiple maps, don't download if one exists.
	if (FileExists(data.downloadpath, false))
	{
		OnDoneDownloadingPlaceInclude();
		return;
	}
	
	data.uniquename = false;
	data.ondone = OnDoneDownloadingNavMeshPlaceIncludeDB;
	SendHTTPRequest(buffer, data);
}

void DownloadNavMeshMapSettingsFile(bool skipunique = false)
{
	char map[128];
	NavBotMapNameType type = (!skipunique && ShouldTryDownloadingUniqueFile()) ? MAPNAME_UNIQUE : MAPNAME_CLEAN;
	NavBotModInterface.GetCurrentMapName(type, map, map.size);
	char buffer[512];
	FormatEx(buffer, buffer.size, "%s/%s_settings.cfg", g_modfolder, map);
	RequestData data;
	data.uniquename = type == MAPNAME_UNIQUE;
	BuildPath(Path_SM, data.downloadpath, data.downloadpath.size, "data/navbot/%s", buffer);
	data.ondone = OnDoneDownloadingNavMeshSettingsFile;
	SendHTTPRequest(buffer, data);
}

void CreateAutoDownloadFile(NavBotMapNameType type)
{
	if (!cvar_create_autodl_file.BoolValue)
	{
		return;
	}

	char map[128];
	NavBotModInterface.GetCurrentMapName(type, map, sizeof(map));
	char path[256];
	BuildPath(Path_SM, path, sizeof(path), "data/navbot/%s/%s.autodownload", g_modfolder, map);

	File file = OpenFile(path, "wt", false);

	if (file != null)
	{
		char time[128];
		FormatTime(time, sizeof(time), "%Y-%m-%d %H:%M:%S");

		file.WriteLine("Navbot Navigation Mesh Manager version %s", PLUGIN_VERSION);
		file.WriteLine("[%s]: Navigation Mesh file download from \"%s\"", time, g_downloadurl);
		file.Close();
	}
}

void GenerateNavMesh()
{
	if (cvar_auto_generate.BoolValue)
	{
		VerboseLog("Generating a nav mesh.");
		NavBotNavMesh.Generate();
	}
}