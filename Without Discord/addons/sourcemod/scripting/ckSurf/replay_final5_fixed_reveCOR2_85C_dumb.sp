
//
// Botmimic2 - modified by 1NutWunDeR
// http://forums.alliedmods.net/showthread.php?t=164148
//
void setReplayTime(int zGrp)
{
	char sPath[256], sTime[54], sBuffer[4][54];
	if (zGrp > 0)
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s_bonus_%i.rec", CK_REPLAY_PATH, g_szMapName, zGrp);
	else
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s.rec", CK_REPLAY_PATH, g_szMapName);

	int iFileHeader[FILE_HEADER_LENGTH];
	LoadRecordFromFile(sPath, iFileHeader);
	Format(sTime, sizeof(sTime), "%s", iFileHeader[view_as<int>(FH_Time)]);

	ExplodeString(sTime, ":", sBuffer, 4, 54);
	float time = (StringToFloat(sBuffer[0]) * 60);
	time += StringToFloat(sBuffer[1]);
	time += (StringToFloat(sBuffer[2]) / 100);
	if (zGrp == 0)
	{
		if ((g_fRecordMapTime - 0.01) < time < (g_fRecordMapTime) + 0.01)
			time = g_fRecordMapTime;
	}
	else
	{
		if ((g_fBonusFastest[zGrp] - 0.01) < time < (g_fBonusFastest[zGrp]) + 0.01)
			time = g_fBonusFastest[zGrp];
	}

	g_fReplayTimes[zGrp] = time;
}

public Action RespawnBot(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;
	
	if (IsValidClient(client))
	{
		if (g_hBotMimicsRecord[client] != null && !IsPlayerAlive(client) && IsFakeClient(client) && client != g_InfoBot && (GetClientTeam(client) >= CS_TEAM_T))
		{
			//if (GetConVarBool(g_hForceCT))
				//TeamChangeActual(client, 3);
			CS_RespawnPlayer(client);
		}
	}
	return Plugin_Handled;
}

//public Action Hook_WeaponCanSwitchTo(int client, int weapon)
//{
	//if (g_hBotMimicsRecord[client] == null)
		//return Plugin_Continue;
	
	//if (g_BotActiveWeapon[client] != weapon)
	//{
		//return Plugin_Stop;
	//}
	//return Plugin_Continue;
//}

public void StartRecording(int client)
{
	if (!WeAreOk)
		return;
	
	if (!IsValidClient(client))
		return;
	if (IsFakeClient(client))
		return;
	
	g_hRecording[client] = CreateArray(view_as<int>(FrameInfo));
	g_hRecordingAdditionalTeleport[client] = CreateArray(view_as<int>(AdditionalTeleport));
	GetClientAbsOrigin(client, g_fInitialPosition[client]);
	GetClientEyeAngles(client, g_fInitialAngles[client]);
	g_RecordedTicks[client] = 0;
	g_OriginSnapshotInterval[client] = 0;
}

public void StopRecording(int client)
{
	if (!IsValidClient(client))
		return;
	if (g_hRecording[client] == null)
		return;
	
	CloseHandle(g_hRecording[client]);
	CloseHandle(g_hRecordingAdditionalTeleport[client]);
	g_hRecording[client] = null;
	g_hRecordingAdditionalTeleport[client] = null;

	g_RecordedTicks[client] = 0;
	g_RecordPreviousWeapon[client] = 0;
	g_CurrentAdditionalTeleportIndex[client] = 0;
	g_OriginSnapshotInterval[client] = 0;
}

public void SaveRecording(int client, int zgroup)
{
	if (!IsValidClient(client) || g_hRecording[client] == null)
		return;
	else
	{
		g_bNewReplay[client] = false;
		g_bNewBonus[client] = false;
	}
	
	char sPath2[256];
	// Check if the default record folder exists?
	BuildPath(Path_SM, sPath2, sizeof(sPath2), "%s", CK_REPLAY_PATH);
	if (!DirExists(sPath2))
	{
		CreateDirectory(sPath2, 511);
	}
	
	if (zgroup == 0) // replay bot
	{
		BuildPath(Path_SM, sPath2, sizeof(sPath2), "%s%s.rec", CK_REPLAY_PATH, g_szMapName);
	}
	else
	{
		if (zgroup > 0) // bonus bot
		{
			BuildPath(Path_SM, sPath2, sizeof(sPath2), "%s%s_bonus_%i.rec", CK_REPLAY_PATH, g_szMapName, zgroup);
		}
	}

	if (FileExists(sPath2) && GetConVarBool(g_hBackupReplays))
	{
		char newPath[256];
		Format(newPath, 256, "%s.bak", sPath2);
		RenameFile(newPath, sPath2);
	}
	
	char szName[MAX_NAME_LENGTH];
	GetClientName(client, szName, MAX_NAME_LENGTH);
	
	int iHeader[FILE_HEADER_LENGTH];
	iHeader[view_as<int>(FH_binaryFormatVersion)] = BINARY_FORMAT_VERSION;
	strcopy(iHeader[view_as<int>(FH_Time)], 32, g_szFinalTime[client]);
	iHeader[view_as<int>(FH_tickCount)] = GetArraySize(g_hRecording[client]);
	strcopy(iHeader[view_as<int>(FH_Playername)], 32, szName);
	iHeader[view_as<int>(FH_Checkpoints)] = 0; // So that KZTimers replays work
	Array_Copy(g_fInitialPosition[client], iHeader[view_as<int>(FH_initialPosition)], 3);
	Array_Copy(g_fInitialAngles[client], iHeader[view_as<int>(FH_initialAngles)], 3);
	iHeader[view_as<int>(FH_frames)] = g_hRecording[client];
	
	if (GetArraySize(g_hRecordingAdditionalTeleport[client]) > 0)
		SetTrieValue(g_hLoadedRecordsAdditionalTeleport, sPath2, g_hRecordingAdditionalTeleport[client]);
	else
	{
		CloseHandle(g_hRecordingAdditionalTeleport[client]);
		g_hRecordingAdditionalTeleport[client] = null;
	}

	WriteRecordToDisk(sPath2, iHeader);

	g_bNewReplay[client] = false;
	g_bNewBonus[client] = false;

	if (g_hRecording[client] != null)
		StopRecording(client);
}

