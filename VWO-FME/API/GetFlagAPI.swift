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

class GetFlagAPI {
    /**
     * This method is used to get the flag value for the given feature key.
     * @param featureKey Feature key for which flag value is to be fetched.
     * @param settings Settings object containing the account settings.
     * @param context  VWOUserContext object containing the user context.
     * @param hookManager  HooksManager object containing the integrations.
     * @param serviceContainer ServiceContainer instance for service access.
     * @return GetFlag object containing the flag value.
     */
    static func getFlag(featureKey: String, settings: Settings, context: VWOUserContext, hookManager: HooksManager, serviceContainer: ServiceContainer, completion: @escaping (GetFlag) -> Void) {
        
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
            
            
            // Initialize debug event properties
            var debugEventProps: [String: Any] = [
                "an": ApiEnum.getFlag.rawValue,
                "uuid": context.uuid,
                "fk": featureKey,
                "sId": context.sessionId
            ]
            
            /**
             * if feature is not found, return false
             */
            guard let feature = feature else {

                serviceContainer.getLoggerService()?.errorLog(key: "FEATURE_NOT_FOUND",data: ["featureKey":featureKey], debugData: debugEventProps)
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
            Self.applyIntegrationDecisionDefaults(feature: feature, settings: settings, decision: &decision)
            
            let storageService = serviceContainer.storage ?? StorageService()
            let storedDataMap = storageService.getFeatureFromStorage(featureKey: featureKey, context: context)
            
            /**
             * If feature is found in the storage, return the stored variation
             */
            do {
                if let storedDataMap = storedDataMap {
                    let normalizedStorageMap = FunctionUtil.normalizeStorageMapForDecoding(storedDataMap)
                    let storageMapAsString = try JSONSerialization.data(withJSONObject: normalizedStorageMap, options: [])
                    let storedData = try JSONDecoder().decode(Storage.self, from: storageMapAsString)

                    let ttl = serviceContainer.getVWOInitOptions().cachedDecisionExpiryTime
                    let now = Date().currentTimeMillis()
                    let storedExpiry = storedData.decisionExpiryTime ?? 0
                    let isExpired: Bool
                    if ttl > 0 {
                        if storedExpiry > 0 {
                            isExpired = now > storedExpiry
                        } else {
                            // No expiry stored but TTL is enabled -> force re-evaluation
                            isExpired = true
                        }
                    } else {
                        isExpired = storedData.isDecisionExpired()
                    }

                    if isExpired {
                        serviceContainer.getLoggerService()?.log(level: .warn, key: "DECISION_EXPIRED", details: [
                            "featureKey": featureKey,
                            "id": context.id ?? ""
                        ])
                    }
                    if !isExpired {
                    // Check for holdout decision (aligned with Android: use holdoutIds, partition with server, cleanup obsolete)
                    let savedHoldoutIds = storedData.holdoutIds ?? storedData.holdoutId ?? storedData.holdoutGroupId ?? []
                    let savedNotInHoldoutIds = storedData.notInHoldoutIds ?? []

                    // Only consider holdouts applicable to this feature (feature-scoped evaluation)
                    let applicableHoldouts = HoldoutGroupService.getApplicableHoldouts(settings: settings, featureId: feature.id)
                    let applicableHoldoutIdsFromSettings = applicableHoldouts.compactMap { $0.id }

                    // Remove stale stored holdouts that no longer exist on server OR are no longer applicable to this feature.
                    let localHidAlsoValidOnServer = savedHoldoutIds.filter { applicableHoldoutIdsFromSettings.contains($0) }
                    let localButHidNotOnServerOrNotApplicable = savedHoldoutIds.filter { !applicableHoldoutIdsFromSettings.contains($0) }
                    if !localButHidNotOnServerOrNotApplicable.isEmpty {
                        storageService.updateDataInStorage(featureKey: featureKey, context: context, data: [
                            Constants.Holdouts.KEY_STORAGE_HOLDOUT_IDS: localHidAlsoValidOnServer
                        ])
                    }

                    // New holdout IDs on server that were not evaluated yet (absent from both holdoutIds and notInHoldoutIds).
                    let alreadyEvaluated = Set(localHidAlsoValidOnServer + savedNotInHoldoutIds)
                    let onServerButNotEvaluatedLocally = applicableHoldoutIdsFromSettings.filter { !alreadyEvaluated.contains($0) }

                    let isInHoldout = !localHidAlsoValidOnServer.isEmpty
                    if isInHoldout && !localHidAlsoValidOnServer.isEmpty {
                        serviceContainer.getLoggerService()?.log(level: .info, key: "STORED_HOLDOUT_DECISION_FOUND", details: [
                            Constants.USER_ID: context.id ?? "",
                            "featureKey": featureKey,
                            "holdoutId": "\(localHidAlsoValidOnServer)"
                        ])

                        var holdoutIdsForIntegration = localHidAlsoValidOnServer.sorted()
                        // Even on storage hit + early exit, evaluate any newly added applicable holdouts and send impressions.
                        if !onServerButNotEvaluatedLocally.isEmpty {
                            let holdoutGroupService = HoldoutGroupService(serviceContainer: serviceContainer, storageService: storageService)
                            let (_, newImpressions) = holdoutGroupService.getHoldoutsFor(settings: settings, feature: feature, context: context, storageService: storageService)
                            if !newImpressions.isEmpty {
                                for imp in newImpressions {
                                    ImpressionUtil.createAndSendImpressionForVariationShown(settings: settings, campaignId: imp.campaignId, variationId: imp.variationId, context: context, serviceContainer: serviceContainer)
                                }
                                let evaluatedIds = Set(newImpressions.map { $0.campaignId })
                                let inIds = Set(newImpressions.filter { $0.variationId == Constants.Holdouts.VARIATION_IS_PART_OF_HOLDOUT }.map { $0.campaignId })
                                let notInIds = evaluatedIds.subtracting(inIds)
                                let mergedHoldoutIds = Array(Set(localHidAlsoValidOnServer).union(inIds)).sorted()
                                let mergedNotInHoldoutIds = Array(Set(savedNotInHoldoutIds).union(notInIds)).sorted()
                                storageService.updateDataInStorage(featureKey: featureKey, context: context, data: [
                                    Constants.Holdouts.KEY_STORAGE_HOLDOUT_IDS: mergedHoldoutIds,
                                    Constants.Holdouts.KEY_STORAGE_NOT_IN_HOLDOUT_IDS: mergedNotInHoldoutIds
                                ])
                                holdoutIdsForIntegration = mergedHoldoutIds
                            }
                        }

                        decision["holdoutIDs"] = holdoutIdsForIntegration
                        decision["isPartOfHoldout"] = true
                        decision["isUserPartOfCampaign"] = false
                        decision["isEnabled"] = false
                        getFlag.setIsEnabled(isEnabled: false)
                        getFlag.setVariables([])
                        hookManager.set(properties: decision)
                        hookManager.execute(properties: hookManager.get())
                        if feature.isDebuggerEnabled {
                            debugEventProps["cg"] = DebuggerCategoryEnum.DECISION.rawValue
                            debugEventProps["lt"] = LogLevelEnum.info.rawValue
                            debugEventProps["msg_t"] = Constants.FLAG_DECISION_GIVEN
                            Self.updateDebugEventProps(&debugEventProps, decision: decision)
                            DebuggerServiceUtil.sendDebugEventToVWO(eventProps: debugEventProps, serviceContainer: serviceContainer)
                        }
                        dispatchGroup.leave()
                        return
                    }
                        
                    if let experimentVariationId = storedData.experimentVariationId {
                        if let experimentKey = storedData.experimentKey, !experimentKey.isEmpty {
                            let variation = CampaignUtil.getVariationFromCampaignKey(settings: settings, campaignKey: experimentKey, variationId: experimentVariationId)
                            // If variation is found in settings, return the variation
                            if let variation = variation {
                                
                                serviceContainer.getLoggerService()?.log(level: .info, key: "STORED_VARIATION_FOUND", details: [
                                    "variationKey": variation.name ?? "",
                                    "userId": context.id ?? "",
                                    "experimentType": "experiment",
                                    "experimentKey": experimentKey
                                ])
                                let (notInImpressions, updatedNotInHoldoutIds) = Self.buildNotInHoldoutForNewlyAddedHoldouts(
                                    newIds: onServerButNotEvaluatedLocally,
                                    storedNotInHoldoutIds: storedData.notInHoldoutIds
                                )
                                for imp in notInImpressions {
                                    ImpressionUtil.createAndSendImpressionForVariationShown(settings: settings, campaignId: imp.campaignId, variationId: imp.variationId, context: context, serviceContainer: serviceContainer)
                                }
                                if !updatedNotInHoldoutIds.isEmpty {
                                    storageService.updateDataInStorage(featureKey: featureKey, context: context, data: [
                                        Constants.Holdouts.KEY_STORAGE_NOT_IN_HOLDOUT_IDS: updatedNotInHoldoutIds
                                    ])
                                }
                                getFlag.setIsEnabled(isEnabled: true)
                                getFlag.setVariables(variation.variables)
                                decision["isEnabled"] = true
                                decision["isUserPartOfCampaign"] = true
                                hookManager.set(properties: decision)
                                hookManager.execute(properties: hookManager.get())
                                if feature.isDebuggerEnabled {
                                    debugEventProps["cg"] = DebuggerCategoryEnum.DECISION.rawValue
                                    debugEventProps["lt"] = LogLevelEnum.info.rawValue
                                    debugEventProps["msg_t"] = Constants.FLAG_DECISION_GIVEN
                                    Self.updateDebugEventProps(&debugEventProps, decision: decision)
                                    DebuggerServiceUtil.sendDebugEventToVWO(eventProps: debugEventProps, serviceContainer: serviceContainer)
                                }
                                dispatchGroup.leave()
                                return
                            }
                        }
                    } else if let rolloutKey = storedData.rolloutKey, !rolloutKey.isEmpty,
                              let rolloutId = storedData.rolloutId {
                        let variation = CampaignUtil.getVariationFromCampaignKey(settings: settings, campaignKey: rolloutKey, variationId: storedData.rolloutVariationId)
                        
                        // If variation is found in settings, prefer stored decision and avoid holdout re-evaluation.
                        if let variation = variation {
                            
                            serviceContainer.getLoggerService()?.log(level: .info, key: "STORED_VARIATION_FOUND", details: [
                                "variationKey": variation.name ?? "",
                                "userId": context.id ?? "",
                                "experimentType": "rollout",
                                "experimentKey": rolloutKey
                            ])
                            
                            serviceContainer.getLoggerService()?.log(level: .debug, key: "EXPERIMENTS_EVALUATION_WHEN_ROLLOUT_PASSED", details: [
                                "userId": context.id ?? ""
                            ])

                            if !onServerButNotEvaluatedLocally.isEmpty {
                                serviceContainer.getLoggerService()?.log(level: .debug, key: "HOLDOUT_SKIP_EVALUATION", details: [
                                    "holdoutName": "\(onServerButNotEvaluatedLocally)",
                                    "reason": "stored variation already exists"
                                ])
                                serviceContainer.getLoggerService()?.log(level: .debug, key: "SAVE_NOT_IN_HOLDOUT", details: [
                                    "userId": context.id ?? "",
                                    "holdoutIds": "\(onServerButNotEvaluatedLocally)"
                                ])
                            }
                            let (notInImpressions, updatedNotInHoldoutIds) = Self.buildNotInHoldoutForNewlyAddedHoldouts(
                                newIds: onServerButNotEvaluatedLocally,
                                storedNotInHoldoutIds: storedData.notInHoldoutIds
                            )
                            for imp in notInImpressions {
                                ImpressionUtil.createAndSendImpressionForVariationShown(settings: settings, campaignId: imp.campaignId, variationId: imp.variationId, context: context, serviceContainer: serviceContainer)
                            }
                            if !updatedNotInHoldoutIds.isEmpty {
                                storageService.updateDataInStorage(featureKey: featureKey, context: context, data: [
                                    Constants.Holdouts.KEY_STORAGE_NOT_IN_HOLDOUT_IDS: updatedNotInHoldoutIds
                                ])
                            }

                            getFlag.setIsEnabled(isEnabled: true)
                            getFlag.setVariables(variation.variables)
                            decision["isEnabled"] = true
                            decision["isUserPartOfCampaign"] = true
                            var featureInfo: [String: Any] = [:]
                            featureInfo["rolloutId"] = rolloutId
                            featureInfo["rolloutKey"] = rolloutKey
                            featureInfo["rolloutVariationId"] = storedData.rolloutVariationId
                            evaluatedFeatureMap[featureKey] = featureInfo
                            
                            passedRulesInformation.merge(featureInfo) { (_, new) in new }
                            decision.merge(featureInfo) { (_, new) in new }
                            hookManager.set(properties: decision)
                            hookManager.execute(properties: hookManager.get())
                            if feature.isDebuggerEnabled {
                                debugEventProps["cg"] = DebuggerCategoryEnum.DECISION.rawValue
                                debugEventProps["lt"] = LogLevelEnum.info.rawValue
                                debugEventProps["msg_t"] = Constants.FLAG_DECISION_GIVEN
                                Self.updateDebugEventProps(&debugEventProps, decision: decision)
                                DebuggerServiceUtil.sendDebugEventToVWO(eventProps: debugEventProps, serviceContainer: serviceContainer)
                            }
                            dispatchGroup.leave()
                            return
                        }
                    }
                    }
                }
            } catch {
                serviceContainer.getLoggerService()?.log(level: .debug, message: "Error parsing stored data: \(error.localizedDescription)")
            }
            
            // Use segmentation manager from service container
            serviceContainer.getSegmentationManager().setContextualData(settings: settings, feature: feature, context: context, serviceContainer: serviceContainer)

            /**
             * Check if user is in a holdout group for this feature.
             * If user is in holdout, exclude them from the feature and return.
             */
            let holdoutGroupService = HoldoutGroupService(serviceContainer: serviceContainer, storageService: storageService)
            let (holdoutGroups, holdoutImpressions) = holdoutGroupService.getHoldoutsFor(settings: settings, feature: feature, context: context, storageService: storageService)

            // Send holdout impressions (both "in holdout" and "not in holdout" for reporting)
            for imp in holdoutImpressions {
                ImpressionUtil.createAndSendImpressionForVariationShown(settings: settings, campaignId: imp.campaignId, variationId: imp.variationId, context: context, serviceContainer: serviceContainer)
            }

            decision["holdoutIDs"] = [Int]()
            decision["isPartOfHoldout"] = false

            if !holdoutGroups.isEmpty {
                let qualifiedHoldoutNames = holdoutGroups.map { $0.name ?? "" }.joined(separator: ",")
                let qualifiedHoldoutIds = holdoutGroups.compactMap { $0.id }
                decision["holdoutIDs"] = qualifiedHoldoutIds
                decision["isPartOfHoldout"] = true

                serviceContainer.getLoggerService()?.log(level: .info, key: "USER_IN_HOLDOUT_GROUP", details: [
                    Constants.USER_ID: context.id ?? "",
                    "featureId": "\(feature.id ?? 0)",
                    "featureKey": featureKey,
                    "holdoutGroupName": qualifiedHoldoutNames
                ])

                var holdoutStorageMap: [String: Any] = [:]
                holdoutStorageMap["featureKey"] = feature.key
                holdoutStorageMap["userId"] = context.id
                holdoutStorageMap[Constants.Holdouts.KEY_STORAGE_HOLDOUT_IDS] = holdoutGroups.compactMap { $0.id }
                let notInHoldoutIds = (settings.holdoutGroups?
                    .filter { h in !holdoutGroups.contains(where: { $0.id == h.id }) }
                    .filter { h in h.isGlobal == true || (feature.id != nil && (h.featureIds?.contains(feature.id!) == true)) }
                    .compactMap { $0.id }) ?? []
                holdoutStorageMap[Constants.Holdouts.KEY_STORAGE_NOT_IN_HOLDOUT_IDS] = notInHoldoutIds
                holdoutStorageMap["holdout"] = true
                storageService.setDataInStorage(data: holdoutStorageMap)

                getFlag.setIsEnabled(isEnabled: false)
                getFlag.setVariables([])
                decision["isEnabled"] = false
                hookManager.set(properties: decision)
                hookManager.execute(properties: hookManager.get())
                dispatchGroup.leave()
                return
            }
            
            serviceContainer.getLoggerService()?.log(level: .info, key: "USER_NOT_EXCLUDED_DUE_TO_HOLDOUT", details: [
                "userId": context.id ?? "",
                "featureKey": featureKey
            ])

            /**
             * get all the rollout rules for the feature and evaluate them
             * if any of the rollout rule passes, break the loop and evaluate the traffic
             */
            let rollOutRules = FunctionUtil.getSpecificRulesBasedOnType(feature: feature, type: .rollout)
            if !rollOutRules.isEmpty && !getFlag.isEnabled() {
                var rolloutRulesToEvaluate: [Campaign] = []
                for rule in rollOutRules {
                    
                    var megGroupWinnerCampaigns: [Int : String]? = [:]
                    
                    let evaluateRuleResult = RuleEvaluationUtil.evaluateRule(settings: settings, feature: feature, campaign: rule, context: context, evaluatedFeatureMap: &evaluatedFeatureMap, megGroupWinnerCampaigns: &megGroupWinnerCampaigns, storageService: storageService, serviceContainer: serviceContainer, decision: &decision)
                    
                    
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
                    let variation = DecisionUtil.evaluateTrafficAndGetVariation(settings: settings, campaign: passedRolloutCampaign, userId: context.id, serviceContainer: serviceContainer)
                    if let variation = variation {
                        getFlag.setIsEnabled(isEnabled: true)
                        getFlag.setVariables(variation.variables)
                        shouldCheckForExperimentsRules = true
                        decision["isUserPartOfCampaign"] = true
                        GetFlagAPI.updateIntegrationsDecisionObject(campaign: passedRolloutCampaign, variation: variation, passedRulesInformation: &passedRulesInformation, decision: &decision)
                        
                        ImpressionUtil.createAndSendImpressionForVariationShown(settings: settings, campaignId: passedRolloutCampaign.id ?? 0, variationId: variation.id ?? 0, context: context, serviceContainer: serviceContainer)
                    }
                }
            } else {
                if rollOutRules.isEmpty{
                     serviceContainer.getLoggerService()?.log(level: .debug, key: "EXPERIMENTS_EVALUATION_WHEN_NO_ROLLOUT_PRESENT", details: nil)
                  }
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
                    let evaluateRuleResult = RuleEvaluationUtil.evaluateRule(settings: settings, feature: feature, campaign: rule, context: context, evaluatedFeatureMap: &evaluatedFeatureMap, megGroupWinnerCampaigns: &megGroupWinnerCampaigns, storageService: storageService, serviceContainer: serviceContainer, decision: &decision)
                    
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
                            decision["isUserPartOfCampaign"] = true
                        }
                        break
                    }
                }
                
