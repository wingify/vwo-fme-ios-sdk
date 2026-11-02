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

/**
 * Collects `vwo_variationShown` rows during a single `getFlag` evaluation.
 * Does not send — callers flush via `ImpressionExposureHelper.record`.
 */
final class VariationShownTracker {

    let payload = ImpressionPayload()

    /// `true` when a non-empty payload was actually sent (set by caller after `record`).
    private(set) var sent = false

    /**
     * Records whether the collected payload was flushed/sent.
     */
    func markSent(_ value: Bool) {
        sent = value
    }

    /**
     * Adds a campaign/variation pair to the payload. Does not send the impression.
     */
    func recordVariationShown(
        settings: Settings,
        campaignId: Int,
        variationId: Int,
        context: WingifyUserContext,
        serviceContainer: ServiceContainer
    ) {
        payload.add(campaignId: campaignId, variationId: variationId)
    }

    /**
     * Adds holdout-related variation-shown rows to the payload. Does not send the impressions.
     */
    func recordHoldoutImpressions(
        settings: Settings,
        impressions: [HoldoutImpression],
        context: WingifyUserContext,
        serviceContainer: ServiceContainer
    ) {
        guard !impressions.isEmpty else { return }
        for imp in impressions {
            payload.add(
                campaignId: imp.campaignId,
                variationId: imp.variationId,
                featureId: Constants.IMPRESSION_NO_FEATURE_ID
            )
        }
    }
}
