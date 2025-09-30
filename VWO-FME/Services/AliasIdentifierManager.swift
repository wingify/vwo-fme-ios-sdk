/**
 * Copyright 2024-2025 Wingify Software Pvt. Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


import Foundation

class AliasIdentifierManager {
    
    static let shared = AliasIdentifierManager()
    
    var isEnabled: Bool?
    var isGatewayEnabled: Bool?
    
    private init(){}
    
    func setIsEnabled(options : VWOInitOptions?) {
        AliasIdentifierManager.shared.isEnabled = options?.isAliasingEnabled
        if let options = options{
            AliasIdentifierManager.shared.isGatewayEnabled = !options.gatewayService.isEmpty
        }else{
            AliasIdentifierManager.shared.isGatewayEnabled = false
        }
        
        
    }
    
    
    /**
     * Sets the alias for a user by calling the setUserAlias API.
     * @param vwoUserContext VWOUserContext containing the user information and ID.
     * @param alias User ID representing the user in logged in state.
     */
    func setAlias(from vwoUserContext: VWOUserContext, to alias: String) {
        
        guard let isAliasEnabled = AliasIdentifierManager.shared.isEnabled , isAliasEnabled == true else{
            LoggerService.log(level: .error, key: "ALIAS_FEATURE_DISABLED", details: [:])
            return
        }
        
        guard let isGatewayEnabled = AliasIdentifierManager.shared.isGatewayEnabled, isGatewayEnabled == true else{
            LoggerService.log(level: .error, key: "ALIAS_FEATURE_DISABLED_GATEWAY", details: [:])
            return
        }
        
        // Get accountId and sdkKey from SettingsManager
        guard let settingsManager = SettingsManager.instance else {
            LoggerService.log(level: .error, key: "SETTINGS_MANAGER_NOT_INITIALIZED", details: [
                "api": "setAlias"
            ])
            return
        }
        
        // Get tempId from userContext
        guard let tempId = vwoUserContext.id,!tempId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            LoggerService.log(level: .error, key: "USER_ID_NULL",details: [:])
            return
        }
        
        if tempId == alias {
            LoggerService.log(level: .error, key: "ALIAS_SAME_AS_TEMPID", details: [
                "aliasId": alias,
                "tempId": tempId
            ])
            return
        }
        
        if alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty{
            LoggerService.log(level: .error, key: "ALIASES_CANNOT_BE_EMPTY", details: [:])
            return
        }
        
        // Call the setUserAlias API
        SetUserAliasAPI().setUserAlias(
            tempId: tempId,
            userId: alias,
            accountId: settingsManager.accountId,
            sdkKey: settingsManager.sdkKey
        ) { result in
            switch result {
            case .success(let response):

                // Log success or failure based on response
                if response.isAliasSet {
                    LoggerService.log(level: .info, key: "ALIAS_SET_SUCCESS", details: [
                        "tempId": tempId,
                        "userId": alias
                    ])
                    
                    // On success, call getAlias API with all stored aliasIds plus the new one
                    self.callGetAliasAfterSetAlias(alias: alias, settingsManager: settingsManager)
                    
                } else {
                    LoggerService.log(level: .info, key: "ALIAS_SET_FAILED", details: [
                        "tempId": tempId
                    ])
                }
                
            case .failure(let error):
                // API call failed
                LoggerService.log(level: .error, key: "ALIAS_SET_API_ERROR", details: [
                    "tempId": tempId,
                    "userId": alias,
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    /**
     * Calls the getAlias API after successful setAlias with all stored aliasIds plus the new one.
     * @param alias The new aliasId that was just set.
     * @param settingsManager The SettingsManager instance for API calls.
     */
    private func callGetAliasAfterSetAlias(alias: String, settingsManager: SettingsManager) {
        // Get all stored alias mappings
        let storageService = StorageService()
        let storedMappings = storageService.getAliasMappings() ?? []
        
        // Extract all existing aliasIds from stored mappings
        var allAliasIds: [String] = []
        for mapping in storedMappings {
            if let aliasId = mapping["aliasId"] {
                allAliasIds.append(aliasId)
            }
        }
        
        // Add the new aliasId that was just set
        allAliasIds.append(alias)
        
        // Remove duplicates and ensure unique values
        let uniqueAliasIds = Array(Set(allAliasIds))
        
        
        // Call the getAlias API with all aliasIds
        GetUserAliasAPI().getUserAlias(
            userIds: uniqueAliasIds,
            accountId: settingsManager.accountId,
            sdkKey: settingsManager.sdkKey
        ) { result in
            switch result {
            case .success(let response):
                LoggerService.log(level: .info, key: "GET_ALIAS_AFTER_SET_SUCCESS", details: [
                    "totalMappings": String(response.aliasMappings.count)
                ])
                
                // Store the new response from getAlias API
                if !response.aliasMappings.isEmpty {
                    let storageService = StorageService()
                    var mappingsForStorage: [[String: String]] = []
                    
                    for mapping in response.aliasMappings {
                        let mappingDict: [String: String] = [
                            "aliasId": mapping.aliasId,
                            "userId": mapping.userId
                        ]
                        mappingsForStorage.append(mappingDict)
                    }
                    
                    storageService.setAliasMappings(aliasMappings: mappingsForStorage)
                    
                }
                
            case .failure(let error):
                LoggerService.log(level: .error, key: "GET_ALIAS_AFTER_SET_ERROR", details: [
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    
    /**
     * Gets the userId if it exists in local storage, or fetches from server if not found.
     * @param tempID Temporary ID to look up.
     * @param completion Completion handler with the userId if found, otherwise nil.
     */
    func getAliasIfExistsAsync(tempID: String, completion: @escaping (String?) -> Void) {
        // Check StorageService for existing alias mappings stored in exact API format
        let storageService = StorageService()
        let storedMappings: [[String: String]] = storageService.getAliasMappings() ?? []
        
        // Find the first mapping where userId matches the tempID
        for mapping in storedMappings {
            if let userId = mapping["userId"], userId == tempID {
                if let userIdValue = mapping["userId"] {
                    completion(userIdValue)
                    return
                }
            }
        }
        
        // If no alias in local storage, fetch from server
        self.fetchAliasIdentifier(forUserIds: [tempID]) { success, alias in
            completion(alias)
        }
    }
    
    /**
     * Fetches the userId for given userIds from the server.
     * @param forUserIds Array of User IDs for which userIds have to be found.
     * @param completion Completion handler with success status and userId.
     */
    func fetchAliasIdentifier(forUserIds: [String], completion: @escaping (Bool, String?) -> Void) {
        // Get accountId and sdkKey from SettingsManager
        guard let settingsManager = SettingsManager.instance else {
            LoggerService.log(level: .error, key: "SETTINGS_MANAGER_NOT_INITIALIZED", details: [
                "api": "fetchAliasIdentifier"
            ])
            completion(false, nil)
            return
        }
        
        // Call the getUserAlias API with array of userIds
        GetUserAliasAPI().getUserAlias(
            userIds: forUserIds,
            accountId: settingsManager.accountId,
            sdkKey: settingsManager.sdkKey
        ) { result in
            switch result {
            case .success(let response):
                // Handle new response format: array of objects with aliasId and userId
                // Example: [{"aliasId": "557", "userId": "tempId1"}, {"aliasId": "10", "userId": "tempId1"}]
                if !response.aliasMappings.isEmpty {
                    // Store the API response exactly as received in UserDefaults
                    // We'll store the entire array of AliasMapping objects
                    let existingMappings = response.aliasMappings
                    
                    // Convert AliasMapping objects to dictionaries for UserDefaults storage
                    var mappingsForStorage: [[String: String]] = []
                    for mapping in existingMappings {
                        let mappingDict: [String: String] = [
                            "aliasId": mapping.aliasId,
                            "userId": mapping.userId
                        ]
                        mappingsForStorage.append(mappingDict)
                    }
                    
                    // Save the exact API response format to StorageService
                    let storageService = StorageService()
                    storageService.setAliasMappings(aliasMappings: mappingsForStorage)
                    
                    
                    // For the current request, we want to return the userId that corresponds to the first requested userId
                    // Find the mapping where userId matches the first requested userId
                    let firstRequestedUserId = forUserIds.first ?? ""
                    if let matchingMapping = response.aliasMappings.first(where: { $0.userId == firstRequestedUserId }) {
                        
                        // Call completion with success and the matching userId
                        completion(true, matchingMapping.userId)
                    } else {
                        // If no exact match found, return the first userId as fallback
                        let firstUserId = response.aliasMappings.first?.userId
                        
                        completion(true, firstUserId)
                    }
                } else {
                    completion(false, nil)
                }
                
            case .failure(let error):
                LoggerService.log(level: .error, key: "GET_ALIAS_FAILED", details: [
                    "error": error.localizedDescription
                ])
                // Call completion with failure
                completion(false, nil)
            }
        }
    }
    
    /**
     * Fetches the userId for a single userId from the server.
     * This is a convenience method for backward compatibility.
     * @param forUserId User ID for which userId has to be found.
     * @param completion Completion handler with success status and userId.
     */
    func fetchAliasIdentifier(forUserId: String, completion: @escaping (Bool, String?) -> Void) {
        // Call the array version with a single userId
        fetchAliasIdentifier(forUserIds: [forUserId], completion: completion)
    }
    
    /**
     * Saves a userId mapping to local storage in StorageService.
     * @param key The key (userId) to store.
     * @param value The value (userId) to associate with the key.
     */
    func saveAliasMapping(key: String, value: String) {
        let storageService = StorageService()
        var existingMappings: [[String: String]] = storageService.getAliasMappings() ?? []
        
        // Check if a mapping with this userId already exists
        var found = false
        for i in 0..<existingMappings.count {
            if existingMappings[i]["userId"] == key {
                // Update existing mapping
                existingMappings[i]["userId"] = value
                found = true
                break
            }
        }
        
        if !found {
            // Add new mapping
            let newMapping: [String: String] = [
                "userId": value,
                "userId": key
            ]
            existingMappings.append(newMapping)
        }
        
        storageService.setAliasMappings(aliasMappings: existingMappings)
    }
    
    
}
