/**
 * Copyright 2024-2026 Wingify Software Pvt. Ltd.
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
@testable import Wingify_FME

final class UserTrackingUsageUtilTests: XCTestCase {

    func testIsUserTrackingEnabledWhenBillingFlagOmitted() throws {
        let json = """
        {"accountId": 1, "version": 1}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let settings = try JSONDecoder().decode(Settings.self, from: data)

        XCTAssertFalse(UserTrackingUsageUtil.isUserTrackingEnabled(settings: settings))
        XCTAssertNil(settings.isMAU)
    }

    func testIsUserTrackingEnabledOnlyWhenBillingFlagExplicitlyTrue() throws {
        let enabledJSON = """
        {"isMAU": true}
        """
        let disabledJSON = """
        {"isMAU": false}
        """

        let enabled = try JSONDecoder().decode(Settings.self, from: XCTUnwrap(enabledJSON.data(using: .utf8)))
        let disabled = try JSONDecoder().decode(Settings.self, from: XCTUnwrap(disabledJSON.data(using: .utf8)))

        XCTAssertTrue(UserTrackingUsageUtil.isUserTrackingEnabled(settings: enabled))
        XCTAssertFalse(UserTrackingUsageUtil.isUserTrackingEnabled(settings: disabled))
    }
}
