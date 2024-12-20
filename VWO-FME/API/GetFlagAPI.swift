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

class GetFlagAPI {
    /**
     * This method is used to get the flag value for the given feature key.
     * @param featureKey Feature key for which flag value is to be fetched.
     * @param settings Settings object containing the account settings.
     * @param context  VWOContext object containing the user context.
     * @param hookManager  HooksManager object containing the integrations.
     * @return GetFlag object containing the flag value.
     */
    static func getFlag(featureKey: String, settings: Settings, context: VWOContext, hookManager: HooksManager, completion: @escaping (GetFlag) -> Void) {
        
        let getFlag = GetFlag()
        let queueFlag = DispatchQueue(label: "com.vwo.fme.getflag",qos: .userInitiated, attributes: .concurrent)
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        queueFlag.async {
            
            var shouldCheckForExperimentsRules = false
            var passedRulesInformation: [String: Any] = [:]
            var evaluatedFeatureMap: [String: Any] = [:]
            
            // get feature object from feature key
            let feature: Feature? = FunctionUtil.getFeatureFromKey(settings: settings, featureKey: featureKey)
            
            /**
             * if feature is not found, return false
             */
            guard let feature = feature else {
                LoggerService.log(level: .error, key: "FEATURE_NOT_FOUND", details: [
                    "featureKey": featureKey
                ])
                getFlag.setIsEnabled(isEnabled: false)
                dispatchGroup.leave()
                return
            }
            
            /**
             * Decision object to be sent for the integrations
             */
            var decision: [String: Any] = [:]
            decision["featureName"] = feature.name
            decision["featureId"] = feature.id
            decision["featureKey"] = feature.key
            decision["userId"] = context.id
            decision["api"] = ApiEnum.getFlag.rawValue
            
            
            let storageService = StorageService()
            let storedDataMap = storageService.getFeatureFromStorage(featureKey: featureKey, context: context)
            
            /**
             * If feature is found in the storage, return the stored variation
             */
            do {
                if let storedDataMap = storedDataMap {
                    let storageMapAsString = try JSONSerialization.data(withJSONObject: storedDataMap, options: [])
                    let storedData = try JSONDecoder().decode(Storage.self, from: storageMapAsString)
                    
                    if let experimentVariationId = storedData.experimentVariationId {
                        if let experimentKey = storedData.experimentKey, !experimentKey.isEmpty {
                            let variation = CampaignUtil.getVariationFromCampaignKey(settings: settings, campaignKey: experimentKey, variationId: experimentVariationId)
                            // If variation is found in settings, return the variation
                            if let variation = variation {
                                
                                LoggerService.log(level: .info, key: "STORED_VARIATION_FOUND", details: [
                                    "variationKey": variation.name ?? "",
                                    "userId": context.id ?? "",
                                    "experimentType": "experiment",
                                    "experimentKey": experimentKey
                                ])
                                getFlag.setIsEnabled(isEnabled: true)
                                getFlag.setVariables(variation.variables)
                                dispatchGroup.leave()
                                return
                            }
                        }
                    } else if let rolloutKey = storedData.rolloutKey, !rolloutKey.isEmpty,
                              let rolloutId = storedData.rolloutId {
                        let variation = CampaignUtil.getVariationFromCampaignKey(settings: settings, campaignKey: rolloutKey, variationId: storedData.rolloutVariationId)
                        
                        // If variation is found in settings, evaluate experiment rules
                        if let variation = variation {
                            
                            LoggerService.log(level: .info, key: "STORED_VARIATION_FOUND", details: [
                                "variationKey": variation.name ?? "",
                                "userId": context.id ?? "",
                                "experimentType": "rollout",
                                "experimentKey": rolloutKey
                            ])
                            
                            LoggerService.log(level: .debug, key: "EXPERIMENTS_EVALUATION_WHEN_ROLLOUT_PASSED", details: [
                                "userId": context.id ?? ""
                            ])
                            
                            getFlag.setIsEnabled(isEnabled: true)
                            shouldCheckForExperimentsRules = true
                            var featureInfo: [String: Any] = [:]
                            featureInfo["rolloutId"] = rolloutId
                            featureInfo["rolloutKey"] = rolloutKey
                            featureInfo["rolloutVariationId"] = storedData.rolloutVariationId
                            evaluatedFeatureMap[featureKey] = featureInfo
                            
                            passedRulesInformation.merge(featureInfo) { (_, new) in new }
                        }
                    }
                }
            } catch {
                LoggerService.log(level: .debug, message: "Error parsing stored data: \(error.localizedDescription)")
            }
            
            SegmentationManager.setContextualData(settings: settings, feature: feature, context: context)
            
            /**
             * get all the rollout rules for the feature and evaluate them
             * if any of the rollout rule passes, break the loop and evaluate the traffic
             */
            let rollOutRules = FunctionUtil.getSpecificRulesBasedOnType(feature: feature, type: .rollout)
            if !rollOutRules.isEmpty && !getFlag.isEnabled() {
                var rolloutRulesToEvaluate: [Campaign] = []
                for rule in rollOutRules {
                    
                    var megGroupWinnerCampaigns: [Int : String]? = [:]
                    
                    let evaluateRuleResult = RuleEvaluationUtil.evaluateRule(settings: settings, feature: feature, campaign: rule, context: context, evaluatedFeatureMap: &evaluatedFeatureMap, megGroupWinnerCampaigns: &megGroupWinnerCampaigns, storageService: storageService, decision: &decision)
                    
                    
                    let preSegmentationResult = evaluateRuleResult["preSegmentationResult"] as? Bool ?? false
                    // If pre-segmentation passes, add the rule to the list of rules to evaluate
                    if preSegmentationResult {
                        rolloutRulesToEvaluate.append(rule)
                        var featureMap: [String: Any] = [:]
                        
                        featureMap["rolloutId"] = rule.id
                        featureMap["rolloutKey"] = rule.key
                        featureMap["rolloutVariationId"] = rule.variations?.first?.id
                        
                        evaluatedFeatureMap[featureKey] = featureMap
                        break
                    }
                }
                
                // Evaluate the passed rollout rule traffic and get the variation
                if !rolloutRulesToEvaluate.isEmpty {
                    let passedRolloutCampaign = rolloutRulesToEvaluate[0]
                    let variation = DecisionUtil.evaluateTrafficAndGetVariation(settings: settings, campaign: passedRolloutCampaign, userId: context.id)
                    if let variation = variation {
                        getFlag.setIsEnabled(isEnabled: true)
                        getFlag.setVariables(variation.variables)
                        shouldCheckForExperimentsRules = true
                        GetFlagAPI.updateIntegrationsDecisionObject(campaign: passedRolloutCampaign, variation: variation, passedRulesInformation: &passedRulesInformation, decision: &decision)
                        
                        ImpressionUtil.createAndSendImpressionForVariationShown(settings: settings, campaignId: passedRolloutCampaign.id ?? 0, variationId: variation.id ?? 0, context: context)
                    }
                }
            } else {
                LoggerService.log(level: .debug, key: "EXPERIMENTS_EVALUATION_WHEN_NO_ROLLOUT_PRESENT", details: nil)
                shouldCheckForExperimentsRules = true
            }
            
            /**
             * If any rollout rule passed pre segmentation and traffic evaluation, check for experiment rules
             * If no rollout rule passed, return false
             */
            if shouldCheckForExperimentsRules {
                var experimentRulesToEvaluate: [Campaign] = []
                let experimentRules = FunctionUtil.getAllExperimentRules(feature: feature)
                var megGroupWinnerCampaigns: [Int : String]? = [:]
                
                for rule in experimentRules {
                    // Evaluate the rule here
                    let evaluateRuleResult = RuleEvaluationUtil.evaluateRule(settings: settings, feature: feature, campaign: rule, context: context, evaluatedFeatureMap: &evaluatedFeatureMap, megGroupWinnerCampaigns: &megGroupWinnerCampaigns, storageService: storageService, decision: &decision)
                    
                    let preSegmentationResult = evaluateRuleResult["preSegmentationResult"] as? Bool ?? false
                    // If pre-segmentation passes, check if the rule has whitelisted variation or not
                    if preSegmentationResult {
                        let whitelistedObject = evaluateRuleResult["whitelistedObject"] as? Variation
                        // If whitelisted object is null, add the rule to the list of rules to evaluate
                        if whitelistedObject == nil {
                            experimentRulesToEvaluate.append(rule)
                        } else {
                            // If whitelisted object is not null, update the decision object and send an impression
                            getFlag.setIsEnabled(isEnabled: true)
                            getFlag.setVariables(whitelistedObject!.variables)
                            passedRulesInformation["experimentId"] = rule.id
                            passedRulesInformation["experimentKey"] = rule.key
                            passedRulesInformation["experimentVariationId"] = whitelistedObject!.id
                        }
                        break
                    }
                }
                
                // Evaluate the passed experiment rule traffic and get the variation
                if !experimentRulesToEvaluate.isEmpty {
                    let campaign = experimentRulesToEvaluate[0]
                    let variation = DecisionUtil.evaluateTrafficAndGetVariation(settings: settings, campaign: campaign, userId: context.id)
                    if let variation = variation {
                        getFlag.setIsEnabled(isEnabled: true)
                        getFlag.setVariables(variation.variables)
                        GetFlagAPI.updateIntegrationsDecisionObject(campaign: campaign, variation: variation, passedRulesInformation: &passedRulesInformation, decision: &decision)
                        
                        ImpressionUtil.createAndSendImpressionForVariationShown(settings: settings, campaignId: campaign.id ?? 0, variationId: variation.id ?? 0, context: context)
                    }
                }
            }
            
            if getFlag.isEnabled() {
                var storageMap: [String: Any] = [:]
                
                storageMap["featureKey"] = feature.key
                storageMap["userId"] = context.id
                storageMap.merge(passedRulesInformation) { (_, new) in new }
                
                storageService.setDataInStorage(data: storageMap)
            }
            
            // Execute the integrations
            hookManager.set(properties: decision)
            hookManager.execute(properties: hookManager.get())
            
            /**
             * If the feature has an impact campaign, send an impression for the variation shown
             * If flag enabled - variation 2, else - variation 1
             */
            if let impactCampaignId = feature.impactCampaign?.campaignId {
                LoggerService.log(level: .info, key: "IMPACT_ANALYSIS", details: [
                    "userId": context.id ?? "",
                    "featureKey": featureKey,
                    "status": getFlag.isEnabled() ? "enabled" : "disabled"
                ])
                ImpressionUtil.createAndSendImpressionForVariationShown(settings: settings, campaignId: impactCampaignId, variationId: getFlag.isEnabled() ? 2 : 1, context: context)
            }
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        completion(getFlag)
    }

    /**
     * This method is used to update the integrations decision object with the campaign and variation details.
     * @param campaign  CampaignModel object containing the campaign details.
     * @param variation  VariationModel object containing the variation details.
     * @param passedRulesInformation  Map containing the information of the passed rules.
     * @param decision  Map containing the decision object.
     */
    private static func updateIntegrationsDecisionObject(campaign: Campaign, variation: Variation, passedRulesInformation: inout [String: Any], decision: inout [String: Any]) {
        if campaign.type == CampaignTypeEnum.rollout.rawValue {
            passedRulesInformation["rolloutId"] = campaign.id ?? 0
            passedRulesInformation["rolloutKey"] = campaign.key ?? ""
            passedRulesInformation["rolloutVariationId"] = variation.id ?? 0
        } else {
            passedRulesInformation["experimentId"] = campaign.id ?? 0
            passedRulesInformation["experimentKey"] = campaign.key ?? ""
            passedRulesInformation["experimentVariationId"] = variation.id ?? 0
        }
        decision.merge(passedRulesInformation) { (_, new) in new }
    }
}
