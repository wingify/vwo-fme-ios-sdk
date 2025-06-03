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

final class SegmentOperatorValueEnumTests: XCTestCase {
    
    func testAllEnumValues() {
        // Test all enum values are correctly defined
        XCTAssertEqual(SegmentOperatorValueEnum.and.rawValue, "and")
        XCTAssertEqual(SegmentOperatorValueEnum.not.rawValue, "not")
        XCTAssertEqual(SegmentOperatorValueEnum.or.rawValue, "or")
        XCTAssertEqual(SegmentOperatorValueEnum.customVariable.rawValue, "custom_variable")
        XCTAssertEqual(SegmentOperatorValueEnum.user.rawValue, "user")
        XCTAssertEqual(SegmentOperatorValueEnum.country.rawValue, "country")
        XCTAssertEqual(SegmentOperatorValueEnum.region.rawValue, "region")
        XCTAssertEqual(SegmentOperatorValueEnum.city.rawValue, "city")
        XCTAssertEqual(SegmentOperatorValueEnum.operatingSystem.rawValue, "os")
        XCTAssertEqual(SegmentOperatorValueEnum.deviceType.rawValue, "device_type")
        XCTAssertEqual(SegmentOperatorValueEnum.browserAgent.rawValue, "browser_string")
        XCTAssertEqual(SegmentOperatorValueEnum.ua.rawValue, "ua")
        XCTAssertEqual(SegmentOperatorValueEnum.device.rawValue, "device")
        XCTAssertEqual(SegmentOperatorValueEnum.featureId.rawValue, "featureId")
    }
    
    func testFromValueSuccess() {
        // Test successful cases for fromValue function
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("and"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("not"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("or"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("custom_variable"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("user"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("country"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("region"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("city"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("os"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("device_type"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("browser_string"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("ua"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("device"))
        XCTAssertNoThrow(try SegmentOperatorValueEnum.fromValue("featureId"))
        
        // Verify the returned values match
        XCTAssertEqual(try SegmentOperatorValueEnum.fromValue("and"), .and)
        XCTAssertEqual(try SegmentOperatorValueEnum.fromValue("not"), .not)
        XCTAssertEqual(try SegmentOperatorValueEnum.fromValue("or"), .or)
    }
    
    func testFromValueFailure() {
        // Test failure cases for fromValue function
        XCTAssertThrowsError(try SegmentOperatorValueEnum.fromValue("invalid_value"))
        XCTAssertThrowsError(try SegmentOperatorValueEnum.fromValue(""))
        XCTAssertThrowsError(try SegmentOperatorValueEnum.fromValue("AND")) // Case sensitive
        XCTAssertThrowsError(try SegmentOperatorValueEnum.fromValue("custom-variable")) // Wrong format
    }
    
    func testErrorDescription() {
        // Test error message contains the invalid value
        do {
            _ = try SegmentOperatorValueEnum.fromValue("invalid_value")
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertTrue(error.localizedDescription.contains("invalid_value"))
            XCTAssertEqual(error.domain, "SegmentOperatorValueEnum")
            XCTAssertEqual(error.code, -1)
        }
    }
}
