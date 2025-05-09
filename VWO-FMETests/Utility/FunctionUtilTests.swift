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

final class FunctionUtilTests: XCTestCase {
    
    var mockSettings: Settings!
    var mockOptions: VWOInitOptions!
    var mockClient: VWOClient!
    var processedMockSetting: Settings!
    var mockFeature: Feature!
    
    override func setUp() {
        super.setUp()
        mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.UtilitySettings.jsonFileName)
        mockOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
        processedMockSetting = mockClient.processedSettings!
        mockFeature = processedMockSetting.features.first!
    }
    
    override func tearDown() {
        mockSettings = nil
        mockOptions = nil
        mockClient = nil
        super.tearDown()
    }
    
    // MARK: - cloneObject Tests
    
    func testCloneObject() {
        
        struct TestStruct: Codable, Equatable {
            let a: Int
            var b: NestedStruct
        }
        
        struct NestedStruct: Codable, Equatable {
            let c: Int
            var d: [Int]
            var e: [String: Int]
        }
        
        let original = TestStruct(
            a: 1,
            b: NestedStruct(
                c: 2,
                d: [3, 4, 5],
                e: ["f": 6]
            )
        )
        
        var cloned = FunctionUtil.cloneObject(original)
        
        XCTAssertNotNil(cloned)
        XCTAssertEqual(cloned, original)
        cloned!.b.d.append(7)
        XCTAssertNotEqual(cloned!.b.d, original.b.d) // Ensure it's a deep copy by modifying cloned
    }

    
    func testCloneObjectWithNil() {
        let result = FunctionUtil.cloneObject(nil as String?)
        XCTAssertNil(result)
    }
    
    // MARK: - Timestamp Tests
    
    func testCurrentUnixTimestamp2() {
        let timestamp = FunctionUtil.currentUnixTimestamp
        let expected = Int64(Date().timeIntervalSince1970)
        
        XCTAssertEqual(timestamp, expected, accuracy: 1, "Timestamp should be close to the current time")
    }
    
    func testCurrentUnixTimestampInMillis2() {
        let timestampMillis = FunctionUtil.currentUnixTimestampInMillis
        let expectedMillis = Int64(Date().timeIntervalSince1970 * 1000)
        
        XCTAssertEqual(timestampMillis, expectedMillis, accuracy: 1000, "Timestamp in millis should be close to the current time")
    }
    
    // MARK: - Rules Tests

    func testGetSpecificRulesBasedOnType() {
        // Test for type "ab"
        let resultAb = FunctionUtil.getSpecificRulesBasedOnType(feature: mockFeature, type: .ab)
        XCTAssertEqual(resultAb.count, 1, "Should return one campaign of type 'ab'")
        XCTAssertEqual(resultAb.first?.type, CampaignTypeEnum.ab.rawValue, "Returned campaign should be of type 'ab'")
        
        // Test for type "personalize"
        let resultPersonalize = FunctionUtil.getSpecificRulesBasedOnType(feature: mockFeature, type: .personalize)
        XCTAssertEqual(resultPersonalize.count, 1, "Should return one campaign of type 'personalize'")
        XCTAssertEqual(resultPersonalize.first?.type, CampaignTypeEnum.personalize.rawValue, "Returned campaign should be of type 'personalize'")
    }
    
    func testGetSpecificRulesBasedOnTypeWithNilFeature() {
        let result = FunctionUtil.getSpecificRulesBasedOnType(feature: nil, type: .ab)
        XCTAssertTrue(result.isEmpty)
    }
    
    func testGetAllExperimentRules() {
        let allRules = FunctionUtil.getAllExperimentRules(feature: mockFeature)
        XCTAssertEqual(allRules.count, 2)
    }
    
    func testGetAllExperimentRulesWithNilFeature() {
        let result = FunctionUtil.getAllExperimentRules(feature: nil)
        XCTAssertTrue(result.isEmpty)
    }
}
