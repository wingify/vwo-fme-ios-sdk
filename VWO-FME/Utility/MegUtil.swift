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

class MegUtil {
    
    static func evaluateGroups(settings: Settings, 
                               feature: Feature?,
                               groupId: Int,
                               evaluatedFeatureMap: inout [String: Any],
                               context: VWOContext,
                               storageService: StorageService) -> Variation? {
        
        var featureToSkip: [String] = [String]()
        var campaignMap = [String: [Campaign]]()
        
        let featureKeysAndGroupCampaignIds = getFeatureKeysFromGroup(settings: settings, groupId: groupId)
        let featureKeys = featureKeysAndGroupCampaignIds["featureKeys"] as? [String] ?? []
        let groupCampaignIds = featureKeysAndGroupCampaignIds["groupCampaignIds"] as? [Int] ?? []
        
        for featureKey in featureKeys {
            
            guard let currentFeature = FunctionUtil.getFeatureFromKey(settings: settings, featureKey: featureKey),
                  !featureToSkip.contains(featureKey) else {
                continue
            }
            
            let isRolloutRulePassed = isRolloutRuleForFeaturePassed(
                settings: settings,
                feature: currentFeature,
                evaluatedFeatureMap: &evaluatedFeatureMap,
                featureToSkip: &featureToSkip,
                context: context,
                storageService: storageService)
            
            if isRolloutRulePassed {
                for campaign in settings.campaigns ?? [] {
                    let featureCampaignIds = CampaignUtil.getCampaignIdsFromFeatureKey(settings: settings, featureKey: featureKey)
                    if groupCampaignIds.contains(campaign.id ?? 0) && featureCampaignIds.contains(campaign.id ?? 0) {
                        var campaigns = campaignMap[featureKey] ?? []
                        if !campaigns.contains(where: { $0.key == campaign.key }) {
                            campaigns.append(campaign)
                        }
                        campaignMap[featureKey] = campaigns
                    }
                }
            }
        }
        
        let eligibleCampaignsMap = getEligibleCampaigns(settings: settings, campaignMap: campaignMap, context: context, storageService: storageService)
        let eligibleCampaigns = eligibleCampaignsMap["eligibleCampaigns"] as? [Campaign]
        let eligibleCampaignsWithStorage = eligibleCampaignsMap["eligibleCampaignsWithStorage"] as? [Campaign]
        
        return findWinnerCampaignAmongEligibleCampaigns(settings: settings,
                                                        featureKey: feature?.key,
                                                        eligibleCampaigns: eligibleCampaigns,
                                                        eligibleCampaignsWithStorage: eligibleCampaignsWithStorage,
                                                        groupId: groupId,
                                                        context: context)
    }
    
    static func getFeatureKeysFromGroup(settings: Settings, groupId: Int) -> [String: [Any]] {
        let groupCampaignIds = CampaignUtil.getCampaignsByGroupId(settings: settings, groupId: groupId)
        let featureKeys = CampaignUtil.getFeatureKeysFromCampaignIds(settings: settings, campaignIds: groupCampaignIds)
        return [
            "featureKeys": featureKeys,
            "groupCampaignIds": groupCampaignIds
        ]
    }
    
    private static func isRolloutRuleForFeaturePassed(settings: Settings, 
                                                      feature: Feature,
                                                      evaluatedFeatureMap: inout [String: Any],
                                                      featureToSkip: inout [String],
                                                      context: VWOContext,
                                                      storageService: StorageService) -> Bool {
        
        guard let featureKey = feature.key else { return false }
        if let evaluatedFeature = evaluatedFeatureMap[featureKey] as? [String: Any], evaluatedFeature["rolloutId"] != nil {
            return true
        }
        
        let rollOutRules = FunctionUtil.getSpecificRulesBasedOnType(feature: feature, type: .rollout)
        
        if !rollOutRules.isEmpty {
            var ruleToTestForTraffic: Campaign?
            var decisionTemp: [String :Any] = [:]
            var megGroupWinnerCampaignsTemp: [Int : Int]? = nil
            for rule in rollOutRules {
                let preSegmentationResult = RuleEvaluationUtil.evaluateRule(settings: settings, 
                                                                            feature: feature,
                                                                            campaign: rule,
                                                                            context: context,
                                                                            evaluatedFeatureMap: &evaluatedFeatureMap,
                                                                            megGroupWinnerCampaigns: &megGroupWinnerCampaignsTemp,
                                                                            storageService: storageService,
                                                                            decision: &decisionTemp)
                if preSegmentationResult["preSegmentationResult"] as? Bool == true {
                    ruleToTestForTraffic = rule
                    break
                }
            }
            
            if let ruleToTestForTraffic = ruleToTestForTraffic {
                if let variation = DecisionUtil.evaluateTrafficAndGetVariation(settings: settings, campaign: ruleToTestForTraffic, userId: context.id) {
                    var rollOutInformation: [String: Any] = [:]
                    rollOutInformation["rolloutId"] = variation.id
                    rollOutInformation["rolloutKey"] = variation.name
                    rollOutInformation["rolloutVariationId"] = variation.id
                    evaluatedFeatureMap[featureKey] = rollOutInformation
                    return true
                }
            }
            
            featureToSkip.append(featureKey)
            return false
        }
        
        LoggerService.log(level: .info, key: "MEG_SKIP_ROLLOUT_EVALUATE_EXPERIMENTS", details: ["featureKey": featureKey])
        return true
    }
    
