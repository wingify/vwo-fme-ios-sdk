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

class DeviceIDUtilTests: XCTestCase {
    let deviceIdKey = "com.vwo.fme.deviceIdKey"
    let suiteName = Constants.SDK_USERDEFAULT_SUITE

    var userDefaults: UserDefaults {
        return UserDefaults(suiteName: suiteName)!
    }

    override func setUp() {
        super.setUp()
        userDefaults.removeObject(forKey: deviceIdKey)
    }

    override func tearDown() {
        userDefaults.removeObject(forKey: deviceIdKey)
        super.tearDown()
    }

    func testGetDeviceID_GeneratesAndReturnsDeviceID() {
        // Test that when no device ID is stored, it generates and stores identifierForVendor
        let util = DeviceIDUtil()
        let deviceId = util.getDeviceID()
        let expected = UIDevice.current.identifierForVendor?.uuidString
        XCTAssertNotNil(deviceId, "Device ID should not be nil when generated.")
        XCTAssertEqual(deviceId, expected, "Device ID should match identifierForVendor.")
        // Also check that it is now stored in UserDefaults
        let stored = userDefaults.string(forKey: deviceIdKey)
        XCTAssertEqual(stored, expected, "Device ID should be stored in UserDefaults.")
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
