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
    
    static func checkWhitelistingAndPreSeg(
        settings: Settings,
        feature: Feature?,
        campaign: Campaign,
        context: VWOContext,
        evaluatedFeatureMap: inout [String: Any],
        megGroupWinnerCampaigns: inout [Int: Int]?,
        storageService: StorageService,
        decision: inout [String: Any]
    ) -> [String: Any] {
        
        let stringAccountId = "\(settings.accountId ?? 0)"
        let vwoUserId = UUIDUtils.getUUID(userId: context.id, accountId: stringAccountId)
        let campaignId = campaign.id
        
        if campaign.type == CampaignTypeEnum.ab.rawValue {
            let id = campaign.isUserListEnabled == true ? vwoUserId : context.id
            if let id = id {
                context.variationTargetingVariables["_vwoUserId"] = id
            }
            
            decision["variationTargetingVariables"] = context.variationTargetingVariables
            
            if campaign.isForcedVariationEnabled == true {
                if let whitelistedVariation = checkCampaignWhitelisting(campaign: campaign, context: context) {
                    let variation = whitelistedVariation["variation"] ?? ""
                    return [
                        "preSegmentationResult": true,
                        "whitelistedObject": variation
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
        
        let userId = campaign.isUserListEnabled == true ? vwoUserId : context.id
        context.customVariables["_vwoUserId"] = userId ?? ""
        
        decision["customVariables"] = context.customVariables
        
        // Check if RUle being evaluated is part of Mutually Exclusive Group
        let groupIdValue = CampaignUtil.getGroupDetailsIfCampaignPartOfIt(settings: settings, campaignId: campaignId ?? 0)["groupId"]
        
        if let groupId = groupIdValue, let groupIdInt = Int(groupId) {
            if let groupWinnerCampaignId = megGroupWinnerCampaigns?[groupIdInt], groupWinnerCampaignId == campaignId {
                return [
                    "preSegmentationResult": true
                ]
            } else if let groupWinnerCampaignId = megGroupWinnerCampaigns?[groupIdInt] {
                return [
                    "preSegmentationResult": false
                ]
            }
        }
        
        let isPreSegmentationPassed = CampaignDecisionService().getPreSegmentationDecision(campaign: campaign, context: context)
        
        if isPreSegmentationPassed, let groupId = groupIdValue, let groupIdInt = Int(groupId) {
            
            let variationM = MegUtil.evaluateGroups(settings: settings, feature: feature, groupId: Int(groupId) ?? 0, evaluatedFeatureMap: &evaluatedFeatureMap, context: context, storageService: storageService)
            
            if let variationModel = variationM, variationModel.id == campaignId {
                return [
                    "preSegmentationResult": true
                ]
            }
            megGroupWinnerCampaigns?[Int(groupId) ?? 0] = variationM?.id ?? 0
            return [
                "preSegmentationResult": false
            ]
        }
        
        return [
            "preSegmentationResult": isPreSegmentationPassed
        ]
    }
    
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
                                        "campaignKey": campaign.ruleKey ?? "",
                                        "status": "did not get any variation"])
            return nil
        }
        
        LoggerService.log(level: .info, 
                          key: "USER_CAMPAIGN_BUCKET_INFO",
                          details: ["userId": userId ?? "",
                                    "campaignKey": campaign.ruleKey ?? "",
                                    "status": "got variation: \(variation?.name)"])
        return variation
    }
    
    private static func checkCampaignWhitelisting(campaign: Campaign, context: VWOContext) -> [String: Any?]? {
        let whitelistingResult = evaluateWhitelisting(campaign: campaign, context: context)
        let status = whitelistingResult != nil ? StatusEnum.passed : StatusEnum.failed
        let variationString = whitelistingResult?["variationName"] as? String ?? ""
        LoggerService.log(level: .info,
                          key: "WHITELISTING_STATUS",
                          details: ["userId": context.id ?? "",
                                    "campaignKey": campaign.ruleKey ?? "",
                                    "status": status.rawValue,
                                    "variationString": variationString])
        return whitelistingResult
    }
    
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
            
            if let segments = variation.segments {
                let segmentationResult = SegmentationManager.validateSegmentation(dsl: segments, properties: context.variationTargetingVariables)
                
                if segmentationResult {
                    if let clonedVariation = FunctionUtil.cloneObject(variation) {
                        targetedVariations.append(clonedVariation)
                    }
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
