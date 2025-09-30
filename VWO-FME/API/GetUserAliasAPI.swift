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
 * GetUserAliasAPI - API client for retrieving user alias mappings
 *
 * This class provides functionality to fetch alias mappings for multiple user IDs
 * from the VWO backend. It's used to resolve temporary user IDs to their permanent
 * aliases, enabling user identification across different sessions and states.
 *
 * ## Key Features:
 * - **Batch Processing**: Can handle multiple user IDs in a single API call
 * - **JSON Response Parsing**: Automatically decodes response to AliasMapping objects
 * - **Comprehensive Logging**: Detailed logging for success and failure scenarios
 * - **Error Handling**: Proper error handling with detailed error information
 *
 * ## API Endpoint:
 * - **Method**: GET
 * - **Path**: `/getUserAlias`
 * - **Query Parameters**: `userId` (JSON array of user IDs)
 *
 * ## Response Format:
 * ```json
 * [
 *   {
 *     "userId": "temp_123",
 *     "aliasId": "user_456"
 *   }
 * ]
 * ```
 *
 * ## Thread Safety:
 * This class is thread-safe and can be called from any thread. The completion
 * handler will be called on the same thread that initiated the request.
 */
class GetUserAliasAPI {
    let userIdKey = "userId"
    
    /**
     * Retrieves alias mappings for the specified user IDs
     *
     * This method makes an HTTP GET request to the VWO backend to fetch alias
     * mappings for the provided user IDs. The response is automatically parsed
     * into `AliasMapping` objects and returned through the completion handler.
     *
     * ## Parameters:
     * - `userIds`: Array of temporary user IDs to resolve aliases for
     * - `accountId`: VWO account identifier for authentication
     * - `sdkKey`: SDK key for API authentication
     * - `completion`: Completion handler that returns the result asynchronously
     *
     * ## Completion Handler:
     * The completion handler provides a `Result` type:
     * - **Success**: `GetUserAliasResponse` containing the alias mappings
     * - **Failure**: `Error` with details about what went wrong
     
     *
     * @param userIds Array of temporary user IDs to resolve
     * @param accountId VWO account identifier
     * @param sdkKey SDK authentication key
     * @param completion Completion handler for the async result
     */
    func getUserAlias(userIds: [String], accountId: Int, sdkKey: String, completion: @escaping (Result<GetUserAliasResponse, Error>) -> Void) {
        
        // Create query parameters with array of userIds in JSON format
        let queryParams: [String: String] = [
            userIdKey: "[" + userIds.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        ]
        
        // Create request model
        let requestModel = RequestModel(
            url:   UrlService.baseUrl,
            method: HTTPMethod.get.rawValue,
            path: UrlEnum.getUserAlias.rawValue,
            query: queryParams,
            body: nil,
            headers: nil,
            scheme: Constants.HTTPS_PROTOCOL,
            port: SettingsManager.instance?.port ?? 0,
            timeout: Constants.SETTINGS_TIMEOUT
        )
        
        // Create network client and make request
        let networkClient = NetworkClient()
        networkClient.GET(request: requestModel) { response in
            if response.isResponseOK() {
                if let data = response.data2 {
                    do {
                        // Decode the response as an array of AliasMapping objects
                        let aliasMappings = try JSONDecoder().decode([AliasMapping].self, from: data)
                        
                        // Create the response object with the decoded mappings
                        let response = GetUserAliasResponse(aliasMappings: aliasMappings)
                        
                        // Log success
                        LoggerService.log(level: .info, key: "GET_ALIAS_SUCCESS", details: ["ids": userIds.joined(separator: ",")])
                        
                        completion(.success(response))
                    } catch {
                        LoggerService.log(level: .error, key: "GET_ALIAS_FAILED", details: [
                            "error": error.localizedDescription,
                            "ids": userIds.joined(separator: ",")
                        ])
                        completion(.failure(error))
                    }
                } else {
                    LoggerService.log(level: .error, key: "GET_ALIAS_FAILED", details: [
                        "error": "No data received",
                        "ids": userIds.joined(separator: ",")
                    ])
                    let error = NSError(domain: "GetUserAliasAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    completion(.failure(error))
                }
            } else {
                LoggerService.log(level: .error, key: "GET_ALIAS_FAILED", details: [
                    "error": "Request failed with status code: \(response.statusCode)",
                    "ids": userIds.joined(separator: ",")
                ])
                let error = NSError(domain: "GetUserAliasAPI", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status code: \(response.statusCode)"])
                completion(.failure(error))
            }
        }
    }
}
