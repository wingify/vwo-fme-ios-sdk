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

/**
 * Manages the settings for the SDK.
 *
 * This class handles fetching, caching, and providing access to the settings required for the SDK operation.
 * It supports fetching settings from a server or using cached settings if available.
 */
class SettingsManager {
    public let sdkKey: String
    public let accountId: Int
    private let cachedSettingsExpiryInterval: Int64
    private let networkTimeout: Int
    var hostname: String
    var isSettingsValid = false
    var settingsFetchTime : Int64 = 0
    var port: Int = 0
    var protocolType: String = "https"
    var isSettingsFetchInProgress = false

    var isGatewayServiceProvided: Bool = false
    private var localStorageService = StorageService()
    
    // Instance-specific logger for multi-instance support
    private weak var loggerService: LoggerService?

    // Multi-instance support: store instances per account
    private static var instances: [String: SettingsManager] = [:]
    private static let instanceQueue = DispatchQueue(label: "com.vwo.fme.settingsmanager.instances", attributes: .concurrent)
    
    // Backward compatibility: most recently created instance
    // Use a serial queue for _instance access to prevent deadlocks
    private static var _instance: SettingsManager?
    private static let instanceAccessQueue = DispatchQueue(label: "com.vwo.fme.settingsmanager.instance.access")
    
    static var instance: SettingsManager? {
        get {
            return instanceAccessQueue.sync {
                return _instance
            }
        }
        set {
            instanceAccessQueue.async {
                _instance = newValue
            }
        }
    }
    
    /// Sets the logger service for this SettingsManager instance.
    /// - Parameter logger: The LoggerService instance to use for logging
    func setLoggerService(_ logger: LoggerService?) {
        self.loggerService = logger
    }
    
    /// Creates or returns an existing instance of `SettingsManager` for the specific account.
    ///
    /// This method supports multi-instance usage by creating separate `SettingsManager` instances
    /// for each account (identified by accountId and sdkKey). This ensures proper isolation
    /// between different VWO accounts.
    ///
    /// - Parameter options: An instance of `VWOInitOptions` containing initialization parameters like account ID,
    ///   SDK key, logging level, and other configuration values.
    ///
    /// - Returns: A `SettingsManager` instance specific to the provided account.
    ///
    /// - Note:
    ///   Uses a thread-safe dictionary to store instances per account.
    ///   Each account gets its own instance to ensure proper isolation.
    static func createInstance(options: VWOInitOptions) -> SettingsManager {
        guard let accountId = options.accountId,
              let sdkKey = options.sdkKey else {
            // Fallback to old behavior if account info is missing
            return instanceQueue.sync(flags: .barrier) {
                // Check _instance using the access queue to avoid deadlock
                var existing: SettingsManager?
                instanceAccessQueue.sync {
                    existing = _instance
                }
                if let existing = existing {
                    return existing
                }
                let newInstance = SettingsManager(options: options)
                // Set _instance using the access queue to avoid deadlock
                instanceAccessQueue.async {
                    _instance = newInstance
                }
                return newInstance
            }
        }
        
        // Generate account key for multi-instance support
        let accountKey = "\(accountId)_\(sdkKey)"
        
        let result = instanceQueue.sync(flags: .barrier) {
            // Check if instance exists for this account
            if let existing = instances[accountKey] {
                // Verify it still matches (account ID and SDK key)
                if existing.accountId == accountId && existing.sdkKey == sdkKey {
                    // Update most recent for backward compatibility (use separate queue to avoid deadlock)
                    instanceAccessQueue.async {
                        _instance = existing
                    }
                    return existing
                }
            }
            
            // Create new instance for this account
            let newInstance = SettingsManager(options: options)
            // Set account info in StorageService for multi-instance support
            newInstance.localStorageService.setAccountInfo(accountId: accountId, sdkKey: sdkKey)
            instances[accountKey] = newInstance
            // Update most recent for backward compatibility (use separate queue to avoid deadlock)
            instanceAccessQueue.async {
                _instance = newInstance
            }
            return newInstance
        }
        return result
    }
    
    /// Creates or returns an existing instance of `SettingsManager` for the specific account with logger.
    ///
    /// - Parameters:
    ///   - options: An instance of `VWOInitOptions` containing initialization parameters
    ///   - logger: Optional LoggerService instance for instance-specific logging
    /// - Returns: A `SettingsManager` instance specific to the provided account
    static func createInstance(options: VWOInitOptions, logger: LoggerService?) -> SettingsManager {
        let instance = createInstance(options: options)
        instance.setLoggerService(logger)
        return instance
    }
    
    /// Gets an existing instance for a specific account
    /// - Parameters:
    ///   - accountId: The account ID
    ///   - sdkKey: The SDK key
    /// - Returns: The SettingsManager instance for this account, or nil if not found
    static func getInstance(accountId: Int, sdkKey: String) -> SettingsManager? {
        let accountKey = "\(accountId)_\(sdkKey)"
        return instanceQueue.sync {
            return instances[accountKey]
        }
    }
    
