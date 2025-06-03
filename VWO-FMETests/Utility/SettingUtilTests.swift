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

final class SettingUtilTests: XCTestCase {
    
    var mockSettings: Settings!
    
    override func setUp() {
        super.setUp()
        mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.UtilitySettings.jsonFileName)
    }
    
    override func tearDown() {
        mockSettings = nil
        super.tearDown()
    }
    
    func testAddLinkedCampaignsToSettings() {
        var settings = mockSettings!
        SettingsUtil.processSettings(&settings)
        
        XCTAssertFalse(settings.features.isEmpty)
        XCTAssertNotNil(settings.campaigns)
        XCTAssertEqual(settings.campaigns?.count, 3)
        XCTAssertNotNil(settings.features.first?.rulesLinkedCampaign)
        XCTAssertEqual(settings.features.first?.rulesLinkedCampaign?.count, 3)
        XCTAssertEqual(settings.features.first?.rulesLinkedCampaign?.first?.variations?.count, 1)
    }
    
    func testCheckValuePresentWithMatchingValues() {
        let expectedMap: [String: [String]] = ["key1": ["value1", "value2"], "key2": ["wildcard(val*)"]]
        let actualMap: [String: String] = ["key1": "value1", "key2": "val123"]
        XCTAssertTrue(SegmentUtil.checkValuePresent(expectedMap: expectedMap, actualMap: actualMap))
    }
    
    func testCheckValuePresentWithNonMatchingValues() {
        let expectedMap: [String: [String]] = ["key1": ["value1", "value2"], "key2": ["wildcard(val*)"]]
        let actualMap: [String: String] = ["key1": "value3", "key2": "other"]
        XCTAssertFalse(SegmentUtil.checkValuePresent(expectedMap: expectedMap, actualMap: actualMap))
    }
    
    func testValuesMatchWithMatchingLocations() {
        let dict: [String: Any] = ["city" : "New York"]
        let expectedLocationMap: [String: CodableValue] = convertToCodableValueDictionary(dict)
        let userLocation: [String: String] = ["city": "New York"]
        XCTAssertTrue(SegmentUtil.valuesMatch(expectedLocationMap: expectedLocationMap, userLocation: userLocation))
    }
    
    func testValuesMatchWithNonMatchingLocations() {
        let dict: [String: Any] = ["city" : "New York"]
        let expectedLocationMap: [String: CodableValue] = convertToCodableValueDictionary(dict)
        let userLocation: [String: String] = ["city": "Los Angeles"]
        XCTAssertFalse(SegmentUtil.valuesMatch(expectedLocationMap: expectedLocationMap, userLocation: userLocation))
    }
    
    func testNormalizeValueWithQuotes() {
        let value = CodableValue(from: "\"Test Value\"")
        XCTAssertEqual(SegmentUtil.normalizeValue(value), "Test Value")
    }
    
    func testNormalizeValueWithoutQuotes() {
        let value = CodableValue(from: "Test Value")
        XCTAssertEqual(SegmentUtil.normalizeValue(value), "Test Value")
    }
    
    func testGetKeyValueWithValidNode() {
        let dict = ["key": "value"]
        let node = convertToCodableValueDictionary(dict)
        let result = SegmentUtil.getKeyValue(node)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.key, "key")
        XCTAssertEqual(result?.value.stringValue, "value")
    }
    
    func testGetKeyValueWithEmptyNode() {
        let node: [String: CodableValue] = [:]
        let result = SegmentUtil.getKeyValue(node)
        XCTAssertNil(result)
    }
    
    func testMatchWithRegexWithMatchingString() {
        let string = "hello123"
        let regex = "hello\\d+"
        XCTAssertTrue(SegmentUtil.matchWithRegex(string: string, regex: regex))
    }
    
    func testMatchWithRegexWithNonMatchingString() {
        let string = "hello"
        let regex = "hello\\d+"
        XCTAssertFalse(SegmentUtil.matchWithRegex(string: string, regex: regex))
    }
    
}

extension CodableValue {
    init?(from value: Any) {
        if let stringValue = value as? String {
            self = .string(stringValue)
        } else if let intValue = value as? Int {
            self = .int(intValue)
        } else if let doubleValue = value as? Double {
            self = .double(doubleValue)
        } else if let floatValue = value as? Float {
            self = .float(floatValue)
        } else if let boolValue = value as? Bool {
            self = .bool(boolValue)
        } else if let arrayValue = value as? [Any] {
            let codableArray = arrayValue.compactMap { element in
                return CodableValue(from: element)
            }
            self = .array(codableArray)
        } else if let dictValue = value as? [String: Any] {
            let codableDict = dictValue.compactMapValues { element in
                return CodableValue(from: element)
            }
            self = .dictionary(codableDict)
        } else {
            return nil
        }
    }
}

func convertToCodableValueDictionary(_ dict: [String: Any]) -> [String: CodableValue] {
    var result: [String: CodableValue] = [:]
    for (key, value) in dict {
        if let codableValue = CodableValue(from: value) {
            result[key] = codableValue
        }
    }
    return result
}
