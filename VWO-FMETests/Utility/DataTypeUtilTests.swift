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

class DataTypeUtilTests: XCTestCase {
    
    func testValidAttributeKeyAndValueTypes() {
        let validAttributes: [AnyHashable: Any] = [
            "validString": "test",
            "validNumber": 123,
            "validBoolean": true
        ]
        for (attributeKey, attributeValue) in validAttributes {
            XCTAssertTrue(DataTypeUtil.isString(attributeKey), "attributeKey should be a String")
            XCTAssertTrue(DataTypeUtil.isString(attributeValue) || DataTypeUtil.isNumber(attributeValue) || DataTypeUtil.isBoolean(attributeValue), "attributeValue should be a String, Number, or Boolean")
        }
    }
    
    func testInvalidAttributeKeyAndValueTypes() {
        let invalidKeyAttributes: [AnyHashable: Any] = [
            123: "validValue"
        ]
        for (attributeKey, attributeValue) in invalidKeyAttributes {
            XCTAssertFalse(DataTypeUtil.isString(attributeKey), "attributeKey should not be a String")
            XCTAssertTrue(DataTypeUtil.isString(attributeValue), "attributeValue should be a String")
        }
        let invalidValueAttributes: [AnyHashable: Any] = [
            "validKey": Date(),
            "validKey2": [2,3]
        ]
        for (attributeKey, attributeValue) in invalidValueAttributes {
            XCTAssertTrue(DataTypeUtil.isString(attributeKey), "attributeKey should be a String")
            XCTAssertFalse(DataTypeUtil.isString(attributeValue) || DataTypeUtil.isNumber(attributeValue) || DataTypeUtil.isBoolean(attributeValue), "attributeValue should not be a String, Number, or Boolean")
        }
    }
}
