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

final class EnumTests: XCTestCase {
    
    
    func testGetFlagRawValue() {
        // Test that the raw value of getFlag is correct
        XCTAssertEqual(ApiEnum.getFlag.rawValue, "getFlag", "The raw value of getFlag should be 'getFlag'")
    }
    
    func testTrackRawValue() {
        // Test that the raw value of track is correct
        XCTAssertEqual(ApiEnum.track.rawValue, "track", "The raw value of track should be 'track'")
    }
    
    func testEnumInitialization() {
        // Test that the enum can be initialized with a valid raw value
        XCTAssertEqual(ApiEnum(rawValue: "getFlag"), .getFlag, "ApiEnum should initialize to .getFlag with raw value 'getFlag'")
        XCTAssertEqual(ApiEnum(rawValue: "track"), .track, "ApiEnum should initialize to .track with raw value 'track'")
        
        // Test that the enum returns nil for an invalid raw value
        XCTAssertNil(ApiEnum(rawValue: "invalid"), "ApiEnum should return nil for an invalid raw value")
    }    
}

class CodableValueTests: XCTestCase {

    func testStringEncodingDecoding() throws {
        let original = CodableValue.string("Hello, World!")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: data)
        
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.stringValue, "Hello, World!")
    }
    
    func testIntEncodingDecoding() throws {
        let original = CodableValue.int(42)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: data)
        
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.intValue, 42)
    }
    
    func testDoubleEncodingDecoding() throws {
        let original = CodableValue.double(2.718)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: data)
        
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.doubleValue, 2.718)
    }
    
    func testBoolEncodingDecoding() throws {
        let original = CodableValue.bool(true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: data)
        
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.boolValue, true)
    }
    
    func testArrayEncodingDecoding() throws {
        let original = CodableValue.array([.int(1), .string("two"), .bool(false)])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: data)
        
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.arrayValue?.count, 3)
    }
    
    func testDictionaryEncodingDecoding() throws {
        let original = CodableValue.dictionary([
            "key1": .int(1),
            "key2": .string("value")
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: data)
        
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.dictionaryValue?["key1"]?.intValue, 1)
        XCTAssertEqual(decoded.dictionaryValue?["key2"]?.stringValue, "value")
    }
    
    func testToJSONCompatible() {
        let original = CodableValue.dictionary([
            "key1": .int(1),
            "key2": .array([.string("value"), .bool(true)])
        ])
        
        let jsonCompatible = original.toJSONCompatible()
        
        if let dict = jsonCompatible as? [String: Any],
           let key1 = dict["key1"] as? Int,
           let key2 = dict["key2"] as? [Any],
           let firstElement = key2.first as? String,
           let secondElement = key2.last as? Bool {
            XCTAssertEqual(key1, 1)
            XCTAssertEqual(firstElement, "value")
            XCTAssertEqual(secondElement, true)
        } else {
            XCTFail("JSON compatible conversion failed")
        }
    }
}
