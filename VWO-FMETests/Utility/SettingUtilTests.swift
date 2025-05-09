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
}
