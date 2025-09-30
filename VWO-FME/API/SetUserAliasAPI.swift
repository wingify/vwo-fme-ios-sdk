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
 * SetUserAliasAPI - API client for creating user alias mappings
 *
 * This class provides functionality to establish alias mappings between temporary
 * user IDs (logged-out state) and permanent user IDs (logged-in state). This
 * enables user identification continuity across different authentication states
 * and sessions.
 *
 * ## Key Features:
 * - **Alias Creation**: Establishes permanent mappings between temp and user IDs
 *
 * ## API Endpoint:
 * - **Method**: POST
 * - **Path**: `/setUserAlias`
 * - **Query Parameters**: `accountId`, `sdkKey`
 * - **Request Body**: JSON with `userId` (temp ID) and `aliasId` (permanent ID)
 *
 * ## Request Format:
 * ```json
 * {
 *   "userId": "temp_123",
 *   "aliasId": "user_456"
 * }
 * ```
 *
 * ## Response Format:
 * ```json
 * {
 *   "isAliasSet": true
 * }
 * ```


 *
 * ## Use Cases:
 * 1. **User Login**: When a user logs in, create alias from temp ID to user ID
 * 2. **Session Continuity**: Maintain user context across authentication state changes
 * 3. **Cross-Device Tracking**: Link anonymous sessions to authenticated users

 */
class SetUserAliasAPI {
    
    let userIdKey = "userId"
    let aliasIdKey = "aliasId"
    let accountIdKey = "accountId"
    let sdkKey_key = "sdkKey"
    let isAliasResponseKey = "isAliasSet"
    
    /**
     * Creates an alias mapping between a temporary ID and a permanent user ID
     *
     * This method makes an HTTP POST request to the VWO backend to establish
     * an alias relationship between a temporary user ID (representing logged-out
     * state) and a permanent user ID (representing logged-in state).
     *
   
     *
     * @param tempId Temporary ID representing logged-out user state
     * @param userId Permanent user ID representing logged-in user state
     * @param accountId VWO account identifier
     * @param sdkKey SDK authentication key
     * @param completion Completion handler for the async result
     */
    func setUserAlias(tempId: String, userId: String, accountId: Int, sdkKey: String, completion: @escaping (Result<SetUserAliasResponse, Error>) -> Void) {
        
        // Create request body with userId (logged-out state) and aliasId (logged-in state)
        let requestBody = [
            userIdKey: tempId,      // tempId represents user in logged-out state
            aliasIdKey: userId      // userId parameter represents user in logged-in state
        ]
        
        // Create query parameters
        let queryParams: [String: String] = [
            accountIdKey: String(accountId),
            sdkKey_key: sdkKey
        ]
        
        // Create request model
        let requestModel = RequestModel(
            url: UrlService.baseUrl,
            method: HTTPMethod.post.rawValue,
            path: UrlEnum.setUserAlias.rawValue,
            query: queryParams,
            body: requestBody,
            headers: nil,
            scheme: Constants.HTTPS_PROTOCOL,
            port: SettingsManager.instance?.port ?? 0,
            timeout: Constants.SETTINGS_TIMEOUT
        )
        
        // Create network client and make request
        let networkClient = NetworkClient()
        networkClient.POST(request: requestModel) { response in
            if response.isResponseOK() {
                if let data = response.data2 {
                   
                    do {
                        // Parse the simple response format: {"isAliasSet": true}
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let isAliasSet = json[self.isAliasResponseKey] as? Bool {
                            
                            // Create a simple response object with only the required fields
                            let response = SetUserAliasResponse(
                                isAliasSet: isAliasSet
                            )
                            
                            completion(.success(response))
                        } else {
                            // If response doesn't contain isAliasSet, treat as failure
                            LoggerService.log(level: .error, key: "ALIAS_SET_API_ERROR", details: [
                                "error": "Invalid response format - missing isAliasSet field",
                                "tempId": tempId
                            ])
                            let error = NSError(domain: "SetUserAliasAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format - missing isAliasSet field"])
                            completion(.failure(error))
                        }
                    } catch {
                        LoggerService.log(level: .error, key: "ALIAS_SET_API_ERROR", details: [
                            "error": error.localizedDescription,
                            "tempId": tempId
                        ])
                        completion(.failure(error))
                    }
                } else {
                    LoggerService.log(level: .error, key: "ALIAS_SET_API_ERROR", details: [
                        "error": "No data received",
                        "tempId": tempId
                    ])
                    let error = NSError(domain: "SetUserAliasAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    completion(.failure(error))
                }
            } else {
                LoggerService.log(level: .error, key: "ALIAS_SET_API_ERROR", details: [
                    "error": "Request failed with status code: \(response.statusCode)",
                    "tempId": tempId
                ])
                let error = NSError(domain: "SetUserAliasAPI", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status code: \(response.statusCode)"])
                completion(.failure(error))
            }
        }
    }
}
