/**
 * Copyright 2024-2026 Wingify Software Pvt. Ltd.
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

struct Constants {
    static let defaultString: String = ""
    static let PLATFORM: String = "ios"

    static let SDK_VERSION: String = "1.50.0"

    static let MAX_TRAFFIC_PERCENT: Int = 100
    static let MAX_TRAFFIC_VALUE: Int = 10000
    static let STATUS_RUNNING: String = "RUNNING"

    static let SEED_VALUE: Int = 1
    static let MAX_EVENTS_PER_REQUEST: Int = 5000
    static let DEFAULT_REQUEST_TIME_INTERVAL: TimeInterval = 600 // 10 * 60(secs) = 600 secs i.e. 10 minutes
    static let DEFAULT_EVENTS_PER_REQUEST: Int = 100
    static var SDK_NAME: String { ProductConfig.current.sdkName }
    static let PRODUCT_NAME: String = "fme"
    static let SETTINGS_EXPIRY: Int64 = 0 // default time for cached setting expiry
    static let SETTINGS_TIMEOUT: Int = 30

    static var HOST_NAME: String { ProductConfig.current.hostName }
    static var SERVING_URL: String { ProductConfig.current.servingUrl }
    static var COLLECTION_URL: String { ProductConfig.current.collectionUrl }
    static var SETTINGS_ENDPOINT: String { ProductConfig.current.settingsEndpoint }
    static var EVENT_BATCH_ENDPOINT: String { ProductConfig.current.eventBatchEndpoint }

    static let VWO_FS_ENVIRONMENT: String = "vwo_fs_environment"
    static let HTTPS_PROTOCOL: String = "https"

    static let RANDOM_ALGO: Int = 1

    static var SDK_USERDEFAULT_SUITE: String { ProductConfig.current.userDefaultsSuite }
    static let VWO_META_MEG_KEY = "_vwo_meta_meg_"

    static let DEFAULT_BATCH_UPLOAD_INTERVAL: Int64 = 3 * 60 * 1000 // 3 minutes in milliseconds

    static let LOCATION_EXPIRY: Int64 = 60 * 60 * 1000 // 60 minutes in milliseconds
    static let LIST_ATTRIBUTE_EXPIRY: Int64 = 60 * 60 * 1000 // 60 minutes in milliseconds

    static var USER_AGENT_VALUE: String {
        "\(ProductConfig.current.displayName) FME \(PlatformInfo.name) \(SDK_VERSION) (\(PlatformInfo.deviceModel)/\(PlatformInfo.systemVersion))"
    }


    // Debugger constants
    static let POLLING = "polling"
    static let BROWSER_STORAGE = "browserStorage"
    static let FLAG_DECISION_GIVEN = "FLAG_DECISION_GIVEN"
    static let  NETWORK_CALL_FAILURE_AFTER_MAX_RETRIES = "NETWORK_CALL_FAILURE_AFTER_MAX_RETRIES"
    static let  NETWORK_CALL_SUCCESS_WITH_RETRIES = "NETWORK_CALL_SUCCESS_WITH_RETRIES"
    static let  NETWORK_CALL_SUCCESS_WITH_RETRIES_FOR_GET_FLAG = "NETWORK_CALL_SUCCESS_WITH_RETRIES_FOR_GET_FLAG"
    static let  NETWORK_CALL_FAILURE_AFTER_MAX_RETRIES_FOR_GET_FLAG = "NETWORK_CALL_FAILURE_AFTER_MAX_RETRIES_FOR_GET_FLAG"
    static let  MOBILE_STORAGE = "MobileDefaultStorage"

    static var userIdErrorMessage: String {
        "User ID is required. Please provide a user ID or enable device ID in \(ProductConfig.current.userContextTypeName)."
    }
    static var VWOContextErrorMessage: String {
        "\(ProductConfig.current.userContextTypeName) is missing. Please provide a valid user context before proceeding."
    }


    static let APP_VERSION = "vwo_av"
    static let OS_VERSION = "vwo_osv"
    static let MANUFACTURER = "vwo_mfr"
    static let DEVICE_MODEL = "vwo_dm"
    static let LOCALE = "vwo_loc"
    
    static let VWO_META_HOLDOUT_KEY: String = "_vwo_meta_holdout_"
    static let VARIATION_KEY = "variationKey"
    static let USER_ID = "userId"
    static let KEY_EXPERIMENT_TYPE = "experimentType"
    static let KEY_EXPERIMENT_KEY = "experimentKey"
    static let IMPRESSION_NO_FEATURE_ID = -1
    static let REGEX_REQUIRES_GATEWAY_SERVICE = "\\b(country|region|city|os|device_type|browser_string|ua)\\b"
    static let REGEX_SEGMENTATION_FULL = "$REGEX_REQUIRES_GATEWAY_SERVICE|\"custom_variable\"\\s*:\\s*\\{\\s*\"name\"\\s*:\\s*\"inlist\\([^)]*\\)\""
    
    // Holdout feature (aligned with Android Constants.Holdouts)
    enum Holdouts {
        static let VARIATION_IS_PART_OF_HOLDOUT = 1
        static let VARIATION_NOT_PART_OF_HOLDOUT = 2
        static let KEY_STORAGE_HOLDOUT_IDS = "holdoutIds"
        static let KEY_STORAGE_NOT_IN_HOLDOUT_IDS = "notInHoldoutIds"
    }

    
    /// Returns storage key for tracking holdout groups already evaluated as "not in holdout" for a user+feature.
    static func getNotInHoldoutKey(_ key: String) -> String {
        return "not_in_holdout_\(key)"
    }
    //Ends here

    static let SETTINGS_MAX_RETRY_ATTEMPTS = 1
    static let MAX_RETRY_ATTEMPTS = 4
    static let HTTP_STATUS_CODE_200 = 200
    static let HTTP_STATUS_CODE_400 = 400
    static let HTTP_STATUS_CODE_401 = 401

    static var LOGGER_TAG: String { ProductConfig.current.loggerTag }
    static var CLIENT_ERROR_DOMAIN: String { ProductConfig.current.clientErrorDomain }

    static func storageKey(_ suffix: String) -> String {
        "\(ProductConfig.current.storageKeyNamespace).\(suffix)"
    }

    
}

public typealias WingifyInitCompletionHandler = (Result<String, Error>) -> Void
