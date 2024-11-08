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

class CampaignUtil {
    
    /**
     * Sets the variation allocation for a given campaign.
     *
     * - Parameter campaign: The campaign for which the variation allocation is to be set.
     */
    static func setVariationAllocation(_ campaign: inout Campaign) {
        if campaign.type == CampaignTypeEnum.rollout.rawValue || campaign.type == CampaignTypeEnum.personalize.rawValue {
            handleRolloutCampaign(&campaign)
        } else {
            var currentAllocation = 0
            for i in 0..<campaign.variations!.count {
                var variation = campaign.variations![i]
                
                // Assign range values to the variation and update current allocation
                let stepFactor = assignRangeValues(&variation, currentAllocation: currentAllocation)
                currentAllocation += stepFactor
                
                LoggerService.log(level: .info,
                                  key: "VARIATION_RANGE_ALLOCATION",
                                  details: ["campaignKey": campaign.key ?? "",
                                            "variationKey": variation.name ?? "",
                                            "variationWeight": "\(variation.weight)",
                                            "startRange": "\(variation.startRangeVariation)",
                                            "endRange": "\(variation.endRangeVariation)"
                                           ])
                campaign.variations![i] = variation
            }
        }
    }
    
    /**
     * Assigns range values to a variation based on its weight.
     *
     * - Parameters:
     *   - data: The variation to which range values are assigned.
     *   - currentAllocation: The current allocation value.
     * - Returns: The step factor used for allocation.
     */
    static func assignRangeValues(_ data: inout Variation, currentAllocation: Int) -> Int {
        let stepFactor = getVariationBucketRange(variationWeight: data.weight)
        if stepFactor > 0 {
            data.startRangeVariation = currentAllocation + 1
            data.endRangeVariation = currentAllocation + stepFactor
        } else {
            data.startRangeVariation = -1
            data.endRangeVariation = -1
        }
        return stepFactor
    }
    
    /**
     * Scales the weights of variations to ensure they sum up to 100.
     *
     * - Parameter variations: The list of variations whose weights are to be scaled.
     */
    static func scaleVariationWeights(_ variations: inout [Variation]) {
        let totalWeight = variations.reduce(0) { $0 + $1.weight }
        if totalWeight == 0 {
            let equalWeight = 100.0 / Double(variations.count)
            for i in 0..<variations.count {
                variations[i].weight = equalWeight
            }
        } else {
            for i in 0..<variations.count {
                variations[i].weight = (variations[i].weight / totalWeight) * 100
            }
        }
    }
    
    /**
     * Generates a bucketing seed based on user ID, campaign, and group ID.
     *
     * - Parameters:
     *   - userId: The user ID.
     *   - campaign: The campaign.
     *   - groupId: The group ID.
     * - Returns: A string representing the bucketing seed.
     */
    static func getBucketingSeed(userId: String?, campaign: Campaign?, groupId: Int?) -> String {
        if let groupId = groupId {
            return "\(groupId)_\(userId ?? "")"
        }
        return "\(campaign?.id ?? 0)_\(userId ?? "")"
    }
    
    /**
     * Retrieves a variation from a campaign using the campaign key and variation ID.
     *
     * - Parameters:
     *   - settings: The settings containing campaign information.
     *   - campaignKey: The key of the campaign.
     *   - variationId: The ID of the variation.
     * - Returns: The variation if found, otherwise nil.
     */
    static func getVariationFromCampaignKey(settings: Settings, campaignKey: String?, variationId: Int?) -> Variation? {
        guard let campaign = settings.campaigns?.first(where: { $0.key == campaignKey }) else {
            return nil
        }
        return campaign.variations?.first(where: { $0.id == variationId })
    }
    
    /**
     * Sets the allocation for a list of campaigns.
     *
     * - Parameter campaigns: The list of campaigns to allocate.
     */
    static func setCampaignAllocation(_ campaigns: inout [Variation]) {
        var currentAllocation = 0
        for i in 0..<campaigns.count {
            var campaign = campaigns[i]
            
            // Assign range values to the campaign and update current allocation
            let stepFactor = assignRangeValuesMEG(&campaign, currentAllocation: currentAllocation)
            currentAllocation += stepFactor
            campaigns[i] = campaign
        }
    }
    
    /**
     * Retrieves group details if a campaign is part of a group.
     *
     * - Parameters:
     *   - settings: The settings containing group information.
     *   - campaignId: The ID of the campaign.
     *   - variationId: The ID of the variation.
     * - Returns: A dictionary containing group details.
     */
    static func getGroupDetailsIfCampaignPartOfIt(settings: Settings, campaignId: Int, variationId: Int) -> [String: String] {
        var groupDetails = [String: String]()
        var campaignToCheck = "\(campaignId)"
        if variationId != -1 {
            campaignToCheck = "\(campaignToCheck)_\(variationId)"
        }
        if let campaignGroups = settings.campaignGroups, campaignGroups[campaignToCheck] != nil {
            let groupId = campaignGroups["\(campaignToCheck)"] ?? -1
            let groupName = settings.groups?["\(groupId)"]?.name ?? ""
            groupDetails["groupId"] = "\(groupId)"
            groupDetails["groupName"] = groupName
            return groupDetails
        }
        return groupDetails
    }
    
