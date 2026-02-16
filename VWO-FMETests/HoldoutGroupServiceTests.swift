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

import XCTest
@testable import VWO_FME

final class HoldoutGroupServiceTests: XCTestCase {

    // Basic helper to create a rollout feature + campaign (similar to Android tests)
    private func makeSettingsWithRolloutFeature(holdoutGroups: [HoldoutGroup]? = nil) -> (Settings, Feature) {
        // Variable
        let variable = Variable(value: .string("test_value"), type: "string", key: "test_key", id: 1)

        // Build variation via JSON to use existing Codable init
        let variationJSON: [String: Any] = [
            "id": 1,
            "name": "Rollout Variation",
            "weight": 100.0,
            "startRangeVariation": 0,
            "endRangeVariation": 100,
            "variables": [
                [
                    "id": 1,
                    "type": "string",
                    "key": "test_key",
                    "value": "test_value"
                ]
            ]
        ]
        let variationData = try! JSONSerialization.data(withJSONObject: variationJSON, options: [])
        let variation = try! JSONDecoder().decode(Variation.self, from: variationData)

        // Campaign for rollout
        let campaign = Campaign(
            isAlwaysCheckSegment: false,
            isUserListEnabled: false,
            id: 1,
            segments: nil,
            ruleKey: nil,
            status: "RUNNING",
            percentTraffic: 100,
            key: "test_feature_rolloutRule1",
            type: CampaignTypeEnum.rollout.rawValue,
            name: "Rollout Campaign",
            isForcedVariationEnabled: false,
            variations: [variation],
            startRangeVariation: 0,
            endRangeVariation: 100,
            variables: nil,
            weight: 100.0,
            salt: nil
        )

        // Feature with rollout rule
        let rule = Rule(ruleKey: "rolloutRule1", variationId: 1, campaignId: 1, type: CampaignTypeEnum.rollout.rawValue)
        var featureJSON: [String: Any] = [
            "key": "test_feature",
            "status": "ON",
            "id": 1,
            "name": "Test Feature",
            "type": "FEATURE_FLAG",
            "rules": [
                [
                    "ruleKey": "rolloutRule1",
                    "variationId": 1,
                    "campaignId": 1,
                    "type": CampaignTypeEnum.rollout.rawValue
                ]
            ]
        ]
        let featureData = try! JSONSerialization.data(withJSONObject: featureJSON, options: [])
        var feature = try! JSONDecoder().decode(Feature.self, from: featureData)
        feature.rulesLinkedCampaign = [campaign]
        feature.variables = [variable]

        // We don't use the JSON decoder path here, so we can construct a minimal Settings
        // instance by decoding from a small JSON blob that matches the Settings schema.
        let settingsJSON: [String: Any] = [
            "version": 1,
            "accountId": 951881,
            "campaigns": [],
            "features": []
        ]
        let data = try! JSONSerialization.data(withJSONObject: settingsJSON, options: [])
        var decodedSettings = try! JSONDecoder().decode(Settings.self, from: data)
        decodedSettings.features = [feature]
        decodedSettings.campaigns = [campaign]
        decodedSettings.holdoutGroups = holdoutGroups

        return (decodedSettings, feature)
    }

    // MARK: - Case 1: Without Holdout - service should return empty list

    func testHoldoutServiceWithoutHoldoutsReturnsEmpty() {
        let (settings, feature) = makeSettingsWithRolloutFeature(holdoutGroups: nil)

        let context = VWOUserContext(id: "test_user_no_holdout", customVariables: [:])
        let storageService = StorageService()
        storageService.emptyLocalStorageSuite()

        // No need for a full ServiceContainer for these unit tests; we pass nil.
        let service = HoldoutGroupService(serviceContainer: nil, storageService: storageService)
        let (groups, impressions) = service.getHoldoutsFor(settings: settings, featureId: feature.id, context: context)

        XCTAssertTrue(groups.isEmpty, "HoldoutGroupService should return empty list when no holdout groups exist")
        XCTAssertTrue(impressions.isEmpty, "No holdout impressions should be generated when no holdouts exist")
    }

    // MARK: - Case 3 (simplified): With Holdout - user stopped in holdout layer

    func testHoldoutServiceWithHoldoutUserInHoldout() {
        // Holdout with 100% traffic, applies to feature id = 1
        let metrics = [HoldoutGroup.Metrics(type: "CUSTOM_GOAL", id: 1, identifier: "holdout_metric_1")]
        let holdout = HoldoutGroup(
            name: "Test Holdout",
            id: 100,
            segments: nil,
            trafficPercent: 100,
            isGlobal: false,
            isGatewayServiceRequired: false,
            featureIds: [1],
            metrics: metrics
        )

        let (settings, feature) = makeSettingsWithRolloutFeature(holdoutGroups: [holdout])

        let context = VWOUserContext(id: "test_user_in_holdout", customVariables: [:])
        let storageService = StorageService()
        storageService.emptyLocalStorageSuite()

        let service = HoldoutGroupService(serviceContainer: nil, storageService: storageService)
        let (groups, impressions) = service.getHoldoutsFor(settings: settings, featureId: feature.id, context: context)

        XCTAssertFalse(groups.isEmpty, "User should be in holdout when trafficPercent is 100")
        XCTAssertEqual(groups.first?.id, 100)
        XCTAssertFalse(impressions.isEmpty, "Holdout impressions should be generated when user is in holdout")
        XCTAssertEqual(impressions.first?.campaignId, 100)
        XCTAssertEqual(impressions.first?.variationId, 1) // variationId 1 == in-holdout
    }

    // MARK: - Case 4 (simplified): With Holdout - user passes holdout (0% traffic)

    func testHoldoutServiceWithHoldoutUserNotInHoldout() {
        // Holdout with 0% traffic, so no user is in holdout
        let metrics = [HoldoutGroup.Metrics(type: "CUSTOM_GOAL", id: 1, identifier: "holdout_metric_1")]
        let holdout = HoldoutGroup(
            name: "Test Holdout Zero Traffic",
            id: 200,
            segments: nil,
            trafficPercent: 0,
            isGlobal: false,
            isGatewayServiceRequired: false,
            featureIds: [1],
            metrics: metrics
        )

        let (settings, feature) = makeSettingsWithRolloutFeature(holdoutGroups: [holdout])

        let context = VWOUserContext(id: "test_user_not_in_holdout", customVariables: [:])
        let storageService = StorageService()
        storageService.emptyLocalStorageSuite()

        let service = HoldoutGroupService(serviceContainer: nil, storageService: storageService)
        let (groups, impressions) = service.getHoldoutsFor(settings: settings, featureId: feature.id, context: context)

        XCTAssertTrue(groups.isEmpty, "User should not be in holdout when trafficPercent is 0")
        // Impressions still contain \"not in holdout\" signals, so just ensure they are created
        XCTAssertFalse(impressions.isEmpty, "Impressions for holdout evaluation (not in holdout) should be generated")
        XCTAssertEqual(impressions.first?.campaignId, 200)
        XCTAssertEqual(impressions.first?.variationId, 2) // variationId 2 == not-in-holdout
    }
}

