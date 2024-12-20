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

/**
 * Represents initialization options for the VWO SDK.
 *
 * This class provides configuration options for initializing the VWO SDK, including SDK key, account ID,
 * logging preferences, network client interface, and other settings.
 */
public class VWOInitOptions {
    var sdkKey: String?
    var accountId: Int?
    var integrations: IntegrationCallback?
    var logger: [String: Any] = [:]
    var logLevel: LogLevelEnum = .error
    var networkClientInterface: NetworkClientInterface?
    var segmentEvaluator: SegmentEvaluator?
    var storage: StorageService?
    var pollInterval: Int64?
    var vwoBuilder: VWOBuilder?
    var gatewayService: [String: Any] = [:]
    var cachedSettingsExpiryTime: Int64 = Constants.SETTINGS_EXPIRY
    var sdkName: String = Constants.SDK_NAME
    var sdkVersion: String = Constants.SDK_VERSION
    
    /**
     * Initializes a new instance of VWOInitOptions.
     *
     * - Parameters:
     *   - sdkKey: The SDK key for authentication.
     *   - accountId: The account ID associated with the SDK.
     *   - logLevel: The level of logging to be used.
     *   - logPrefix: A prefix to be added to log messages.
     *   - integrations: Callback for integrations.
     *   - gatewayService: Configuration for the gateway service.
     *   - cachedSettingsExpiryTime: Expiry time for cached settings in milliseconds.
     *   - pollInterval: Interval for polling updates in milliseconds.
     */
    public init(sdkKey: String? = nil,
                accountId: Int? = nil,
                logLevel: LogLevelEnum = .error,
                logPrefix: String = "",
                integrations: IntegrationCallback? = nil,
                gatewayService: [String: Any] = [:],
                cachedSettingsExpiryTime: Int64? = nil,
                pollInterval: Int64? = nil,
                sdkName: String? = nil,
                sdkVersion: String? = nil) {
        
        // Assigning the SDK key
        self.sdkKey = sdkKey
        
        // Assigning the account ID
        self.accountId = accountId
        
        // Setting the log level
        self.logLevel = logLevel
                
        // Configuring the logger with level and prefix
        self.logger = ["level": "\(logLevel.rawValue)", "prefix": "\(logPrefix)"]
        
        // Setting the integrations callback
        self.integrations = integrations
        
        // Configuring the gateway service
        self.gatewayService = gatewayService
        
        // Setting the cached settings expiry time if provided
        if let userExpiryTime = cachedSettingsExpiryTime {
            self.cachedSettingsExpiryTime = userExpiryTime
        }
        
        // Setting the poll interval if provided
        if let pollingTime = pollInterval {
            self.pollInterval = pollingTime
        }
        
        if let sdkNameClient = sdkName {
            self.sdkName = sdkNameClient
            SDKMetaUtil.name = sdkNameClient
        } else {
            self.sdkName = Constants.SDK_NAME
            SDKMetaUtil.name = Constants.SDK_NAME
        }
        
        if let sdkVersionClient = sdkVersion {
            self.sdkVersion = sdkVersionClient
            SDKMetaUtil.version = sdkVersionClient
        } else {
            self.sdkVersion = Constants.SDK_VERSION
            SDKMetaUtil.version = Constants.SDK_VERSION
        }
    }
}
