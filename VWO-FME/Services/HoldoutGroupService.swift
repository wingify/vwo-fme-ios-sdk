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
    private static let variationIsPartOfHoldout = 1
    private static let variationNotPartOfHoldout = 2

    private let serviceContainer: ServiceContainer?
    private let storageService: StorageService

    init(serviceContainer: ServiceContainer?, storageService: StorageService) {
        self.serviceContainer = serviceContainer
        self.storageService = storageService
    }

    /// Checks if a user should be excluded from a specific feature due to holdout group membership.
    ///
    /// - Parameters:
    ///   - settings: The settings containing holdout groups configuration.
    ///   - featureId: The ID of the feature being evaluated.
    ///   - context: The user context containing user information.
    /// - Returns: Tuple of (qualified holdout groups, impressions to send).
    func getHoldoutsFor(settings: Settings, featureId: Int?, context: VWOUserContext) -> (holdoutGroups: [HoldoutGroup], impressions: [HoldoutImpression]) {
        let notInHoldoutKey = Constants.getNotInHoldoutKey("\(context.id ?? "")_\(featureId ?? 0)")
        let alreadyEvaluatedKeysCSV = storageService.getString(forKey: notInHoldoutKey) ?? ""
        let alreadyEvaluatedHoldoutIds: [String] = alreadyEvaluatedKeysCSV.isEmpty ? [] : alreadyEvaluatedKeysCSV.split(separator: ",").map { String($0) }

        guard let holdoutGroups = settings.holdoutGroups, !holdoutGroups.isEmpty else {
            return ([], [])
        }

        if featureId == nil {
            serviceContainer?.getLoggerService()?.log(level: .error, key: "HOLDOUT_FEATURE_ID_NULL", details: nil)
        }

        var qualifiedHoldoutGroups: [HoldoutGroup] = []
        var impressions: [HoldoutImpression] = []

        for holdoutGroup in holdoutGroups {
            if alreadyEvaluatedHoldoutIds.contains("\(holdoutGroup.id ?? 0)") {
                serviceContainer?.getLoggerService()?.log(
                    level: .debug,
                    key: "HOLDOUT_SKIP_EVALUATION",
                    details: [
                        "holdoutName": holdoutGroup.name ?? "",
                        "reason": "user \(context.id ?? "") was already evaluated for feature with id: \(featureId ?? 0); SKIP decision making altogether."
                    ]
                )
                continue
            }

            if !doesHoldoutApplyToFeature(holdoutGroup: holdoutGroup, featureId: featureId) {
                continue
            }

            let passesSegmentation = evaluateHoldoutSegmentation(holdoutGroup: holdoutGroup, context: context)
            if !passesSegmentation {
                serviceContainer?.getLoggerService()?.log(
                    level: .debug,
                    key: "HOLDOUT_SEGMENTATION_FAIL",
                    details: ["userId": context.id ?? "", "holdoutGroupName": holdoutGroup.name ?? ""]
                )
                if let holdoutId = holdoutGroup.id {
                    impressions.append(HoldoutImpression(
                        campaignId: holdoutId,
                        variationId: Self.variationNotPartOfHoldout,
                        featureId: featureId ?? Constants.IMPRESSION_NO_FEATURE_ID
                    ))
                }
                continue
            }

            let shouldExcludeUser = shouldExcludeUserFromFeature(
                holdoutGroup: holdoutGroup,
                userId: context.id,
                accountId: settings.accountId,
                featureId: featureId
            )

            if shouldExcludeUser {
                serviceContainer?.getLoggerService()?.log(
                    level: .info,
                    key: "USER_IN_HOLDOUT_GROUP",
                    details: [
                        "userId": context.id ?? "",
                        "featureId": "\(featureId ?? 0)",
                        "holdoutGroupName": holdoutGroup.name ?? "",
                        "featureKey": "\(featureId ?? 0)"
                    ]
                )
                qualifiedHoldoutGroups.append(holdoutGroup)
                if let holdoutId = holdoutGroup.id {
                    impressions.append(HoldoutImpression(
                        campaignId: holdoutId,
                        variationId: Self.variationIsPartOfHoldout,
                        featureId: featureId ?? Constants.IMPRESSION_NO_FEATURE_ID
                    ))
                }
            } else {
                if let holdoutId = holdoutGroup.id {
                    impressions.append(HoldoutImpression(
                        campaignId: holdoutId,
                        variationId: Self.variationNotPartOfHoldout,
                        featureId: featureId ?? Constants.IMPRESSION_NO_FEATURE_ID
                    ))
                }
            }
        }

        return (qualifiedHoldoutGroups, impressions)
    }

    private func doesHoldoutApplyToFeature(holdoutGroup: HoldoutGroup, featureId: Int?) -> Bool {
        if holdoutGroup.isGlobal == true {
            return true
        }
        if let fid = featureId, let featureIds = holdoutGroup.featureIds, !featureIds.isEmpty, featureIds.contains(fid) {
            return true
        }
        return false
    }

    private func evaluateHoldoutSegmentation(holdoutGroup: HoldoutGroup, context: VWOUserContext) -> Bool {
        guard let segments = holdoutGroup.segments, !segments.isEmpty else {
            return true
        }
        return (serviceContainer?.getSegmentationManager())?.validateSegmentation(dsl: segments, properties: context.customVariables ?? [:]) ?? false
    }

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
