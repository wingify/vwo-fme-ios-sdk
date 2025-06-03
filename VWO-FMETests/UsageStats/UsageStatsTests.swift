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

class UsageStatsTests: XCTestCase {
    
    var storageService: StorageService!

    override func setUp() {
        super.setUp()
        storageService = StorageService()
        UsageStatsUtil.emptyUsageStats()
    }
    
    override func tearDown() {
        storageService.emptyLocalStorageSuite()
        super.tearDown()
    }
    
    func testSetUsageStatsWithOptions() {
        
        let options = VWOInitOptions(sdkKey: "sdk-key",
                                     accountId: 12345,
                                     logLevel: .debug,
                                     integrations: nil,
                                     cachedSettingsExpiryTime: 2*60*1000,
                                     pollInterval: nil,
                                     batchMinSize: 10,
                                     batchUploadTimeInterval: nil,
                                     logTransport: nil,
                                     vwoMeta: ["_ea": 1])
        
        UsageStatsUtil.setUsageStats(options: options)
        let statsDict = UsageStatsUtil.getUsageStatsDict()
        
        
        XCTAssertEqual(statsDict[UsageStatsKeys.logLevel] as? Int, 1)
        XCTAssertEqual(statsDict[UsageStatsKeys.integrations] as? Int, 0)
        XCTAssertEqual(statsDict[UsageStatsKeys.cachedSettingsExpiryTime] as? Int, 1)
        XCTAssertEqual(statsDict[UsageStatsKeys.storage] as? Int, 1)
        XCTAssertEqual(statsDict[UsageStatsKeys.pollInterval] as? Int, 0)
        XCTAssertNotNil(statsDict[UsageStatsKeys.eventBatchingSize])
        XCTAssertEqual(statsDict[UsageStatsKeys.offlineBatching] as? Int, 1)
        XCTAssertEqual(statsDict[UsageStatsKeys.logTransport] as? Int, 0)
        XCTAssertEqual(statsDict["_ea"] as? Int, 1)
    }
    
    func testCanSendStats() {
        let options = VWOInitOptions(sdkKey: "sdk-key",
                                     accountId: 12345,
                                     logLevel: .debug,
                                     integrations: nil,
                                     cachedSettingsExpiryTime: 2*60*1000,
                                     pollInterval: nil,
                                     batchMinSize: 100,
                                     batchUploadTimeInterval: nil,
                                     logTransport: nil,
                                     vwoMeta: ["_ea": 1])
        
        UsageStatsUtil.setUsageStats(options: options)
        UsageStatsUtil.saveUsageStatsInStorage()
        XCTAssertTrue(UsageStatsUtil.canSendStats())
    }
    
    func testRemoveFalseValues() {
        let dict = ["key1": 0, "key2": 1, "key3": 2]
        let filteredDict = UsageStatsUtil.removeFalseValues(dict: dict)
        XCTAssertNil(filteredDict["key1"])
        XCTAssertEqual(filteredDict["key2"] as? Int, 1)
        XCTAssertEqual(filteredDict["key3"] as? Int, 2)
    }
    
    func testEmptyUsageStats() {
        let options = VWOInitOptions(sdkKey: "sdk-key",
                                     accountId: 12345,
                                     logLevel: .debug,
                                     integrations: nil,
                                     cachedSettingsExpiryTime: 2*60*1000,
                                     pollInterval: nil,
                                     batchMinSize: 100,
                                     batchUploadTimeInterval: nil,
                                     logTransport: nil,
                                     vwoMeta: ["_ea": 1])
        UsageStatsUtil.setUsageStats(options: options)
        UsageStatsUtil.emptyUsageStats()
        let statsDict = UsageStatsUtil.getUsageStatsDict()
        XCTAssertTrue(statsDict.isEmpty)
    }
    
    func testAreDictionariesEqualWhenDictionariesAreEqualShouldReturnTrue() {
        let dict1: [String: Any] = [
            "key1": 1,
            "key2": "value",
            "key3": true,
            "key4": ["subKey1": 1, "subKey2": "subValue"]
        ]
        
        let dict2: [String: Any] = [
            "key1": 1,
            "key2": "value",
            "key3": true,
            "key4": ["subKey1": 1, "subKey2": "subValue"]
        ]
        
        XCTAssertTrue(UsageStatsUtil.areDictionariesEqual(dict1, dict2))
    }
    
    func testAreDictionariesEqualWhenDictionariesAreNotEqualShouldReturnFalse() {
        let dict1: [String: Any] = [
            "key1": 1,
            "key2": "value",
            "key3": true
        ]
        
        let dict2: [String: Any] = [
            "key1": 1,
            "key2": "differentValue",
            "key3": true
        ]
        
        XCTAssertFalse(UsageStatsUtil.areDictionariesEqual(dict1, dict2))
    }
    
    func testAreDictionariesEqualWhenDictionariesHaveDifferentKeysShouldReturnFalse() {
        let dict1: [String: Any] = [
            "key1": 1,
            "key2": "value"
        ]
        
        let dict2: [String: Any] = [
            "key1": 1,
            "key3": "value"
        ]
        
        XCTAssertFalse(UsageStatsUtil.areDictionariesEqual(dict1, dict2))
    }
    
    func testAreDictionariesEqualWhenNestedDictionariesAreEqualShouldReturnTrue() {
        let dict1: [String: Any] = [
            "key1": ["subKey1": 1, "subKey2": "subValue"]
        ]
        
        let dict2: [String: Any] = [
            "key1": ["subKey1": 1, "subKey2": "subValue"]
        ]
        
        XCTAssertTrue(UsageStatsUtil.areDictionariesEqual(dict1, dict2))
    }
    
    func testAreDictionariesEqualWhenNestedDictionariesAreNotEqualShouldReturnFalse() {
        let dict1: [String: Any] = [
            "key1": ["subKey1": 1, "subKey2": "subValue"]
        ]
        
        let dict2: [String: Any] = [
            "key1": ["subKey1": 1, "subKey2": "differentSubValue"]
        ]
        
        XCTAssertFalse(UsageStatsUtil.areDictionariesEqual(dict1, dict2))
    }
}