public void LoadReplays()
{
	if (!GetConVarBool(g_hReplayBot) && !GetConVarBool(g_hBonusBot))
		return;
		
	// Init variables:
	g_bMapReplay = false;
	for (int i = 0; i < MAXZONEGROUPS; i++)
	{
		g_fReplayTimes[i] = 0.0;
		//g_bMapBonusReplay[i] = false;
	}

	//g_BonusBotCount = 0;
	//g_RecordBot = -1;
	//g_BonusBot = -1;
	//g_iCurrentBonusReplayIndex = 0;
	ClearTrie(g_hLoadedRecordsAdditionalTeleport);

	// Check that map replay exists
	char sPath[256];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s.rec", CK_REPLAY_PATH, g_szMapName);
	if (FileExists(sPath))
	{
		setReplayTime(0);
		g_bMapReplay = true;
	}
	else// Check if backup exists
	{
		char sPathBack[256];
		BuildPath(Path_SM, sPathBack, sizeof(sPathBack), "%s%s.rec.bak", CK_REPLAY_PATH, g_szMapName);
		if (FileExists(sPathBack))
		{
			RenameFile(sPath, sPathBack);
			setReplayTime(0);
			g_bMapReplay = true;
		}
	}
	
	if (g_bMapReplay)
		CreateTimer(1.0, RefreshBot, _, TIMER_FLAG_NO_MAPCHANGE);
	
	
	CreateTimer(2.0, LoadOnlyBonus, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action LoadOnlyBonus(Handle timer)
{
	char sPath2[256];
	// Init variables:
	for (int i = 0; i < MAXZONEGROUPS; i++)
	{
		//g_fReplayTimes[i] = 0.0;
		g_bMapBonusReplay[i] = false;
	}

	g_BonusBotCount = 0;
	g_BonusBot = -1;
	g_iCurrentBonusReplayIndex = 0;
	//ClearTrie(g_hLoadedRecordsAdditionalTeleport);
	
	// Try to fix old bonus replays
	//BuildPath(Path_SM, sPath2, sizeof(sPath2), "%s%s_bonus.rec", CK_REPLAY_PATH, g_szMapName);
	//Handle hFilex = OpenFile(sPath2, "r");

	//if (hFilex != null)
	//{
		//int iFileHeader[FILE_HEADER_LENGTH];
		//float initPos[3];
		//char newPath[256];
		//LoadRecordFromFile(sPath2, iFileHeader);
		//Array_Copy(iFileHeader[view_as<int>(FH_initialPosition)], initPos, 3);
		//int zId = IsInsideZone(initPos, 50.0);
		//if (zId != -1 && g_mapZones[zId][zoneGroup] != 0)
		//{
			//BuildPath(Path_SM, newPath, sizeof(newPath), "%s%s_Bonus_%i.rec", CK_REPLAY_PATH, g_szMapName, g_mapZones[zId][zoneGroup]);
			//if (RenameFile(newPath, sPath2))
				//PrintToServer("[ckSurf] Succesfully renamed bonus record file to: %s", newPath);
		//}
		//CloseHandle(hFilex);
	//}
	//hFilex = null;
	//delete hFilex;

	// Check if bonus replays exists
	for (int i = 1; i < g_mapZoneGroupCount; i++)
	{
		BuildPath(Path_SM, sPath2, sizeof(sPath2), "%s%s_bonus_%i.rec", CK_REPLAY_PATH, g_szMapName, i);
		if (FileExists(sPath2))
		{
			setReplayTime(i);
			g_iBonusToReplay[g_BonusBotCount] = i;
			g_BonusBotCount++;
			g_bMapBonusReplay[i] = true;
		}
		else// Check if backup exists
		{
			char sPathBack2[256];
			BuildPath(Path_SM, sPathBack2, sizeof(sPathBack2), "%s%s_bonus_%i.rec.bak", CK_REPLAY_PATH, g_szMapName, i);
			if (FileExists(sPathBack2))
			{
				setReplayTime(i);
				RenameFile(sPath2, sPathBack2);
				g_iBonusToReplay[g_BonusBotCount] = i;
				g_BonusBotCount++;
				g_bMapBonusReplay[i] = true;
			}
		} 
	}
	
	if (g_BonusBotCount > 0)
		CreateTimer(1.4, RefreshBonusBot, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void PlayRecord(int client, int type)
{
	if (!IsValidClient(client))
		return;
	//if (g_hRecording[client] != null || !IsFakeClient(client))
		//return;
	char buffer[256];
	char sPath[256];
	if (type == 0)
		Format(sPath, sizeof(sPath), "%s%s.rec", CK_REPLAY_PATH, g_szMapName);
	if (type == 1)
		Format(sPath, sizeof(sPath), "%s%s_bonus_%i.rec", CK_REPLAY_PATH, g_szMapName, g_iBonusToReplay[g_iCurrentBonusReplayIndex]);
	// He's currently recording. Don't start to play some record on it at the same time.
	if (g_hRecording[client] != null || !IsFakeClient(client))
		return;

	int iFileHeader[FILE_HEADER_LENGTH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", sPath);
	LoadRecordFromFile(sPath, iFileHeader);
	
	if (type == 0)
	{
		Format(g_szReplayTime, sizeof(g_szReplayTime), "%s", iFileHeader[view_as<int>(FH_Time)]);
		Format(g_szReplayName, sizeof(g_szReplayName), "%s", iFileHeader[view_as<int>(FH_Playername)]);
		Format(buffer, sizeof(buffer), "%s (%s)", g_szReplayName, g_szReplayTime);
		CS_SetClientClanTag(client, "MAP REPLAY");
		SetClientName(client, buffer);
	}
	else
	{
		Format(g_szBonusTime, sizeof(g_szBonusTime), "%s", iFileHeader[view_as<int>(FH_Time)]);
		Format(g_szBonusName, sizeof(g_szBonusName), "%s", iFileHeader[view_as<int>(FH_Playername)]);
		Format(buffer, sizeof(buffer), "%s (%s)", g_szBonusName, g_szBonusTime);
		CS_SetClientClanTag(client, "BONUS REPLAY");
		SetClientName(client, buffer);
	}
	g_hBotMimicsRecord[client] = iFileHeader[view_as<int>(FH_frames)];
	g_BotMimicTick[client] = 0;
	g_BotMimicRecordTickCount[client] = iFileHeader[view_as<int>(FH_tickCount)];
	g_CurrentAdditionalTeleportIndex[client] = 0;
	
	Array_Copy(iFileHeader[view_as<int>(FH_initialPosition)], g_fInitialPosition[client], 3);
	Array_Copy(iFileHeader[view_as<int>(FH_initialAngles)], g_fInitialAngles[client], 3);
	//SDKHook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);
	
	// Disarm bot
	Client_RemoveAllWeapons(client);
	
	// Respawn it to get it moving!
	if (IsValidClient(client))
	{
		if (!IsPlayerAlive(client) && GetClientTeam(client) >= CS_TEAM_T && client != g_InfoBot)
		{
			//if (GetConVarBool(g_hForceCT))
				//TeamChangeActual(client, 3);
			CreateTimer(1.4, RespawnBot, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void WriteRecordToDisk(const char[] sPath, iFileHeader[FILE_HEADER_LENGTH])
{
	Handle hFile = OpenFile(sPath, "wb");
	if (hFile == null)
	{
		LogError("Can't open the record file for writing! (%s)", sPath);
		return;
	}
	
	WriteFileCell(hFile, BM_MAGIC, 4);
	WriteFileCell(hFile, iFileHeader[view_as<int>(FH_binaryFormatVersion)], 1);
	WriteFileCell(hFile, strlen(iFileHeader[view_as<int>(FH_Time)]), 1);
	WriteFileString(hFile, iFileHeader[view_as<int>(FH_Time)], false);
	WriteFileCell(hFile, strlen(iFileHeader[view_as<int>(FH_Playername)]), 1);
	WriteFileString(hFile, iFileHeader[view_as<int>(FH_Playername)], false);
	WriteFileCell(hFile, iFileHeader[view_as<int>(FH_Checkpoints)], 4);
	WriteFile(hFile, view_as<int>(iFileHeader[view_as<int>(FH_initialPosition)]), 3, 4);
	WriteFile(hFile, view_as<int>(iFileHeader[view_as<int>(FH_initialAngles)]), 2, 4);
	
	Handle hAdditionalTeleport;
	int iATIndex;
	GetTrieValue(g_hLoadedRecordsAdditionalTeleport, sPath, hAdditionalTeleport);
	
	int iTickCount = iFileHeader[view_as<int>(FH_tickCount)];
	WriteFileCell(hFile, iTickCount, 4);
	
	int iFrame[FRAME_INFO_SIZE];
	for (int i = 0; i < iTickCount; i++)
	{
		GetArrayArray(iFileHeader[view_as<int>(FH_frames)], i, iFrame, view_as<int>(FrameInfo));
		WriteFile(hFile, iFrame, view_as<int>(FrameInfo), 4);
		
		// Handle the optional Teleport call
		if (hAdditionalTeleport != null && iFrame[view_as<int>(additionalFields)] & (ADDITIONAL_FIELD_TELEPORTED_ORIGIN | ADDITIONAL_FIELD_TELEPORTED_ANGLES | ADDITIONAL_FIELD_TELEPORTED_VELOCITY))
		{
			int iAT[AT_SIZE];
			GetArrayArray(hAdditionalTeleport, iATIndex, iAT, AT_SIZE);
			if (iFrame[view_as<int>(additionalFields)] & ADDITIONAL_FIELD_TELEPORTED_ORIGIN)
				WriteFile(hFile, view_as<int>(iAT[view_as<int>(atOrigin)]), 3, 4);
			if (iFrame[view_as<int>(additionalFields)] & ADDITIONAL_FIELD_TELEPORTED_ANGLES)
				WriteFile(hFile, view_as<int>(iAT[view_as<int>(atAngles)]), 3, 4);
			if (iFrame[view_as<int>(additionalFields)] & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
				WriteFile(hFile, view_as<int>(iAT[view_as<int>(atVelocity)]), 3, 4);
			iATIndex++;
		}
	}
	
	CloseHandle(hFile);
	//seems to crash
	//CloseHandle(hAdditionalTeleport);
	LoadReplays();
}

public void LoadRecordFromFile(const char[] path, int headerInfo[FILE_HEADER_LENGTH])
{
	Handle hFile = OpenFile(path, "rb");
	if (hFile == null)
		return;
	int iMagic;
	ReadFileCell(hFile, iMagic, 4);
	if (iMagic != BM_MAGIC)
	{
		CloseHandle(hFile);
		return;
	}
	int iBinaryFormatVersion;
	ReadFileCell(hFile, iBinaryFormatVersion, 1);
	headerInfo[view_as<int>(FH_binaryFormatVersion)] = iBinaryFormatVersion;
	
	if (iBinaryFormatVersion > BINARY_FORMAT_VERSION)
	{
		CloseHandle(hFile);
		return;
	}
	
	int iNameLength;
	ReadFileCell(hFile, iNameLength, 1);
	char szTime[MAX_NAME_LENGTH];
	ReadFileString(hFile, szTime, iNameLength + 1, iNameLength);
	szTime[iNameLength] = '\0';
	
	int iNameLength2;
	ReadFileCell(hFile, iNameLength2, 1);
	char szName[MAX_NAME_LENGTH];
	ReadFileString(hFile, szName, iNameLength2 + 1, iNameLength2);
	szName[iNameLength2] = '\0';
	
	int iCp;
	ReadFileCell(hFile, iCp, 4);
	
	ReadFile(hFile, view_as<int>(headerInfo[view_as<int>(FH_initialPosition)]), 3, 4);
	ReadFile(hFile, view_as<int>(headerInfo[view_as<int>(FH_initialAngles)]), 2, 4);
	
	int iTickCount;
	ReadFileCell(hFile, iTickCount, 4);
	
	strcopy(headerInfo[view_as<int>(FH_Time)], 32, szTime);
	strcopy(headerInfo[view_as<int>(FH_Playername)], 32, szName);
	headerInfo[view_as<int>(FH_Checkpoints)] = iCp;
	headerInfo[view_as<int>(FH_tickCount)] = iTickCount;
	headerInfo[view_as<int>(FH_frames)] = null;
	
	Handle hRecordFrames = CreateArray(view_as<int>(FrameInfo));
	Handle hAdditionalTeleport = CreateArray(AT_SIZE);
	
	int iFrame[FRAME_INFO_SIZE];
	for (int i = 0; i < iTickCount; i++)
	{
		ReadFile(hFile, iFrame, view_as<int>(FrameInfo), 4);
		PushArrayArray(hRecordFrames, iFrame, view_as<int>(FrameInfo));
		
		if (iFrame[view_as<int>(additionalFields)] & (ADDITIONAL_FIELD_TELEPORTED_ORIGIN | ADDITIONAL_FIELD_TELEPORTED_ANGLES | ADDITIONAL_FIELD_TELEPORTED_VELOCITY))
		{
			int iAT[AT_SIZE];
			if (iFrame[view_as<int>(additionalFields)] & ADDITIONAL_FIELD_TELEPORTED_ORIGIN)
				ReadFile(hFile, view_as<int>(iAT[atOrigin]), 3, 4);
			if (iFrame[view_as<int>(additionalFields)] & ADDITIONAL_FIELD_TELEPORTED_ANGLES)
				ReadFile(hFile, view_as<int>(iAT[atAngles]), 3, 4);
			if (iFrame[view_as<int>(additionalFields)] & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
				ReadFile(hFile, view_as<int>(iAT[atVelocity]), 3, 4);
			iAT[view_as<int>(atFlags)] = iFrame[view_as<int>(additionalFields)] & (ADDITIONAL_FIELD_TELEPORTED_ORIGIN | ADDITIONAL_FIELD_TELEPORTED_ANGLES | ADDITIONAL_FIELD_TELEPORTED_VELOCITY);
			PushArrayArray(hAdditionalTeleport, iAT, AT_SIZE);
		}
	}
	
	headerInfo[view_as<int>(FH_frames)] = hRecordFrames;
	
	// Free any old handles if we already loaded this one once before. // Need to test this later
	//Handle hOldAT;
	//if (GetTrieValue(g_hLoadedRecordsAdditionalTeleport, path, hOldAT))
	//{
		//delete hOldAT;
		//RemoveFromTrie(g_hLoadedRecordsAdditionalTeleport, path);
	//}

	if (GetArraySize(hAdditionalTeleport) > 0)
		SetTrieValue(g_hLoadedRecordsAdditionalTeleport, path, hAdditionalTeleport);
	//else
		//CloseHandle(hAdditionalTeleport); //Thx but error log
	CloseHandle(hFile);
	//// error logs
	////CloseHandle(hRecordFrames);
	////CloseHandle(hAdditionalTeleport);
	
	return;
}

public Action RefreshBot(Handle timer)
{
	setBotQuota();
	//LoadRecordReplay();
	CreateTimer(2.0, RefreshBot2, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action RefreshBot2(Handle timer)
{
	LoadRecordReplay();
	return Plugin_Handled;
}

public void LoadRecordReplay()
{
	if (!GetConVarBool(g_hReplayBot) || !WeAreOk)
		return;
	
	g_RecordBot = -1;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;
		if (!IsFakeClient(i) || IsClientSourceTV(i) || i == g_InfoBot || i == g_BonusBot)
			continue;
		
		g_RecordBot = i;
		g_fCurrentRunTime[g_RecordBot] = 0.0;
		break;
	}
	
	if (IsValidClient(g_RecordBot))
	{
		// Set trail
		//if (GetConVarBool(g_hRecordBotTrail) && g_hBotTrail[0] == null)
			//g_hBotTrail[0] = CreateTimer(5.0 , ReplayTrailRefresh, GetClientUserId(g_RecordBot), TIMER_REPEAT);
			
		char clantag[100];
		CS_GetClientClanTag(g_RecordBot, clantag, sizeof(clantag));
		if (StrContains(clantag, "REPLAY") == -1)
			g_bNewRecordBot = true;

		g_iClientInZone[g_RecordBot][2] = 0;
		PlayRecord(g_RecordBot, 0);
		SetEntityRenderColor(g_RecordBot, g_ReplayBotColor[0], g_ReplayBotColor[1], g_ReplayBotColor[2], 50);
		if (GetConVarBool(g_hPlayerSkinChange))
		{
			char szBuffer[256];
			GetConVarString(g_hReplayBotPlayerModel, szBuffer, 256);
			SetEntityModel(g_RecordBot, szBuffer);

			GetConVarString(g_hReplayBotArmModel, szBuffer, 256);
			SetEntPropString(g_RecordBot, Prop_Send, "m_szArmsModel", szBuffer);
		}
		if (!IsPlayerAlive(g_RecordBot))
		{
			//if (GetConVarBool(g_hForceCT))
				//TeamChangeActual(i, 3);
			CreateTimer(1.0, RespawnBot, GetClientUserId(g_RecordBot), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else
	{
		CreateTimer(3.4, RefreshBot, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action RefreshBonusBot(Handle timer)
{
	setBotQuota();
	//LoadBonusReplay();
	CreateTimer(1.0, RefreshBonusBot2, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action RefreshBonusBot2(Handle timer)
{
	LoadBonusReplay();
	return Plugin_Handled;
}

public void LoadBonusReplay()
{
	if (!GetConVarBool(g_hBonusBot) || !WeAreOk)
		return;
	
	g_BonusBot = -1;
	//g_BonusBotCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue; // Add condition if already bonus bot, cuz they are several?
		if (!IsFakeClient(i) || IsClientSourceTV(i) || i == g_InfoBot || i == g_RecordBot || i == g_BonusBot)
			continue;
		
		g_BonusBot = i;
		g_fCurrentRunTime[g_BonusBot] = 0.0;
		//g_BonusBotCount++;
		break;
	}
	
	if (IsValidClient(g_BonusBot))
	{
		//if (GetConVarBool(g_hBonusBotTrail) && g_hBotTrail[1] == null)
		//{
			//g_hBotTrail[1] = CreateTimer(5.0 , ReplayTrailRefresh, GetClientUserId(g_BonusBot), TIMER_REPEAT);
		//}

		char clantag[100];
		CS_GetClientClanTag(g_BonusBot, clantag, sizeof(clantag));
		if (StrContains(clantag, "REPLAY") == -1)
			g_bNewBonusBot = true;
		g_iClientInZone[g_BonusBot][2] = g_iBonusToReplay[0];
		PlayRecord(g_BonusBot, 1);
		SetEntityRenderColor(g_BonusBot, g_BonusBotColor[0], g_BonusBotColor[1], g_BonusBotColor[2], 50);
		if (GetConVarBool(g_hPlayerSkinChange))
		{
			char szBuffer[256];
			GetConVarString(g_hReplayBotPlayerModel, szBuffer, 256);
			SetEntityModel(g_BonusBot, szBuffer);

			GetConVarString(g_hReplayBotArmModel, szBuffer, 256);
			SetEntPropString(g_BonusBot, Prop_Send, "m_szArmsModel", szBuffer);
		}
		if (!IsPlayerAlive(g_BonusBot))
		{
			//if (GetConVarBool(g_hForceCT))
				//TeamChangeActual(i, 3);
			CreateTimer(1.2, RespawnBot, GetClientUserId(g_BonusBot), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else
	{
		// Make sure bot_quota is set correctly and try again
		CreateTimer(3.9, RefreshBonusBot, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void StopPlayerMimic(int client)
{
	if (!IsValidClient(client))
		return;
	
	g_BotMimicTick[client] = 0;
	g_CurrentAdditionalTeleportIndex[client] = 0;
	g_BotMimicRecordTickCount[client] = 0;
	g_bValidTeleportCall[client] = false;
	//SDKUnhook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);
	if (g_hBotMimicsRecord[client] != null)
	{
		CloseHandle(g_hBotMimicsRecord[client]); // Closed at Disconnection?
		g_hBotMimicsRecord[client] = null;
	}
	//delete g_hBotMimicsRecord[client];
	////fix - makes crash at end of player run
	////g_hRecordingAdditionalTeleport[client] = null;
	////g_hLoadedRecordsAdditionalTeleport = null;
}

public bool IsPlayerMimicing(int client)
{
	if (!IsValidClient(client))
		return false;
	return g_hBotMimicsRecord[client] != null;
}

void DeleteReplay(int client, int zonegroup, char[] map)
{
	char sPath[PLATFORM_MAX_PATH + 1];
	if (zonegroup == 0) // Record
		Format(sPath, sizeof(sPath), "%s%s.rec", CK_REPLAY_PATH, map);
	else
		if (zonegroup > 0) // Bonus
			Format(sPath, sizeof(sPath), "%s%s_bonus_%i.rec", CK_REPLAY_PATH, map, g_iBonusToReplay[g_iCurrentBonusReplayIndex]);
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", sPath);
	
	// Delete the file
	if (FileExists(sPath))
	{
		if (!DeleteFile(sPath))
		{
			PrintToConsole(client, "<ERROR> Failed to delete %s - Please try to delete it manually!", sPath);
			return;
		}
		
		if (zonegroup > 0)
		{
			g_bMapBonusReplay[zonegroup] = false;
			PrintToConsole(client, "Bonus Replay %s_bonus_%i.rec deleted.", map, zonegroup);
		}
		else
		{
			g_bMapReplay = false;
			PrintToConsole(client, "Record Replay %s.rec deleted.", map);
		}
		if (StrEqual(map, g_szMapName))
		{
			if (zonegroup == 0 && IsValidClient(g_RecordBot))
			{
				ConVar hBotQuota4 = FindConVar("bot_quota");
				if (GetConVarInt(hBotQuota4) > 0)
					ServerCommand("bot_quota %i", GetConVarInt(hBotQuota4)-1);
				
				CloseHandle(hBotQuota4);
				if (GetConVarBool(g_hReplayBot))
				{
					CreateTimer(1.0, RefreshBot, _, TIMER_FLAG_NO_MAPCHANGE);
				}
				if (GetConVarBool(g_hBonusBot))
				{
					CreateTimer(1.6, RefreshBonusBot, _, TIMER_FLAG_NO_MAPCHANGE);
				}
				if (GetConVarBool(g_hInfoBot))
				{
					CreateTimer(2.5, RefreshInfoBot, _, TIMER_FLAG_NO_MAPCHANGE);
				}
				
			}
			else if (zonegroup > 1 && IsValidClient(g_BonusBot))
			{
				ConVar hBotQuota3 = FindConVar("bot_quota");
				if (GetConVarInt(hBotQuota3) > 0)
					ServerCommand("bot_quota %i", GetConVarInt(hBotQuota3)-1);
				
				CloseHandle(hBotQuota3);
				if (GetConVarBool(g_hReplayBot))
				{
					CreateTimer(1.0, RefreshBot, _, TIMER_FLAG_NO_MAPCHANGE);
				}
				if (GetConVarBool(g_hBonusBot))
				{
					CreateTimer(1.6, RefreshBonusBot, _, TIMER_FLAG_NO_MAPCHANGE);
				}
				if (GetConVarBool(g_hInfoBot))
				{
					CreateTimer(2.5, RefreshInfoBot, _, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
	else
		PrintToConsole(client, "Failed! %s not found.", sPath);
}

public void RecordReplay (int client, int &buttons, int &subtype, int &seed, int &impulse, int &weapon, float angles[3], float vel[3])
{
	if (g_hRecording[client] != null && !IsFakeClient(client))
	{
		if (g_bPause[client]) //  Dont record pause frames
			return;
		
		int iFrame[FrameInfo];
		iFrame[playerButtons] = buttons;
		iFrame[playerImpulse] = impulse;
		
		float vVel[3];
		Entity_GetAbsVelocity(client, vVel);
		iFrame[actualVelocity] = vVel;
		iFrame[predictedVelocity] = vel;

		Array_Copy(angles, iFrame[predictedAngles], 2);
		iFrame[newWeapon] = CSWeapon_NONE;
		iFrame[playerSubtype] = subtype;
		iFrame[playerSeed] = seed;

		// Save the current position 
		if (g_OriginSnapshotInterval[client] > ORIGIN_SNAPSHOT_INTERVAL  || g_createAdditionalTeleport[client])
		{
			int iAT[AdditionalTeleport];
			float fBuffer[3];
			GetClientAbsOrigin(client, fBuffer);
			Array_Copy(fBuffer, iAT[atOrigin], 3);

			/*GetClientEyeAngles(client, fBuffer);
			Array_Copy(fBuffer, iAT[atAngles], 3);

			Entity_GetAbsVelocity(client, fBuffer);
			Array_Copy(fBuffer, iAT[atVelocity], 3);*/
			
			iAT[atFlags] = ADDITIONAL_FIELD_TELEPORTED_ORIGIN;
			PushArrayArray(g_hRecordingAdditionalTeleport[client], iAT[0], view_as<int>(AdditionalTeleport));
			g_OriginSnapshotInterval[client] = 0;
			g_createAdditionalTeleport[client] = false;
		}
		g_OriginSnapshotInterval[client]++;

		// Check for additional Teleports
		if (GetArraySize(g_hRecordingAdditionalTeleport[client]) > g_CurrentAdditionalTeleportIndex[client])
		{
			int iAT[AdditionalTeleport];
			GetArrayArray(g_hRecordingAdditionalTeleport[client], g_CurrentAdditionalTeleportIndex[client], iAT[0], view_as<int>(AdditionalTeleport));
			// Remember, we were teleported this frame!
			iFrame[additionalFields] |= iAT[atFlags];
			g_CurrentAdditionalTeleportIndex[client]++;
		}

		PushArrayArray(g_hRecording[client], iFrame[0], view_as<int>(FrameInfo));
		g_RecordedTicks[client]++;
		
		//Requested by Freak.exe & ZZK Community
		//Getting RoundToNearest is not mandatory for the calc
		if (GetConVarBool(g_hEstimatedStartSpeed) && g_RecordedTicks[client] == 1 && g_bTimeractivated[client] && g_fLastSpeed[client] > 0.0)
		{
			//g_bNEEDSPEED[client] = true;
			if (RoundToNearest(g_fLastSpeed[client]) < 250) // 320 should be max
			{
				CPrintToChat(client, "[{olive}CK{default}] Estimated Start Speed: {orange}%i", RoundToNearest(g_fLastSpeed[client]));
			}
			else if (249 < RoundToNearest(g_fLastSpeed[client]) < 280)
			{
				CPrintToChat(client, "[{olive}CK{default}] Estimated Start Speed: {lime}%i", RoundToNearest(g_fLastSpeed[client]));
			}
			else if (279 < RoundToNearest(g_fLastSpeed[client]) < 310)
			{
				CPrintToChat(client, "[{olive}CK{default}] Estimated Start Speed: {blue}%i", RoundToNearest(g_fLastSpeed[client]));
			}
			else if (309 < RoundToNearest(g_fLastSpeed[client]) < 370)
			{
				CPrintToChat(client, "[{olive}CK{default}] Estimated Start Speed: {purple}%i", RoundToNearest(g_fLastSpeed[client]));
			}
			else if (RoundToNearest(g_fLastSpeed[client]) > 370)
			{
				CPrintToChat(client, "[{olive}CK{default}] Estimated Start Speed: {pink}%i", RoundToNearest(g_fLastSpeed[client]));
				CPrintToChat(client, "[{olive}CK{default}] There must have been a big boost here, you're insane!");
			}
			//g_bNEEDSPEED[client] = false;
		}
	}
}

public void PlayReplay(int client, int &buttons, int &subtype, int &seed, int &impulse, int &weapon, float angles[3], float vel[3])
{
	if (!IsValidClient(client))
		return;
		
	if (!IsPlayerAlive(client) || (GetClientTeam(client) < CS_TEAM_T) || !IsFakeClient(client) || IsClientSourceTV(client))
		return;
	
	if (g_hBotMimicsRecord[client] != null)
	{
		if (g_BotMimicTick[client] >= g_BotMimicRecordTickCount[client] || g_bReplayAtEnd[client])
		{
			if (!g_bReplayAtEnd[client])
			{
				g_fReplayRestarted[client] = GetEngineTime();
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.0);
				g_bReplayAtEnd[client] = true;
			}
			
			//g_CurrentAdditionalTeleportIndex[client] = 0;
			//g_BotMimicTick[client] = 0;
			
			if ((GetEngineTime() - g_fReplayRestarted[client]) < (BEAMLIFE))
				return;
			
			//if (client == g_BonusBot)
			//{
				// Call to load another replay
				// Here is why there's a new handle when same bonus bot restarts the run. We need it if multiple bonus bots are expected, but I remove it for now
				//if (g_iCurrentBonusReplayIndex < (g_BonusBotCount-1))
				//{
					//g_iCurrentBonusReplayIndex++;
					//g_iClientInZone[g_BonusBot][2] = g_iBonusToReplay[g_iCurrentBonusReplayIndex];
					//PlayRecord(g_BonusBot, 1);
				//}
				//else
				//{
					//g_iCurrentBonusReplayIndex = 0;
					//g_iClientInZone[g_BonusBot][2] = g_iBonusToReplay[g_iCurrentBonusReplayIndex];
					//PlayRecord(g_BonusBot, 1);
				//}
				//
				//PlayRecord(g_BonusBot, 1);
			//}
			
			// was written if (client != g_BonusBot), but then repeated for other bots
			//if (client != g_BonusBot)
			//{
				//g_BotMimicTick[client] = 0;
				//g_CurrentAdditionalTeleportIndex[client] = 0;
			//}
			
			g_CurrentAdditionalTeleportIndex[client] = 0; // Important
			g_BotMimicTick[client] = 0;
			g_bReplayAtEnd[client] = false;
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
		}
		//if (CheckHideBotWeapon(client))
			//StripAllWeapons(g_RecordBot);
		
		int iFrame[15];
		GetArrayArray(g_hBotMimicsRecord[client], 
						g_BotMimicTick[client],
						iFrame,
						view_as<int>(FrameInfo)
					);

		buttons = iFrame[playerButtons];
		impulse = iFrame[playerImpulse];
		Array_Copy(iFrame[predictedVelocity], vel, 3);
		Array_Copy(iFrame[predictedAngles], angles, 2);
		subtype = iFrame[playerSubtype];
		seed = iFrame[playerSeed];
		weapon = 0;

		float fActualVelocity[3];
		Array_Copy(iFrame[actualVelocity], fActualVelocity, 3);

		// We're supposed to teleport stuff?
		if (iFrame[additionalFields] & (ADDITIONAL_FIELD_TELEPORTED_ORIGIN | ADDITIONAL_FIELD_TELEPORTED_ANGLES | ADDITIONAL_FIELD_TELEPORTED_VELOCITY))
		{
			int iAT[10];
			Handle hAdditionalTeleport;
			char sPath[PLATFORM_MAX_PATH];
			if (client == g_RecordBot)
				Format(sPath, sizeof(sPath), "%s%s.rec", CK_REPLAY_PATH, g_szMapName);
			else
				if (client == g_BonusBot)
					Format(sPath, sizeof(sPath), "%s%s_bonus_%i.rec", CK_REPLAY_PATH, g_szMapName, g_iBonusToReplay[g_iCurrentBonusReplayIndex]);
			
			BuildPath(Path_SM, sPath, sizeof(sPath), "%s", sPath);
			if (g_hLoadedRecordsAdditionalTeleport != null)
			{
				GetTrieValue(g_hLoadedRecordsAdditionalTeleport, sPath, hAdditionalTeleport);
				if (hAdditionalTeleport != null && g_CurrentAdditionalTeleportIndex[client])
					GetArrayArray(hAdditionalTeleport, g_CurrentAdditionalTeleportIndex[client], iAT, 10);
				
				float fOrigin[3], fAngles[3], fVelocity[3];
				Array_Copy(iAT[atOrigin], fOrigin, 3);
				Array_Copy(iAT[atAngles], fAngles, 3);
				Array_Copy(iAT[atVelocity], fVelocity, 3);

				// The next call to Teleport is ok.
				g_bValidTeleportCall[client] = true;

				if (iAT[atFlags] & ADDITIONAL_FIELD_TELEPORTED_ORIGIN)
				{
					if (iAT[atFlags] & ADDITIONAL_FIELD_TELEPORTED_ANGLES)
					{
						if (iAT[atFlags] & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
							TeleportEntity(client, fOrigin, fAngles, fVelocity);
						else
							TeleportEntity(client, fOrigin, fAngles, NULL_VECTOR);
					}
					else
					{
						if (iAT[atFlags] & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
							TeleportEntity(client, fOrigin, NULL_VECTOR, fVelocity);
						else
							TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR);
					}
				}
				else
				{
					if (iAT[atFlags] & ADDITIONAL_FIELD_TELEPORTED_ANGLES)
					{
						if (iAT[atFlags] & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
							TeleportEntity(client, NULL_VECTOR, fAngles, fVelocity);
						else
							TeleportEntity(client, NULL_VECTOR, fAngles, NULL_VECTOR);
					}
					else
					{
						if (iAT[atFlags] & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
							TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
					}
				}
				g_CurrentAdditionalTeleportIndex[client]++;
			}
		}

		// This is the first tick. Teleport it to the initial position
		if (g_BotMimicTick[client] == 0)
		{
			CL_OnStartTimerPress(client);
			g_bValidTeleportCall[client] = true;
			TeleportEntity(client, g_fInitialPosition[client], g_fInitialAngles[client], fActualVelocity);
			
		}
		else
		{
			g_bValidTeleportCall[client] = true;
			TeleportEntity(client, NULL_VECTOR, angles, fActualVelocity);
		}
		
		if (iFrame[newWeapon] != CSWeapon_NONE)
		{
			char sAlias[64];
			CS_WeaponIDToAlias(iFrame[newWeapon], sAlias, sizeof(sAlias));

			Format(sAlias, sizeof(sAlias), "weapon_%s", sAlias);
			
			//if (g_BotMimicTick[client] > 0)
			//{
				//Client_RemoveAllWeapons(client);
			//}
			if (g_BotMimicTick[client] == 0)
			{
				if ((client == g_RecordBot && g_bNewRecordBot) || (client == g_BonusBot && g_bNewBonusBot))
				{
					Client_RemoveAllWeapons(client);
					
					//bool hasweapon;
					if (client == g_RecordBot)
						g_bNewRecordBot = false;
					else
						if (client == g_BonusBot)
							g_bNewBonusBot = false;
				}
				else
				{
					Client_RemoveAllWeapons(client);
				}
			}
		}
		g_BotMimicTick[client]++;
	}
}
