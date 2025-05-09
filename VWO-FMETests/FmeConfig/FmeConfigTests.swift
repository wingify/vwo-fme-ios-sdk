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

final class FmeConfigTests: XCTestCase {

    func testSetSessionDataWithValidData() {
        let validData: [String: Any] = ["sessionId": Int64(12345)]
        FmeConfig.setSessionData(validData)
        
        XCTAssertTrue(FmeConfig.checkIsMILinked(), "isMISdkLinked should be true for valid session data")
    }
    
    func testSetSessionDataWithEmptyData() {
        let emptyData: [String: Any] = [:]
        FmeConfig.setSessionData(emptyData)
        
        XCTAssertFalse(FmeConfig.checkIsMILinked(), "isMISdkLinked should be false for empty session data")
    }
    
    func testSetSessionDataWithoutSessionIdKey() {
        let dataWithoutSessionId: [String: Any] = ["otherKey": "value"]
        FmeConfig.setSessionData(dataWithoutSessionId)
        
        XCTAssertFalse(FmeConfig.checkIsMILinked(), "isMISdkLinked should be false if sessionId key is missing")
    }
    
    func testSetSessionDataWithInvalidSessionIdValue() {
        let invalidSessionIdData: [String: Any] = ["sessionId": -1]
        FmeConfig.setSessionData(invalidSessionIdData)
        
        XCTAssertFalse(FmeConfig.checkIsMILinked(), "isMISdkLinked should be false for invalid sessionId value")
    }
    
    func testGenerateSessionIdWithExistingSession() {
        let validData: [String: Any] = ["sessionId": Int64(12345)]
        FmeConfig.setSessionData(validData)
        
        let sessionId = FmeConfig.generateSessionId()
        XCTAssertEqual(sessionId, 12345, "generateSessionId should return existing sessionId")
    }
    
    func testGenerateSessionIdWithoutExistingSession() {
        let sessionId = FmeConfig.generateSessionId()
        XCTAssertGreaterThan(sessionId, 0, "generateSessionId should return a positive number when no session exists")
    }

}
