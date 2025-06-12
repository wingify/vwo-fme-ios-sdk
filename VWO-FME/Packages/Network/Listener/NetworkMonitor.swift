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
    
    // Work item for debouncing network status updates
    private var debounceWorkItem: DispatchWorkItem?
    
    // Queue for handling debounced tasks
    private let debounceQueue = DispatchQueue(label: "com.vwo.fme.debounceQueue", qos: .background)
    
    private init() {}
    
    /**
     * Starts monitoring network connectivity changes.
     * If the network becomes available, it checks internet connectivity and triggers a sync of saved events.
     */
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                // Network is available
                self.debounceWorkItem?.cancel()
                self.debounceWorkItem = DispatchWorkItem {
                    self.checkInternetConnectivity { success in
                        if success {
                            // Trigger sync of saved events if internet connectivity is confirmed
                            SyncManager.shared.syncSavedEvents(ignoreThreshold: true)
                        }
                    }
                }
                
                // Add a delay to prevent rapid successive updates
                let delay = 3.0
                if let workItem = self.debounceWorkItem {
                    self.debounceQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
                }
                
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
        isMonitoring = false
    }
    
    /**
     * Checks internet connectivity by making a HEAD request to a known URL.
     * Retries the request a specified number of times with exponential backoff.
     *
     * - Parameters:
     *   - retries: Number of retry attempts
     *   - delay: Initial delay between retries
     *   - completion: Completion handler with a boolean indicating connectivity status
     */
    private func checkInternetConnectivity(retries: Int = 3, delay: TimeInterval = 1.0, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://www.google.com") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true)
            } else {
                if retries > 0 {
                    let nextDelay = delay * 2
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.checkInternetConnectivity(retries: retries - 1, delay: nextDelay, completion: completion)
                    }
                } else {
                    completion(false)
                }
            }
        }
        task.resume()
    }
    
    // Deinitializer to stop monitoring when the instance is deallocated
    deinit {
        self.stopMonitoring()
    }
}
