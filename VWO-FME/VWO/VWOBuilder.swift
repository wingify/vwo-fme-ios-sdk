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

class VWOBuilder {
    private var vwoClient: VWOClient?
    private var options: VWOInitOptions?
    private var settingFileManager: SettingsManager?
    private var originalSettings: Settings? = nil
    // Timer is instance-specific - each VWOBuilder has its own timer for multi-instance support
    private var timer: Timer?
    var isSettingsValid = false
    var settingsFetchTime : Int64 = 0

    // Instance-level services instead of static ones
    private var loggerService: LoggerService?
    internal var storage: StorageService = StorageService()
    
    // Track if polling is active for this instance
    private var isPollingActive: Bool = false

    init(options: VWOInitOptions?) {
        self.options = options
        UsageStatsUtil.shared.setUsageStats(options: options)
        
        // Alias settings are now managed by ServiceContainer when it's created
        // No need to set them here as they'll be initialized in ServiceContainer.init()
    }

    // Set VWOClient instance
    func setVWOClient(_ vwoClient: VWOClient?) {
        self.vwoClient = vwoClient
    }
    
    /**
     * Gets the LoggerService instance
     * @return LoggerService instance
     */
    func getLoggerService() -> LoggerService? {
        return loggerService
    }
    
    /**
     * Gets the SettingsManager instance
     * @return SettingsManager instance
     */
    func getSettingsManager() -> SettingsManager? {
        return settingFileManager
    }
    
    /**
     * Gets the SyncManager instance (iOS equivalent of BatchManager)
     * @return SyncManager instance
     */
    internal func getBatchManager() -> SyncManager? {
        return SyncManager.shared
    }
    
    /**
     * Creates a ServiceContainer instance with the current settings and options
     * Following Android SDK pattern where ServiceContainer is created per API call
     * @param processedSettings Processed settings object
     * @param options VWO initialization options
     * @return ServiceContainer instance
     */
    func createServiceContainer(processedSettings: Settings?, options: VWOInitOptions) -> ServiceContainer {
        return ServiceContainer(
            settingsManager: settingFileManager,
            options: options,
            settings: processedSettings,
            loggerService: loggerService
        )
    }

    /**
     * Configures the shared StorageConnectorProvider instance.
     * This should be one of the first steps.
     * @return The VWOBuilder instance.
     */
    func setStorage() -> VWOBuilder {
        StorageConnectorProvider.configure(with: options?.storageConnector)
        return self
    }
    
    /**
     * Sets the network manager with the provided client and development mode options.
     * @return The VWOBuilder instance.
     */
    func setNetworkManager() -> VWOBuilder {
        if let options = self.options, let networkClientInterface = options.networkClientInterface {
            NetworkManager.attachClient(client: networkClientInterface)
        } else {
            NetworkManager.attachClient()
        }
        NetworkManager.config?.developmentMode = false
        // Use instance-specific logger to ensure correct prefix
        self.loggerService?.log(level: .debug, key: "SERVICE_INITIALIZED", details: ["service": "Network Layer"])
        return self
    }

    /**
     * Sets the segmentation evaluator with the provided segmentation options.
     * @return The instance of this builder.
     */
    func setSegmentation() -> VWOBuilder {
        if let segmentEvaluator = options?.segmentEvaluator {
            SegmentationManager.attachEvaluator(segmentEvaluator: segmentEvaluator)
        }
        // Use instance-specific logger to ensure correct prefix
        self.loggerService?.log(level: .debug, key: "SERVICE_INITIALIZED", details: ["service": "Segmentation Evaluator"])
        return self
    }