    private static func getEligibleCampaigns(settings: Settings, campaignMap: [String: [Campaign]], context: VWOContext, storageService: StorageService) -> [String: Any] {
        var eligibleCampaigns: [Campaign] = []
        var eligibleCampaignsWithStorage: [Campaign] = []
        var inEligibleCampaigns: [Campaign] = []
        
        for (featureKey, campaigns) in campaignMap {
            for campaign in campaigns {
                if let storedDataMap = StorageDecorator().getFeatureFromStorage(featureKey: featureKey, context: context, storageService: storageService) {
                    do {
                        let storageMapAsString = try JSONSerialization.data(withJSONObject: storedDataMap, options: [])
                        let storedData = try JSONDecoder().decode(Storage.self, from: storageMapAsString)
                        if let experimentVariationId = storedData.experimentVariationId {
                            if let experimentKey = storedData.experimentKey, experimentKey == campaign.key {
                                if let variation = CampaignUtil.getVariationFromCampaignKey(settings: settings, campaignKey: experimentKey, variationId: experimentVariationId) {
                                    LoggerService.log(level: .info, key: "MEG_CAMPAIGN_FOUND_IN_STORAGE", details: ["campaignKey": experimentKey, "userId": context.id ?? ""])
                                    if !eligibleCampaignsWithStorage.contains(where: { $0.key == campaign.key }) {
                                        eligibleCampaignsWithStorage.append(campaign)
                                    }
                                    continue
                                }
                            }
                        }
                    } catch {
                        fatalError("Error processing stored data: \(error)")
                    }
                }
                
                if CampaignDecisionService().getPreSegmentationDecision(campaign: campaign, context: context) && CampaignDecisionService().isUserPartOfCampaign(userId: context.id, campaign: campaign) {
                    LoggerService.log(level: .info, 
                                      key: "MEG_CAMPAIGN_ELIGIBLE",
                                      details: ["campaignKey": campaign.key ?? "", "userId": context.id ?? ""])
                    eligibleCampaigns.append(campaign)
                    continue
                }
                
                inEligibleCampaigns.append(campaign)
            }
        }
        
        return ["eligibleCampaigns": eligibleCampaigns, "eligibleCampaignsWithStorage": eligibleCampaignsWithStorage, "inEligibleCampaigns": inEligibleCampaigns]
    }
    
    private static func findWinnerCampaignAmongEligibleCampaigns(settings: Settings, featureKey: String?, eligibleCampaigns: [Campaign]?, eligibleCampaignsWithStorage: [Campaign]?, groupId: Int, context: VWOContext) -> Variation? {
        let campaignIds = CampaignUtil.getCampaignIdsFromFeatureKey(settings: settings, featureKey: featureKey)
        var winnerCampaign: Variation?
        
        do {
            if let group = settings.groups?[String(groupId)], let megAlgoNumber = group.et {
                if eligibleCampaignsWithStorage?.count == 1 {
                    let campaignModel = try JSONEncoder().encode(eligibleCampaignsWithStorage?[0])
                    winnerCampaign = try JSONDecoder().decode(Variation.self, from: campaignModel)
                    LoggerService.log(level: .info,
                                      key: "MEG_WINNER_CAMPAIGN",
                                      details: ["campaignKey": winnerCampaign?.key ?? "",
                                                "groupId": "\(groupId)",
                                                "userId": context.id ?? ""])
                } else if eligibleCampaignsWithStorage?.count ?? 0 > 1 && megAlgoNumber == Constants.RANDOM_ALGO {
                    winnerCampaign = normalizeWeightsAndFindWinningCampaign(shortlistedCampaigns: eligibleCampaignsWithStorage, context: context, calledCampaignIds: campaignIds, groupId: groupId)
                } else if eligibleCampaignsWithStorage?.count ?? 0 > 1 {
                    winnerCampaign = getCampaignUsingAdvancedAlgo(settings: settings, shortlistedCampaigns: eligibleCampaignsWithStorage!, context: context, calledCampaignIds: campaignIds, groupId: groupId)
                }
                
                if eligibleCampaignsWithStorage?.isEmpty == true {
                    if eligibleCampaigns?.count == 1 {
                        let campaignModel = try JSONEncoder().encode(eligibleCampaigns?[0])
                        winnerCampaign = try JSONDecoder().decode(Variation.self, from: campaignModel)
                        LoggerService.log(level: .info,
                                          key: "MEG_WINNER_CAMPAIGN",
                                          details: ["campaignKey": winnerCampaign?.key ?? "",
                                                    "groupId": "\(groupId)",
                                                    "userId": context.id ?? "",
                                                    "algo": ""])
                    } else if eligibleCampaigns?.count ?? 0 > 1 && megAlgoNumber == Constants.RANDOM_ALGO {
                        winnerCampaign = normalizeWeightsAndFindWinningCampaign(shortlistedCampaigns: eligibleCampaigns, context: context, calledCampaignIds: campaignIds, groupId: groupId)
                    } else if eligibleCampaigns?.count ?? 0 > 1 {
                        
                        winnerCampaign = self.getCampaignUsingAdvancedAlgo(settings: settings, shortlistedCampaigns: eligibleCampaigns!, context: context, calledCampaignIds: campaignIds, groupId: groupId)
                    }
                }
            }
        } catch {
            LoggerService.log(level: .error, message: "MEG: error inside findWinnerCampaignAmongEligibleCampaigns \(error)")
        }
        
        return winnerCampaign
    }
    
