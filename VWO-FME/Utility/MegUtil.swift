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

class MegUtil {
    
    /**
     * Evaluates groups to determine the winning variation.
     *
     * This function evaluates the groups based on the provided settings, feature, and group ID.
     * It updates the evaluated feature map and returns the winning variation if found.
     *
     * - Parameters:
     *   - settings: The settings object containing configuration details.
     *   - feature: The feature to be evaluated.
     *   - groupId: The ID of the group to be evaluated.
     *   - evaluatedFeatureMap: A map to store evaluated features.
     *   - context: The context of the VWO.
     *   - storageService: The service used for storage operations.
     * - Returns: The winning variation if found, otherwise nil.
     */
    static func evaluateGroups(settings: Settings,
                               feature: Feature?,
                               groupId: Int,
                               evaluatedFeatureMap: inout [String: Any],
                               context: VWOContext,
                               storageService: StorageService) -> Variation? {
        
        // Initialize variables to track features to skip and campaign mappings
        var featureToSkip: [String] = [String]()
        var campaignMap = [String: [Campaign]]()
        
        // Retrieve feature keys and group campaign IDs
        let featureKeysAndGroupCampaignIds = getFeatureKeysFromGroup(settings: settings, groupId: groupId)
        let featureKeys = featureKeysAndGroupCampaignIds["featureKeys"] as? [String] ?? []
        let groupCampaignIds = featureKeysAndGroupCampaignIds["groupCampaignIds"] as? [String] ?? []
        
        // Iterate over each feature key
        for featureKey in featureKeys {
            
            // Check if the current feature should be evaluated
            guard let currentFeature = FunctionUtil.getFeatureFromKey(settings: settings, featureKey: featureKey),
                  !featureToSkip.contains(featureKey) else {
                continue
            }
            
            // Determine if the rollout rule for the feature is passed
            let isRolloutRulePassed = isRolloutRuleForFeaturePassed(
                settings: settings,
                feature: currentFeature,
                evaluatedFeatureMap: &evaluatedFeatureMap,
                featureToSkip: &featureToSkip,
                context: context,
                storageService: storageService)
            
            // If rollout rule is passed, process linked campaigns
            if isRolloutRulePassed {
                for feature in settings.features {
                    if let key = feature.key {
                        if key == featureKey {
                            if let rulesLinkedCampaign = feature.rulesLinkedCampaign {
                                
                                rulesLinkedCampaign.forEach({ campaign in
                                    
                                    if let campaignId = campaign.id, let variations = campaign.variations, !variations.isEmpty  {
                                        let campaignIdString = "\(campaignId)"
                                        let campaignVariationId = "\(variations[0].id!)"
                                        let concatId = "\(campaignIdString)_\(campaignVariationId)"
                                        if groupCampaignIds.contains(campaignIdString) || groupCampaignIds.contains(concatId) {
                                            if campaignMap[featureKey] == nil {
                                                campaignMap[featureKey] = [Campaign]()
                                            }
                                            var campaigns = campaignMap[featureKey]!
                                            if !campaigns.contains(where: { $0.ruleKey == campaign.ruleKey }) {
                                                campaigns.append(campaign)
                                            }
                                            campaignMap[featureKey] = campaigns
                                        }
                                    }
                                })
                            }
                        }
                    }
                }
            }
        }
        
        // Determine eligible campaigns and find the winner
        let eligibleCampaignsMap = getEligibleCampaigns(settings: settings, campaignMap: campaignMap, context: context, storageService: storageService)
        let eligibleCampaigns = eligibleCampaignsMap["eligibleCampaigns"] as? [Campaign]
        let eligibleCampaignsWithStorage = eligibleCampaignsMap["eligibleCampaignsWithStorage"] as? [Campaign]
        
        let winnerCampaign = findWinnerCampaignAmongEligibleCampaigns(settings: settings,
                                                                      featureKey: feature?.key,
                                                                      eligibleCampaigns: eligibleCampaigns,
                                                                      eligibleCampaignsWithStorage: eligibleCampaignsWithStorage,
                                                                      groupId: groupId,
                                                                      context: context,
                                                                      storageService: storageService)
        return winnerCampaign
    }
    