    /**
     * Finds groups that a feature is part of.
     *
     * - Parameters:
     *   - settings: The settings containing feature information.
     *   - featureKey: The key of the feature.
     * - Returns: A list of dictionaries containing group details.
     */
    static func findGroupsFeaturePartOf(settings: Settings, featureKey: String) -> [[String: String]] {
        var ruleList: [Rule] = []
        for feature in settings.features {
            if feature.key == featureKey {
                feature.rules?.forEach { rule in
                    if !ruleList.contains(where: {$0 == rule }) {
                        ruleList.append(rule)
                    }
                }
            }
        }
        
        var groups = [[String: String]]()
        ruleList.forEach { rule in
            if let ruleCampaignId = rule.campaignId, let ruleVariationId = rule.variationId {
                let group = getGroupDetailsIfCampaignPartOfIt(settings: settings, campaignId: ruleCampaignId, variationId: ruleVariationId)
                groups.append(group)
            }
        }
        return groups
    }
    
    /**
     * Retrieves campaign keys by group ID.
     *
     * - Parameters:
     *   - settings: The settings containing group information.
     *   - groupId: The ID of the group.
     * - Returns: A list of campaign keys.
     */
    static func getCampaignsByGroupId(settings: Settings, groupId: Int) -> [String] {
        return settings.groups?["\(groupId)"]?.campaigns ?? []
    }
    
    /**
     * Retrieves feature keys from a list of campaign IDs with variations.
     *
     * - Parameters:
     *   - settings: The settings containing feature information.
     *   - campaignIdWithVariation: A list of campaign IDs with variations.
     * - Returns: A list of feature keys.
     */
    static func getFeatureKeysFromCampaignIds(settings: Settings, campaignIdWithVariation: [String]) -> [String] {
        var featureKeys = [String]()
        for campaign in campaignIdWithVariation {
            let campaignIdVariationId = campaign.components(separatedBy: "_")
            guard let campaignId = Int(campaignIdVariationId[0]) else { continue }
            let variationId = campaignIdVariationId.count > 1 ? Int(campaignIdVariationId[1]) : nil
            for feature in settings.features {
                if let key = feature.key {
                    if featureKeys.contains(key) {
                        continue
                    }
                    feature.rules?.forEach{ rule in
                        if let ruleCampaignId = rule.campaignId, ruleCampaignId == campaignId {
                            if let variationId = variationId {
                                if let ruleVariationId = rule.variationId, variationId == ruleVariationId {
                                    featureKeys.append(key)
                                }
                            } else {
                                featureKeys.append(key)
                            }
                        }
                    }
                }
            }
        }
        return featureKeys
    }
    
    /**
     * Retrieves campaign IDs from a feature key.
     *
     * - Parameters:
     *   - settings: The settings containing feature information.
     *   - featureKey: The key of the feature.
     * - Returns: A list of campaign IDs.
     */
    static func getCampaignIdsFromFeatureKey(settings: Settings, featureKey: String?) -> [Int] {
        var campaignIds = [Int?]()
        for feature in settings.features {
            if feature.key == featureKey {
                feature.rules?.forEach { rule in
                    campaignIds.append(rule.campaignId)
                }
            }
        }
        let nonNullCampaignIds = campaignIds.compactMap({$0})
        return nonNullCampaignIds
    }
    
    /**
     * Assigns range values to a variation for multi-experiment groups.
     *
     * - Parameters:
     *   - data: The variation to which range values are assigned.
     *   - currentAllocation: The current allocation value.
     * - Returns: The step factor used for allocation.
     */
    static func assignRangeValuesMEG(_ data: inout Variation, currentAllocation: Int) -> Int {
        let stepFactor = getVariationBucketRange(variationWeight: data.weight)
        if stepFactor > 0 {
            data.startRangeVariation = currentAllocation + 1
            data.endRangeVariation = currentAllocation + stepFactor
        } else {
            data.startRangeVariation = -1
            data.endRangeVariation = -1
        }
        return stepFactor
    }
    
    /**
     * Retrieves the rule type using a campaign ID from a feature.
     *
     * - Parameters:
     *   - feature: The feature containing the rules.
     *   - campaignId: The ID of the campaign.
     * - Returns: The type of the rule.
     */
    static func getRuleTypeUsingCampaignIdFromFeature(feature: Feature, campaignId: Int) -> String {
        return feature.rules?.first(where: { $0.campaignId == campaignId })?.type ?? ""
    }
    
    /**
     * Calculates the bucket range for a variation based on its weight.
     *
     * - Parameter variationWeight: The weight of the variation.
     * - Returns: The calculated bucket range.
     */
    private static func getVariationBucketRange(variationWeight: Double) -> Int {
        if variationWeight <= 0 {
            return 0
        }
        let startRange = ceil(variationWeight * 100)
        return Int(min(startRange, Double(Constants.MAX_TRAFFIC_VALUE)))
        
    }
    
    /**
     * Handles the allocation of variations for rollout campaigns.
     *
     * - Parameter campaign: The campaign for which the variations are allocated.
     */
    private static func handleRolloutCampaign(_ campaign: inout Campaign) {
        for i in 0..<campaign.variations!.count {
            var variation = campaign.variations![i]
            let endRange = Int(variation.weight * 100)
            variation.startRangeVariation = 1
            variation.endRangeVariation = endRange
            LoggerService.log(level: .info,
                              key: "VARIATION_RANGE_ALLOCATION",
                              details: ["campaignKey": campaign.key ?? "",
                                        "variationKey": variation.name ?? "",
                                        "variationWeight": "\(variation.weight)",
                                        "startRange": "\(variation.startRangeVariation)",
                                        "endRange": "\(variation.endRangeVariation)"])
            campaign.variations![i] = variation
        }
    }
}
