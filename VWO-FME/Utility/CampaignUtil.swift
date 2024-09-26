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
    
    static func setVariationAllocation(_ campaign: inout Campaign) {
        if campaign.type == CampaignTypeEnum.rollout.rawValue || campaign.type == CampaignTypeEnum.personalize.rawValue {
            handleRolloutCampaign(&campaign)
        } else {
            
            var currentAllocation = 0
            for i in 0..<campaign.variations!.count {
                var variation = campaign.variations![i]
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
    
    static func getBucketingSeed(userId: String?, campaign: Campaign?, groupId: Int?) -> String {
        if let groupId = groupId {
            return "\(groupId)_\(userId ?? "")"
        }
        return "\(campaign?.id ?? 0)_\(userId ?? "")"
    }
    
    static func getVariationFromCampaignKey(settings: Settings, campaignKey: String?, variationId: Int?) -> Variation? {
        
        guard let campaign = settings.campaigns?.first(where: { $0.key == campaignKey }) else {
            return nil
        }
        return campaign.variations?.first(where: { $0.id == variationId })
    }
    
    static func setCampaignAllocation(_ campaigns: inout [Variation]) {
        
        var currentAllocation = 0
        for i in 0..<campaigns.count {
            var campaign = campaigns[i]
            let stepFactor = assignRangeValuesMEG(&campaign, currentAllocation: currentAllocation)
            currentAllocation += stepFactor
            campaigns[i] = campaign
        }
    }
    
    static func getGroupDetailsIfCampaignPartOfIt(settings: Settings, campaignId: Int) -> [String: String] {
        var groupDetails = [String: String]()
        if let groupId = settings.campaignGroups?[String(campaignId)], let groupName = settings.groups?[String(groupId)]?.name {
            groupDetails["groupId"] = String(groupId)
            groupDetails["groupName"] = groupName
        }
        return groupDetails
    }
    
    static func findGroupsFeaturePartOf(settings: Settings, featureKey: String) -> [[String: String]] {
        
        var campaignIds = [Int]()
        for feature in settings.features {
            if feature.key == featureKey {
                feature.rules?.forEach { rule in
                    if !campaignIds.contains(rule.campaignId ?? 0) {
                        campaignIds.append(rule.campaignId ?? 0)
                    }
                }
            }
        }
        
        
        var groups = [[String: String]]()
        for campaignId in campaignIds {
            let group = getGroupDetailsIfCampaignPartOfIt(settings: settings, campaignId: campaignId)
            if !group.isEmpty && !groups.contains(where: { $0["groupId"] == group["groupId"] }) {
                groups.append(group)
            }
        }
        return groups
    }
    
    static func getCampaignsByGroupId(settings: Settings, groupId: Int) -> [Int] {
        return settings.groups?[String(groupId)]?.campaigns ?? []
    }
    
    static func getFeatureKeysFromCampaignIds(settings: Settings, campaignIds: [Int]) -> [String] {
        var featureKeys = [String]()
        campaignIds.forEach { campaignId in
            settings.features.forEach { feature in
                feature.rules?.forEach { rule in
                    if rule.campaignId == campaignId, let key = feature.key {
                        featureKeys.append(key)
                    }
                }
            }
        }
        return featureKeys
    }
    
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
    
    static func getRuleTypeUsingCampaignIdFromFeature(feature: Feature, campaignId: Int) -> String {
        return feature.rules?.first(where: { $0.campaignId == campaignId })?.type ?? ""
        
    }
    
    private static func getVariationBucketRange(variationWeight: Double) -> Int {
        
        if variationWeight <= 0 {
            return 0
        }
        let startRange = ceil(variationWeight * 100)
        return Int(min(startRange, Double(Constants.MAX_TRAFFIC_VALUE)))
        
    }
    
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