    /**
     * Retrieves feature keys and group campaign IDs for a given group.
     *
     * This function fetches the feature keys and campaign IDs associated with a specific group ID.
     *
     * - Parameters:
     *   - settings: The settings object containing configuration details.
     *   - groupId: The ID of the group to retrieve data for.
     * - Returns: A dictionary containing feature keys and group campaign IDs.
     */
    static func getFeatureKeysFromGroup(settings: Settings, groupId: Int) -> [String: [Any]] {
        
        // Get campaign IDs associated with the group
        let groupCampaignIds = CampaignUtil.getCampaignsByGroupId(settings: settings, groupId: groupId)
        
        // Get feature keys from the campaign IDs
        let featureKeys = CampaignUtil.getFeatureKeysFromCampaignIds(settings: settings, campaignIdWithVariation: groupCampaignIds)
        
        // Return a dictionary with feature keys and group campaign IDs
        return [
            "featureKeys": featureKeys,
            "groupCampaignIds": groupCampaignIds
        ]
    }
    
    
    /**
     * Checks if the rollout rule for a feature is passed.
     *
     * This function evaluates the rollout rules for a given feature and updates the evaluated feature map.
     *
     * - Parameters:
     *   - settings: The settings object containing configuration details.
     *   - feature: The feature to be evaluated.
     *   - evaluatedFeatureMap: A map to store evaluated features.
     *   - featureToSkip: A list of features to skip.
     *   - context: The context of the VWO.
     *   - storageService: The service used for storage operations.
     * - Returns: A boolean indicating whether the rollout rule is passed.
     */
    private static func isRolloutRuleForFeaturePassed(settings: Settings,
                                                      feature: Feature,
                                                      evaluatedFeatureMap: inout [String: Any],
                                                      featureToSkip: inout [String],
                                                      context: VWOContext,
                                                      storageService: StorageService) -> Bool {
        
        // Check if the feature key is available
        guard let featureKey = feature.key else { return false }
        
        // Check if the feature has already been evaluated
        if let evaluatedFeature = evaluatedFeatureMap[featureKey] as? [String: Any], evaluatedFeature["rolloutId"] != nil {
            return true
        }
        
        // Get rollout rules for the feature
        let rollOutRules = FunctionUtil.getSpecificRulesBasedOnType(feature: feature, type: .rollout)
        
        // If there are rollout rules, evaluate them
        if !rollOutRules.isEmpty {
            var ruleToTestForTraffic: Campaign?
            var decisionTemp: [String :Any] = [:]
            var megGroupWinnerCampaignsTemp: [Int : String]? = nil
            
            // Evaluate each rule for pre-segmentation
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
            
            // If a rule passes pre-segmentation, evaluate traffic
            if let ruleToTestForTraffic = ruleToTestForTraffic {
                if let variation = DecisionUtil.evaluateTrafficAndGetVariation(settings: settings, campaign: ruleToTestForTraffic, userId: context.id) {
                    var rollOutInformation: [String: Any] = [:]
                    rollOutInformation["rolloutId"] = ruleToTestForTraffic.id
                    rollOutInformation["rolloutKey"] = ruleToTestForTraffic.key
                    rollOutInformation["rolloutVariationId"] = variation.id
                    evaluatedFeatureMap[featureKey] = rollOutInformation
                    return true
                }
            }
            
            // If no rule passes, add feature to skip list
            featureToSkip.append(featureKey)
            return false
        }
        
        LoggerService.log(level: .info, key: "MEG_SKIP_ROLLOUT_EVALUATE_EXPERIMENTS", details: ["featureKey": featureKey])
        return true
    }
   
