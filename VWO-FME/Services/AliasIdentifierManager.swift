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
    
    // Static registry for backward compatibility (similar to LoggerService pattern)
    private static var _instances: [String: AliasIdentifierManager] = [:]
    private static let instanceQueue = DispatchQueue(label: "com.vwo.fme.aliasmanager.instances", attributes: .concurrent)
    
    // Instance properties
    var isEnabled: Bool = false
    var isGatewayEnabled: Bool = false
    private var accountId: Int = 0
    private var sdkKey: String = ""
    private weak var serviceContainer: ServiceContainer?
    
    /**
     * Internal initializer for ServiceContainer to create instances
     */
    internal init() {}
    
    /**
     * Sets the ServiceContainer reference and initializes settings from options
     */
    func setServiceContainer(_ container: ServiceContainer, options: VWOInitOptions?) {
        self.serviceContainer = container
        self.accountId = container.getAccountId()
        self.sdkKey = container.getSdkKey()
        self.isEnabled = options?.isAliasingEnabled ?? false
        self.isGatewayEnabled = !(options?.gatewayService.isEmpty ?? true)
        
        // Register this instance for static lookup
        let accountKey = "\(accountId)_\(sdkKey)"
        AliasIdentifierManager.instanceQueue.async(flags: .barrier) {
            AliasIdentifierManager._instances[accountKey] = self
        }
    }
    
    /**
     * Legacy static shared instance for backward compatibility.
     * Returns an instance based on SettingsManager.instance if available.
     */
    static var shared: AliasIdentifierManager {
        if let settingsManager = SettingsManager.instance {
            let accountKey = "\(settingsManager.accountId)_\(settingsManager.sdkKey)"
            return instanceQueue.sync {
                if let instance = _instances[accountKey] {
                    return instance
                }
                // Create a temporary instance for backward compatibility
                let instance = AliasIdentifierManager()
                instance.accountId = settingsManager.accountId
                instance.sdkKey = settingsManager.sdkKey
                return instance
            }
        }
        // Fallback: create a temporary instance
        return AliasIdentifierManager()
    }
    
    /**
     * Static method for backward compatibility - gets instance by account key
     */
    static func getInstance(accountId: Int, sdkKey: String) -> AliasIdentifierManager? {
        let accountKey = "\(accountId)_\(sdkKey)"
        return instanceQueue.sync {
            return _instances[accountKey]
        }
    }
    
    /**
     * Static method to remove instance from registry when account is cleared
     */
    static func removeInstance(accountId: Int, sdkKey: String) {
        let accountKey = "\(accountId)_\(sdkKey)"
        instanceQueue.async(flags: .barrier) {
            _instances.removeValue(forKey: accountKey)
        }
    }
    
    /**
     * Legacy method for backward compatibility.
     * - Parameter options: The VWOInitOptions containing alias configuration
     */
    func setIsEnabled(options : VWOInitOptions?) {
        guard let accountId = options?.accountId,
              let sdkKey = options?.sdkKey else {
            return
        }
        self.accountId = accountId
        self.sdkKey = sdkKey
        self.isEnabled = options?.isAliasingEnabled ?? false
        self.isGatewayEnabled = !(options?.gatewayService.isEmpty ?? true)
    }
    
    
    /**
     * Sets the alias for a user by calling the setUserAlias API.
     * @param vwoUserContext VWOUserContext containing the user information and ID.
     * @param alias User ID representing the user in logged in state.
     * @param serviceContainer: Optional ServiceContainer to use for account info and logging (for multi-instance support).
     */
    func setAlias(from vwoUserContext: VWOUserContext, to alias: String, serviceContainer: ServiceContainer? = nil) {
        
        // Use provided serviceContainer or fallback to instance's serviceContainer
        let container = serviceContainer ?? self.serviceContainer
        let loggerService: LoggerService?
        let settingsManager: SettingsManager?
        
        if let container = container {
            loggerService = container.getLoggerService()
            settingsManager = container.getSettingsManager()
        } else {
            // Fallback to SettingsManager for backward compatibility
            guard let settingsManagerInstance = SettingsManager.instance else {
                LoggerService.errorLog(key: "SETTINGS_MANAGER_NOT_INITIALIZED", data: [
                    "api": "setAlias"
                ])
                return
            }
            loggerService = nil
            settingsManager = settingsManagerInstance
        }
        
        // Check alias settings
        guard isEnabled else {
            if let logger = loggerService {
                logger.errorLog(key: "ALIAS_FEATURE_DISABLED", data: [:])
            } else {
                LoggerService.errorLog(key: "ALIAS_FEATURE_DISABLED", data: [:])
            }
            return
        }
        
        guard isGatewayEnabled else {
            if let logger = loggerService {
                logger.errorLog(key: "ALIAS_FEATURE_DISABLED_GATEWAY", data: [:])
            } else {
                LoggerService.errorLog(key: "ALIAS_FEATURE_DISABLED_GATEWAY", data: [:])
            }
            return
        }
        
        guard let settingsManager = settingsManager else {
            if let logger = loggerService {
                logger.errorLog(key: "SETTINGS_MANAGER_NOT_INITIALIZED", data: [
                    "api": "setAlias"
                ])
            } else {
                LoggerService.errorLog(key: "SETTINGS_MANAGER_NOT_INITIALIZED", data: [
                    "api": "setAlias"
                ])
            }
            return
        }
        
        // Get accountId and sdkKey for API calls
        let accountId = container?.getAccountId() ?? self.accountId
        let sdkKey = container?.getSdkKey() ?? self.sdkKey
        
        // Get tempId from userContext
        guard let tempId = vwoUserContext.id,!tempId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if let logger = loggerService {
                logger.errorLog(key: "USER_ID_NULL", data: [:])
            } else {
                LoggerService.errorLog(key: "USER_ID_NULL", data: [:])
            }
            return
        }
        
        if tempId == alias {
            if let logger = loggerService {
                logger.errorLog(key: "ALIAS_SAME_AS_TEMPID", data: [
                    "aliasId": alias,
                    "tempId": tempId
                ])
            } else {
                LoggerService.errorLog(key: "ALIAS_SAME_AS_TEMPID", data: [
                    "aliasId": alias,
                    "tempId": tempId
                ])
            }
            return
        }
        
        if alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty{
            if let logger = loggerService {
                logger.errorLog(key: "ALIASES_CANNOT_BE_EMPTY", data: [:])
            } else {
                LoggerService.errorLog(key: "ALIASES_CANNOT_BE_EMPTY", data: [:])
            }
            return
        }
        
        // Call the setUserAlias API
        SetUserAliasAPI().setUserAlias(
            tempId: tempId,
            userId: alias,
            accountId: accountId,
            sdkKey: sdkKey,
            loggerService: loggerService
        ) { result in
            switch result {
            case .success(let response):

                // Log success or failure based on response
                if response.isAliasSet {
                    if let logger = loggerService {
                        logger.log(level: .info, key: "ALIAS_SET_SUCCESS", details: [
                            "tempId": tempId,
                            "userId": alias
                        ])
                    } else {
                        LoggerService.log(level: .info, key: "ALIAS_SET_SUCCESS", details: [
                            "tempId": tempId,
                            "userId": alias
                        ])
                    }
                    
                    // On success, call getAlias API with all stored aliasIds plus the new one
                    self.callGetAliasAfterSetAlias(alias: alias, settingsManager: settingsManager, loggerService: loggerService)
                    
                } else {
                    if let logger = loggerService {
                        logger.log(level: .info, key: "ALIAS_SET_FAILED", details: [
                            "tempId": tempId
                        ])
                    } else {
                        LoggerService.log(level: .info, key: "ALIAS_SET_FAILED", details: [
                            "tempId": tempId
                        ])
                    }
                }
                
            case .failure(let error):
                // API call failed
                if let logger = loggerService {
                    logger.errorLog(key: "ALIAS_SET_API_ERROR", data: [
                        "tempId": tempId,
                        "userId": alias,
                        "error": error.localizedDescription
                    ])
                } else {
                    LoggerService.errorLog(key: "ALIAS_SET_API_ERROR", data: [
                        "tempId": tempId,
                        "userId": alias,
                        "error": error.localizedDescription
                    ])
                }
            }
        }
    }
    
    /**
     * Calls the getAlias API after successful setAlias with all stored aliasIds plus the new one.
     * @param alias The new aliasId that was just set.
     * @param settingsManager The SettingsManager instance for API calls.
     * @param loggerService Optional LoggerService for instance-specific logging.
     */
    private func callGetAliasAfterSetAlias(alias: String, settingsManager: SettingsManager, loggerService: LoggerService? = nil) {
        // Get all stored alias mappings - use instance-specific StorageService
        let storageService = self.serviceContainer?.storage ?? StorageService(accountId: self.accountId, sdkKey: self.sdkKey)
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
            sdkKey: settingsManager.sdkKey,
            loggerService: loggerService
        ) { result in
            switch result {
            case .success(let response):
                if let logger = loggerService {
                    logger.log(level: .info, key: "GET_ALIAS_AFTER_SET_SUCCESS", details: [
                        "totalMappings": String(response.aliasMappings.count)
                    ])
                } else {
                    LoggerService.log(level: .info, key: "GET_ALIAS_AFTER_SET_SUCCESS", details: [
                        "totalMappings": String(response.aliasMappings.count)
                    ])
                }
                
                // Store the new response from getAlias API
                if !response.aliasMappings.isEmpty {
                    // Use instance-specific StorageService
                    let storageService = self.serviceContainer?.storage ?? StorageService(accountId: settingsManager.accountId, sdkKey: settingsManager.sdkKey)
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
                if let logger = loggerService {
                    logger.errorLog(key: "GET_ALIAS_AFTER_SET_ERROR", data: [
                        "error": error.localizedDescription
                    ])
                } else {
                    LoggerService.errorLog(key: "GET_ALIAS_AFTER_SET_ERROR", data: [
                        "error": error.localizedDescription
                    ])
                }
            }
        }
    }
    
    
    /**
     * Gets the userId if it exists in local storage, or fetches from server if not found.
     * @param tempID Temporary ID to look up.
     * @param serviceContainer Optional ServiceContainer to use for account info (for multi-instance support).
     * @param completion Completion handler with the userId if found, otherwise nil.
     */
    func getAliasIfExistsAsync(tempID: String, serviceContainer: ServiceContainer? = nil, completion: @escaping (String?) -> Void) {
        // Check StorageService for existing alias mappings stored in exact API format
        // Use instance-specific StorageService
        let container = serviceContainer ?? self.serviceContainer
        let storageService = container?.storage ?? StorageService(accountId: self.accountId, sdkKey: self.sdkKey)
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
        self.fetchAliasIdentifier(forUserIds: [tempID], serviceContainer: serviceContainer) { success, alias in
            completion(alias)
        }
    }
    
    /**
     * Fetches the userId for given userIds from the server.
     * @param forUserIds Array of User IDs for which userIds have to be found.
     * @param serviceContainer Optional ServiceContainer to use for account info and logging (for multi-instance support).
     * @param completion Completion handler with success status and userId.
     */
    func fetchAliasIdentifier(forUserIds: [String], serviceContainer: ServiceContainer? = nil, completion: @escaping (Bool, String?) -> Void) {
        // Use provided serviceContainer or fallback to instance's serviceContainer
        let container = serviceContainer ?? self.serviceContainer
        let loggerService: LoggerService?
        let settingsManager: SettingsManager?
        
        if let container = container {
            loggerService = container.getLoggerService()
            settingsManager = container.getSettingsManager()
        } else {
            // Fallback to SettingsManager for backward compatibility
            guard let settingsManagerInstance = SettingsManager.instance else {
                LoggerService.errorLog(key: "SETTINGS_MANAGER_NOT_INITIALIZED", data: [
                    "api": "fetchAliasIdentifier"
                ])
                completion(false, nil)
                return
            }
            loggerService = nil
            settingsManager = settingsManagerInstance
        }
        
        guard let settingsManager = settingsManager else {
            if let logger = loggerService {
                logger.errorLog(key: "SETTINGS_MANAGER_NOT_INITIALIZED", data: [
                    "api": "fetchAliasIdentifier"
                ])
            } else {
                LoggerService.errorLog(key: "SETTINGS_MANAGER_NOT_INITIALIZED", data: [
                    "api": "fetchAliasIdentifier"
                ])
            }
            completion(false, nil)
            return
        }
        
        // Get accountId and sdkKey for API calls
        let accountId = container?.getAccountId() ?? self.accountId
        let sdkKey = container?.getSdkKey() ?? self.sdkKey
        
        // Call the getUserAlias API with array of userIds
        GetUserAliasAPI().getUserAlias(
            userIds: forUserIds,
            accountId: accountId,
            sdkKey: sdkKey,
            loggerService: loggerService
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
                    // Use instance-specific StorageService
                    let container = serviceContainer ?? self.serviceContainer
                    let storageService = container?.storage ?? StorageService(accountId: self.accountId, sdkKey: self.sdkKey)
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
                if let logger = loggerService {
                    logger.errorLog(key: "GET_ALIAS_FAILED", data: [
                        "error": error.localizedDescription
                    ])
                } else {
                    LoggerService.errorLog(key: "GET_ALIAS_FAILED", data: [
                        "error": error.localizedDescription
                    ])
                }
                // Call completion with failure
                completion(false, nil)
            }
        }
    }
    
    /**
     * Fetches the userId for a single userId from the server.
     * This is a convenience method for backward compatibility.
     * @param forUserId User ID for which userId has to be found.
     * @param serviceContainer Optional ServiceContainer to use for account info (for multi-instance support).
     * @param completion Completion handler with success status and userId.
     */
    func fetchAliasIdentifier(forUserId: String, serviceContainer: ServiceContainer? = nil, completion: @escaping (Bool, String?) -> Void) {
        // Call the array version with a single userId
        fetchAliasIdentifier(forUserIds: [forUserId], serviceContainer: serviceContainer, completion: completion)
    }
    
    /**
     * Saves a userId mapping to local storage in StorageService.
     * @param key The key (userId) to store.
     * @param value The value (userId) to associate with the key.
     */
    func saveAliasMapping(key: String, value: String) {
        // Use instance-specific StorageService
        let storageService = self.serviceContainer?.storage ?? StorageService(accountId: self.accountId, sdkKey: self.sdkKey)
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
