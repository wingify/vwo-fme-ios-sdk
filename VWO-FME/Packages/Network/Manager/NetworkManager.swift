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

class NetworkManager {
    // Serial queue to synchronise access to config and client
    private static let configQueue = DispatchQueue(label: "com.vwo.fme.network.config")

    private static var _config: GlobalRequestModel?
    static var config: GlobalRequestModel? {
        get { configQueue.sync { _config } }
        set { configQueue.sync { _config = newValue } }
    }

    private static var _client: NetworkClientInterface?
    private static var client: NetworkClientInterface? {
        get { configQueue.sync { _client } }
        set { configQueue.sync { _client = newValue } }
    }

    private static let executorService = DispatchQueue.global(qos: .background)
        
    static func attachClient(client: NetworkClientInterface? = NetworkClient()) {
        configQueue.sync {
            if _client != nil {
                return
            }
            _client = client
            _config = GlobalRequestModel() // Initialize with default config
        }
    }
    
    private static func createRequest(_ request: RequestModel) -> RequestModel? {
        let handler = RequestHandler()
        // Snapshot config under the serial queue to avoid races
        let currentConfig = configQueue.sync { _config }
        return currentConfig.flatMap { handler.createRequest(request: request, config: $0) } // Merge and create request
    }
    
    private static func parseJSONString(_ jsonString: String) {
        if jsonString.isEmpty {
            LoggerService.log(level: .error, message: "Cannot parse empty string to JSON")
        } else {
            if let jsonData = jsonString.data(using: .utf8) {
                do {
                    if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                        LoggerService.log(level: .info, message: "Parse JSON Success \(jsonDict)")
                    }
                } catch {
                    LoggerService.log(level: .error, message: "Failed to parse JSON from string: Err: \(error.localizedDescription)")
                }
            } else {
                LoggerService.log(level: .error, message: "Failed to convert JSON string to Data")
            }
        }
    }
    
    static func get(_ request: RequestModel, completion: @escaping (ResponseModel) -> Void) {
        guard let networkOptions = createRequest(request) else {
            return
        }
        
        client?.GET(request: networkOptions, completion: { result in
            completion(result)
        })
    }
    
    static func post(_ request: RequestModel, completion: @escaping (ResponseModel) -> Void) {
        guard let networkOptions = createRequest(request) else {
            return
        }
        
        client?.POST(request: networkOptions, completion: { result in
            completion(result)
        })
    }
    
    static func postAsync(_ request: RequestModel, completion: @escaping (ResponseModel) -> Void) {
        executorService.async {
            let payloadToStore = request.body ?? [:]
            
            // Get account info from request (preferred) or extract from headers
            let accountId = request.accountId
            let sdkKey = request.sdkKey ?? request.headers?["Authorization"] ?? ""
            
            // Try to get ServiceContainer for this account to determine correct SyncManager
            var serviceContainer: ServiceContainer? = nil
            var syncManager: SyncManager? = nil
            
            if let accountId = accountId, !sdkKey.isEmpty {
                serviceContainer = EventDataManager.getServiceContainer(accountId: accountId, sdkKey: sdkKey)
                syncManager = serviceContainer?.getSyncManager()
            }
            
            // Fallback to SyncManager.shared if ServiceContainer not found
            let effectiveSyncManager = syncManager ?? SyncManager.shared
            
            // Check if the request is for event batching
            let isEventBatchingRequest = request.path == Constants.EVENT_BATCH_ENDPOINT
            
            // If online batching is allowed and the request is not an event batching request
            if effectiveSyncManager.isOnlineBatchingAllowed && !isEventBatchingRequest {
                // Store the event payload for later processing with account info
                EventDataManager.shared.createEvent(
                    payload: payloadToStore,
                    sdkKey: sdkKey.isEmpty ? nil : sdkKey,
                    accountId: accountId != nil ? Int64(accountId!) : nil
                )
                return
            } else {
                post(request) { response in
                    // If the response is not successful and the request is not an event batching request
                    if !response.isResponseOK() && !isEventBatchingRequest {
                        // Store the event payload for later processing with account info
                        EventDataManager.shared.createEvent(
                            payload: payloadToStore,
                            sdkKey: sdkKey.isEmpty ? nil : sdkKey,
                            accountId: accountId != nil ? Int64(accountId!) : nil
                        )
                    }
                    completion(response)
                }
            }
        }
    }
}
