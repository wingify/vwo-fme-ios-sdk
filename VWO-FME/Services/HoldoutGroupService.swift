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

/// Represents a single holdout impression to be sent.
struct HoldoutImpression {
    let campaignId: Int
    let variationId: Int
    let featureId: Int
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

    /// Checks if a user should be excluded from a specific feature due to holdout group membership.
    /// Aligned with Android: takes feature + storageService, reads storage via storageService, iterates all settings.holdoutGroups.
    ///
    /// - Parameters:
    ///   - settings: The settings containing holdout groups configuration.
    ///   - feature: The feature being evaluated.
    ///   - context: The user context containing user information.
    ///   - storageService: Storage service to read feature storage (holdoutIds, notInHoldoutIds).
    /// - Returns: Tuple containing:
    ///   - holdoutGroups: Qualified holdout groups for which the user should be excluded.
    ///   - impressions: Holdout impressions to emit (including featureId and variationId).
    func getHoldoutsFor(settings: Settings, feature: Feature, context: VWOUserContext, storageService: StorageService) -> (holdoutGroups: [HoldoutGroup], impressions: [HoldoutImpression]) {
        let storedData = storageService.getFeatureFromStorage(featureKey: feature.key ?? "", context: context)
        let alreadyEvaluatedHoldoutIds: [String] = Self.getAlreadyEvaluatedHoldoutIds(from: storedData)
        let holdoutGroups = settings.holdoutGroups ?? []

        if holdoutGroups.isEmpty {
            return ([], [])
        }

        if feature.id == nil {
            serviceContainer?.getLoggerService()?.log(level: .error, key: "HOLDOUT_FEATURE_ID_NULL", details: nil)
        }

        var qualifiedHoldoutGroups: [HoldoutGroup] = []
        var impressions: [HoldoutImpression] = []

        for holdoutGroup in holdoutGroups {
            if !Self.doesHoldoutApplyToFeature(holdoutGroup, featureId: feature.id) {
                continue
            }
            if alreadyEvaluatedHoldoutIds.contains("\(holdoutGroup.id ?? 0)") {
                serviceContainer?.getLoggerService()?.log(
                    level: .debug,
                    key: "HOLDOUT_SKIP_EVALUATION",
                    details: [
                        "holdoutName": holdoutGroup.name ?? "",
                        "reason": "user \(context.id ?? "") was already evaluated for feature with id: \(feature.id ?? 0); skip decision making altogether."
                    ]
                )
                continue
            }

            let passesSegmentation = evaluateHoldoutSegmentation(holdoutGroup: holdoutGroup, context: context)
            if !passesSegmentation {
                serviceContainer?.getLoggerService()?.log(
                    level: .info,
                    key: "SEGMENTATION_FAILED_HOLDOUT",
                    details: ["userId": context.id ?? "", "holdoutId": "\(holdoutGroup.id ?? 0)"]
                )
                serviceContainer?.getLoggerService()?.log(
                    level: .debug,
                    key: "HOLDOUT_SEGMENTATION_FAIL",
                    details: ["userId": context.id ?? "", "holdoutGroupName": holdoutGroup.name ?? ""]
                )
                if let holdoutId = holdoutGroup.id {
                    impressions.append(HoldoutImpression(
                        campaignId: holdoutId,
                        variationId: Self.variationNotPartOfHoldout,
                        featureId: feature.id ?? Constants.IMPRESSION_NO_FEATURE_ID
                    ))
                }
                continue
            }
            serviceContainer?.getLoggerService()?.log(
                level: .info,
                key: "SEGMENTATION_PASSED_HOLDOUT",
                details: ["userId": context.id ?? "", "holdoutId": "\(holdoutGroup.id ?? 0)"]
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
                qualifiedHoldoutGroups.append(holdoutGroup)
                if let holdoutId = holdoutGroup.id {
                    impressions.append(HoldoutImpression(
                        campaignId: holdoutId,
                        variationId: Self.variationIsPartOfHoldout,
                        featureId: feature.id ?? Constants.IMPRESSION_NO_FEATURE_ID
                    ))
                }
            } else {
                if let holdoutId = holdoutGroup.id {
                    impressions.append(HoldoutImpression(
                        campaignId: holdoutId,
                        variationId: Self.variationNotPartOfHoldout,
                        featureId: feature.id ?? Constants.IMPRESSION_NO_FEATURE_ID
                    ))
                }
            }
        }

        return (qualifiedHoldoutGroups, impressions)
    }

