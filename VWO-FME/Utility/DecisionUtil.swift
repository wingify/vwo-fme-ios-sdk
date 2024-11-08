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

class DecisionUtil {
    
    /**
     * Checks whitelisting and pre-segmentation for a given campaign.
     *
     * - Parameters:
     *   - settings: The settings object containing account information.
     *   - feature: The feature being evaluated (optional).
     *   - campaign: The campaign to be evaluated.
     *   - context: The context of the current VWO session.
     *   - evaluatedFeatureMap: A map to store evaluated features.
     *   - megGroupWinnerCampaigns: A map to store winner campaigns in mutually exclusive groups.
     *   - storageService: The storage service for retrieving stored data.
     *   - decision: A map to store decision-related data.
     * - Returns: A dictionary containing the pre-segmentation result and whitelisted object.
     */
    static func checkWhitelistingAndPreSeg(
        settings: Settings,
        feature: Feature?,
        campaign: Campaign,
        context: VWOContext,
        evaluatedFeatureMap: inout [String: Any],
        megGroupWinnerCampaigns: inout [Int: String]?,
        storageService: StorageService,
        decision: inout [String: Any]
    ) -> [String: Any] {
        
        // Generate a unique user ID for the campaign
        let stringAccountId = "\(settings.accountId ?? 0)"
        let vwoUserId = UUIDUtils.getUUID(userId: context.id, accountId: stringAccountId)
        let campaignId = campaign.id!
        
        // Handle AB campaign type
        if campaign.type == CampaignTypeEnum.ab.rawValue {
            let id = campaign.isUserListEnabled == true ? vwoUserId : context.id
            if let id = id {
                context.variationTargetingVariables["_vwoUserId"] = id
            }
            
            decision["variationTargetingVariables"] = context.variationTargetingVariables
            
            // Check for forced variation
            if campaign.isForcedVariationEnabled == true {
                if let whitelistedVariation = checkCampaignWhitelisting(campaign: campaign, context: context) {
                    let variation = whitelistedVariation["variation"] ?? ""
                    return [
                        "preSegmentationResult": true,
                        "whitelistedObject": variation as Any
                    ]
                }
            } else {
                LoggerService.log(level: .info,
                                  key: "WHITELISTING_SKIP",
                                  details: [
                                    "userId": context.id ?? "",
                                    "campaignKey": campaign.ruleKey ?? ""])
            }
        }
        
        // Set custom variables for the user
        let userId = campaign.isUserListEnabled == true ? vwoUserId : context.id
        context.customVariables["_vwoUserId"] = userId ?? ""
        
        decision["customVariables"] = context.customVariables
        
        // Check if the rule is part of a Mutually Exclusive Group
        let variationId = campaign.type == CampaignTypeEnum.personalize.rawValue ? campaign.variations?[0].id : -1
        
        let groupIdValue = CampaignUtil.getGroupDetailsIfCampaignPartOfIt(settings: settings, campaignId: campaignId, variationId: variationId ?? -1)["groupId"]
        
        if let groupId = groupIdValue, let groudIdInt = Int(groupId) {
            
            if let groupWinnerCampaignId = megGroupWinnerCampaigns?[groudIdInt], !groupWinnerCampaignId.isEmpty {
                
                if campaign.type == CampaignTypeEnum.ab.rawValue {
                    if groupWinnerCampaignId == "\(campaignId)" {
                        return [
                            "preSegmentationResult": true,
                            "whitelistedObject": NSNull()
                        ]
                    }
                } else if campaign.type == CampaignTypeEnum.personalize.rawValue {
                    if groupWinnerCampaignId == "\(campaignId)_\(campaign.variations?.first?.id ?? 0)" {
                        return [
                            "preSegmentationResult": true,
                            "whitelistedObject": NSNull()
                        ]
                    }
                }
                return [
                    "preSegmentationResult": false,
                    "whitelistedObject": NSNull()
                ]
            } else {
                
                let storageFeatureKey = Constants.VWO_META_MEG_KEY + groupId
                let storageDataMap = storageService.getFeatureFromStorage(featureKey: storageFeatureKey, context: context)
                
                if let storageDataMap = storageDataMap {
                    
                    do {
                        let storageData = try JSONDecoder().decode(Storage.self, from: JSONSerialization.data(withJSONObject: storageDataMap))
                        
                        if let experimentId = storageData.experimentId, let experimentKey = storageData.experimentKey {
                            LoggerService.log(level: .info, key: "MEG_CAMPAIGN_FOUND_IN_STORAGE", details: [
                                "campaignKey": experimentKey,
                                "userId": "\(context.id ?? "--")"
                            ])
                            if experimentId == campaignId {
                                if campaign.type == CampaignTypeEnum.personalize.rawValue {
                                    if storageData.experimentVariationId == campaign.variations?[0].id {
                                        return [
                                            "preSegmentationResult": true,
                                            "whitelistedObject": NSNull()
                                        ]
                                    } else {
                                        megGroupWinnerCampaigns?[Int(groupId) ?? 0] = "\(experimentId)_\(storageData.experimentVariationId ?? 0)"
                                        return [
                                            "preSegmentationResult": false,
                                            "whitelistedObject": NSNull()
                                        ]
                                    }
                                } else {
                                    return [
                                        "preSegmentationResult": true,
                                        "whitelistedObject": NSNull()
                                    ]
                                }
                            }
                            if storageData.experimentVariationId != -1 {
                                megGroupWinnerCampaigns?[Int(groupId) ?? 0] = "\(experimentId)_\(storageData.experimentVariationId ?? 0)"
                            } else {
                                megGroupWinnerCampaigns?[Int(groupId) ?? 0] = String(experimentId)
                            }
                            return [
                                "preSegmentationResult": false,
                                "whitelistedObject": NSNull()
                            ]
                        }
                    } catch {
                        LoggerService.log(level: .error, key: "STORED_DATA_ERROR", details: [
                            "err": error.localizedDescription
                        ])
                    }
                }
            }
        }
        
        // Evaluate pre-segmentation decision
        let isPreSegmentationPassed = CampaignDecisionService().getPreSegmentationDecision(campaign: campaign, context: context)
        
        let variationId2 = campaign.type == CampaignTypeEnum.personalize.rawValue ? campaign.variations?[0].id : -1
        
        let groupDetails = CampaignUtil.getGroupDetailsIfCampaignPartOfIt(settings: settings, campaignId: campaign.id ?? -1, variationId: variationId2 ?? -1)
        let groupId = groupDetails["groupId"]
        
        if let groupId = groupId, !groupId.isEmpty, isPreSegmentationPassed {
            
            let variationModelEvaluated = MegUtil.evaluateGroups(settings: settings, feature: feature, groupId: Int(groupId) ?? 0, evaluatedFeatureMap: &evaluatedFeatureMap, context: context, storageService: storageService)
            
            if let variationModel = variationModelEvaluated, let variationId = variationModel.id, variationId == campaignId {
                
                if variationModel.type == CampaignTypeEnum.ab.rawValue {
                    return [
                        "preSegmentationResult": true,
                        "whitelistedObject": NSNull()
                    ]
                } else {
                    if variationModel.variations[0].id == campaign.variations?[0].id {
                        return [
                            "preSegmentationResult": true,
                            "whitelistedObject": NSNull()
                        ]
                    } else {
                        megGroupWinnerCampaigns?[Int(groupId) ?? 0] = "\(variationId)_\(variationModel.variations.first?.id ?? 0)"
                        return [
                            "preSegmentationResult": false,
                            "whitelistedObject": NSNull()
                        ]
                    }
                }
            } else if let variationModel = variationModelEvaluated, let variationId = variationModel.id {
                
                if variationModel.type == CampaignTypeEnum.ab.rawValue {
                    megGroupWinnerCampaigns?[Int(groupId) ?? 0] = String(variationId)
                } else {
                    megGroupWinnerCampaigns?[Int(groupId) ?? 0] = "\(variationId)_\(variationModel.variations.first?.id ?? 0)"
                }
                return [
                    "preSegmentationResult": false,
                    "whitelistedObject": NSNull()
                ]
            }
            
            megGroupWinnerCampaigns?[Int(groupId) ?? 0] = String(-1)
            return [
                "preSegmentationResult": false,
                "whitelistedObject": NSNull()
            ]
        }
        
        return [
            "preSegmentationResult": isPreSegmentationPassed,
            "whitelistedObject": NSNull()
        ]
    }
    
