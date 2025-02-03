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

/**
 * Enumeration representing different campaign types.
 *
 * This enum defines constants for various campaign types supported by the application,
 * such as feature rollouts, A/B testing, and personalization. Each campaign type
 * is associated with a specific string value.
 */
enum CampaignTypeEnum: String {
    /**
     * Campaign type for feature rollouts.
     */
    case rollout = "FLAG_ROLLOUT"
    
    /**
     * Campaign type for A/B testing.
     */
    case ab = "FLAG_TESTING"
    
    /**
     * Campaign type for personalization.
     */
    case personalize = "FLAG_PERSONALIZE"
}
