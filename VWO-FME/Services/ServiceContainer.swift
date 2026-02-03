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
 * ServiceContainer manages all services required for VWO SDK operations.
 * This ensures each VWO instance has its own isolated set of services,
 * preventing conflicts when multiple accounts are used.
 */
class ServiceContainer {
    private var settingsManager: SettingsManager?
    private let options: VWOInitOptions
    private var settings: Settings?
    private var loggerService: LoggerService?
    
    private let hooksManager: HooksManager
    
    // iOS equivalents for Android managers
    // Instance-based SegmentationManager for isolation
    private let segmentationManager: SegmentationManager
    private let syncManager: SyncManager
    private let aliasIdentifierManager: AliasIdentifierManager
    
    // Usage stats utility (singleton in iOS)
    let usageStats = UsageStatsUtil.shared
    
    // Optional storage service exposure if needed by callers
    // Initialize with account info for multi-instance support
    internal var storage: StorageService? = StorageService()
    
    init(settingsManager: SettingsManager?, options: VWOInitOptions, settings: Settings?, loggerService: LoggerService?) {
        self.settingsManager = settingsManager
        self.options = options
        self.settings = settings
        self.loggerService = loggerService
        self.hooksManager = HooksManager(callback: options.integrations)
        self.segmentationManager = SegmentationManager()
        
        // Initialize syncManager with a temporary instance first (all stored properties must be initialized before using self)
        // We'll set the serviceContainer reference after initialization
        self.syncManager = SyncManager()
        self.aliasIdentifierManager = AliasIdentifierManager()
        
        // Now that all properties are initialized, we can use self
        // Set the serviceContainer reference and register it
        self.syncManager.setServiceContainer(self)
        self.aliasIdentifierManager.setServiceContainer(self, options: options)
        
        // Set account info in StorageService for multi-instance support
        self.storage?.setAccountInfo(accountId: getAccountId(), sdkKey: getSdkKey())
        
        // Initialize SyncManager with batch settings from options
        let batchSize = options.batchMinSize
        let batchTime = options.batchUploadTimeInterval
        let isAllowed = syncManager.checkOnlineBatchingAllowed(batchSize: batchSize, batchUploadInterval: batchTime)
        if isAllowed {
            syncManager.initialize(minBatchSize: batchSize, timeInterval: batchTime)
        }
        // Use instance-specific logger to ensure correct prefix
        loggerService?.log(level: .info, key: "ONLINE_BATCH_PROCESSING_STATUS", details: ["status": isAllowed ? "enabled" : "disabled"])
        
        // Attach segment evaluator if provided
        if let segmentEvaluator = options.segmentEvaluator {
            self.segmentationManager.attachEvaluator(segmentEvaluator: segmentEvaluator)
        }
        
        // Set ServiceContainer reference in LoggerService for error event sending
        loggerService?.setServiceContainer(self)
        
        // Register LoggerService instance with account key for static log prefix lookup
        if let logger = loggerService {
            let accountKey = "\(getAccountId())_\(getSdkKey())"
            LoggerService.registerInstance(accountKey: accountKey, instance: logger)
        }
        
        // Register ServiceContainer in EventDataManager for instance-specific operations
        EventDataManager.registerServiceContainer(self)
    }
    
    // MARK: - LoggerService
    func getLoggerService() -> LoggerService? {
        return loggerService
    }
    
    func setLoggerService(_ loggerService: LoggerService) {
        self.loggerService = loggerService
    }
    
    // MARK: - SettingsManager
    func getSettingsManager() -> SettingsManager? {
        return settingsManager
    }
    
    func setSettingsManager(_ settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }
    
    // MARK: - HooksManager
    func getHooksManager() -> HooksManager {
        return hooksManager
    }
    
    // MARK: - Options
    func getVWOInitOptions() -> VWOInitOptions {
        return options
    }
    
    // MARK: - Sync (batch) manager (iOS equivalent)
    func getSyncManager() -> SyncManager {
        return syncManager
    }
    
    // MARK: - Segmentation
    func getSegmentationManager() -> SegmentationManager {
        return segmentationManager
    }
    
    // MARK: - AliasIdentifierManager
    func getAliasIdentifierManager() -> AliasIdentifierManager {
        return aliasIdentifierManager
    }
    
    // MARK: - Settings
    func getSettings() -> Settings? {
        return settings
    }
    
    func setSettings(_ settings: Settings) {
        self.settings = settings
    }
    
    // MARK: - Base URL
    func getBaseUrl() -> String {
        let baseUrl = self.settingsManager?.hostname ?? ""
        
        // If gateway service is provided, return base URL as-is
        if !self.options.gatewayService.isEmpty {
            return baseUrl
        }
        
        // Append collection prefix if available
        if let collectionPrefix = self.settings?.collectionPrefix, !collectionPrefix.isEmpty {
            return baseUrl.isEmpty ? collectionPrefix : "\(baseUrl)/\(collectionPrefix)"
        }
        
        return baseUrl
    }
    
    // MARK: - Identifiers
    func getAccountId() -> Int {
        return settingsManager?.accountId ?? options.accountId ?? 0
    }
    
    func getSdkKey() -> String {
        return settingsManager?.sdkKey ?? options.sdkKey ?? ""
    }
}


