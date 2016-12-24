/**
 * [TF2] Spray Inspect
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdktools>

#pragma newdecls required
#include <stocksoup/tf/annotations>

#define PLUGIN_VERSION "0.0.1"
public Plugin myinfo = {
	name = "[TF2] Spray Inspect",
	author = "nosoop",
	description = "Inspect sprays as you would weapons.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-TFSprayInspect"
}

int g_bSprayActive[MAXPLAYERS+1];
float g_vecSprayOrigin[MAXPLAYERS+1][3];

public void OnPluginStart() {
	AddTempEntHook("Player Decal", OnPlayerDecalCreated);
	
	// AddCommandListener(OnPlayerInspect, "+inspect");
}

public Action OnPlayerDecalCreated(const char[] name, int[] clients, int nClients,
		float delay) {
	int client = TE_ReadNum("m_nPlayer");
	
	if (client > 0 && client <= MaxClients) {
		g_bSprayActive[client] = true;
		TE_ReadVector("m_vecOrigin", g_vecSprayOrigin[client]);
	}
}

public void OnClientDisconnect(int client) {
	g_bSprayActive[client] = false;
}

public Action OnClientCommandKeyValues(int client, KeyValues kv) {
	char command[64];
	kv.GetSectionName(command, sizeof(command));
	
	// TODO check command access for "spray_inspect"
	if (StrEqual(command, "+inspect_server")) {
		float vecWallPoint[3];
		
		if (GetWallFromEyePosition(client, vecWallPoint)) {
			for (int i = 1; i <= MaxClients; i++) {
				if (!IsClientInGame(i) || !g_bSprayActive[client]) {
					continue;
				}
				
				// TODO cycle through stacked sprays
				if (GetVectorDistance(vecWallPoint, g_vecSprayOrigin[i]) <= 50.0) {
					float vecAnnotation[3];
					AddVectors(NULL_VECTOR, g_vecSprayOrigin[i], vecAnnotation);
					
					// Offset annotation so spray is visible
					vecAnnotation[2] += 32.0;
					
					char sprayMessage[128];
					Format(sprayMessage, sizeof(sprayMessage), "Sprayed by %N", i);
					
					TF2_ShowPositionalAnnotationToClient(client, vecAnnotation, sprayMessage);
					
					return Plugin_Handled;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

bool GetWallFromEyePosition(int client, float vecPoint[3]) {
	float vecEyeOrigin[3], vecEyeAngles[3];
	GetClientEyePosition(client, vecEyeOrigin);
	GetClientEyeAngles(client, vecEyeAngles);
	
	Handle trace = TR_TraceRayFilterEx(vecEyeOrigin, vecEyeAngles, MASK_SHOT, RayType_Infinite,
			TraceFilterPlayers);
	
	if (TR_DidHit(trace)) {
		TR_GetEndPosition(vecPoint, trace);
		
		delete trace;
		return true;
	}
	
	delete trace;
	return false;
}

public bool TraceFilterPlayers(int entity, int contentsMask) {
	return entity > MaxClients;
}