    /// Builds already-evaluated holdout IDs from feature storage (holdoutIds + notInHoldoutIds).
    ///
    /// - Parameters:
    ///   - storedData: Feature storage data that can contain previously evaluated holdout IDs.
    /// - Returns: Array of holdout IDs represented as `String`.
    private static func getAlreadyEvaluatedHoldoutIds(from storedData: [String: Any]?) -> [String] {
        guard let stored = storedData else { return [] }
        let inIds = Self.intsFromStorage(stored[Constants.Holdouts.KEY_STORAGE_HOLDOUT_IDS])
        let notInIds = Self.intsFromStorage(stored[Constants.Holdouts.KEY_STORAGE_NOT_IN_HOLDOUT_IDS])
        return (inIds + notInIds).map { "\($0)" }
    }

    /// Converts a stored value into an array of integers.
    ///
    /// - Parameters:
    ///   - value: Storage value that may be `[Int]`, `[NSNumber]`, or `[Double]`.
    /// - Returns: Array of integers extracted from the provided value.
    private static func intsFromStorage(_ value: Any?) -> [Int] {
        guard let value = value else { return [] }
        if let arr = value as? [Int] { return arr }
        if let arr = value as? [NSNumber] { return arr.map { $0.intValue } }
        if let arr = value as? [Double] { return arr.map { Int($0) } }
        return []
    }

    /// Evaluates segmentation rules for a given holdout group.
    ///
    /// - Parameters:
    ///   - holdoutGroup: Holdout group containing segmentation DSL.
    ///   - context: User context with custom variables used as segmentation properties.
    /// - Returns: `true` if the user passes segmentation rules (or there are no segments), otherwise `false`.
    private func evaluateHoldoutSegmentation(holdoutGroup: HoldoutGroup, context: VWOUserContext) -> Bool {
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
    ///
    /// - Parameters:
    ///   - holdoutGroup: Holdout group definition (contains `id` and `trafficPercent`).
    ///   - userId: User id used to compute the bucket value.
    ///   - accountId: Account id used to namespace the bucket.
    ///   - featureId: Feature id used only for logging.
    /// - Returns: `true` if the user falls within the holdout traffic allocation; otherwise `false`.
    private func shouldExcludeUserFromFeature(holdoutGroup: HoldoutGroup, userId: String?, accountId: Int?, featureId: Int?) -> Bool {
        guard let userId = userId, let holdoutId = holdoutGroup.id, let trafficPercent = holdoutGroup.trafficPercent, let accountId = accountId else {
            return false
        }
        let bucketKey = "\(accountId)_\(holdoutId)_\(userId)"
        let bucketValue = DecisionMaker.getBucketValueForUser(userId: bucketKey)
        let trafficAllocation = trafficPercent
        let isInHoldout = bucketValue != 0 && bucketValue <= trafficAllocation

        if isInHoldout {
            serviceContainer?.getLoggerService()?.log(
                level: .info,
                key: "HOLDOUT_SHOULD_EXCLUDE_USER",
                details: [
                    "userId": userId,
                    "bucketValue": "\(bucketValue)",
                    "holdoutGroupName": holdoutGroup.name ?? "",
                    "featureId": "\(featureId ?? 0)",
                    "percentTraffic": "\(trafficAllocation)",
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
