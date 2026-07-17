
void Frame_LoadNavMesh()
{
	NavBotNavMesh.Load();
}

void Frame_DownloadPlaceDBFile()
{
	DownloadNavMeshPlaceDB(false);
}

void Frame_DownloadSettingsFile()
{
	DownloadNavMeshMapSettingsFile(false);
}

void Frame_ParsePlaceDBFile()
{
	SMCParser parser = new SMCParser();
	parser.OnStart = PlaceDBParser_Start;
	parser.OnEnterSection = PlaceDBParser_NewSection;
	parser.OnLeaveSection = PlaceDBParser_EndSection;
	parser.OnKeyValue = PlaceDBParser_KeyValue;

	int line;
	int col;
	SMCError error = parser.ParseFile(g_placedbfilepath, line, col);
	delete parser;

	if (error != SMCError_Okay)
	{
		LogError("Error while parsing nav mesh place database file!");
		// nav mesh should still work but place names will be missing.
		RequestFrame(Frame_LoadNavMesh);
		return;
	}

	g_includesDownloaded = 0;

	if (g_placeIncludes.Length == 0)
	{
		// no additional place database files needs to be downloaded
		RequestFrame(Frame_LoadNavMesh);
		return;
	}

	LogMessage("Nav mesh place database includes %i additional files. Trying to donwload.", g_placeIncludes.Length);

	for (int i = 0; i < g_placeIncludes.Length; i++)
	{
		char buffer[256];
		g_placeIncludes.GetString(i, buffer, sizeof(buffer));
		DownloadNavMeshPlaceDBIncludeFile(buffer, i);
	}
}