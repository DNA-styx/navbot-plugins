
void OnNavMeshPlaceDBFileDownloadRequestCompleted(HTTPStatus status, any value, const char[] error)
{
	if (status != HTTPStatus_OK)
	{
		if (status == HTTPStatus_NotFound)
		{
			// if we attempted to download a map with a unique workshop ID, try download again but without the unique ID.
			if (g_wasuniquemap)
			{
				DeletePlaceDBFile();
				// try again but don't download maps with unique names.
				DownloadNavMeshPlaceDB(true);
				return;
			}

			DeletePlaceDBFile();
			// just load the nav mesh, the map probably doesn't have one
			RequestFrame(Frame_LoadNavMesh);
			return;
		}

		DeletePlaceDBFile();
		RequestFrame(Frame_LoadNavMesh);
		LogError("Failed to download nav mesh place database file. HTTP status code \"%i\". Error: %s", view_as<int>(status), error);
		return;
	}

	RequestFrame(Frame_ParsePlaceDBFile);
}

void OnNavMeshPlaceDBIncludeDownloadCompleted(HTTPStatus status, any value, const char[] error)
{
	g_includesDownloaded++;
	char name[256];
	g_placeIncludes.GetString(view_as<int>(value), name, sizeof(name));

	if (g_includesDownloaded >= g_placeIncludes.Length)
	{
		RequestFrame(Frame_LoadNavMesh);
		return;
	}

	if (status != HTTPStatus_OK)
	{
		DeletePlaceDBIncludeFile(name);
		LogError("Failed to download nav mesh place database include file \"%s\". HTTP status code \"%i\". Error: %s", name, view_as<int>(status), error);
		return;
	}
}

void OnNavMeshFileDownloadRequestCompleted(HTTPStatus status, any value, const char[] error)
{
	if (status != HTTPStatus_OK)
	{
		if (status == HTTPStatus_NotFound)
		{
			// if we attempted to download a map with a unique workshop ID, try download again but without the unique ID.
			if (g_wasuniquemap)
			{
				DeleteNavMeshFile();
				// try again but don't download maps with unique names.
				DownloadNavMeshFromMirror(true);
				return;
			}

			// don't log 404 as errors, we don't expect mirrors to have all the maps.
			LogMessage("Failed to download nav mesh file. File does not exists on mirror.");
			DeleteNavMeshFile(); // don't save the 404 page as a navmesh file

			if (cvar_auto_generate.BoolValue)
			{
				NavBotNavMesh.Generate();
			}

			return;
		}

		DeleteNavMeshFile();
		LogError("Failed to download nav mesh file. HTTP status code \"%i\". Error: %s", view_as<int>(status), error);

		if (cvar_auto_generate.BoolValue)
		{
			NavBotNavMesh.Generate();
		}

		return;
	}

	// this just helps finding nav mesh files that were downloaded from the net (includes URL and timestamp)
	CreateAutoDownloadFile();
	RequestFrame(Frame_DownloadSettingsFile);
}


void OnNavMeshSettingsFileDownloadCompleted(HTTPStatus status, any value, const char[] error)
{
	if (status != HTTPStatus_OK)
	{
		if (status == HTTPStatus_NotFound)
		{
			// if we attempted to download a map with a unique workshop ID, try download again but without the unique ID.
			if (g_wasuniquemap)
			{
				DeleteNavSettingsFile();
				// try again but don't download maps with unique names.
				DownloadNavMeshMapSettingsFile(true);
				return;
			}

			DeleteNavSettingsFile();
			RequestFrame(Frame_DownloadPlaceDBFile);
			return;
		}

		DeleteNavSettingsFile();
		LogError("Failed to download nav mesh map settings file. HTTP status code \"%i\". Error: %s", view_as<int>(status), error);
		RequestFrame(Frame_DownloadPlaceDBFile);
		return;
	}

	RequestFrame(Frame_DownloadPlaceDBFile);
}