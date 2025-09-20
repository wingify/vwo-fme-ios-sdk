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
 */
class SyncManager {
    static let shared = SyncManager()
    private var dispatchTimer: DispatchSourceTimer?
    var timerNextFireDate = Date()

    // Minimum number of events required to trigger a sync
    var minimumEventCount: Int = 0
    
    // Time interval for periodic syncs
    var timeInterval: Int64 = 0
    
    // Flag indicating if online batching is allowed
    var isOnlineBatchingAllowed : Bool = false
    private let backgroundQueue = DispatchQueue(label: "com.vwo.fme.timer.syncManager", qos: .background, attributes: .concurrent)
    private let coreDataStack = CoreDataStack.shared
    private let eventManager = EventDataManager.shared
    private let initLock = NSLock()
    
    var isOngoing: Bool = false

    private init() {}
    
    /**
     * Initializes the SyncManager with batch size and time interval.
     *
     * - Parameters:
     *   - minBatchSize: Minimum number of events required to trigger a sync.
     *   - timeInterval: Time interval for periodic syncs in milliseconds.
     */
    func initialize(minBatchSize: Int?, timeInterval: Int64?) {
        initLock.lock()
        defer { initLock.unlock() }
        
        self.isOnlineBatchingAllowed = self.checkOnlineBatchingAllowed(batchSize: minBatchSize, batchUploadInterval: timeInterval)
        self.minimumEventCount = minBatchSize ?? 0
        self.timeInterval = timeInterval ?? (isOnlineBatchingAllowed ? Constants.DEFAULT_BATCH_UPLOAD_INTERVAL : 0)
        if self.timeInterval > 0 {
            self.startSyncing()
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
            let currentTime = Date()
            let tolerance: TimeInterval = 1.0 // 1 second tolerance
            let shouldIgnoreThreshold = currentTime >= self.timerNextFireDate.addingTimeInterval(-tolerance)
            self.timerNextFireDate = currentTime.addingTimeInterval(timeIntervalSeconds)
            self.syncSavedEvents(ignoreThreshold: shouldIgnoreThreshold)
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
        self.coreDataStack.fetchManagedObjects { [weak self] events, error in
            guard let self = self else { return }
            guard let events = events, !events.isEmpty else {
                self.isOngoing = false
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
            if self.isOnlineBatchingAllowed {
                LoggerService.log(level: .info, key: "BATCH_PROCESSING_STARTED", details: ["name": triggerForOnlineBatching])
            }
            self.eventManager.uploadEvents(events: events) { success, eventsData  in
                self.isOngoing = false
                if success {
                    self.eventManager.deleteEvents(data: eventsData) { success in
                        if self.isOnlineBatchingAllowed {
                            LoggerService.log(level: .info,
                                              key: "BATCH_PROCESSING_FINISHED",
                                              details: ["name": triggerForOnlineBatching,
                                                        "status": success ? "success" : "failed"])
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
                LoggerService.log(level: .error, key: "INIT_OPTIONS_INVALID", details: ["key": "batchUploadInterval", "correctType": "number", "value": "60000, batchUploadInterval value in milliseconds "])
            }
            if let size = batchSize, size <= 0 {
                LoggerService.log(level: .error, key: "INIT_OPTIONS_INVALID", details: ["key": "batchMinSize", "correctType": "number", "value": "1"])
            }
            return false
        }
    }
}
