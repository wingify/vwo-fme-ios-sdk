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

struct Constants {
    static let defaultString: String = ""
    static let PLATFORM: String = "ios"

    static let SDK_VERSION: String = "1.11.0"
    
    static let MAX_TRAFFIC_PERCENT: Int = 100
    static let MAX_TRAFFIC_VALUE: Int = 10000
    static let STATUS_RUNNING: String = "RUNNING"

    static let SEED_VALUE: Int = 1
    static let MAX_EVENTS_PER_REQUEST: Int = 5000
    static let DEFAULT_REQUEST_TIME_INTERVAL: TimeInterval = 600 // 10 * 60(secs) = 600 secs i.e. 10 minutes
    static let DEFAULT_EVENTS_PER_REQUEST: Int = 100
    static let SDK_NAME: String = "vwo-fme-ios-sdk"
    static let PRODUCT_NAME: String = "fme"
    static let SETTINGS_EXPIRY: Int64 = 0 // default time for cached setting expiry
    static let SETTINGS_TIMEOUT: Int = 30

    static let HOST_NAME: String = "dev.visualwebsiteoptimizer.com"
    static let SETTINGS_ENDPOINT: String = "/server-side/v2-settings"
    static let EVENT_BATCH_ENDPOINT: String = "/server-side/batch-events-v2"

    static let VWO_FS_ENVIRONMENT: String = "vwo_fs_environment"
    static let HTTPS_PROTOCOL: String = "https"

    static let RANDOM_ALGO: Int = 1

    static let SDK_USERDEFAULT_SUITE = "com.vwo.fme.userdefault.suite"
    static let VWO_META_MEG_KEY = "_vwo_meta_meg_"

    static let DEFAULT_BATCH_UPLOAD_INTERVAL: Int64 = 3 * 60 * 1000 // 3 minutes in milliseconds

    static let LOCATION_EXPIRY: Int64 = 60 * 60 * 1000 // 60 minutes in milliseconds
    static let LIST_ATTRIBUTE_EXPIRY: Int64 = 60 * 60 * 1000 // 60 minutes in milliseconds

    static let USER_AGENT_VALUE: String = "VWO FME \(PlatformInfo.name) \(SDK_VERSION) (\(PlatformInfo.deviceModel)/\(PlatformInfo.systemVersion))"

    
    static let APP_VERSION = "vwo_av"
    static let OS_VERSION = "vwo_osv"
    static let MANUFACTURER = "vwo_mfr"
    static let DEVICE_MODEL = "vwo_dm"
    static let LOCALE = "vwo_loc"
}

public typealias VWOInitCompletionHandler = (Result<String, Error>) -> Void
