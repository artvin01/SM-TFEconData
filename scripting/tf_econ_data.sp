/**
 * [TF2] Econ Data
 * 
 * Functions to read item information from game memory.
 */
#pragma semicolon 1
#include <sourcemod>

#include <tf2_stocks>

#pragma newdecls required

#include <stocksoup/handles>
#include <stocksoup/memory>

#define PLUGIN_VERSION "0.8.1"
public Plugin myinfo = {
	name = "[TF2] Econ Data",
	author = "nosoop",
	description = "A library to read item data straight from the game's memory.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-TFEconData"
}

#include "tf_econ_data/loadout_slot.sp"
#include "tf_econ_data/item_definition.sp"
#include "tf_econ_data/attribute_definition.sp"
#include "tf_econ_data/keyvalues.sp"

Handle g_SDKCallGetEconItemSchema;
Handle g_SDKCallSchemaGetItemDefinition;
Handle g_SDKCallSchemaGetAttributeDefinition;
Handle g_SDKCallTranslateWeaponEntForClass;

Address offs_CEconItemSchema_ItemList,
		offs_CEconItemSchema_nItemCount;

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int maxlen) {
	RegPluginLibrary("tf_econ_data");
	
	// item information
	CreateNative("TF2Econ_IsValidItemDefinition", Native_IsValidItemDefinition);
	CreateNative("TF2Econ_GetItemName", Native_GetItemName);
	CreateNative("TF2Econ_GetLocalizedItemName", Native_GetLocalizedItemName);
	CreateNative("TF2Econ_GetItemClassName", Native_GetItemClassName);
	CreateNative("TF2Econ_GetItemSlot", Native_GetItemSlot);
	CreateNative("TF2Econ_GetItemLevelRange", Native_GetItemLevelRange);
	CreateNative("TF2Econ_GetItemDefinitionString", Native_GetItemDefinitionString);
	
	// global items
	CreateNative("TF2Econ_GetItemList", Native_GetItemList);
	
	// other useful functions for items
	CreateNative("TF2Econ_TranslateWeaponEntForClass", Native_TranslateWeaponEntForClass);
	
	// loadout slot information
	CreateNative("TF2Econ_TranslateLoadoutSlotNameToIndex",
			Native_TranslateLoadoutSlotNameToIndex);
	CreateNative("TF2Econ_TranslateLoadoutSlotIndexToName",
			Native_TranslateLoadoutSlotIndexToName);
	CreateNative("TF2Econ_GetLoadoutSlotCount", Native_GetLoadoutSlotCount);
	
	// attribute information
	CreateNative("TF2Econ_IsValidAttributeDefinition", Native_IsValidAttributeDefinition);
	CreateNative("TF2Econ_IsAttributeHidden", Native_IsAttributeHidden);
	CreateNative("TF2Econ_IsAttributeStoredAsInteger", Native_IsAttributeStoredAsInteger);
	CreateNative("TF2Econ_GetAttributeName", Native_GetAttributeName);
	CreateNative("TF2Econ_GetAttributeClassName", Native_GetAttributeClassName);
	CreateNative("TF2Econ_GetAttributeDefinitionString", Native_GetAttributeDefinitionString);
	
	// low-level stuff
	CreateNative("TF2Econ_GetItemDefinitionAddress", Native_GetItemDefinitionAddress);
	CreateNative("TF2Econ_GetAttributeDefinitionAddress", Native_GetAttributeDefinitionAddress);
	
	// backwards-compatibile
	CreateNative("TF2Econ_IsValidDefinitionIndex", Native_IsValidItemDefinition);
	
	return APLRes_Success;
}

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("tf2.econ_data");
	if (!hGameConf) {
		SetFailState("Failed to load gamedata (tf2.econ_data).");
	}
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GEconItemSchema()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallGetEconItemSchema = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature,
			"CEconItemSchema::GetItemDefinition()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallSchemaGetItemDefinition = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature,
			"CEconItemSchema::GetAttributeDefinition()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallSchemaGetAttributeDefinition = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "TranslateWeaponEntForClass()");
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallTranslateWeaponEntForClass = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "KeyValues::GetString()");
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallGetKeyValuesString = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "KeyValues::FindKey()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_SDKCallGetKeyValuesFindKey = EndPrepSDKCall();
	
	offs_CEconItemDefinition_pKeyValues =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_pKeyValues");
	offs_CEconItemDefinition_u8MinLevel =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_u8MinLevel");
	offs_CEconItemDefinition_u8MaxLevel =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_u8MaxLevel");
	offs_CEconItemDefinition_pszLocalizedItemName =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_pszLocalizedItemName");
	offs_CEconItemDefinition_pszItemClassname =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_pszItemClassname");
	offs_CEconItemDefinition_pszItemName =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_pszItemName");
	offs_CEconItemDefinition_aiItemSlot =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_aiItemSlot");
	offs_CEconItemSchema_ItemList =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_ItemList");
	offs_CEconItemSchema_nItemCount =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_nItemCount");
	offs_CTFItemSchema_ItemSlotNames =
			GameConfGetAddressOffset(hGameConf, "CTFItemSchema::m_ItemSlotNames");
	
	offs_CEconItemAttributeDefinition_pKeyValues =
			GameConfGetAddressOffset(hGameConf, "CEconItemAttributeDefinition::m_pKeyValues");
	offs_CEconItemAttributeDefinition_bHidden =
			GameConfGetAddressOffset(hGameConf, "CEconItemAttributeDefinition::m_bHidden");
	offs_CEconItemAttributeDefinition_bIsInteger =
			GameConfGetAddressOffset(hGameConf, "CEconItemAttributeDefinition::m_bIsInteger");
	offs_CEconItemAttributeDefinition_pszAttributeName = GameConfGetAddressOffset(hGameConf,
			"CEconItemAttributeDefinition::m_pszAttributeName");
	offs_CEconItemAttributeDefinition_pszAttributeClass = GameConfGetAddressOffset(hGameConf,
			"CEconItemAttributeDefinition::m_pszAttributeClass");
	
	delete hGameConf;
	
	CreateConVar("tfecondata_version", PLUGIN_VERSION,
			"Version for TF2 Econ Data, to gauge popularity.", FCVAR_NOTIFY);
}