    /**
     * Evaluates traffic and determines the appropriate variation for a user.
     *
     * - Parameters:
     *   - settings: The settings object containing account information.
     *   - campaign: The campaign to be evaluated.
     *   - userId: The user ID for which the variation is to be determined.
     * - Returns: The variation assigned to the user, if any.
     */
    static func evaluateTrafficAndGetVariation(
        settings: Settings,
        campaign: Campaign,
        userId: String?
    ) -> Variation? {
        let stringAccountId = String(describing: settings.accountId)
        let variation = CampaignDecisionService().getVariationAllotted(userId: userId, accountId: stringAccountId, campaign: campaign)
        
        if variation == nil {
            LoggerService.log(level: .info,
                              key: "USER_CAMPAIGN_BUCKET_INFO",
                              details: ["userId": userId ?? "",
                                        "campaignKey": campaign.type == CampaignTypeEnum.ab.rawValue ? "\(campaign.key ?? "--")" : "\(campaign.name ?? "--")_\(campaign.ruleKey ?? "--")",
                                        "status": "did not get any variation"])
            return nil
        }
        
        LoggerService.log(level: .info,
                          key: "USER_CAMPAIGN_BUCKET_INFO",
                          details: ["userId": userId ?? "",
                                    "campaignKey": campaign.type == CampaignTypeEnum.ab.rawValue ? "\(campaign.key ?? "--")" : "\(campaign.name ?? "--")_\(campaign.ruleKey ?? "--")",
                                    "status": "got variation: \(variation?.name ?? "--")"])
        return variation
    }
    
