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
import Network

/**
 * NetworkMonitor is a singleton class responsible for monitoring network connectivity changes.
 * It uses NWPathMonitor to observe network status and performs actions when the network becomes available.
 */
@available(macOS 10.14, *)
class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)
    private var isMonitoring = false
    
    // Work item for debouncing network status updates (only accessed on debounceQueue)
    private var debounceWorkItem: DispatchWorkItem?
    
    // Serial queue for all debounce cancel/schedule to avoid dispatch_block_cancel crash
    private let debounceQueue = DispatchQueue(label: "com.vwo.fme.debounceQueue", qos: .background)
    
    private init() {}
    
    /**
     * Starts monitoring network connectivity changes.
     * When the network path becomes satisfied, triggers a sync of saved events directly
     */
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied, let self = self else { return }
            self.debounceQueue.async {
                self.debounceWorkItem?.cancel()
                let workItem = DispatchWorkItem {
                    SyncManager.shared.syncSavedEvents(ignoreThreshold: true)
                }
                self.debounceWorkItem = workItem
                self.debounceQueue.asyncAfter(deadline: .now() + 3.0, execute: workItem)
            }
        }
        monitor.start(queue: queue)
    }
    
    /**
     * Stops monitoring network connectivity changes.
     */
    func stopMonitoring() {
        guard isMonitoring else { return }
        monitor.cancel()
        debounceQueue.async { [weak self] in
            self?.debounceWorkItem?.cancel()
            self?.debounceWorkItem = nil
        }
        isMonitoring = false
    }
    
    // Deinitializer to stop monitoring when the instance is deallocated
    deinit {
        self.stopMonitoring()
    }
}