public int Native_TranslateWeaponEntForClass(Handle hPlugin, int nParams) {
	char weaponClass[64];
	GetNativeString(1, weaponClass, sizeof(weaponClass));
	int maxlen = GetNativeCell(2);
	TFClassType playerClass = GetNativeCell(3);
	
	if (TranslateWeaponEntForClass(weaponClass, maxlen, playerClass)) {
		SetNativeString(1, weaponClass, maxlen, true);
		return true;
	}
	return false;
}

public int Native_GetItemList(Handle hPlugin, int nParams) {
	Function func = GetNativeFunction(1);
	any data = GetNativeCell(2);
	
	Address pSchema = GetEconItemSchema();
	if (!pSchema) {
		return 0;
	}
	
	ArrayList itemList = new ArrayList();
	
	// CEconItemSchema.field_0xE8 is a CUtlVector of some struct size 0x0C
	// (int defindex, CEconItemDefinition*, int m_Unknown)
	
	int nItemDefs = LoadFromAddress(pSchema + offs_CEconItemSchema_nItemCount,
			NumberType_Int32);
	for (int i = 0; i < nItemDefs; i++) {
		Address entry = DereferencePointer(pSchema + offs_CEconItemSchema_ItemList)
				+ view_as<Address>(i * 0x0C);
		
		// I have no idea how this check works but it's also in
		// CEconItemSchema::GetItemDefinitionByName
		if (LoadFromAddress(entry + view_as<Address>(0x08), NumberType_Int32) < -1) {
			continue;
		}
		
		int defindex = LoadFromAddress(entry, NumberType_Int32);
		
		if (func == INVALID_FUNCTION) {
			itemList.Push(defindex);
			continue;
		}
		
		bool result;
		Call_StartFunction(hPlugin, func);
		Call_PushCell(defindex);
		Call_PushCell(data);
		Call_Finish(result);
		
		if (result) {
			itemList.Push(defindex);
		}
	}
	
	return MoveHandle(itemList, hPlugin);
}

public int Native_GetItemDefinitionAddress(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	return view_as<int>(GetEconItemDefinition(defindex));
}

bool ValidItemDefIndex(int defindex) {
	return !!GetEconItemDefinition(defindex);
}

Address GetEconItemDefinition(int defindex) {
	Address pSchema = GetEconItemSchema();
	return pSchema? SDKCall(g_SDKCallSchemaGetItemDefinition, pSchema, defindex) : Address_Null;
}

public int Native_GetAttributeDefinitionAddress(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	return view_as<int>(GetEconAttributeDefinition(defindex));
}

Address GetEconAttributeDefinition(int defindex) {
	Address pSchema = GetEconItemSchema();
	return pSchema?
			SDKCall(g_SDKCallSchemaGetAttributeDefinition, pSchema, defindex) : Address_Null;
}

Address GetEconItemSchema() {
	return SDKCall(g_SDKCallGetEconItemSchema);
}

static bool TranslateWeaponEntForClass(char[] buffer, int maxlen, TFClassType playerClass) {
	return SDKCall(g_SDKCallTranslateWeaponEntForClass, buffer, maxlen, buffer, playerClass);
}

static Address GameConfGetAddressOffset(Handle gamedata, const char[] key) {
	Address offs = view_as<Address>(GameConfGetOffset(gamedata, key));
	if (offs == view_as<Address>(-1)) {
		SetFailState("Failed to get member offset %s", key);
	}
	return offs;
}