    /**
     * Retrieves eligible campaigns based on the campaign map.
     *
     * This function determines which campaigns are eligible based on the provided campaign map and context.
     *
     * - Parameters:
     *   - settings: The settings object containing configuration details.
     *   - campaignMap: A map of campaigns to evaluate.
     *   - context: The context of the VWO.
     *   - storageService: The service used for storage operations.
     * - Returns: A dictionary containing eligible and ineligible campaigns.
     */
    private static func getEligibleCampaigns(settings: Settings, campaignMap: [String: [Campaign]], context: VWOContext, storageService: StorageService) -> [String: Any] {
        
        // Initialize lists for eligible and ineligible campaigns
        var eligibleCampaigns: [Campaign] = []
        var eligibleCampaignsWithStorage: [Campaign] = []
        var inEligibleCampaigns: [Campaign] = []
        
        // Iterate over each feature key and its campaigns
        for (featureKey, campaigns) in campaignMap {
            for campaign in campaigns {
                
                // Check if the campaign is stored in storage
                if let storedDataMap = storageService.getFeatureFromStorage(featureKey: featureKey, context: context) {
                    do {
                        let storageMapAsString = try JSONSerialization.data(withJSONObject: storedDataMap, options: [])
                        let storedData = try JSONDecoder().decode(Storage.self, from: storageMapAsString)
                        if let experimentVariationId = storedData.experimentVariationId {
                            if let experimentKey = storedData.experimentKey, experimentKey == campaign.key {
                                if CampaignUtil.getVariationFromCampaignKey(settings: settings, campaignKey: experimentKey, variationId: experimentVariationId) != nil {
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
                
                // Evaluate pre-segmentation and user participation
                if CampaignDecisionService().getPreSegmentationDecision(campaign: campaign, context: context) && CampaignDecisionService().isUserPartOfCampaign(userId: context.id, campaign: campaign) {
                    LoggerService.log(level: .info,
                                      key: "MEG_CAMPAIGN_ELIGIBLE",
                                      details: ["campaignKey": campaign.type == CampaignTypeEnum.ab.rawValue ? "\(campaign.key ?? "--")" : "\(campaign.name ?? "--")_\(campaign.ruleKey ?? "--")",
                                                "userId": context.id ?? ""])
                    eligibleCampaigns.append(campaign)
                    continue
                }
                
                // Add to ineligible campaigns if not eligible
                inEligibleCampaigns.append(campaign)
            }
        }
        
        // Return eligible and ineligible campaigns
        return ["eligibleCampaigns": eligibleCampaigns, "eligibleCampaignsWithStorage": eligibleCampaignsWithStorage, "inEligibleCampaigns": inEligibleCampaigns]
    }
    
    /**
     * Finds the winning campaign among eligible campaigns.
     *
     * This function selects the winning campaign from a list of eligible campaigns based on various criteria.
     *
     * - Parameters:
     *   - settings: The settings object containing configuration details.
     *   - featureKey: The key of the feature being evaluated.
     *   - eligibleCampaigns: A list of eligible campaigns.
     *   - eligibleCampaignsWithStorage: A list of eligible campaigns with storage data.
     *   - groupId: The ID of the group being evaluated.
     *   - context: The context of the VWO.
     *   - storageService: The service used for storage operations.
     * - Returns: The winning variation if found, otherwise nil.
     */
    private static func findWinnerCampaignAmongEligibleCampaigns(settings: Settings, featureKey: String?, eligibleCampaigns: [Campaign]?, eligibleCampaignsWithStorage: [Campaign]?, groupId: Int, context: VWOContext, storageService: StorageService) -> Variation? {
        
        // Get campaign IDs from the feature key
        let campaignIds = CampaignUtil.getCampaignIdsFromFeatureKey(settings: settings, featureKey: featureKey)
        var winnerCampaign: Variation?
        
        do {
            // Check if the group exists in settings
            if let group = settings.groups?[String(groupId)] {
                let megAlgoNumber = group.et ?? Constants.RANDOM_ALGO
                
                // Determine winner from eligible campaigns with storage
                if eligibleCampaignsWithStorage?.count == 1 {
                    let campaignModel = try JSONEncoder().encode(eligibleCampaignsWithStorage?[0])
                    winnerCampaign = try JSONDecoder().decode(Variation.self, from: campaignModel)
                    LoggerService.log(level: .info,
                                      key: "MEG_WINNER_CAMPAIGN",
                                      details: ["campaignKey": winnerCampaign?.type == CampaignTypeEnum.ab.rawValue ? "\(winnerCampaign?.key ?? "--")" : "\(winnerCampaign?.name ?? "--")_\(winnerCampaign?.ruleKey ?? "--")",
                                                "groupId": "\(groupId)",
                                                "userId": context.id ?? ""])
                } else if eligibleCampaignsWithStorage?.count ?? 0 > 1 && megAlgoNumber == Constants.RANDOM_ALGO {
                    winnerCampaign = normalizeWeightsAndFindWinningCampaign(shortlistedCampaigns: eligibleCampaignsWithStorage, context: context, calledCampaignIds: campaignIds, groupId: groupId, storageService: storageService)
                } else if eligibleCampaignsWithStorage?.count ?? 0 > 1 {
                    winnerCampaign = getCampaignUsingAdvancedAlgo(settings: settings, shortlistedCampaigns: eligibleCampaignsWithStorage!, context: context, calledCampaignIds: campaignIds, groupId: groupId, storageService: storageService)
                }
                
                // Determine winner from eligible campaigns without storage
                if eligibleCampaignsWithStorage?.isEmpty == true {
                    if eligibleCampaigns?.count == 1 {
                        let campaignModel = try JSONEncoder().encode(eligibleCampaigns?[0])
                        winnerCampaign = try JSONDecoder().decode(Variation.self, from: campaignModel)
                        LoggerService.log(level: .info,
                                          key: "MEG_WINNER_CAMPAIGN",
                                          details: [
                                            "campaignKey": winnerCampaign?.type == CampaignTypeEnum.ab.rawValue ? "\(winnerCampaign?.key ?? "--")" : "\(winnerCampaign?.name ?? "--")_\(winnerCampaign?.ruleKey ?? "--")",
                                                    "groupId": "\(groupId)",
                                                    "userId": context.id ?? "",
                                                    "algo": ""])
                    } else if eligibleCampaigns?.count ?? 0 > 1 && megAlgoNumber == Constants.RANDOM_ALGO {
                        winnerCampaign = normalizeWeightsAndFindWinningCampaign(shortlistedCampaigns: eligibleCampaigns, context: context, calledCampaignIds: campaignIds, groupId: groupId, storageService: storageService)
                    } else if eligibleCampaigns?.count ?? 0 > 1 {
                        
                        winnerCampaign = self.getCampaignUsingAdvancedAlgo(settings: settings, shortlistedCampaigns: eligibleCampaigns!, context: context, calledCampaignIds: campaignIds, groupId: groupId, storageService: storageService)
                    }
                }
            }
        } catch {
            LoggerService.log(level: .error, message: "MEG: error inside findWinnerCampaignAmongEligibleCampaigns \(error)")
        }
        
        return winnerCampaign
    }
    
    /**
     * Normalizes weights and finds the winning campaign.
     *
     * This function adjusts the weights of shortlisted campaigns and determines the winning campaign.
     *
     * - Parameters:
     *   - shortlistedCampaigns: A list of shortlisted campaigns.
     *   - context: The context of the VWO.
     *   - calledCampaignIds: A list of campaign IDs that have been called.
     *   - groupId: The ID of the group being evaluated.
     *   - storageService: The service used for storage operations.
     * - Returns: The winning variation if found, otherwise nil.
     */
    static func normalizeWeightsAndFindWinningCampaign(shortlistedCampaigns: [Campaign]?, context: VWOContext, calledCampaignIds: [Int]?, groupId: Int, storageService: StorageService) -> Variation? {
        do {
            // Use a for loop to modify the weights
            if var campaigns = shortlistedCampaigns {
                for i in 0..<campaigns.count {
                    campaigns[i].weight = 100.0 / Double(campaigns.count)
                }
                
                // Convert campaigns to variations
                var variations: [Variation] = try campaigns.compactMap { campaign in
                    let campaignData = try JSONEncoder().encode(campaign)
                    return try JSONDecoder().decode(Variation.self, from: campaignData)
                }
                
                // Set campaign allocation and calculate bucket value
                CampaignUtil.setCampaignAllocation(&variations)
                let bucketValue = DecisionMaker.calculateBucketValue(str: CampaignUtil.getBucketingSeed(userId: context.id, campaign: nil, groupId: groupId))
                
                // Get the winning variation
                let winnerVariation = CampaignDecisionService.getVariation(variations: variations, bucketValue: bucketValue)
                
                if let winnerVariation = winnerVariation {
                    
                    LoggerService.log(
                        level: .info,
                        key: "MEG_WINNER_CAMPAIGN",
                        details: [
                            "campaignKey": winnerVariation.type == CampaignTypeEnum.ab.rawValue ? "\(winnerVariation.key ?? "--")" : "\(winnerVariation.name ?? "--")_\(winnerVariation.ruleKey ?? "--")",
                            "groupId": String(groupId),
                            "userId": context.id ?? "",
                            "algo": "using random algorithm"
                        ]
                    )
                    
                    // Store the winning campaign details
                    var storageMap: [String: Any] = [:]
                    storageMap["featureKey"] = Constants.VWO_META_MEG_KEY + "\(groupId)"
                    storageMap["userId"] = context.id
                    storageMap["experimentId"] = winnerVariation.id
                    storageMap["experimentKey"] = winnerVariation.key
                    storageMap["experimentVariationId"] = winnerVariation.type == CampaignTypeEnum.personalize.rawValue ? winnerVariation.variations[0].id : -1
                    
                    
                    storageService.setDataInStorage(data: storageMap)
                    
                    if let _ = calledCampaignIds?.first(where: {$0 == winnerVariation.id}) {
                        return winnerVariation
                    }
                } else {
                    LoggerService.log(level: .info, message: "No winner campaign found for MEG group: \(groupId)")
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
    
    /**
     * Selects a campaign using an advanced algorithm.
     *
     * This function uses an advanced algorithm to select a campaign from a list of shortlisted campaigns.
     *
     * - Parameters:
     *   - settings: The settings object containing configuration details.
     *   - shortlistedCampaigns: A list of shortlisted campaigns.
     *   - context: The context of the VWO.
     *   - calledCampaignIds: A list of campaign IDs that have been called.
     *   - groupId: The ID of the group being evaluated.
     *   - storageService: The service used for storage operations.
     * - Returns: The winning variation if found, otherwise nil.
     */
    private static func getCampaignUsingAdvancedAlgo(settings: Settings, shortlistedCampaigns: [Campaign], context: VWOContext, calledCampaignIds: [Int]?, groupId: Int, storageService: StorageService) -> Variation? {
        var winnerCampaign: Variation?
        var found = false
        
        do {
            // Check if the group exists and has priority order and weights
            if let group = settings.groups?[String(groupId)], let groupWt = group.wt {
                
                let priorityOrder = group.p ?? []
                let wt = groupWt
                
                // Iterate over priority order to find the winner
                for item in priorityOrder {
                    for shortlistedCampaign in shortlistedCampaigns {
                        
                        if let shortlistedCampaignId = shortlistedCampaign.id {
                            if "\(shortlistedCampaignId)" == item {
                                let campaignModel = try JSONEncoder().encode(FunctionUtil.cloneObject(shortlistedCampaign))
                                winnerCampaign = try JSONDecoder().decode(Variation.self, from: campaignModel)
                                found = true
                                break
                            } else if "\(shortlistedCampaignId)_\(shortlistedCampaign.variations?.first?.id ?? 0)" == item {
                                let campaignModel = try JSONEncoder().encode(FunctionUtil.cloneObject(shortlistedCampaign))
                                winnerCampaign = try JSONDecoder().decode(Variation.self, from: campaignModel)
                                found = true
                                break
                            }
                        }
                    }
                    if found { break }
                }
                
                // If no winner found, use weights to determine the winner
                if winnerCampaign == nil {
                    var participatingCampaignList: [Campaign?] = []
                    for campaign in shortlistedCampaigns {
                        if let campaignId = campaign.id {
                            if let weight = wt["\(campaignId)"]  {
                                var clonedCampaign = FunctionUtil.cloneObject(campaign)! as Campaign
                                clonedCampaign.weight = weight
                                participatingCampaignList.append(clonedCampaign)
                            } else if let weight = wt["\(campaignId)_\(campaign.variations?.first?.id ?? 0)"] {
                                var clonedCampaign = FunctionUtil.cloneObject(campaign)! as Campaign
                                clonedCampaign.weight = weight
                                participatingCampaignList.append(clonedCampaign)
                            }
                        }
                    }
                    
                    // Convert campaigns to variations
                    var variations = try participatingCampaignList.map { campaign -> Variation in
                        let campaignModel = try JSONEncoder().encode(campaign)
                        return try JSONDecoder().decode(Variation.self, from: campaignModel)
                    }
                    
                    // Set campaign allocation and calculate bucket value
                    CampaignUtil.setCampaignAllocation(&variations)
                    winnerCampaign = CampaignDecisionService.getVariation(variations: variations, bucketValue: DecisionMaker.calculateBucketValue(str: CampaignUtil.getBucketingSeed(userId: context.id, campaign: nil, groupId: groupId)))
                }
                
                // Log the winning campaign
                if let finalWinnerCampaign = winnerCampaign {
                    
                    LoggerService.log(level: .info,
                                      key: "MEG_WINNER_CAMPAIGN",
                                      details: ["campaignKey": winnerCampaign?.type == CampaignTypeEnum.ab.rawValue ? "\(finalWinnerCampaign.key ?? "--")" : "\(finalWinnerCampaign.name ?? "--")_\(finalWinnerCampaign.ruleKey ?? "--")",
                                                "groupId": String(groupId),
                                                "userId": context.id ?? "",
                                                "algo": "using advanced algorithm"])
                    
                    // Store the winning campaign details
                    var storageMap: [String: Any] = [:]
                    storageMap["featureKey"] = Constants.VWO_META_MEG_KEY + "\(groupId)"
                    storageMap["userId"] = context.id
                    storageMap["experimentId"] = finalWinnerCampaign.id
                    storageMap["experimentKey"] = finalWinnerCampaign.key
                    storageMap["experimentVariationId"] = finalWinnerCampaign.type == CampaignTypeEnum.personalize.rawValue ? finalWinnerCampaign.variations[0].id : -1

                    storageService.setDataInStorage(data: storageMap)
                    
                    if let _ = calledCampaignIds?.first(where: {$0 == finalWinnerCampaign.id}) {
                        return finalWinnerCampaign
                    }
                } else {
                    LoggerService.log(level: .info, message: "No winner campaign found for MEG group: \(groupId)")
                }
            } else {
                LoggerService.log(level: .error, message: "MEG: error inside getCampaignUsingAdvancedAlgo")
            }
        } catch {
            LoggerService.log(level: .error, message: "MEG: error inside getCampaignUsingAdvancedAlgo \(error)")
        }
        
        return nil
    }
    
    /**
     * Converts weight dictionary keys from String to Int.
     *
     * This function converts the keys of a weight dictionary from String to Int format.
     *
     * - Parameters:
     *   - wt: A dictionary with String keys and Int values.
     * - Returns: A dictionary with Int keys and Int values.
     */
    private static func convertWtToMap(wt: [String: Int]) -> [Int: Int] {
        
        // Initialize a dictionary to store converted weights
        var wtToReturn: [Int: Int] = [:]
        
        // Convert each key from String to Int
        for (key, value) in wt {
            if let intKey = Int(key) {
                wtToReturn[intKey] = value
            }
        }
        
        // Return the converted weight dictionary
        return wtToReturn
    }
}
