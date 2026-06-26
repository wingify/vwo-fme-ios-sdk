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
 * Utility struct for rule evaluation operations.
 *
 * This struct provides helper methods for evaluating rules and conditions, such as checking if
 * user attributes match targeting conditions or determining if variations should be applied based
 * on defined rules.
 */
struct RuleEvaluationUtil {
    /**
     * Evaluates the rule for a given feature and campaign.
     *
     * - Parameters:
     *   - settings: SDK settings for the current account.
     *   - feature: Feature being evaluated.
     *   - campaign: Rollout or experiment campaign rule to evaluate.
     *   - context: User context for the evaluation.
     *   - evaluatedFeatureMap: Map of evaluated feature metadata, updated in place.
     *   - megGroupWinnerCampaigns: MEG winner campaigns map, updated in place.
     *   - storageService: Storage service for cached user decisions.
     *   - serviceContainer: Service container for service access.
     *   - decision: Integration decision object, updated in place.
     *   - variationShownTracker: Optional tracker used by `getFlag` to record `variationShown`
     *     impressions (e.g. whitelist hits) for user-tracking billing decisions.
     * - Returns: Dictionary with `preSegmentationResult`, optional `whitelistedObject`, and `updatedDecision`.
     */
    static func evaluateRule(
        settings: Settings,
        feature: Feature?,
        campaign: Campaign,
        context: WingifyUserContext,
        evaluatedFeatureMap: inout [String: Any],
        megGroupWinnerCampaigns: inout [Int: String]?,
        storageService: StorageService,
        serviceContainer: ServiceContainer,
        decision: inout [String: Any],
        variationShownTracker: VariationShownTracker? = nil
    ) -> [String: Any] {
        // Check if the campaign satisfies the whitelisting and pre-segmentation
        let checkResult = DecisionUtil.checkWhitelistingAndPreSeg(
            settings: settings,
            feature: feature,
            campaign: campaign,
            context: context,
            evaluatedFeatureMap: &evaluatedFeatureMap,
            megGroupWinnerCampaigns: &megGroupWinnerCampaigns,
            storageService: storageService,
            serviceContainer: serviceContainer,
            decision: &decision
        )
        
        // Extract the results of the evaluation
        let preSegmentationResult = checkResult["preSegmentationResult"] as? Bool ?? false
        let whitelistedObject = checkResult["whitelistedObject"] as? Variation
        
        // If pre-segmentation is successful and a whitelisted object exists, proceed to send an impression
        if let whitelistedId = whitelistedObject?.id, preSegmentationResult {
            // Update the decision object with campaign and variation details
            let cmpId = campaign.id ?? 0
            decision["experimentId"] = cmpId
            decision["experimentKey"] = campaign.key ?? ""
            decision["experimentVariationId"] = whitelistedId
            
            // Send an impression for the variation shown
            if let tracker = variationShownTracker {
                tracker.recordVariationShown(
                    settings: settings,
                    campaignId: cmpId,
                    variationId: whitelistedId,
                    context: context,
                    serviceContainer: serviceContainer
                )
            } else {
                ImpressionUtil.createAndSendImpressionForVariationShown(
                    settings: settings,
                    campaignId: cmpId,
                    variationId: whitelistedId,
                    context: context,
                    serviceContainer: serviceContainer
                )
            }
        }
        
        // Return the results of the evaluation
        var result: [String: Any] = [:]
        result["preSegmentationResult"] = preSegmentationResult
        if let whitelistedObject = whitelistedObject {
            result["whitelistedObject"] = whitelistedObject
        }
        result["updatedDecision"] = decision
        return result
    }
}