    /**
     * Initializes a new instance of SettingsManager.
     *
     * - Parameters:
     *   - options: The initialization options containing SDK key, account ID, and other configurations.
     */
    init(options: VWOInitOptions) {
        self.sdkKey = options.sdkKey ?? ""
        
        // Safe unwrapping for accountId
        guard let accountId = options.accountId else {
            fatalError("Account ID is required for SettingsManager initialization")
        }
        self.accountId = accountId
        
        self.cachedSettingsExpiryInterval = options.cachedSettingsExpiryTime
        self.networkTimeout = Constants.SETTINGS_TIMEOUT
        
        if !options.gatewayService.isEmpty {
            isGatewayServiceProvided = true
            
            // Safe unwrapping for gateway service URL
            guard let gatewayServiceUrl = options.gatewayService["url"] as? String, !gatewayServiceUrl.isEmpty else {
                LoggerService.log(level: .error, message: "Gateway service URL is required and must be a non-empty string")
                self.hostname = Constants.HOST_NAME
                SettingsManager.instance = self
                return
            }
            
            let gatewayServiceProtocol = options.gatewayService["protocol"] as? String
            let gatewayServicePort = options.gatewayService["port"] as? Int
            
            var parsedUrl: URL?
            
            if gatewayServiceUrl.hasPrefix("http://") || gatewayServiceUrl.hasPrefix("https://") {
                parsedUrl = URL(string: gatewayServiceUrl)
            } else if let protocolType = gatewayServiceProtocol, !protocolType.isEmpty {
                parsedUrl = URL(string: "\(protocolType)://\(gatewayServiceUrl)")
            } else {
                parsedUrl = URL(string: "https://\(gatewayServiceUrl)")
            }
            
            if let url = parsedUrl {
                self.hostname = url.host ?? Constants.HOST_NAME
                self.protocolType = url.scheme ?? "https"
                if let port = url.port {
                    self.port = port
                } else if let port = gatewayServicePort {
                    self.port = port
                }
            } else {
                LoggerService.log(level: .error, message: "Invalid gateway service URL: \(gatewayServiceUrl)")
                self.hostname = Constants.HOST_NAME
            }
        } else {
            self.hostname = Constants.HOST_NAME
        }
        
        // Thread-safe assignment
        SettingsManager.instance = self
    }
    
    /**
     * Fetches and caches server settings.
     *
     * - Parameters:
     *   - completion: A closure to be executed once the fetch is complete, with the fetched settings.
     */
    private func fetchAndCacheServerSettings(completion: @escaping (Settings?) -> Void) {
        self.fetchSettings(completion: completion)
    }
    
    /**
     * Fetches settings from cache or server.
     *
     * - Parameters:
     *   - completion: A closure to be executed once the fetch is complete, with the fetched settings.
     */
    private func fetchFromCacheOrServer(completion: @escaping (Settings?) -> Void) {
        if self.canUseCachedSettings(), let settingObj = self.getSettingFromUserDefaults() {
                // Use instance-specific logger if available, otherwise fallback to static logger
                self.loggerService?.log(level: .info, key: "SETTINGS_FETCH_SUCCESS", details: [:]) ?? LoggerService.log(level: .info, key: "SETTINGS_FETCH_SUCCESS", details: [:])
                completion(settingObj)
        } else {
            // Cache expired or no cached settings - log and fetch from server
            // Only log if cache expiry is enabled (cachedSettingsExpiryInterval > 0) and cache was invalid
            if self.cachedSettingsExpiryInterval > 0 && !self.isCachedSettingValid() {
                // Use instance-specific logger if available, otherwise fallback to static logger
                self.loggerService?.log(level: .info, key: "SETTINGS_CACHE_EXPIRED", details: [:]) ?? LoggerService.log(level: .info, key: "SETTINGS_CACHE_EXPIRED", details: [:])
            }
            self.fetchAndCacheServerSettings(completion: completion)
        }
    }
    
