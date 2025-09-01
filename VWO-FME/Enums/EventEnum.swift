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
 * Enumeration representing different event types.
 *
 * This enum defines constants for various event types used in the application,
 * particularly those related to VWO (Visual Website Optimizer) functionality.
 * Each event type is associated with a specific string value.
 */
enum EventEnum: String {
    /**
     * Event triggered when a variation is shown to the user.
     */
    case vwoVariationShown = "vwo_variationShown"
    
    /**
     * Event triggered when a user attribute is set.
     */
    case vwoSyncVisitorProp = "vwo_syncVisitorProp"
    
    /**
     * Event triggered when a sdk error is logged.
     */
    case vwoError = "vwo_log"
    
    /**
     * FME sdk init event
     */
    case VWO_INIT_CALLED = "vwo_fmeSdkInit"
    
    /**
     * FME sdk usage stat even
     t*/
    case VWO_USAGE_STATS = "vwo_sdkUsageStats"
}
