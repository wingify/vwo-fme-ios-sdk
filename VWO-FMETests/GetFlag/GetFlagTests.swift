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

final class GetFlagTests: XCTestCase {
    
    // MARK: - Properties
    
    var mockSettings: Settings!
    var mockContext: VWOUserContext!
    var mockHookManager: MockHooksManager!
    var mockBuilder: VWOBuilder!
    var mockOptions: VWOInitOptions!
    var mockCallback: MockIntegrationCallback!
    var storageService: StorageService!

    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        storageService = StorageService()
        storageService.emptyLocalStorageSuite()
        mockContext = VWOUserContext(id: "\(Date().timeIntervalSince1970)_user_id", customVariables: [:])
        mockCallback = MockIntegrationCallback()
        mockHookManager = MockHooksManager(callback: mockCallback)
    }
    
    override func tearDown() {
        mockSettings = nil
        mockContext = nil
        mockHookManager = nil
        mockCallback = nil
        storageService.emptyLocalStorageSuite()
        super.tearDown()
    }
    
    // MARK: - Test Cases
        
    func testGetFlagWithoutStorage() {

        let expectation = XCTestExpectation(description: "Get flag without storage")
        let data = FlagTestCaseLoader.loadTestData(jsonFileName: GetFlagTestJson.jsonFileName)
        
        if let myData = data, let cases = myData.withoutStorage {
            
            for item in cases {
                
                storageService.emptyLocalStorageSuite()
                
                let fileForSetting = GetFlagTestJson.getJsonFileForSetting(input: item.settings)
                let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: fileForSetting.jsonFileName)
                
                let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
                let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
                let processedMockSetting = mockClient.processedSettings!
                
                let contextData = VWOUserContext(id: item.context.id!, customVariables: item.context.customVariables!)
                
                GetFlagAPI.getFlag(featureKey: item.featureKey, settings: processedMockSetting, context: contextData, hookManager: mockHookManager) { getFlag in
                    
                    XCTAssertNotNil(getFlag)
                    XCTAssertEqual(getFlag.isEnabled(),item.expectation.isEnabled)
                    
                    if getFlag.isEnabled() {
                        
                        if let intVariable = getFlag.getVariable(key: "int", defaultValue: 1) as? Int {
                            
                            XCTAssertEqual(intVariable, item.expectation.intVariable)
                        }
                        
                        if let floatVariable = getFlag.getVariable(key: "float", defaultValue: 0.0) as? Float {
                            XCTAssertEqual(floatVariable, item.expectation.floatVariable)
                        }
                        
                        if let stringVariable = getFlag.getVariable(key: "string", defaultValue: "") as? String {
                            XCTAssertEqual(stringVariable, item.expectation.stringVariable)
                        }
                        
                        if let boolVariable = getFlag.getVariable(key: "boolean", defaultValue: false) as? Bool {
                            XCTAssertEqual(boolVariable, item.expectation.booleanVariable)
                        }
                        
                        if let jsonVariable = getFlag.getVariable(key: "json", defaultValue: false) as? JsonVariable {
                            XCTAssertEqual(jsonVariable.name, item.expectation.jsonVariable.name)
                        }
                    }
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testGetFlagWithStorage() {
        let expectation = XCTestExpectation(description: "Get flag with storage")
        let data = FlagTestCaseLoader.loadTestData(jsonFileName: GetFlagTestJson.jsonFileName)
        
        if let myData = data, let cases = myData.withStorage {

            for item in cases {
                
                storageService.emptyLocalStorageSuite()
                
                let fileForSetting = GetFlagTestJson.getJsonFileForSetting(input: item.settings)
                let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: fileForSetting.jsonFileName)
                
                let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
                let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
                let processedMockSetting = mockClient.processedSettings!
                
                let contextData = VWOUserContext(id: item.context.id!, customVariables: item.context.customVariables!)
                
                GetFlagAPI.getFlag(featureKey: item.featureKey, settings: processedMockSetting, context: contextData, hookManager: mockHookManager) { getFlag in
                    
                    XCTAssertNotNil(getFlag)
                    XCTAssertEqual(getFlag.isEnabled(),item.expectation.isEnabled)
                    
                    if getFlag.isEnabled() {
                        
                        if let intVariable = getFlag.getVariable(key: "int", defaultValue: 1) as? Int {
                            
                            XCTAssertEqual(intVariable, item.expectation.intVariable)
                        }
                        
                        if let floatVariable = getFlag.getVariable(key: "float", defaultValue: 0.0) as? Float {
                            XCTAssertEqual(floatVariable, item.expectation.floatVariable)
                        }
                        
                        if let stringVariable = getFlag.getVariable(key: "string", defaultValue: "") as? String {
                            XCTAssertEqual(stringVariable, item.expectation.stringVariable)
                        }
                        
                        if let boolVariable = getFlag.getVariable(key: "boolean", defaultValue: false) as? Bool {
                            XCTAssertEqual(boolVariable, item.expectation.booleanVariable)
                        }
                        
                        if let jsonVariable = getFlag.getVariable(key: "json", defaultValue: false) as? JsonVariable {
                            XCTAssertEqual(jsonVariable.name, item.expectation.jsonVariable.name)
                        }
                        
                        
                        if let testCaseStorageData = item.expectation.storageData {
                            
                            // compare test case storage values with user default values
                            if let userDefaultDict = self.storageService.getFeatureFromStorage(featureKey: item.featureKey, context: contextData) {
                                
                                do {
                                    let jsonData = try JSONSerialization.data(withJSONObject: userDefaultDict, options: [])
                                    let userDefaultStorageData = try JSONDecoder().decode(StorageDataTestCase.self, from: jsonData)
                                    let areEqual = compareStorageData(userDefaultStorageData, testCaseStorageData)
                                    XCTAssertEqual(areEqual, true, "Storage data is the same as the expected test case")
                                } catch {
                                    print("Error converting dictionary to StorageData: \(error)")

                                }
                            }
                        }
                    }
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    
    func testGetFlagWithFeatureNotFound() {
        
        let featureKey = "non_existent_feature"
        let expectation = XCTestExpectation(description: "Get flag with non-existent feature")
        storageService.emptyLocalStorageSuite()
        let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
        let processedMockSetting = mockClient.processedSettings!

        GetFlagAPI.getFlag(featureKey: featureKey, settings: processedMockSetting, context: mockContext, hookManager: mockHookManager) { getFlag in
            XCTAssertNotNil(getFlag)
            XCTAssertFalse(getFlag.isEnabled())
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGetFlagWithMEGRandomAlgo() {
        
        let expectation = XCTestExpectation(description: "Get flag with MEG random algo")
        
        let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.MegRandomAlgoCampaignSettings.jsonFileName)
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
        let processedMockSetting = mockClient.processedSettings!
        
        let data = FlagTestCaseLoader.loadTestData(jsonFileName: GetFlagTestJson.jsonFileName)
        if let myData = data, let megData = myData.megRandom {
            
            for item in megData {
                storageService.emptyLocalStorageSuite()
                
                let contextData = VWOUserContext(id: item.context.id!, customVariables: item.context.customVariables!)
                
                GetFlagAPI.getFlag(featureKey: item.featureKey, settings: processedMockSetting, context: contextData, hookManager: mockHookManager) { getFlag in
                    
                    XCTAssertNotNil(getFlag)
                    XCTAssertEqual(getFlag.isEnabled(),item.expectation.isEnabled)
                    
                    if let intVariable = getFlag.getVariable(key: "int", defaultValue: 1) as? Int {
                        
                        XCTAssertEqual(intVariable, item.expectation.intVariable)
                    }
                    
                    if let floatVariable = getFlag.getVariable(key: "float", defaultValue: 0.0) as? Float {
                        XCTAssertEqual(floatVariable, item.expectation.floatVariable)
                    }
                    
                    if let stringVariable = getFlag.getVariable(key: "string", defaultValue: "") as? String {
                        XCTAssertEqual(stringVariable, item.expectation.stringVariable)
                    }
                    
                    if let boolVariable = getFlag.getVariable(key: "boolean", defaultValue: false) as? Bool {
                        XCTAssertEqual(boolVariable, item.expectation.booleanVariable)
                    }
                    
                    if let jsonVariable = getFlag.getVariable(key: "json", defaultValue: false) as? JsonVariable {
                        XCTAssertEqual(jsonVariable.campaign, item.expectation.jsonVariable.campaign)
                    }
                    
                    expectation.fulfill()
                }
            }
            
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testGetFlagWithMEGAdvanceAlgo() {

        let expectation = XCTestExpectation(description: "Get flag with MEG random algo")
        
        let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.MegAdvanceAlgoCampaignSettings.jsonFileName)
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
        let processedMockSetting = mockClient.processedSettings!
        
        let data = FlagTestCaseLoader.loadTestData(jsonFileName: GetFlagTestJson.jsonFileName)
        if let myData = data, let megData = myData.megAdvance {
            for item in megData {
                storageService.emptyLocalStorageSuite()
                
                let contextData = VWOUserContext(id: item.context.id!, customVariables: item.context.customVariables!)

                GetFlagAPI.getFlag(featureKey: item.featureKey, settings: processedMockSetting, context: contextData, hookManager: mockHookManager) { getFlag in
                    XCTAssertNotNil(getFlag)
                    XCTAssertEqual(getFlag.isEnabled(),item.expectation.isEnabled)
                    
                    if let intVariable = getFlag.getVariable(key: "int", defaultValue: 1) as? Int {
                        
                        XCTAssertEqual(intVariable, item.expectation.intVariable)
                    }
                    
                    if let floatVariable = getFlag.getVariable(key: "float", defaultValue: 0.0) as? Float {
                        XCTAssertEqual(floatVariable, item.expectation.floatVariable)
                    }
                    
                    if let stringVariable = getFlag.getVariable(key: "string", defaultValue: "") as? String {
                        XCTAssertEqual(stringVariable, item.expectation.stringVariable)
                    }
                    
                    if let boolVariable = getFlag.getVariable(key: "boolean", defaultValue: false) as? Bool {
                        XCTAssertEqual(boolVariable, item.expectation.booleanVariable)
                    }
                    
                    if let jsonVariable = getFlag.getVariable(key: "json", defaultValue: false) as? JsonVariable {
                        XCTAssertEqual(jsonVariable.campaign, item.expectation.jsonVariable.campaign)
                    }
                    
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testGetFlagWithSameSalt() {

        let featureKey1 = "feature1"
        let featureKey2 = "feature2"

        let expectation = XCTestExpectation(description: "Get flag with same salt")

        let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.SettingsWithSameSalt.jsonFileName)
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
        let processedMockSetting = mockClient.processedSettings!

        let userIds = ["user_id_1", "user_id_2", "user_id_3", "user_id_4", "user_id_5"]

        for item in userIds {
            storageService.emptyLocalStorageSuite()

            let userContext = VWOUserContext(id: item, customVariables: [:])

            GetFlagAPI.getFlag(featureKey: featureKey1, settings: processedMockSetting, context: userContext, hookManager: mockHookManager) { getFlag1 in

                XCTAssertNotNil(getFlag1)

                GetFlagAPI.getFlag(featureKey: featureKey2, settings: processedMockSetting, context: userContext, hookManager: self.mockHookManager) { getFlag2 in

                    XCTAssertNotNil(getFlag2)
                    
                    let resultInt1 = getFlag1.getVariable(key: "int", defaultValue: 0) as! Int
                    let resultInt2 = getFlag2.getVariable(key: "int", defaultValue: 0) as! Int
                    XCTAssertEqual(resultInt1, resultInt2, "Variables should be same for flags with same salt")
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }
        
    func testGetFlagWithDifferentSalt() {
        let featureKey1 = "feature1"
        let featureKey2 = "feature2"
        let expectation = XCTestExpectation(description: "Get flag with different salt")
        
        let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.SettingsWithDifferentSalt.jsonFileName)
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
        let processedMockSetting = mockClient.processedSettings!

        let userIds = ["user_id_1", "user_id_3", "user_id_5", "user_id_7","user_id_9"]

        for item in userIds {
            
            storageService.emptyLocalStorageSuite()
            
            let userContext = VWOUserContext(id: item, customVariables: [:])
            
            GetFlagAPI.getFlag(featureKey: featureKey1, settings: processedMockSetting, context: userContext, hookManager: mockHookManager) { getFlag1 in

                XCTAssertNotNil(getFlag1)
                

                GetFlagAPI.getFlag(featureKey: featureKey2, settings: processedMockSetting, context: userContext, hookManager: self.mockHookManager) { getFlag2 in

                    XCTAssertNotNil(getFlag2)
                    
                    let resultInt1 = getFlag1.getVariable(key: "int", defaultValue: 0) as! Int
                    let resultInt2 = getFlag2.getVariable(key: "int", defaultValue: 0) as! Int
                    XCTAssertNotEqual(resultInt1, resultInt2, "Variables should be different for flags with different salts")
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }
}
