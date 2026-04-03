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

class SettingsSchemaTests: XCTestCase {

    /// Minimal holdout that satisfies `SettingsSchema.isValidHoldoutGroup` (all required fields present).
    private func makeSchemaValidHoldout(
        id: Int? = 9001,
        trafficPercent: Int? = 10,
        isGlobal: Bool? = false,
        segments: [String: CodableValue]? = [:]
    ) -> HoldoutGroup {
        HoldoutGroup(
            name: "schema_test_holdout",
            id: id,
            segments: segments,
            trafficPercent: trafficPercent,
            isGlobal: isGlobal,
            isGatewayServiceRequired: false,
            featureIds: [1],
            metrics: nil
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
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let mockClient1 = VWOClient(options: mockOptions, settingObj: mockSettings1)
        let processedMockSetting1 = mockClient1.processedSettings!

        let mockSettings2 = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettingsWithPreSegmentMobileUA.jsonFileName)
        let mockClient2 = VWOClient(options: mockOptions, settingObj: mockSettings2)
        let processedMockSetting2 = mockClient2.processedSettings!
        let vwoBuilder = VWOBuilder(options: mockOptions)
        let hasDifferences = vwoBuilder.findDifference(localSettings: processedMockSetting1, apiSettings: processedMockSetting2)
        XCTAssertTrue(hasDifferences, "Expected differences found")
    }
    
    func testFindDifferenceWithoutDifferences() {
        let mockSettings1 = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let mockClient1 = VWOClient(options: mockOptions, settingObj: mockSettings1)
        let processedMockSetting1 = mockClient1.processedSettings!
        let vwoBuilder = VWOBuilder(options: mockOptions)
        let hasDifferences = vwoBuilder.findDifference(localSettings: processedMockSetting1, apiSettings: processedMockSetting1)
        XCTAssertFalse(hasDifferences, "Expected differences not found")
    }
}