    /**
     * Fetches settings asynchronously, ensuring no parallel fetches.
     * @param forceFetch - Force fetch ignoring cache.
     * @return The fetched settings.
     */
    private func fetchSettings(forceFetch: Bool, completion: @escaping (Settings?) -> Void) {
        guard let settingMangager = settingFileManager else { return }
        
        settingMangager.getSettings(forceFetch: forceFetch) { settingObj in
            
            self.isSettingsValid = settingMangager.isSettingsValid
            self.settingsFetchTime = settingMangager.settingsFetchTime
            if let setting = settingObj {
                self.originalSettings = setting
            }
            completion(settingObj)
        }
    }

    /**
     * Gets the settings, fetching them if not cached or if forced.
     * @param forceFetch - Force fetch ignoring cache.
     * @return The fetched settings.
     */
    func getSettings(forceFetch: Bool, completion: @escaping (Settings?) -> Void) {
        fetchSettings(forceFetch: forceFetch, completion: completion)
    }

    /**
     * Sets the settings manager for the VWO instance.
     * @return The instance of this builder.
     */
    func setSettingsManager() -> VWOBuilder {
        if options == nil {
            return self
        }
        
        // Use thread-safe method to prevent race conditions
        // This will return immediately if instance exists, or create one if needed
        // Pass loggerService to SettingsManager for instance-specific logging
        settingFileManager = SettingsManager.createInstance(options: options!, logger: loggerService)
        
        return self
    }

    /**
     * Sets the logger for the VWO instance.
     * @return The instance of this builder.
     */
    func setLogger() -> VWOBuilder {
        do {
            // Get account info from options for proper instance registration
            let accountId = options?.accountId
            let sdkKey = options?.sdkKey
            
            if self.options == nil || options?.logger.isEmpty != false {
                self.loggerService = LoggerService(config: [:], logLevel: .error, logTransport: nil, accountId: accountId, sdkKey: sdkKey)
                // Also create static instance for backward compatibility
                _ = LoggerService.createInstance(config: [:], logLevel: .error, logTransport: nil, accountId: accountId, sdkKey: sdkKey)
            } else {
                self.loggerService = LoggerService(config: options!.logger, logLevel: options!.logLevel, logTransport: options!.logTransport, accountId: accountId, sdkKey: sdkKey)
                // Also create static instance for backward compatibility
                _ = LoggerService.createInstance(config: options!.logger, logLevel: options!.logLevel, logTransport: options!.logTransport, accountId: accountId, sdkKey: sdkKey)
            }
            
            // Use instance-specific logger to ensure correct prefix (logger is now created)
            self.loggerService?.log(level: .debug, key: "SERVICE_INITIALIZED", details: ["service": "Logger"])
        } catch {
            let message = "Error occurred while initializing Logger : \(error.localizedDescription)"
            print(message)
        }
        return self
    }

    /**
     * Initializes the polling with the provided poll interval.
     * @return The instance of this builder.
     */
    func initPolling() -> VWOBuilder {
        guard let pollInterval = options?.pollInterval else {
            return self
        }

        if pollInterval < 1000 {
            LoggerService.errorLog(key: "INVALID_POLLING_CONFIGURATION",data:["key": "pollInterval", "correctType": "number", "value": "1000"],debugData: ["an":ApiEnum.Init.rawValue] )
            return self
        }

        DispatchQueue.global().async {
            self.startPolling(interval: pollInterval)
        }
        return self
    }
    
