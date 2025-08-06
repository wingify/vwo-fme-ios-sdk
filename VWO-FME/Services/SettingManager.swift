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

    static var instance: SettingsManager?
    
    /**
     * Initializes a new instance of SettingsManager.
     *
     * - Parameters:
     *   - options: The initialization options containing SDK key, account ID, and other configurations.
     */
    init(options: VWOInitOptions) {
        self.sdkKey = options.sdkKey ?? ""
        self.accountId = options.accountId!
        self.cachedSettingsExpiryInterval = options.cachedSettingsExpiryTime
        self.networkTimeout = Constants.SETTINGS_TIMEOUT
        
        if !options.gatewayService.isEmpty {
            isGatewayServiceProvided = true
            var parsedUrl: URL
            let gatewayServiceUrl = options.gatewayService["url"] as! String
            let gatewayServiceProtocol = options.gatewayService["protocol"] as? String
            let gatewayServicePort = options.gatewayService["port"] as? Int
            
            if gatewayServiceUrl.hasPrefix("http://") || gatewayServiceUrl.hasPrefix("https://") {
                parsedUrl = URL(string: gatewayServiceUrl)!
            } else if let protocolType = gatewayServiceProtocol, !protocolType.isEmpty {
                parsedUrl = URL(string: "\(protocolType)://\(gatewayServiceUrl)")!
            } else {
                parsedUrl = URL(string: "https://\(gatewayServiceUrl)")!
            }
            
            self.hostname = parsedUrl.host ?? Constants.HOST_NAME
            self.protocolType = parsedUrl.scheme ?? "https"
            if parsedUrl.port != nil {
                self.port = parsedUrl.port!
            } else if let port = gatewayServicePort {
                self.port = port
            }
        } else {
            self.hostname = Constants.HOST_NAME
        }
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
                LoggerService.log(level: .info, key: "SETTINGS_FETCH_SUCCESS", details: [:])
                completion(settingObj)
        } else {
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
            LoggerService.log(level: .error,
                              key: "SETTINGS_FETCH_ERROR",
                              details: ["err":"SDK Key and Account ID are required to fetch settings. Aborting!"])
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
                    LoggerService.log(level: .info, key: "SETTINGS_FETCH_SUCCESS", details: [:])
                    self.saveSettingInUserDefaults(settingObj: settingsObj)
                    self.saveSettingExpiryInUserDefault()
                    self.settingsFetchTime = Date().currentTimeMillis() - startTime
                    self.isSettingsValid = true
                    completion(settingsObj)
                } else {
                    LoggerService.log(level: .error, key: "SETTINGS_SCHEMA_INVALID", details: nil)
                    completion(nil)
                }
            } else {
                if result.error == .noNetwork {
                    if let cachedSetting = self.getSettingFromUserDefaults() {
                        LoggerService.log(level: .info, key: "SETTINGS_FETCH_SUCCESS", details: [:])
                        self.settingsFetchTime = Date().currentTimeMillis() - startTime
                        self.isSettingsValid = true
                        completion(cachedSetting)
                    } else {
                        LoggerService.log(level: .error, key: "SETTINGS_FETCH_ERROR", details: ["err": "\(result.errorMessage ?? "Unknown error")"])
                        completion(nil)
                    }
                } else {
                    LoggerService.log(level: .error, key: "SETTINGS_FETCH_ERROR", details: ["err": "\(result.errorMessage ?? "Unknown error")"])
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
