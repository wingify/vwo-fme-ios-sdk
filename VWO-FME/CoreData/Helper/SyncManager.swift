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
import CoreData

/**
 * Manages synchronization of event data with the server.
 * Each instance is tied to a specific ServiceContainer for multi-instance support.
 * 
 * IMPORTANT: For multi-instance support, use the SyncManager instance from ServiceContainer,
 * not the static `shared` singleton. The `shared` singleton is kept only for backward compatibility
 * and should not be used in new multi-instance code.
 * 
 * Each instance maintains its own:
 * - Timer (dispatchTimer)
 * - Account identifiers (accountId, sdkKey)
 * - Batch settings (minimumEventCount, timeInterval)
 * - Background queue (unique per instance)
 * 
 * Calling `stopSyncing()` on an instance will only stop that instance's timer,
 * not affecting other instances.
 */
class SyncManager {
    // Static registry for backward compatibility (similar to AliasIdentifierManager pattern)
    private static var _instances: [String: SyncManager] = [:]
    private static let instanceQueue = DispatchQueue(label: "com.vwo.fme.syncmanager.instances", attributes: .concurrent)
    
    /**
     * Legacy singleton for backward compatibility.
     * Returns an instance based on SettingsManager.instance if available.
     * WARNING: In multi-instance scenarios, prefer using SyncManager from ServiceContainer.
     */
    static var shared: SyncManager {
        if let settingsManager = SettingsManager.instance {
            let accountKey = "\(settingsManager.accountId)_\(settingsManager.sdkKey)"
            return instanceQueue.sync {
                if let instance = _instances[accountKey] {
                    return instance
                }
                // Create a temporary instance for backward compatibility
                let instance = SyncManager()
                instance.accountId = settingsManager.accountId
                instance.sdkKey = settingsManager.sdkKey
                return instance
            }
        }
        // Fallback: create a temporary instance
        return SyncManager()
    }
    
    /**
     * Static method for backward compatibility - gets instance by account key
     */
    static func getInstance(accountId: Int, sdkKey: String) -> SyncManager? {
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
    
    // Instance-specific ServiceContainer reference for multi-instance support
    private weak var serviceContainer: ServiceContainer?
    
    // Instance-specific account identifiers
    private var accountId: Int = 0
    private var sdkKey: String = ""
    
    private var dispatchTimer: DispatchSourceTimer?
    var timerNextFireDate = Date()

    // Minimum number of events required to trigger a sync
    var minimumEventCount: Int = 0
    
    // Time interval for periodic syncs
    var timeInterval: Int64 = 0
    
    // Flag indicating if online batching is allowed
    var isOnlineBatchingAllowed : Bool = false
    // Instance-specific background queue for timer (unique per instance to avoid conflicts)
    private let backgroundQueue: DispatchQueue
    private let coreDataStack = CoreDataStack.shared
    private let eventManager = EventDataManager.shared
    // Concurrent queue for initialization (better performance than locks)
    private let initQueue = DispatchQueue(label: "com.vwo.fme.syncmanager.init", attributes: .concurrent)
    
    var isOngoing: Bool = false

    internal init() {
        // Create instance-specific serial queue for timer (DispatchSourceTimer should use serial queue)
        let uniqueId = UUID().uuidString
        self.backgroundQueue = DispatchQueue(label: "com.vwo.fme.timer.syncManager.\(uniqueId)", qos: .background)
    }
    
    /**
     * Sets the ServiceContainer reference for this SyncManager instance.
     * - Parameter serviceContainer: The ServiceContainer instance
     */
    func setServiceContainer(_ serviceContainer: ServiceContainer) {
        self.serviceContainer = serviceContainer
        self.accountId = serviceContainer.getAccountId()
        self.sdkKey = serviceContainer.getSdkKey()
        
        // Register this instance for static lookup
        let accountKey = "\(accountId)_\(sdkKey)"
        SyncManager.instanceQueue.async(flags: .barrier) {
            SyncManager._instances[accountKey] = self
        }
    }
    
    /**
     * Initializes the SyncManager with batch size and time interval.
     *
     * - Parameters:
     *   - minBatchSize: Minimum number of events required to trigger a sync.
     *   - timeInterval: Time interval for periodic syncs in milliseconds.
     */
    func initialize(minBatchSize: Int?, timeInterval: Int64?) {
        initQueue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.isOnlineBatchingAllowed = self.checkOnlineBatchingAllowed(batchSize: minBatchSize, batchUploadInterval: timeInterval)
            self.minimumEventCount = minBatchSize ?? 0
            self.timeInterval = timeInterval ?? (self.isOnlineBatchingAllowed ? Constants.DEFAULT_BATCH_UPLOAD_INTERVAL : 0)
            if self.timeInterval > 0 {
                self.startSyncing()
            }
        }
    }
    
