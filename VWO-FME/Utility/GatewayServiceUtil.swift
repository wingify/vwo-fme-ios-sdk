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

/**
 * Utility class for gateway service operations.
 *
 * This class provides helper methods for interacting with gateway services, such as sending
 * requests, handling responses, or managing connections.
 */
class GatewayServiceUtil {
    
    /**
     * Fetches data from the gateway service
     * @param queryParams The query parameters to send with the request
     * @param endpoint The endpoint to send the request to
     * @return The response data from the gateway service
     */
    static func getFromGatewayService(queryParams: [String: String], endpoint: String, completion: @escaping (ResponseModel?) -> Void) {
        if UrlService.baseUrl.contains(Constants.HOST_NAME) {
            LoggerService.log(level: .error, key: "GATEWAY_URL_ERROR", details: nil)
            completion(nil)
            return
        }
        
        let request = RequestModel(
            url: UrlService.baseUrl,
            method: HTTPMethod.get.rawValue,
            path: endpoint,
            query: queryParams,
            body: nil,
            headers: nil,
            scheme: SettingsManager.instance?.protocolType ?? Constants.HTTPS_PROTOCOL,
            port: SettingsManager.instance?.port ?? 0
        )
        
        NetworkManager.get(request) { response in
            completion(response)
        }
    }
    
    /**
     * Encodes the query parameters to ensure they are URL-safe
     * @param queryParams The query parameters to encode
     * @return The encoded query parameters
     */
    static func getQueryParams(_ queryParams: [String: String?]) -> [String: String] {
        var encodedParams: [String: String] = [:]
        
        for (key, value) in queryParams {
            if let value = value {
                // Encode the parameter value to ensure it is URL-safe
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                // Add the encoded parameter to the result dictionary
                encodedParams[key] = encodedValue
            }
        }
        
        return encodedParams
    }
}
