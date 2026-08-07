/**
 * Copyright 2024-2026 Wingify Software Pvt. Ltd.
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

/// Represents a single holdout impression to be sent.
struct HoldoutImpression {
    let campaignId: Int
    let variationId: Int
    let featureId: Int
}

/// Result of evaluating applicable holdouts for a feature.
struct HoldoutMatchResult {
    let matchedHoldoutGroups: [HoldoutGroup]
    let notMatchedHoldoutGroups: [HoldoutGroup]
    let impressions: [HoldoutImpression]
    let alreadyEvaluatedHoldoutIds: [Int]
}

/// Tracks holdout IDs already evaluated for the current request (and merged from storage).
class HoldoutEvaluationState {
    private var outcomeById: [Int: Bool] = [:]

    init() {}

    static func fromStorage(_ stored: Storage?) -> HoldoutEvaluationState {
        let state = HoldoutEvaluationState()
        state.mergeFromStorage(stored)
        return state
    }

    static func fromStorageMap(_ storedDataMap: [String: Any]?) -> HoldoutEvaluationState {
        guard let storedDataMap = storedDataMap else { return HoldoutEvaluationState() }
        do {
            let normalizedStorageMap = FunctionUtil.normalizeStorageMapForDecoding(storedDataMap)
            let storageMapAsString = try JSONSerialization.data(withJSONObject: normalizedStorageMap, options: [])
            let stored = try JSONDecoder().decode(Storage.self, from: storageMapAsString)
            return fromStorage(stored)
        } catch {
            return HoldoutEvaluationState()
        }
    }

    /// Adds outcomes from `stored` without overwriting keys already present (caller / earlier eval wins).
    func mergeFromStorage(_ stored: Storage?) {
        guard let stored = stored else { return }
        let inIds = stored.holdoutIds ?? stored.holdoutId ?? stored.holdoutGroupId ?? []
        for id in inIds where !outcomeById.keys.contains(id) {
            outcomeById[id] = true
        }
        let notInIds = stored.notInHoldoutIds ?? []
        for id in notInIds where !outcomeById.keys.contains(id) {
            outcomeById[id] = false
        }
    }

    func recordIn(_ holdoutId: Int) {
        outcomeById[holdoutId] = true
    }

    func recordNotIn(_ holdoutId: Int) {
        outcomeById[holdoutId] = false
    }

    func isEvaluated(_ holdoutId: Int) -> Bool {
        outcomeById.keys.contains(holdoutId)
    }

    func isInHoldout(_ holdoutId: Int) -> Bool {
        outcomeById[holdoutId] == true
    }

    func isNotInHoldout(_ holdoutId: Int) -> Bool {
        outcomeById[holdoutId] == false
    }

    func getAlreadyEvaluatedHoldoutIds() -> [Int] {
        Array(outcomeById.keys)
    }
}

/// Service for evaluating holdout group targeting and bucketing logic.
///
/// Handles the core business logic for determining if a user should be
/// excluded from features due to holdout group membership. Evaluates segmentation
/// rules and traffic percentage bucketing to determine holdout status.
class HoldoutGroupService {
    /// Aligned with Android Constants.Holdouts.VARIATION_IS_PART_OF_HOLDOUT / VARIATION_NOT_PART_OF_HOLDOUT
    private static let variationIsPartOfHoldout = Constants.Holdouts.VARIATION_IS_PART_OF_HOLDOUT
    private static let variationNotPartOfHoldout = Constants.Holdouts.VARIATION_NOT_PART_OF_HOLDOUT

    private let serviceContainer: ServiceContainer?
    private let storageService: StorageService

    /// Creates a `HoldoutGroupService`.
    ///
    /// - Parameters:
    ///   - serviceContainer: Optional service container used to access logger and segmentation manager.
    ///   - storageService: Storage service used to read holdout-related decision data.
    /// - Returns: A configured `HoldoutGroupService` instance.
    init(serviceContainer: ServiceContainer?, storageService: StorageService) {
        self.serviceContainer = serviceContainer
        self.storageService = storageService
    }

    /// Gets the applicable holdout groups for a given feature ID (same as Android `doesHoldoutApplyToFeature` filter).
    ///
    /// - Parameters:
    ///   - settings: Settings containing configured holdout groups.
    ///   - featureId: Feature id to match against holdout group targeting rules.
    /// - Returns: Array of `HoldoutGroup` that apply to the provided feature.
    static func getApplicableHoldouts(settings: Settings, featureId: Int?) -> [HoldoutGroup] {
        let holdouts = settings.holdoutGroups ?? []
        return holdouts.filter { doesHoldoutApplyToFeature($0, featureId: featureId) }
    }

    /// Determines if a holdout group applies to the given feature (aligned with Android `doesHoldoutApplyToFeature`).
    ///
    /// - Parameters:
    ///   - holdoutGroup: Holdout group definition.
    ///   - featureId: Optional feature id used to check `holdoutGroup.featureIds`.
    /// - Returns: `true` if the holdout group applies to the feature, otherwise `false`.
    private static func doesHoldoutApplyToFeature(_ holdoutGroup: HoldoutGroup, featureId: Int?) -> Bool {
        if holdoutGroup.isGlobal == true { return true }
        guard let featureId = featureId else { return false }
        return (holdoutGroup.featureIds?.contains(featureId) ?? false)
    }

    /// Evaluates all applicable holdouts for a feature, reusing per-request and stored outcomes.
    func getMatchedHoldouts(
        settings: Settings,
        feature: Feature,
        context: WingifyUserContext,
        storedData: Storage?,
        holdoutEvalState: HoldoutEvaluationState?
    ) -> HoldoutMatchResult {
        var evalState = holdoutEvalState ?? HoldoutEvaluationState()
        evalState.mergeFromStorage(storedData)

        let applicableHoldouts = Self.getApplicableHoldouts(settings: settings, featureId: feature.id)
        if applicableHoldouts.isEmpty {
            return HoldoutMatchResult(
                matchedHoldoutGroups: [],
                notMatchedHoldoutGroups: [],
                impressions: [],
                alreadyEvaluatedHoldoutIds: evalState.getAlreadyEvaluatedHoldoutIds()
            )
        }

        if feature.id == nil {
            serviceContainer?.getLoggerService()?.log(level: .error, key: "HOLDOUT_FEATURE_ID_NULL", details: nil)
        }

        var matchedHoldoutGroups: [HoldoutGroup] = []
        var notMatchedHoldoutGroups: [HoldoutGroup] = []
        var impressions: [HoldoutImpression] = []

        for holdoutGroup in applicableHoldouts {
            guard let holdoutId = holdoutGroup.id else { continue }

            if evalState.isEvaluated(holdoutId) {
                serviceContainer?.getLoggerService()?.log(
                    level: .debug,
                    key: "HOLDOUT_SKIP_EVALUATION",
                    details: [
                        "holdoutName": holdoutGroup.name ?? "",
                        "reason": "user \(context.id ?? "") was already evaluated for feature with id: \(feature.id ?? 0); SKIP decision making altogether."
                    ]
                )
                if evalState.isInHoldout(holdoutId) {
                    matchedHoldoutGroups.append(holdoutGroup)
                } else {
                    notMatchedHoldoutGroups.append(holdoutGroup)
                }
                continue
            }

            let passesSegmentation = evaluateHoldoutSegmentation(holdoutGroup: holdoutGroup, context: context)
            if !passesSegmentation {
                serviceContainer?.getLoggerService()?.log(
                    level: .info,
                    key: "SEGMENTATION_FAILED_HOLDOUT",
                    details: ["userId": context.id ?? "", "holdoutId": "\(holdoutId)"]
                )
                serviceContainer?.getLoggerService()?.log(
                    level: .debug,
                    key: "HOLDOUT_SEGMENTATION_FAIL",
                    details: ["userId": context.id ?? "", "holdoutGroupName": holdoutGroup.name ?? ""]
                )
                notMatchedHoldoutGroups.append(holdoutGroup)
                evalState.recordNotIn(holdoutId)
                impressions.append(HoldoutImpression(
                    campaignId: holdoutId,
                    variationId: Self.variationNotPartOfHoldout,
                    featureId: feature.id ?? Constants.IMPRESSION_NO_FEATURE_ID
                ))
                continue
            }

            serviceContainer?.getLoggerService()?.log(
                level: .info,
                key: "SEGMENTATION_PASSED_HOLDOUT",
                details: ["userId": context.id ?? "", "holdoutId": "\(holdoutId)"]
            )

            let shouldExcludeUser = shouldExcludeUserFromFeature(
                holdoutGroup: holdoutGroup,
                userId: context.id,
                accountId: settings.accountId,
                featureId: feature.id
            )

            if shouldExcludeUser {
                serviceContainer?.getLoggerService()?.log(
                    level: .info,
                    key: "USER_EXCLUDED_DUE_TO_HOLDOUT",
                    details: [
                        "userId": context.id ?? "",
                        "holdoutGroupName": holdoutGroup.name ?? "",
                        "featureKey": feature.key ?? ""
                    ]
                )
                serviceContainer?.getLoggerService()?.log(
                    level: .info,
                    key: "USER_IN_HOLDOUT_GROUP",
                    details: [
                        "userId": context.id ?? "",
                        "featureId": "\(feature.id ?? 0)",
                        "holdoutGroupName": holdoutGroup.name ?? "",
                        "featureKey": feature.key ?? ""
                    ]
                )
                matchedHoldoutGroups.append(holdoutGroup)
                evalState.recordIn(holdoutId)
                impressions.append(HoldoutImpression(
                    campaignId: holdoutId,
                    variationId: Self.variationIsPartOfHoldout,
                    featureId: feature.id ?? Constants.IMPRESSION_NO_FEATURE_ID
                ))
            } else {
                notMatchedHoldoutGroups.append(holdoutGroup)
                evalState.recordNotIn(holdoutId)
                impressions.append(HoldoutImpression(
                    campaignId: holdoutId,
                    variationId: Self.variationNotPartOfHoldout,
                    featureId: feature.id ?? Constants.IMPRESSION_NO_FEATURE_ID
                ))
            }
        }

        return HoldoutMatchResult(
            matchedHoldoutGroups: matchedHoldoutGroups,
            notMatchedHoldoutGroups: notMatchedHoldoutGroups,
            impressions: impressions,
            alreadyEvaluatedHoldoutIds: evalState.getAlreadyEvaluatedHoldoutIds()
        )
    }

    /// Checks if a user should be excluded from a specific feature due to holdout group membership.
    ///
    /// - Parameters:
    ///   - settings: The settings containing holdout groups configuration.
    ///   - feature: The feature being evaluated.
    ///   - context: The user context containing user information.
    ///   - storageService: Storage service to read feature storage (holdoutIds, notInHoldoutIds).
    /// - Returns: Tuple containing qualified holdout groups and impressions to emit.
    func getHoldoutsFor(
        settings: Settings,
        feature: Feature,
        context: WingifyUserContext,
        storageService: StorageService
    ) -> (holdoutGroups: [HoldoutGroup], impressions: [HoldoutImpression]) {
        let storedDataMap = storageService.getFeatureFromStorage(featureKey: feature.key ?? "", context: context)
        let storedData = Self.decodeStorage(from: storedDataMap)
        let result = getMatchedHoldouts(
            settings: settings,
            feature: feature,
            context: context,
            storedData: storedData,
            holdoutEvalState: nil
        )
        return (result.matchedHoldoutGroups, result.impressions)
    }

    /// Sends impressions and updates storage for newly added holdouts not yet tracked locally.
    static func sendNetworkCallsForNotInHoldouts(
        settings: Settings,
        feature: Feature,
        context: WingifyUserContext,
        storedData: Storage?,
        storageService: StorageService,
        serviceContainer: ServiceContainer
    ) -> [Int] {
        let applicableHoldouts = getApplicableHoldouts(settings: settings, featureId: feature.id)
        var updatedNotInHoldoutIds = storedData?.notInHoldoutIds ?? []
        let isInHoldoutIds = storedData?.holdoutIds ?? storedData?.holdoutId ?? storedData?.holdoutGroupId ?? []
        let originalSize = updatedNotInHoldoutIds.count

        for holdout in applicableHoldouts {
            guard let holdoutId = holdout.id else { continue }
            if !updatedNotInHoldoutIds.contains(holdoutId) && !isInHoldoutIds.contains(holdoutId) {
                updatedNotInHoldoutIds.append(holdoutId)
                ImpressionUtil.createAndSendImpressionForVariationShown(
                    settings: settings,
                    campaignId: holdoutId,
                    variationId: Constants.Holdouts.VARIATION_NOT_PART_OF_HOLDOUT,
                    context: context,
                    serviceContainer: serviceContainer
                )
            }
        }

        if updatedNotInHoldoutIds.count > originalSize {
            var mergedStoredData: [String: Any] = storageService.getFeatureFromStorage(
                featureKey: feature.key ?? "",
                context: context
            ) ?? [:]
            mergedStoredData["featureKey"] = feature.key
            mergedStoredData["userId"] = context.id
            mergedStoredData[Constants.Holdouts.KEY_STORAGE_NOT_IN_HOLDOUT_IDS] = updatedNotInHoldoutIds
            storageService.setDataInStorage(data: mergedStoredData)
        }

        return updatedNotInHoldoutIds
    }

    private static func decodeStorage(from storedDataMap: [String: Any]?) -> Storage? {
        guard let storedDataMap = storedDataMap else { return nil }
        do {
            let normalizedStorageMap = FunctionUtil.normalizeStorageMapForDecoding(storedDataMap)
            let storageMapAsString = try JSONSerialization.data(withJSONObject: normalizedStorageMap, options: [])
            return try JSONDecoder().decode(Storage.self, from: storageMapAsString)
        } catch {
            return nil
        }
    }

    /// Evaluates segmentation rules for a given holdout group.
    private func evaluateHoldoutSegmentation(holdoutGroup: HoldoutGroup, context: WingifyUserContext) -> Bool {
        guard let segments = holdoutGroup.segments, !segments.isEmpty else {
            serviceContainer?.getLoggerService()?.log(
                level: .info,
                key: "HOLDOUT_SEGMENTATION_SKIP",
                details: ["holdoutGroupName": holdoutGroup.name ?? ""]
            )
            return true
        }
        return (serviceContainer?.getSegmentationManager())?.validateSegmentation(dsl: segments, properties: context.customVariables) ?? false
    }

    /// Determines whether the user should be excluded from a feature based on holdout bucketing.
    private func shouldExcludeUserFromFeature(holdoutGroup: HoldoutGroup, userId: String?, accountId: Int?, featureId: Int?) -> Bool {
        guard let userId = userId, let holdoutId = holdoutGroup.id, let trafficPercent = holdoutGroup.trafficPercent, let accountId = accountId else {
            return false
        }
        let bucketKey = "\(accountId)_\(holdoutId)_\(userId)"
        let bucketValue = DecisionMaker.getBucketValueForUser(userId: bucketKey)
        let isInHoldout = bucketValue != 0 && bucketValue <= trafficPercent

        if isInHoldout {
            serviceContainer?.getLoggerService()?.log(
                level: .info,
                key: "HOLDOUT_SHOULD_EXCLUDE_USER",
                details: [
                    "userId": userId,
                    "bucketValue": "\(bucketValue)",
                    "holdoutGroupName": holdoutGroup.name ?? "",
                    "featureId": "\(featureId ?? 0)",
                    "percentTraffic": "\(trafficPercent)",
                    "isInHoldout": "\(isInHoldout)"
                ]
            )
        } else {
            serviceContainer?.getLoggerService()?.log(
                level: .debug,
                key: "HOLDOUT_SHOULD_NOT_EXCLUDE_USER",
                details: ["userId": userId, "holdoutGroupName": holdoutGroup.name ?? ""]
            )
        }
        return isInHoldout
    }
}