    static func normalizeWeightsAndFindWinningCampaign(shortlistedCampaigns: [Campaign]?, context: VWOContext, calledCampaignIds: [Int]?, groupId: Int) -> Variation? {
        do {
            // Use a for loop to modify the weights
            if var campaigns = shortlistedCampaigns {
                for i in 0..<campaigns.count {
                    campaigns[i].weight = 100.0 / Double(campaigns.count)
                }
                
                var variations: [Variation] = try campaigns.compactMap { campaign in
                    let campaignData = try JSONEncoder().encode(campaign)
                    return try JSONDecoder().decode(Variation.self, from: campaignData)
                }
                
                CampaignUtil.setCampaignAllocation(&variations)
                let bucketValue = DecisionMaker.calculateBucketValue(
                    str: CampaignUtil.getBucketingSeed(userId: context.id, campaign: nil, groupId: groupId)
                )
                
                let winnerVariation = CampaignDecisionService.getVariation(variations: variations, bucketValue: bucketValue)
                
                
                LoggerService.log(
                    level: .info,
                    key: "MEG_WINNER_CAMPAIGN",
                    details: [
                        "campaignKey": winnerVariation?.key ?? "",
                        "groupId": String(groupId),
                        "userId": context.id ?? "",
                        "algo": "using random algorithm"
                    ]
                )
                                
                if let winnerVariation = winnerVariation, calledCampaignIds?.contains(winnerVariation.id!) == true {
                    return winnerVariation
                }
                
                
            }
        } catch {
            LoggerService.log(
                level: .error,
                message: "MEG: error inside normalizeWeightsAndFindWinningCampaign"
            )
        }
        return nil
    }
    
    private static func getCampaignUsingAdvancedAlgo(settings: Settings, shortlistedCampaigns: [Campaign], context: VWOContext, calledCampaignIds: [Int?]?, groupId: Int) -> Variation? {
        var winnerCampaign: Variation?
        var found = false
        
        do {
            if let group = settings.groups?[String(groupId)], let priorityOrder = group.p, let groupWt = group.wt {
                let wt = convertWtToMap(wt: groupWt)
                
                for integer in priorityOrder {
                    for shortlistedCampaign in shortlistedCampaigns {
                        if shortlistedCampaign.id == integer {
                            let campaignModel = try JSONEncoder().encode(FunctionUtil.cloneObject(shortlistedCampaign))
                            winnerCampaign = try JSONDecoder().decode(Variation.self, from: campaignModel)
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
                
                if winnerCampaign == nil {
                    var participatingCampaignList: [Campaign?] = []
                    for campaign in shortlistedCampaigns {
                        if let campaignId = campaign.id, wt.keys.contains(campaignId) {
                            var clonedCampaign = FunctionUtil.cloneObject(campaign)! as Campaign
                            clonedCampaign.weight = Double(wt[campaignId] ?? 0)
                            participatingCampaignList.append(clonedCampaign)
                        }
                    }
                    
                    var variations = try participatingCampaignList.map { campaign -> Variation in
                        let campaignModel = try JSONEncoder().encode(campaign)
                        return try JSONDecoder().decode(Variation.self, from: campaignModel)
                    }
                    
                    CampaignUtil.setCampaignAllocation(&variations)
                    winnerCampaign = CampaignDecisionService.getVariation(variations: variations, bucketValue: DecisionMaker.calculateBucketValue(str: CampaignUtil.getBucketingSeed(userId: context.id, campaign: nil, groupId: groupId)))
                }
                
                LoggerService.log(level: .info,
                                  key: "MEG_WINNER_CAMPAIGN",
                                  details: ["campaignKey": winnerCampaign?.name ?? "",
                                            "groupId": String(groupId),
                                            "userId": context.id ?? "",
                                            "algo": "using advanced algorithm"])
                
                if calledCampaignIds?.contains(winnerCampaign?.id) == true {
                    return winnerCampaign
                }
            }
        } catch {
            LoggerService.log(level: .error, message: "MEG: error inside getCampaignUsingAdvancedAlgo \(error)")
        }
        
        return nil
    }
    
    private static func convertWtToMap(wt: [String: Int]) -> [Int: Int] {
        var wtToReturn: [Int: Int] = [:]
        for (key, value) in wt {
            if let intKey = Int(key) {
                wtToReturn[intKey] = value
            }
        }
        return wtToReturn
    }
}
