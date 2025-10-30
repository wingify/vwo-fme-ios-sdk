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
    private let syncManager = SyncManager.shared
    
    // Usage stats utility (singleton in iOS)
    let usageStats = UsageStatsUtil.shared
    
    // Optional storage service exposure if needed by callers
    internal var storage: StorageService? = StorageService()
    
    init(settingsManager: SettingsManager?, options: VWOInitOptions, settings: Settings?, loggerService: LoggerService?) {
        self.settingsManager = settingsManager
        self.options = options
        self.settings = settings
        self.loggerService = loggerService
        self.hooksManager = HooksManager(callback: options.integrations)
        self.segmentationManager = SegmentationManager()
        
        // Attach segment evaluator if provided
        if let segmentEvaluator = options.segmentEvaluator {
            self.segmentationManager.attachEvaluator(segmentEvaluator: segmentEvaluator)
        }
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


