

static void UnpackRequestData(DataPack dp, RequestData data)
{
	dp.Reset();
	dp.ReadString(data.downloadpath, data.downloadpath.size);
	data.uniquename = dp.ReadCell();
	data.ondone = dp.ReadFunction();
	delete dp;
}

void OnHTTPRequestCompleted(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
	SteamWorksHTTPRequest http = view_as<SteamWorksHTTPRequest>(hRequest);
	RequestData data;
	UnpackRequestData(view_as<DataPack>(data1), data);

	VerboseLog("HTTP request completed: Failure %i Successful %i Status Code %i File: %s", 
	view_as<int>(bFailure), view_as<int>(bRequestSuccessful), view_as<int>(eStatusCode), data.downloadpath);

	if (bRequestSuccessful)
	{
		if (eStatusCode == k_EHTTPStatusCode200OK)
		{
			http.WriteResponseBodyToFile(data.downloadpath);
		}
	}

	delete hRequest;

	// call on done after the request handle was deleted
	if (bRequestSuccessful)
	{
		Call_StartFunction(null, data.ondone);
		Call_PushCell(eStatusCode);
		Call_PushCell(data.uniquename);
		Call_Finish();
	}
}
