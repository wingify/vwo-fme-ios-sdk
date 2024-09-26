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

class NetworkManager {
    static var config: GlobalRequestModel? = nil
    private static var client: NetworkClientInterface? = nil
    private static let executorService = DispatchQueue.global(qos: .background)
        
    static func attachClient(client: NetworkClientInterface? = NetworkClient()) {
        self.client = client
        self.config = GlobalRequestModel() // Initialize with default config
    }
    
    private static func createRequest(_ request: RequestModel) -> RequestModel? {
        let handler = RequestHandler()
        return self.config.flatMap { handler.createRequest(request: request, config: $0) } // Merge and create request
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
            post(request, completion: completion)
        }
    }
}
