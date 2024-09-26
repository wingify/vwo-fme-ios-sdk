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
 * Provides URL-related services.
 *
 * This class is responsible for managing and providing URLs used by the application, such as
 * constructing API endpoints or generating URLs for resources.
 */
class UrlService {
    private static var collectionPrefix: String? = nil

    /**
     * Initializes the UrlService with the collectionPrefix
     * @param collectionPrefix  collectionPrefix to be used in the URL
     */
    static func initialize(collectionPrefix: String?) {
        if let prefix = collectionPrefix, !prefix.isEmpty {
            UrlService.collectionPrefix = prefix
        }
    }

    static var baseUrl: String {
        /**
         * Returns the base URL for the API requests
         */
        let baseUrl: String = SettingsManager.instance?.hostname ?? ""

        if SettingsManager.instance?.isGatewayServiceProvided == true {
            return baseUrl
        }

        // Construct URL with collectionPrefix if it exists
        if let prefix = collectionPrefix, !prefix.isEmpty {
            return "\(baseUrl)/\(prefix)"
        }

        return baseUrl
    }
}
