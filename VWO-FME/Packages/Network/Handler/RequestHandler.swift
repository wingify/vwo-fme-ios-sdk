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

// Handles the creation and modification of network requests
class RequestHandler {
    /**
     * Creates a new request by merging properties from a base request and a configuration model.
     * If both the request URL and the base URL from the configuration are missing, it returns nil.
     * Otherwise, it merges the properties from the configuration into the request if they are not already set.
     *
     * @param request The initial request model.
     * @param config The global request configuration model.
     * @return The merged request model or nil if both URLs are missing.
     */
    func createRequest(request: RequestModel, config: GlobalRequestModel) -> RequestModel? {
        var request = request
        
        // Check if both the request URL and the configuration base URL are missing
        if (config.baseUrl?.isEmpty ?? true) && (request.url?.isEmpty ?? true) {
            return nil // Return nil if no URL is specified
        }

        // Set the request URL, defaulting to the configuration base URL if not set
        if request.url?.isEmpty ?? true {
            request.url = config.baseUrl
        }

        // Set the request timeout, defaulting to the configuration timeout if not set
        if request.timeout == -1 {
            request.timeout = config.timeout
        }

        // Set the request body, defaulting to the configuration body if not set
        if request.body == nil {
            request.body = config.body
        }

        // Set the request headers, defaulting to the configuration headers if not set
        if request.headers == nil {
            request.headers = config.headers ?? [:]
        }

        // Initialize request query parameters, defaulting to an empty map if not set
        var requestQueryParams = request.query ?? [:]

        // Initialize configuration query parameters, defaulting to an empty map if not set
        let configQueryParams = config.query ?? [:]

        // Merge configuration query parameters into the request query parameters if they don't exist
        for (key, value) in configQueryParams {
            if requestQueryParams[key] == nil {
                requestQueryParams[key] = value as? String
            }
        }

        // Set the merged query parameters back to the request
        request.query = requestQueryParams

        return request // Return the modified request
    }
}
