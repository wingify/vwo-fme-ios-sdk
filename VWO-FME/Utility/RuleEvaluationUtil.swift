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
 * Utility struct for rule evaluation operations.
 *
 * This struct provides helper methods for evaluating rules and conditions, such as checking if
 * user attributes match targeting conditions or determining if variations should be applied based
 * on defined rules.
 */
struct RuleEvaluationUtil {
    /**
     * This method is used to evaluate the rule for a given feature and campaign.
     */
    
    static func evaluateRule(
        settings: Settings,
        feature: Feature?,
        campaign: Campaign,
        context: VWOContext,
        evaluatedFeatureMap: inout [String: Any],
        megGroupWinnerCampaigns: inout [Int: String]?,
        storageService: StorageService,
        decision: inout [String: Any]
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
            ImpressionUtil.createAndSendImpressionForVariationShown(
                settings: settings,
                campaignId: cmpId,
                variationId: whitelistedId,
                context: context
            )
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
