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

import XCTest
@testable import Wingify_FME

class SettingsSchemaTests: XCTestCase {

    private static let validHoldoutSegments: [String: CodableValue] = [
        "or": .array([.dictionary(["country": .string("US")])])
    ]
    private static let validHoldoutMetrics: [HoldoutGroup.Metrics] = [
        HoldoutGroup.Metrics(type: "CUSTOM_GOAL", id: 1, identifier: "holdout_metric")
    ]

    /// Holdout that satisfies `SettingsSchema.isValidHoldoutGroup` (required holdout JSON fields present).
    private func makeSchemaValidHoldout(
        id: Int? = 9001,
        trafficPercent: Int? = 10,
        isGlobal: Bool? = false,
        segments: [String: CodableValue]? = SettingsSchemaTests.validHoldoutSegments,
        featureIds: [Int]? = [1],
        metrics: [HoldoutGroup.Metrics]? = SettingsSchemaTests.validHoldoutMetrics
    ) -> HoldoutGroup {
        HoldoutGroup(
            name: "schema_test_holdout",
            id: id,
            segments: segments,
            trafficPercent: trafficPercent,
            isGlobal: isGlobal,
            isGatewayServiceRequired: false,
            featureIds: featureIds,
            metrics: metrics
        )
    }

    /// Rollout + testing fixture; `holdoutGroups` is nil until tests assign it.
    private func loadBaseSettings() throws -> Settings {
        try XCTUnwrap(
            FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName),
            "RolloutAndTestingSettings.json must load for schema tests"
        )
    }
    
    override func setUp() {
        super.setUp()
    }

    // MARK: - Holdout (`SettingsSchema.isValidHoldoutGroup`)
    // Covered: missing id / percentTraffic / isGlobal; segments nil or empty; metrics nil, empty, or any metric
    // missing id, type, identifier, or empty identifier; non-global with nil or empty featureIds; global with nil/empty
    // featureIds allowed; mixed list invalid; no holdouts (nil or empty array).

    func testValidSettingsWithHoldoutGroup() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout()]
        XCTAssertTrue(SettingsSchema().isSettingsValid(settings), "Settings with a well-formed holdout group should be valid")
    }

    func testInvalidSettingsHoldoutMissingId() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(id: nil)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "Holdout without id should invalidate settings")
    }

    func testInvalidSettingsHoldoutMissingTrafficPercent() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(trafficPercent: nil)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "Holdout without percentTraffic should invalidate settings")
    }

    func testInvalidSettingsHoldoutMissingIsGlobal() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(isGlobal: nil)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "Holdout without isGlobal should invalidate settings")
    }

    func testInvalidSettingsHoldoutMissingSegments() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(segments: nil)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "Holdout without segments should invalidate settings")
    }

    func testInvalidSettingsHoldoutEmptySegments() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(segments: [:])]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "Holdout with empty segments object should invalidate settings")
    }

    func testInvalidSettingsHoldoutMissingMetrics() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(metrics: nil)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "Holdout without metrics should invalidate settings")
    }

    func testInvalidSettingsHoldoutMissingFeatureIdsWhenNotGlobal() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(isGlobal: false, featureIds: [])]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "Non-global holdout without featureIds should invalidate settings")
    }

    func testInvalidSettingsHoldoutNonGlobalNilFeatureIds() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(isGlobal: false, featureIds: nil)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "Non-global holdout with nil featureIds should invalidate settings")
    }

    func testValidSettingsGlobalHoldoutNilFeatureIds() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(isGlobal: true, featureIds: nil)]
        XCTAssertTrue(SettingsSchema().isSettingsValid(settings), "Global holdout may omit featureIds")
    }

    func testValidSettingsGlobalHoldoutEmptyFeatureIds() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(isGlobal: true, featureIds: [])]
        XCTAssertTrue(SettingsSchema().isSettingsValid(settings), "Global holdout may use empty featureIds")
    }

    func testInvalidSettingsHoldoutEmptyMetricsArray() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = [makeSchemaValidHoldout(metrics: [])]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "Holdout with empty metrics array should invalidate settings")
    }

    func testInvalidSettingsHoldoutMetricMissingId() throws {
        var settings = try loadBaseSettings()
        let bad = [HoldoutGroup.Metrics(type: "CUSTOM_GOAL", id: nil, identifier: "m")]
        settings.holdoutGroups = [makeSchemaValidHoldout(metrics: bad)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings))
    }

    func testInvalidSettingsHoldoutMetricMissingType() throws {
        var settings = try loadBaseSettings()
        let bad = [HoldoutGroup.Metrics(type: nil, id: 1, identifier: "m")]
        settings.holdoutGroups = [makeSchemaValidHoldout(metrics: bad)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings))
    }

    func testInvalidSettingsHoldoutMetricMissingIdentifier() throws {
        var settings = try loadBaseSettings()
        let bad = [HoldoutGroup.Metrics(type: "CUSTOM_GOAL", id: 1, identifier: nil)]
        settings.holdoutGroups = [makeSchemaValidHoldout(metrics: bad)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings))
    }

    func testInvalidSettingsHoldoutMetricEmptyIdentifier() throws {
        var settings = try loadBaseSettings()
        let bad = [HoldoutGroup.Metrics(type: "CUSTOM_GOAL", id: 1, identifier: "")]
        settings.holdoutGroups = [makeSchemaValidHoldout(metrics: bad)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings))
    }

    func testInvalidSettingsHoldoutSecondMetricInvalid() throws {
        var settings = try loadBaseSettings()
        let metrics: [HoldoutGroup.Metrics] = [
            HoldoutGroup.Metrics(type: "CUSTOM_GOAL", id: 1, identifier: "ok"),
            HoldoutGroup.Metrics(type: nil, id: 2, identifier: "bad")
        ]
        settings.holdoutGroups = [makeSchemaValidHoldout(metrics: metrics)]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "Any invalid metric in the list should fail validation")
    }

    func testValidSettingsHoldoutGroupsNilSkipsHoldoutChecks() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = nil
        XCTAssertTrue(SettingsSchema().isSettingsValid(settings))
    }

    func testValidSettingsEmptyHoldoutGroupsArray() throws {
        var settings = try loadBaseSettings()
        settings.holdoutGroups = []
        XCTAssertTrue(SettingsSchema().isSettingsValid(settings))
    }

    func testInvalidSettingsWhenAnyHoldoutInListIsInvalid() throws {
        var settings = try loadBaseSettings()
        let valid = makeSchemaValidHoldout(id: 1)
        let invalid = makeSchemaValidHoldout(id: nil)
        settings.holdoutGroups = [valid, invalid]
        XCTAssertFalse(SettingsSchema().isSettingsValid(settings), "One invalid holdout in the list should fail validation")
    }
    
    func testValidSettings() {
        let settings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)
        XCTAssertTrue(SettingsSchema().isSettingsValid(settings))
    }
    
    func testInvalidSettingsNil() {
        XCTAssertFalse(SettingsSchema().isSettingsValid(nil))
    }
    
    func testInvalidSettingsEmptyCampaigns() {
        let settings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.EmptySettings.jsonFileName)
        XCTAssertTrue(SettingsSchema().isSettingsValid(settings))
    }
    
    func testFindDifferenceWithDifferences() {
        let mockSettings1 = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)
        let mockOptions: WingifyInitOptions = WingifyInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let mockClient1 = WingifyClient(options: mockOptions, settingObj: mockSettings1)
        let processedMockSetting1 = mockClient1.processedSettings!

        let mockSettings2 = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettingsWithPreSegmentMobileUA.jsonFileName)
        let mockClient2 = WingifyClient(options: mockOptions, settingObj: mockSettings2)
        let processedMockSetting2 = mockClient2.processedSettings!
        let wingifyBuilder = WingifyBuilder(options: mockOptions)
        let hasDifferences = wingifyBuilder.findDifference(localSettings: processedMockSetting1, apiSettings: processedMockSetting2)
        XCTAssertTrue(hasDifferences, "Expected differences found")
    }
    
    func testFindDifferenceWithoutDifferences() {
        let mockSettings1 = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)
        let mockOptions: WingifyInitOptions = WingifyInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let mockClient1 = WingifyClient(options: mockOptions, settingObj: mockSettings1)
        let processedMockSetting1 = mockClient1.processedSettings!
        let wingifyBuilder = WingifyBuilder(options: mockOptions)
        let hasDifferences = wingifyBuilder.findDifference(localSettings: processedMockSetting1, apiSettings: processedMockSetting1)
        XCTAssertFalse(hasDifferences, "Expected differences not found")
    }
}