    /**
     * Checks if a campaign is whitelisted for a given context.
     *
     * - Parameters:
     *   - campaign: The campaign to be evaluated.
     *   - context: The context of the current VWO session.
     * - Returns: A dictionary containing the whitelisted variation, if any.
     */
    private static func checkCampaignWhitelisting(campaign: Campaign, context: VWOContext) -> [String: Any?]? {
        let whitelistingResult = evaluateWhitelisting(campaign: campaign, context: context)
        let status = whitelistingResult != nil ? StatusEnum.passed : StatusEnum.failed
        let variationString = whitelistingResult?["variationName"] as? String ?? ""
        LoggerService.log(level: .info,
                          key: "WHITELISTING_STATUS",
                          details: ["userId": context.id ?? "",
                                    "campaignKey": campaign.type == CampaignTypeEnum.ab.rawValue ? "\(campaign.key ?? "--")" : "\(campaign.name ?? "--")_\(campaign.ruleKey ?? "--")",
                                    "status": status.rawValue,
                                    "variationString": variationString])
        return whitelistingResult
    }
    
    /**
     * Evaluates whitelisting for a campaign based on the context.
     *
     * - Parameters:
     *   - campaign: The campaign to be evaluated.
     *   - context: The context of the current VWO session.
     * - Returns: A dictionary containing the whitelisted variation, if any.
     */
    private static func evaluateWhitelisting(campaign: Campaign, context: VWOContext) -> [String: Any?]? {
        
        var targetedVariations = [Variation]()
        
        for variation in campaign.variations ?? [] {
            
            guard let segments = variation.segments else {
                LoggerService.log(level: .info,
                                  key: "WHITELISTING_SKIP",
                                  details: ["userId": context.id ?? "",
                                            "campaignKey": campaign.ruleKey ?? "",
                                            "variation": variation.name ?? ""])
                continue
            }
            
            let segmentationResult = SegmentationManager.validateSegmentation(dsl: segments, properties: context.variationTargetingVariables)
            if segmentationResult {
                if let clonedVariation = FunctionUtil.cloneObject(variation) {
                    targetedVariations.append(clonedVariation)
                }
            }
        }
        
        var whitelistedVariation: Variation?
        
        if targetedVariations.count > 1 {
            CampaignUtil.scaleVariationWeights(&targetedVariations)
            var currentAllocation = 0
            for i in 0..<targetedVariations.count {
                var variation = targetedVariations[i]
                let stepFactor = CampaignUtil.assignRangeValues(&variation, currentAllocation: currentAllocation)
                currentAllocation += stepFactor
                targetedVariations[i] = variation
            }
            whitelistedVariation = CampaignDecisionService.getVariation(variations: targetedVariations, bucketValue: DecisionMaker.calculateBucketValue(str: CampaignUtil.getBucketingSeed(userId: context.id, campaign: campaign, groupId: nil)))
        } else if targetedVariations.count == 1 {
            whitelistedVariation = targetedVariations[0]
        }
        
        if let whitelistedVariation = whitelistedVariation {
            return [
                "variation": whitelistedVariation,
                "variationName": whitelistedVariation.name,
                "variationId": whitelistedVariation.id
            ]
        }
        
        return nil
        
    }
}
