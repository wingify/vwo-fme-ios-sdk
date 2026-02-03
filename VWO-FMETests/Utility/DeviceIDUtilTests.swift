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
import Security
@testable import VWO_FME

class DeviceIDUtilTests: XCTestCase {
    let deviceIdKey = "com.vwo.fme.deviceIdKey"
    let suiteName = Constants.SDK_USERDEFAULT_SUITE

    var userDefaults: UserDefaults {
        return UserDefaults(suiteName: suiteName)!
    }

    override func setUp() {
        super.setUp()
        userDefaults.removeObject(forKey: deviceIdKey)
        // Clear Keychain entry to ensure deterministic test
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.vwo.fme.deviceId",
            kSecAttrAccount as String: "com.vwo.fme"
        ]
        SecItemDelete(query as CFDictionary)
    }

    override func tearDown() {
        userDefaults.removeObject(forKey: deviceIdKey)
        super.tearDown()
    }

    func testGetDeviceID_GeneratesAndReturnsDeviceID() {
        // When nothing stored, it should generate (from keychain path) and persist to UserDefaults
        let util = DeviceIDUtil()
        let deviceId = util.getDeviceID()
        XCTAssertNotNil(deviceId, "Device ID should not be nil when generated.")
        // Check it is stored in UserDefaults and matches returned value
        let stored = userDefaults.string(forKey: deviceIdKey)
        XCTAssertEqual(stored, deviceId, "Device ID should be stored in UserDefaults and match returned value.")
        
        // Subsequent fetch should return the same (stability check)
        let deviceIdAgain = util.getDeviceID()
        XCTAssertEqual(deviceId, deviceIdAgain, "Device ID should remain stable across calls.")
    }

    func testGetDeviceID_ReturnsExistingDeviceIDFromUserDefaults() {
        // Test that if a value is already stored, it is returned (even if not a real device ID)
        let fakeId = "test-fake-device-id-xyz"
        userDefaults.set(fakeId, forKey: deviceIdKey)
        let util = DeviceIDUtil()
        let deviceId = util.getDeviceID()
        XCTAssertEqual(deviceId, fakeId, "Should return the existing device ID from UserDefaults, regardless of its value.")
    }
} 