                // Evaluate the passed experiment rule traffic and get the variation
                if !experimentRulesToEvaluate.isEmpty {
                    let campaign = experimentRulesToEvaluate[0]
                    let variation = DecisionUtil.evaluateTrafficAndGetVariation(settings: settings, campaign: campaign, userId: context.id, serviceContainer: serviceContainer)
                    if let variation = variation {
                        getFlag.setIsEnabled(isEnabled: true)
                        getFlag.setVariables(variation.variables)
                        decision["isUserPartOfCampaign"] = true
                        GetFlagAPI.updateIntegrationsDecisionObject(campaign: campaign, variation: variation, passedRulesInformation: &passedRulesInformation, decision: &decision)
                        
                        ImpressionUtil.createAndSendImpressionForVariationShown(settings: settings, campaignId: campaign.id ?? 0, variationId: variation.id ?? 0, context: context, serviceContainer: serviceContainer)
                    }
                }
            }
            
            var storageMap: [String: Any] = [:]
            
            storageMap["featureKey"] = feature.key
            storageMap["userId"] = context.id
            storageMap.merge(passedRulesInformation) { (_, new) in new }
            // Store "not in holdout" IDs for reporting (even when flag is disabled).
            // Persist only the holdouts that were evaluated as "NOT in holdout" for this feature.
            // This is derived from evaluation impressions and stays correct even if applicable holdouts change.
            let notInHoldoutIds = Array(
                Set(
                    holdoutImpressions
                        .filter { $0.variationId == Constants.Holdouts.VARIATION_NOT_PART_OF_HOLDOUT }
                        .map { $0.campaignId }
                )
            ).sorted()
            storageMap[Constants.Holdouts.KEY_STORAGE_NOT_IN_HOLDOUT_IDS] = notInHoldoutIds
            
            let cachedDecisionExpiryTime = serviceContainer.getVWOInitOptions().cachedDecisionExpiryTime
            if cachedDecisionExpiryTime > 0 {
                let newExpiry = Date().currentTimeMillis() + cachedDecisionExpiryTime
                storageMap["decisionExpiryTime"] = newExpiry
            }
            storageService.setDataInStorage(data: storageMap)

            // Execute the integrations
            decision.merge(passedRulesInformation) { _, new in new }
            decision["isEnabled"] = getFlag.isEnabled()
            decision["isUserPartOfCampaign"] = getFlag.isEnabled()
            hookManager.set(properties: decision)
            hookManager.execute(properties: hookManager.get())
            
            // Send debug event if debugger is enabled
            if feature.isDebuggerEnabled {
                debugEventProps["cg"] = DebuggerCategoryEnum.DECISION.rawValue
                debugEventProps["lt"] = LogLevelEnum.info.rawValue
                debugEventProps["msg_t"] = Constants.FLAG_DECISION_GIVEN
                // Update debug event props with decision keys
                updateDebugEventProps(&debugEventProps, decision: decision)
                DebuggerServiceUtil.sendDebugEventToVWO(eventProps: debugEventProps, serviceContainer: serviceContainer)
            }

            /**
             * If the feature has an impact campaign, send an impression for the variation shown
             * If flag enabled - variation 2, else - variation 1
             */
            if let impactCampaignId = feature.impactCampaign?.campaignId {
                serviceContainer.getLoggerService()?.log(level: .info, key: "IMPACT_ANALYSIS", details: [
                    "userId": context.id ?? "",
                    "featureKey": featureKey,
                    "status": getFlag.isEnabled() ? "enabled" : "disabled"
                ])
                ImpressionUtil.createAndSendImpressionForVariationShown(settings: settings, campaignId: impactCampaignId, variationId: getFlag.isEnabled() ? 2 : 1, context: context, serviceContainer: serviceContainer)
            }
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        completion(getFlag)
    }

    /// Integration defaults: whether the feature uses any holdout, and cleared participation until evaluated.
    private static func applyIntegrationDecisionDefaults(feature: Feature, settings: Settings, decision: inout [String: Any]) {
        decision["isUserPartOfCampaign"] = false
        decision["isPartOfHoldout"] = false
        decision["holdoutIDs"] = [Int]()
        decision["isHoldoutPresent"] = !HoldoutGroupService
            .getApplicableHoldouts(settings: settings, featureId: feature.id)
            .isEmpty
    }

    /// Update debug event props with decision keys
    /// - Parameters:
    ///   - debugEventProps: The debug event properties (modified in-place)
    ///   - decision: The decision dictionary
    private static func updateDebugEventProps(_ debugEventProps: inout [String: Any], decision: [String: Any]) {

        let decisionKeys = DebuggerServiceUtil.extractDecisionKeys(decisionObj: decision)
        
        guard let featureKey = decision["featureKey"] as? String else {
            debugEventProps["msg"] = "Invalid decision: Missing featureKey"
            return
        }

        var message = "Flag decision given for feature:\(featureKey)."
        
        if let rolloutKey = decision["rolloutKey"] as? String,
           let rolloutVariationId = decision["rolloutVariationId"] {
            let trimmedRolloutKey = rolloutKey.replacingOccurrences(of: "\(featureKey)_", with: "")
            message += " Got rollout:\(trimmedRolloutKey) with variation:\(rolloutVariationId)"
        }

        if let experimentKey = decision["experimentKey"] as? String,
           let experimentVariationId = decision["experimentVariationId"] {
            let trimmedExperimentKey = experimentKey.replacingOccurrences(of: "\(featureKey)_", with: "")
            message += " and experiment:\(trimmedExperimentKey) with variation:\(experimentVariationId)"
        }

        debugEventProps["msg"] = message

        for (key, value) in decisionKeys {
            debugEventProps[key] = value
        }
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

    /// Builds impressions and updated "not in holdout" IDs when the server adds new holdouts.
    ///
    /// - Parameters:
    ///   - newIds: Newly added holdout IDs from server for which we must generate "not in holdout" impressions.
    ///   - storedNotInHoldoutIds: Previously stored "not in holdout" IDs (may be nil if nothing was stored yet).
    /// - Returns: Tuple containing:
    ///   - impressions: The generated `HoldoutImpression` list for the provided `newIds`.
    ///   - updatedNotInHoldoutIds: The merged and de-duplicated sorted list of "not in holdout" IDs to persist.
    private static func buildNotInHoldoutForNewlyAddedHoldouts(
        newIds: [Int],
        storedNotInHoldoutIds: [Int]?
    ) -> (impressions: [HoldoutImpression], updatedNotInHoldoutIds: [Int]) {
        if newIds.isEmpty { return ([], storedNotInHoldoutIds ?? []) }
        let impressions = newIds.map { hid in
            HoldoutImpression(campaignId: hid, variationId: Constants.Holdouts.VARIATION_NOT_PART_OF_HOLDOUT, featureId: Constants.IMPRESSION_NO_FEATURE_ID)
        }
        let existingIds = storedNotInHoldoutIds ?? []
        let updatedIds = Array(Set(existingIds + newIds)).sorted()
        return (impressions, updatedIds)
    }
}