    /**
     * Checks and polls for settings updates at the provided interval.
     * Each VWOBuilder instance maintains its own timer for multi-instance support.
     */
    private func startPolling(interval: Int64) {
        // Stop any existing polling for this instance only
        self.stopPolling()
        let intervalInMilliseconds = interval
        // Convert milliseconds to seconds
        let pollingIntervalSeconds = TimeInterval(intervalInMilliseconds) / 1000.0
        
        // Mark polling as active for this instance
        self.isPollingActive = true
        
        // Schedule timer on main run loop for this specific instance
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isPollingActive else { return }
            // Create timer with strong reference to self to keep the instance alive
            // The timer will retain self, and self is retained by VWOClient -> VWOFme
            self.timer = Timer.scheduledTimer(timeInterval: pollingIntervalSeconds, target: self, selector: #selector(self.checkSettingUpdates), userInfo: nil, repeats: true)
            if let timer = self.timer {
                // Add to current run loop mode to ensure it runs
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }
    
    /**
     * Stops polling for this specific VWOBuilder instance.
     * This only affects the timer for this instance, not other instances.
     */
    private func stopPolling() {
        self.isPollingActive = false
        // Invalidate timer on main thread to avoid threading issues
        if let timer = self.timer {
            DispatchQueue.main.async { [weak self] in
                timer.invalidate()
                self?.timer = nil
            }
        } else {
            self.timer = nil
        }
    }

    @objc private func checkSettingUpdates() {
        let pollingQueue = DispatchQueue(label: "com.vwo.fme.polling", qos: .background)
        pollingQueue.async { [weak self] in
            guard let self = self else { return }
            guard let settingMangager = self.settingFileManager else { return }
            settingMangager.getSettings(forceFetch: true) { settingObj in
                
                if let latestSettings = settingObj, let originalSetting = self.originalSettings {
                    let isDifferent = self.findDifference(localSettings: originalSetting, apiSettings: latestSettings)
                    if isDifferent {
                        self.originalSettings = latestSettings
                        settingMangager.saveSettingInUserDefaults(settingObj: latestSettings)
                        settingMangager.saveSettingExpiryInUserDefault()
                        
                        if let vwoClient = self.vwoClient {
                            vwoClient.updateSettings(newSettings: self.originalSettings)
                        }

                        // Use instance-specific logger to ensure correct prefix
                        self.loggerService?.log(level: .info, key: "POLLING_SET_SETTINGS", details: [:])
                    } else {
                        // Use instance-specific logger to ensure correct prefix
                        self.loggerService?.log(level: .info, key: "POLLING_NO_CHANGE_IN_SETTINGS", details: [:])
                    }
                }
            }
        }
    }
    
    func findDifference(localSettings: Settings, apiSettings: Settings) -> Bool {
        var differences = [String]()
        
        let sortedLocalSettingFeatures = localSettings.features.sortedById()
        let sortedApiSettingsFeatures = apiSettings.features.sortedById()
        
        if sortedLocalSettingFeatures != sortedApiSettingsFeatures {
            differences.append("features")
        }
        if localSettings.accountId != apiSettings.accountId {
            differences.append("accountId")
        }
        if localSettings.groups != apiSettings.groups {
            differences.append("groups")
        }
        if localSettings.campaignGroups != apiSettings.campaignGroups {
            differences.append("campaignGroups")
        }
        if localSettings.isNBv2 != apiSettings.isNBv2 {
            differences.append("isNBv2")
        }
        if localSettings.campaigns != apiSettings.campaigns {
            differences.append("campaigns")
        }
        if localSettings.isNB != apiSettings.isNB {
            differences.append("isNB")
        }
        if localSettings.sdkKey != apiSettings.sdkKey {
            differences.append("sdkKey")
        }
        if localSettings.version != apiSettings.version {
            differences.append("version")
        }
        if localSettings.collectionPrefix != apiSettings.collectionPrefix {
            differences.append("collectionPrefix")
        }
        return !differences.isEmpty
    }
    
    /**
     * Starts network monitoring.
     * @return The instance of this builder.
     */
    @available(macOS 10.14, *)
    func setNetworkMonitoring() -> VWOBuilder {
        NetworkMonitor.shared.startMonitoring()
        return self
    }
    
    /**
     * Initializes the SyncManager with batch processing options.
     * Note: SyncManager is now initialized in ServiceContainer, so this method is kept for backward compatibility
     * but does nothing. The initialization happens automatically when ServiceContainer is created.
     */
    func initSyncManager() {
        // SyncManager initialization is now handled in ServiceContainer.init()
        // This method is kept for backward compatibility but is a no-op
    }
}