    /**
     * Starts the periodic syncing of events.
     */
    func startSyncing() {
        // Stop any existing timer first
        stopSyncing()
        
        // Validate timeInterval before proceeding
        guard self.timeInterval > 0 else {
            print("SyncManager: Invalid timeInterval (\(self.timeInterval)), skipping startSyncing")
            return
        }
        
        let intervalInMilliseconds = self.timeInterval
        // Convert milliseconds to seconds
        let timeIntervalSeconds = TimeInterval(intervalInMilliseconds) / 1000.0
        
        // Additional validation for timeIntervalSeconds
        guard timeIntervalSeconds > 0 else {
            print("SyncManager: Invalid timeIntervalSeconds (\(timeIntervalSeconds)), skipping startSyncing")
            return
        }
                
        self.timerNextFireDate = Date().addingTimeInterval(timeIntervalSeconds)
        self.dispatchTimer = DispatchSource.makeTimerSource(queue: self.backgroundQueue)
        self.dispatchTimer?.schedule(deadline: .now() + timeIntervalSeconds, repeating: timeIntervalSeconds)
        self.dispatchTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            // Always use ignoreThreshold=true for timer-based triggers to ensure time interval works
            // This ensures that time-based batch processing works regardless of minimum batch size
            self.syncSavedEvents(ignoreThreshold: true)
        }
        self.dispatchTimer?.resume()
    }
    
    /**
     * Stops the periodic syncing of events.
     */
    func stopSyncing() {
        if self.dispatchTimer != nil {
            self.dispatchTimer?.cancel()
            self.dispatchTimer = nil
        }
    }
    
    /**
     * Synchronizes saved events with the server. It can be triggered
     * either automatically based on certain conditions (like reaching a minimum event count or
     * a time interval) or manually.
     *
     * - Parameter manually: A boolean indicating if the sync was triggered manually. When set to true,
     *   the sync will occur regardless of whether the usual triggers (such as minimum event count or time interval)
     *   have been met.
     */
    @objc func syncSavedEvents(manually: Bool = false, ignoreThreshold: Bool = false) {
        
        if self.isOngoing {
            return
        }
        
        self.isOngoing = true
        
        // Debug: Verify which instance this SyncManager belongs to
        
        // Fetch events filtered by this instance's accountId and sdkKey
        self.coreDataStack.fetchManagedObjects(accountId: Int64(self.accountId), sdkKey: self.sdkKey) { [weak self] events, error in
            guard let self = self else { return }
            guard let events = events, !events.isEmpty else {
                self.isOngoing = false
                // If triggered by time interval and no events, still log that batch processing was attempted
                if ignoreThreshold && self.isOnlineBatchingAllowed {
                    // Try to get logger from serviceContainer first, then fallback to getting by accountId/sdkKey
                    var loggerService = self.serviceContainer?.getLoggerService()
                    if loggerService == nil && self.accountId > 0 && !self.sdkKey.isEmpty {
                        loggerService = LoggerService.getInstance(accountId: self.accountId, sdkKey: self.sdkKey)
                    }
                    if let logger = loggerService {
                        logger.log(level: .info, key: "BATCH_PROCESSING_FINISHED", details: [
                            "name": "time interval",
                            "status": "no events to upload"
                        ])
                    } else {
                        LoggerService.log(level: .info, key: "BATCH_PROCESSING_FINISHED", details: [
                            "name": "time interval",
                            "status": "no events to upload"
                        ])
                    }
                }
                return
            }
            
            let allEventsCount = events.count
            let isThresdholdReached = allEventsCount >= self.minimumEventCount
            let isMinimumCountRequired = self.minimumEventCount != 0

            if self.isOnlineBatchingAllowed && isMinimumCountRequired && !isThresdholdReached && !manually && !ignoreThreshold {
                self.isOngoing = false
                return
            }
            
            let triggerForOnlineBatching = ignoreThreshold ? "time interval" : "minimum batch size"
            
            // Use instance-specific logger from ServiceContainer, with fallback to get by accountId/sdkKey
            var loggerService = self.serviceContainer?.getLoggerService()
            if loggerService == nil && self.accountId > 0 && !self.sdkKey.isEmpty {
                loggerService = LoggerService.getInstance(accountId: self.accountId, sdkKey: self.sdkKey)
            }
            
            if self.isOnlineBatchingAllowed {
                if let logger = loggerService {
                    logger.log(level: .info, key: "BATCH_PROCESSING_STARTED", details: ["name": triggerForOnlineBatching])
                } else {
                    // Fallback to static log if no instance found
                    LoggerService.log(level: .info, key: "BATCH_PROCESSING_STARTED", details: ["name": triggerForOnlineBatching])
                }
            }
            
            self.eventManager.uploadEvents(events: events, serviceContainer: self.serviceContainer) { success, eventsData  in
                self.isOngoing = false
                if success {
                    self.eventManager.deleteEvents(data: eventsData) { deleteSuccess in
                        if self.isOnlineBatchingAllowed {
                            if let logger = loggerService {
                                logger.log(level: .info,
                                          key: "BATCH_PROCESSING_FINISHED",
                                          details: ["name": triggerForOnlineBatching,
                                                    "status": deleteSuccess ? "success" : "failed"])
                            } else {
                                // Fallback to static log if no instance found
                                LoggerService.log(level: .info,
                                                  key: "BATCH_PROCESSING_FINISHED",
                                                  details: ["name": triggerForOnlineBatching,
                                                            "status": deleteSuccess ? "success" : "failed"])
                            }
                        }
                    }
                } else {
                    // Log failure even if upload failed
                    if self.isOnlineBatchingAllowed {
                        if let logger = loggerService {
                            logger.log(level: .info,
                                      key: "BATCH_PROCESSING_FINISHED",
                                      details: ["name": triggerForOnlineBatching,
                                                "status": "failed"])
                        } else {
                            LoggerService.log(level: .info,
                                              key: "BATCH_PROCESSING_FINISHED",
                                              details: ["name": triggerForOnlineBatching,
                                                        "status": "failed"])
                        }
                    }
                }
            }
        }
    }
    
    /**
     * Determines whether online batching is allowed based on configured settings.
     *
     * This function checks if online batching is enabled by verifying if either the minimum batch
     * size or the batch upload time interval is configured.
     * Online batching is considered allowed if either of these settings is greater than 0.
     *
     * - Returns: `true` if online batching is allowed, `false` otherwise.
     */
    func checkOnlineBatchingAllowed(batchSize: Int?, batchUploadInterval: Int64?) -> Bool {
        if batchSize == nil && batchUploadInterval == nil {
            return false
        }
        
        let minimumInterval = 1*60*1000 // 1 min in milliseconds
        
        switch (batchSize, batchUploadInterval) {
        case let (size?, interval?) where size > 0 && interval > minimumInterval:
            return true
        case let (size?, nil) where size > 0:
            return true
        case let (nil, interval?) where interval > minimumInterval:
            return true
        case let (0, interval?) where interval > minimumInterval:
            return true
        case let (size?, 0) where size > 0: // New condition added here
            return true
        default:
            if let interval = batchUploadInterval, interval < minimumInterval {
                LoggerService.errorLog(key: "INIT_OPTIONS_INVALID",data:["key": "batchUploadInterval", "correctType": "number", "value": "60000, batchUploadInterval value in milliseconds "],debugData: ["an":ApiEnum.Init.rawValue] )
            }
            if let size = batchSize, size <= 0 {
                LoggerService.errorLog(key: "INIT_OPTIONS_INVALID",data:["key": "batchMinSize", "correctType": "number", "value": "1"],debugData: ["an":ApiEnum.Init.rawValue] )
            }
            return false
        }
    }
}
