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

class CampaignDecisionService {
    
    /**
     * This method is used to check if the user is part of the campaign.
     * @param userId  User ID for which the check is to be performed.
     * @param campaign CampaignModel object containing the campaign settings.
     * @return  boolean value indicating if the user is part of the campaign.
     */
    func isUserPartOfCampaign(userId: String?, campaign: Campaign?) -> Bool {
        guard let campaign = campaign, let campaignId = campaign.id , let userId = userId else {
            return false
        }
        
        // Check if the campaign is of type ROLLOUT or PERSONALIZE
        let isRolloutOrPersonalize = campaign.type == CampaignTypeEnum.rollout.rawValue || campaign.type == CampaignTypeEnum.personalize.rawValue
        
        // Get salt based on campaign type
        let salt = isRolloutOrPersonalize ? campaign.variations?.first?.salt ?? "" : campaign.salt ?? ""
        
        // Get traffic allocation based on campaign type
        let trafficAllocation = isRolloutOrPersonalize ? campaign.variations?.first?.weight ?? 0.0 : Double(campaign.percentTraffic ?? 0)
        
        // Generate bucket key using salt if available, otherwise use campaign ID
        let bucketKey = !salt.isEmpty ? "\(salt)_\(userId)" : "\(campaignId)_\(userId)"
        
        // Get the bucket value assigned to the user
        let valueAssignedToUser = DecisionMaker.getBucketValueForUser(userId: "\(bucketKey)")
        
        // Check if user is part of campaign
        let isUserPart = valueAssignedToUser != 0 && valueAssignedToUser <= Int(trafficAllocation)
        
        LoggerService.log(
            level: .info,
            key: "USER_PART_OF_CAMPAIGN",
            details: [
                "userId": userId,
                "campaignKey": campaign.type == CampaignTypeEnum.ab.rawValue ? "\(campaign.key ?? "--")" : "\(campaign.name ?? "--")_\(campaign.ruleKey ?? "--")",
                "notPart": isUserPart ? "" : "not"
            ]
        )
        return isUserPart
    }
    
    /**
     * This method is used to get the variation for the user based on the bucket value.
     * @param variations  List of VariationModel objects containing the variations.
     * @param bucketValue  Bucket value assigned to the user.
     * @return  VariationModel object containing the variation for the user.
     */
    static func getVariation(variations: [Variation], bucketValue: Int) -> Variation? {
        for variation in variations {
            if bucketValue >= variation.startRangeVariation && bucketValue <= variation.endRangeVariation {
                return variation
            }
        }
        return nil
    }
    
    /**
     * This method is used to check if the bucket value falls in the range of the variation.
     * @param variation  VariationModel object containing the variation settings.
     * @param bucketValue  Bucket value assigned to the user.
     * @return  VariationModel object containing the variation if the bucket value falls in the range, otherwise null.
     */
    func checkInRange(variation: Variation, bucketValue: Int) -> Variation? {
        if bucketValue >= variation.startRangeVariation && bucketValue <= variation.endRangeVariation {
            return variation
        }
        return nil
    }
    
    /**
     * This method is used to bucket the user to a variation based on the bucket value.
     * @param userId  User ID for which the bucketing is to be performed.
     * @param accountId  Account ID for which the bucketing is to be performed.
     * @param campaign  CampaignModel object containing the campaign settings.
     * @return  VariationModel object containing the variation allotted to the user.
     */
    func bucketUserToVariation(userId: String?, accountId: String, campaign: Campaign?) -> Variation? {
        guard let campaign = campaign, let campaignId = campaign.id, let userId = userId else {
            return nil
        }
        
        let multiplier = campaign.percentTraffic != 0 ? 1 : 0
        let percentTraffic = campaign.percentTraffic
        
        // Get salt from campaign
        let salt = campaign.salt ?? ""
        
        // Generate bucket key using salt if available, otherwise use campaign ID
        let bucketKey = !salt.isEmpty ? "\(salt)_\(accountId)_\(userId)" : "\(campaignId)_\(accountId)_\(userId)"
        
        let hashValue = DecisionMaker.generateHashValue(hashKey: bucketKey)
        let bucketValue = DecisionMaker.generateBucketValue(hashValue: hashValue, maxValue: Constants.MAX_TRAFFIC_VALUE, multiplier: multiplier)
        
        LoggerService.log(
            level: .debug,
            key: "USER_BUCKET_TO_VARIATION",
            details: [
                "userId": userId,
                "campaignKey": campaign.ruleKey ?? "",
                "percentTraffic": "\(percentTraffic ?? 0)",
                "bucketValue": "\(bucketValue)",
                "hashValue": "\(hashValue)"
            ]
        )
            
        return CampaignDecisionService.getVariation(variations: campaign.variations ?? [], bucketValue: bucketValue)
    }
    
    /**
     * This method is used to analyze the pre-segmentation decision for the user in the campaign.
     * @param campaign  CampaignModel object containing the campaign settings.
     * @param context  VWOUserContext object containing the user context.
     * @return  boolean value indicating if the user passes the pre-segmentation.
     */
    func getPreSegmentationDecision(campaign: Campaign, context: VWOUserContext) -> Bool {
        
        let campaignType = campaign.type
        let segments: [String: Any]
        
        if campaignType == CampaignTypeEnum.rollout.rawValue || campaignType == CampaignTypeEnum.personalize.rawValue {
            segments = campaign.variations?.first?.segments ?? [:]
        } else if campaignType == CampaignTypeEnum.ab.rawValue {
            segments = campaign.segments ?? [:]
        } else {
            segments = [:]
        }
        
        if segments.isEmpty {
            LoggerService.log(level: .info, key: "SEGMENTATION_SKIP", details: [
                "userId": context.id ?? "",
                "campaignKey": campaign.type == CampaignTypeEnum.ab.rawValue ? "\(campaign.key ?? "--")" : "\(campaign.name ?? "--")_\(campaign.ruleKey ?? "--")",
            ])
            return true
        } else {
            let preSegmentationResult = SegmentationManager.validateSegmentation(dsl: segments, properties: context.customVariables)
            LoggerService.log(level: .info, key: "SEGMENTATION_STATUS", details: [
                "userId": context.id ?? "",
                "campaignKey": campaign.type == CampaignTypeEnum.ab.rawValue ? "\(campaign.key ?? "--")" : "\(campaign.name ?? "--")_\(campaign.ruleKey ?? "--")",
                "status": preSegmentationResult ? "passed" : "failed"
            ])
            return preSegmentationResult
        }
    }
    
    
    /**
     * This method is used to get the variation allotted to the user in the campaign.
     * @param userId  User ID for which the variation is to be allotted.
     * @param accountId  Account ID for which the variation is to be allotted.
     * @param campaign  CampaignModel object containing the campaign settings.
     * @return  VariationModel object containing the variation allotted to the user.
     */
    func getVariationAllotted(userId: String?, accountId: String, campaign: Campaign) -> Variation? {
        let isUserPart = isUserPartOfCampaign(userId: userId, campaign: campaign)
        if campaign.type == CampaignTypeEnum.rollout.rawValue || campaign.type == CampaignTypeEnum.personalize.rawValue {
            return isUserPart ? campaign.variations?[0] : nil
        } else {
            return isUserPart ? bucketUserToVariation(userId: userId, accountId: accountId, campaign: campaign) : nil
        }
    }
}
