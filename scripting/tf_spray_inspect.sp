/**
 * [TF2] Spray Inspect
 * 
 * Display an annotation when inspecting sprays.
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdktools>

#pragma newdecls required
#include <stocksoup/tf/annotations>

#define PLUGIN_VERSION "0.1.0"
public Plugin myinfo = {
	name = "[TF2] Spray Inspect",
	author = "nosoop",
	description = "Inspect sprays as you would weapons.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-TFSprayInspect"
}

/**
 * Annotation IDs must be unique to the annotation -- if you fire another annotation event with
 * the same ID, existing annotations on other clients may be replaced.
 * 
 * We use a specific offset to ensure each client gets their own annotation ID for sprays.
 */
#define SPRAY_ANNOTATION_ID_OFFSET 0xDABBAD00

int g_bSprayActive[MAXPLAYERS+1];
float g_vecSprayOrigin[MAXPLAYERS+1][3];

ConVar g_WallDistanceThreshold, g_AimDistanceThreshold, g_InspectDuration;

public void OnPluginStart() {
	g_WallDistanceThreshold = CreateConVar("spray_inspect_max_wall_distance", "300.0",
			"Maximum distance a wall can be from a player for spray inspection.");
	g_AimDistanceThreshold = CreateConVar("spray_inspect_max_aim_distance", "50.0",
			"Maximum distance a spray can be from the cursor for inspection.");
	g_InspectDuration = CreateConVar("spray_inspect_duration", "5.0",
			"Amount of time the spray annotation is displayed.");
	
	AutoExecConfig(true);
	
	AddTempEntHook("Player Decal", OnPlayerDecalCreated);
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
		float vecWallPoint[3], vecEyePosition[3];
		GetClientEyePosition(client, vecEyePosition);
		
		float flWallThreshold = Pow(g_WallDistanceThreshold.FloatValue, 2.0);
		
		// Only attempt to inspect spray if wall isn't too far
		if (GetWallFromEyePosition(client, vecWallPoint)
				&& GetVectorDistance(vecWallPoint, vecEyePosition, true) <= flWallThreshold) {
			float flSprayThreshold = Pow(g_AimDistanceThreshold.FloatValue, 2.0);
			for (int i = 1; i <= MaxClients; i++) {
				if (!IsClientInGame(i) || !g_bSprayActive[client]) {
					continue;
				}
				
				// TODO cycle through stacked sprays
				if (GetVectorDistance(vecWallPoint, g_vecSprayOrigin[i], true)
						<= flSprayThreshold) {
					float vecAnnotation[3];
					AddVectors(NULL_VECTOR, g_vecSprayOrigin[i], vecAnnotation);
					
					// Offset annotation so spray is visible
					vecAnnotation[2] += 32.0;
					
					char sprayMessage[128];
					Format(sprayMessage, sizeof(sprayMessage), "Sprayed by %N", i);
					
					TF2_ShowPositionalAnnotationToClient(client, vecAnnotation, sprayMessage,
							SPRAY_ANNOTATION_ID_OFFSET + client, _,
							g_InspectDuration.FloatValue);
					
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
