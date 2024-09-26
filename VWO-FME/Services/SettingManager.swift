/**
 * Copyright 2024 Wingify Software Pvt. Ltd.
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

class SettingsManager {
    private let sdkKey: String
    private let accountId: Int
    private let expiry: Int
    private let networkTimeout: Int
    var hostname: String
    var port: Int = 0
    var protocolType: String = "https"
    var isSettingsFetchInProgress = false

    var isGatewayServiceProvided: Bool = false
    private var localStorageService = LocalStorageService()

    static var instance: SettingsManager?
    
    init(options: VWOInitOptions) {
        self.sdkKey = options.sdkKey ?? ""
        self.accountId = options.accountId!
        self.expiry = Constants.SETTINGS_EXPIRY
        self.networkTimeout = Constants.SETTINGS_TIMEOUT
        
        if !options.gatewayService.isEmpty {
            
            isGatewayServiceProvided = true
            do {
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
            } catch {
                LoggerService.log(level: .error, message: "Error occurred while parsing gateway service URL: \(error.localizedDescription)")
                self.hostname = Constants.HOST_NAME
            }
        } else {
            self.hostname = Constants.HOST_NAME
        }
        SettingsManager.instance = self
    }
    
    private func fetchSettingsAndCacheInStorage(completion: @escaping (Settings?) -> Void) {
        
        fetchSettings(completion: completion)
    }
    
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
            do {
                let error = result.errorMessage
                if let data = result.data2, error == nil {
                    let settingsObj = try JSONDecoder().decode(Settings.self, from: data)
                    LoggerService.log(level: .info, key: "SETTINGS_FETCH_SUCCESS", details: [:])
                    self.saveSettingInUserDefaults(settingObj: settingsObj)
                    completion(settingsObj)
                } else {
                    LoggerService.log(level: .error, key: "SETTINGS_FETCH_ERROR", details: ["err": "\(result.errorMessage ?? "Unknown error")"])
                    completion(nil)
                }
            } catch {
                LoggerService.log(level: .error, key: "SETTINGS_FETCH_ERROR", details: ["err": "\(error.localizedDescription)"])
                completion(nil)
            }
        }
    }
        
    func getSettings(forceFetch: Bool, completion: @escaping (Settings?) -> Void) {
        
        if self.isSettingsFetchInProgress {
            return
        }
        
        if (forceFetch) {
            fetchSettingsAndCacheInStorage(completion: completion)
        } else {
            if let settings = getSettingFromUserDefaults() {
                completion(settings)
            } else {
                fetchSettingsAndCacheInStorage(completion: completion)
            }
        }
    }
    
    private func getSettingFromUserDefaults() -> Settings? {
        return localStorageService.loadSettings()
    }
    
    private func saveSettingInUserDefaults(settingObj: Settings) {
        localStorageService.saveSettings(settingObj)
    }
}