    /**
     * Fetches settings from the server.
     *
     * - Parameters:
     *   - completion: A closure to be executed once the fetch is complete, with the fetched settings.
     */
    private func fetchSettings(completion: @escaping (Settings?) -> Void) {
        guard !sdkKey.isEmpty else {
            LoggerService.errorLog(key: "ERROR_FETCHING_SETTINGS", data: ["err":"SDK Key and Account ID are required to fetch settings. Aborting!"],debugData: ["an":ApiEnum.Init.rawValue])
            completion(nil)
            return
        }
        
        var options = NetworkUtil.getSettingsPath(apikey: sdkKey, accountId: accountId)
        options["api-version"] = "3"
        
        if NetworkManager.config?.developmentMode != true {
            options["s"] = "prod"
        }
        
        let startTime = Date().currentTimeMillis()
        
        options["sn"] = SDKMetaUtil.name
        options["sv"] = SDKMetaUtil.version
        
        let request = RequestModel(url: hostname,
                                   method: HTTPMethod.get.rawValue,
                                   path: Constants.SETTINGS_ENDPOINT,
                                   query: options,
                                   body: nil,
                                   headers: nil,
                                   scheme: protocolType,
                                   port: port,
                                   timeout: networkTimeout)
        
        self.isSettingsFetchInProgress = true

        NetworkManager.get(request) { result in
            self.isSettingsFetchInProgress = false
            let error = result.errorMessage
            if let data = result.data2, error == nil {
                if let settingsObj = try? JSONDecoder().decode(Settings.self, from: data) {
                    // Use instance-specific logger if available, otherwise fallback to static logger
                    self.loggerService?.log(level: .info, key: "SETTINGS_FETCH_SUCCESS", details: [:]) ?? LoggerService.log(level: .info, key: "SETTINGS_FETCH_SUCCESS", details: [:])
                    self.saveSettingInUserDefaults(settingObj: settingsObj)
                    self.saveSettingExpiryInUserDefault()
                    self.settingsFetchTime = Date().currentTimeMillis() - startTime
                    self.isSettingsValid = true
                    completion(settingsObj)
                } else {
                    LoggerService.errorLog(
                        key: "INVALID_SETTINGS_SCHEMA",
                        data: ["err": "Setting is invalid"],
                        debugData: ["an": ApiEnum.Init.rawValue],
                        shouldSendToVWO: false
                    )

                    completion(nil)
                }
            } else {
                if result.error == .noNetwork {
                    if let cachedSetting = self.getSettingFromUserDefaults() {
                        // Use instance-specific logger if available, otherwise fallback to static logger
                        self.loggerService?.log(level: .info, key: "SETTINGS_FETCH_SUCCESS", details: [:]) ?? LoggerService.log(level: .info, key: "SETTINGS_FETCH_SUCCESS", details: [:])
                        self.settingsFetchTime = Date().currentTimeMillis() - startTime
                        self.isSettingsValid = true
                        completion(cachedSetting)
                    } else {
                        LoggerService.errorLog(key: "ERROR_FETCHING_SETTINGS", data: ["err":"\(result.errorMessage ?? "Unknown error")"],debugData: ["an":Constants.MOBILE_STORAGE])
                        completion(nil)
                    }
                } else {
                    LoggerService.errorLog(key: "ERROR_FETCHING_SETTINGS", data: ["err":"\(result.errorMessage ?? "Unknown error")"],debugData: ["an":ApiEnum.Init.rawValue])
                    completion(nil)
                }
            }
        }
    }
      
    /**
     * Retrieves settings, optionally forcing a fetch from the server.
     *
     * - Parameters:
     *   - forceFetch: A boolean indicating whether to force a fetch from the server.
     *   - completion: A closure to be executed once the fetch is complete, with the fetched settings.
     */
    func getSettings(forceFetch: Bool, completion: @escaping (Settings?) -> Void) {
        if self.isSettingsFetchInProgress {
            return
        }
        
        if (forceFetch) {
            fetchAndCacheServerSettings(completion: completion)
        } else {
            self.fetchFromCacheOrServer(completion: completion)
        }
    }
    
    /**
     * Retrieves settings from user defaults.
     *
     * - Returns: The cached settings, if available.
     */
    func getSettingFromUserDefaults() -> Settings? {
        return localStorageService.loadSettings()
    }
    
    /**
     * Saves settings to user defaults.
     *
     * - Parameters:
     *   - settingObj: The settings object to be saved.
     */
    func saveSettingInUserDefaults(settingObj: Settings) {
        localStorageService.saveSettings(settingObj)
    }
    
    /**
     * Saves the settings expiry time in user defaults.
     */
    func saveSettingExpiryInUserDefault() {
        let time = Date().currentTimeMillis() + self.cachedSettingsExpiryInterval
        localStorageService.saveSettingExpiry(timeInterval: time)
    }
    
    /**
     * Retrieves the settings expiry time from user defaults.
     *
     * - Returns: The expiry time, if available.
     */
    func getSettingExpiryFromUserDefault() -> Int64? {
        return localStorageService.getSettingExpiry()
    }
    
    /**
     * Determines if cached settings can be used.
     *
     * - Returns: A boolean indicating if cached settings are valid and can be used.
     */
    func canUseCachedSettings() -> Bool {
        return cachedSettingsExpiryInterval == 0 ? false : self.isCachedSettingValid()
    }
    
    /**
     * Checks if the cached settings are still valid.
     *
     * - Returns: A boolean indicating if the cached settings are valid.
     */
    func isCachedSettingValid() -> Bool {
        let savedExpiryTime = self.getSettingExpiryFromUserDefault()
        let now = Date().currentTimeMillis()
        if let expiryTime = savedExpiryTime {
            return now < expiryTime
        }
        return false
    }
}
