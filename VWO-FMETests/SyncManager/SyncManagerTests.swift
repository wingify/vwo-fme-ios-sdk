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

class SyncManagerTests: XCTestCase {

    var syncManager: SyncManager!

    override func setUp() {
        super.setUp()
        CoreDataStack.shared.clearCoreData()
        syncManager = SyncManager.shared
    }

    override func tearDown() {
        syncManager.stopSyncing()
        syncManager = nil
        CoreDataStack.shared.clearCoreData()
        super.tearDown()
    }

    func testInitializeWithValidBatchSizeAndInterval() {
        syncManager.initialize(minBatchSize: 10, timeInterval: 60001)
        XCTAssertTrue(syncManager.isOnlineBatchingAllowed)
        XCTAssertEqual(syncManager.minimumEventCount, 10)
        XCTAssertEqual(syncManager.timeInterval, 60001)
    }

    func testInitializeWithInvalidBatchSizeAndInterval() {
        syncManager.initialize(minBatchSize: 0, timeInterval: 50000)
        XCTAssertFalse(syncManager.isOnlineBatchingAllowed)
    }

    func testCheckOnlineBatchingAllowed() {
        XCTAssertTrue(syncManager.checkOnlineBatchingAllowed(batchSize: 10, batchUploadInterval: 60001))
        XCTAssertFalse(syncManager.checkOnlineBatchingAllowed(batchSize: 0, batchUploadInterval: 50000))
    }
}

class StorageServiceTests: XCTestCase {
    
    var storageService: StorageService!
    
    override func setUp() {
        super.setUp()
        storageService = StorageService()
        storageService.emptyLocalStorageSuite()
    }
    
    override func tearDown() {
        storageService.emptyLocalStorageSuite()
        super.tearDown()
    }
    
    func testSaveAndLoadSettings() {
        let settings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)!
        storageService.saveSettings(settings)
        
        let loadedSettings = storageService.loadSettings()
        XCTAssertNotNil(loadedSettings, "Settings should be loaded successfully")
    }
    
    func testClearSettings() {
        let settings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)!
        storageService.saveSettings(settings)
        storageService.clearSettings()
        
        let loadedSettings = storageService.loadSettings()
        XCTAssertNil(loadedSettings, "Settings should be cleared")
    }
    
    func testSaveAndLoadVersion() {
        let version = "1.0.0"
        storageService.saveVersion(version)
        
        let loadedVersion = storageService.loadVersion()
        XCTAssertEqual(loadedVersion, version, "Version should be loaded successfully")
    }
    
    func testClearUserDetail() {
        let userDetail = GatewayService()
        storageService.saveUserDetail(userDetail: userDetail)
        storageService.clearUserDetail()
        
        let loadedUserDetail = storageService.getUserDetail()
        XCTAssertNil(loadedUserDetail, "User detail should be cleared")
    }
    
    func testSaveAndLoadUsageStats() {
        let usageStats: [String: Any] = ["key": "value"]
        storageService.setUsageStats(data: usageStats)
        
        let loadedUsageStats = storageService.getUsageStats()
        XCTAssertEqual(loadedUsageStats?["key"] as? String, "value", "Usage stats should be loaded successfully")
    }
    
    func testClearUsageStats() {
        let usageStats: [String: Any] = ["key": "value"]
        storageService.setUsageStats(data: usageStats)
        storageService.clearUsageStats()
        
        let loadedUsageStats = storageService.getUsageStats()
        XCTAssertNil(loadedUsageStats, "Usage stats should be cleared")
    }
    
}
