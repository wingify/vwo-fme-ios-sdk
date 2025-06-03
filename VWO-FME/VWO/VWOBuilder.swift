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
    private var timer: Timer?

    init(options: VWOInitOptions?) {
        self.options = options
        UsageStatsUtil.setUsageStats(options: options)
    }

    // Set VWOClient instance
    func setVWOClient(_ vwoClient: VWOClient?) {
        self.vwoClient = vwoClient
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
        LoggerService.log(level: .debug, key: "SERVICE_INITIALIZED", details: ["service": "Network Layer"])
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
        LoggerService.log(level: .debug, key: "SERVICE_INITIALIZED", details: ["service": "Segmentation Evaluator"])
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
        settingFileManager = SettingsManager(options: options!)
        return self
    }

    /**
     * Sets the logger for the VWO instance.
     * @return The instance of this builder.
     */
    func setLogger() -> VWOBuilder {
        
        if let options = options, !options.logger.isEmpty {
            _ = LoggerService(config: options.logger, logLevel: options.logLevel, logTransport: options.logTransport)
        } else {
            _ = LoggerService(config: [:], logLevel: .error, logTransport: nil)
        }
        LoggerService.log(level: .debug, key: "SERVICE_INITIALIZED", details: ["service": "Logger"])
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
            LoggerService.log(level: .error, key: "INIT_OPTIONS_INVALID", details: ["key": "pollInterval", "correctType": "number", "value": "1000"])
            return self
        }

        DispatchQueue.global().async {
            self.startPolling(interval: pollInterval)
        }
        return self
    }
    
    /**
     * Checks and polls for settings updates at the provided interval.
     */
    private func startPolling(interval: Int64) {
        self.stopPolling()
        let intervalInMilliseconds = interval
        // Convert milliseconds to seconds
        let pollingIntervalSeconds = TimeInterval(intervalInMilliseconds) / 1000.0
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(timeInterval: pollingIntervalSeconds, target: self, selector: #selector(self.checkSettingUpdates), userInfo: nil, repeats: true)
            if self.timer != nil {
                RunLoop.current.add(self.timer!, forMode: .common)
            }
        }
    }
    
    private func stopPolling() {
        self.timer?.invalidate()
        self.timer = nil
    }

    @objc private func checkSettingUpdates() {
        let pollingQueue = DispatchQueue(label: "com.vwo.fme.polling", qos: .background)
        pollingQueue.async { [unowned self] in
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

                        LoggerService.log(level: .info, key: "POLLING_SET_SETTINGS", details: [:])
                    } else {
                        LoggerService.log(level: .info, key: "POLLING_NO_CHANGE_IN_SETTINGS", details: [:])
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
    func setNetworkMonitoring() -> VWOBuilder {
        NetworkMonitor.shared.startMonitoring()
        return self
    }
    
    /**
     * Initializes the SyncManager with batch processing options.
     */
    func initSyncManager() {
        let batchSize = options?.batchMinSize
        let batchTime = options?.batchUploadTimeInterval
        let isAllowed = SyncManager.shared.checkOnlineBatchingAllowed(batchSize: batchSize, batchUploadInterval: batchTime)
        if isAllowed {
            SyncManager.shared.initialize(minBatchSize: batchSize, timeInterval: batchTime)
        }
        LoggerService.log(level: .info, key: "ONLINE_BATCH_PROCESSING_STATUS", details: ["status": isAllowed ? "enabled" : "disabled"])
    }
}
