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

class UUIDUtilsTests: XCTestCase {
    
    func testGetRandomUUID() {
        let sdkKey = "test-api-key"
        
        let result = UUIDUtils.getRandomUUID(sdkKey: sdkKey)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result.count, 36) // Standard UUID length with dashes
        XCTAssertTrue(result.contains("-"))
    }
    
    func testGetUUID() {
        let userId = "test-user"
        let accountId = "123456"
        
        let result = UUIDUtils.getUUID(userId: userId, accountId: accountId)
        
        let expectedUUID = "6E110359D229586996503BF106AB395B"
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result.count, 32) // UUID without dashes
        XCTAssertFalse(result.contains("-"))
        XCTAssertEqual(result, expectedUUID.uppercased())
    }
    
    func testGenerateUUID() {
        let name = "test-name"
        let namespace =  UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")! // DNS_NAMESPACE defined in UUIDUtils
        
        let result = UUIDUtils.generateUUID(name: name, namespace: namespace)
        
        let expectedUUID = "BF82697C-C673-5019-A043-71151AD336F8"
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result.uuidString.count, 36)
        XCTAssertTrue(result.uuidString.contains("-"))
        XCTAssertEqual(result.uuidString, expectedUUID.uppercased())
    }
}
