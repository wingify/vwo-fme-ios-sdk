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

final class TrackEventTests: XCTestCase {
    
    // MARK: - Properties
    
    var mockSettings: Settings!
    var mockContext: VWOUserContext!
    var mockHookManager: MockHooksManager!
    var mockBuilder: VWOBuilder!
    var mockOptions: VWOInitOptions!
    var mockCallback: MockIntegrationCallback!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockContext = VWOUserContext(id: "123", customVariables: [:])
        mockCallback = MockIntegrationCallback()
        mockHookManager = MockHooksManager(callback: mockCallback)
    }
    
    override func tearDown() {
        mockSettings = nil
        mockContext = nil
        mockHookManager = nil
        mockCallback = nil
        super.tearDown()
    }
    
    func testTrackEventSuccess() {
        mockHookManager.clear()
        let eventName = "custom1"
        let eventProperties = ["key": "value"]
        let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456, integrations: mockCallback)
        let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
        let processedMockSetting = mockClient.processedSettings!
        
        TrackEventAPI.track(settings: processedMockSetting, eventName: eventName, context: mockContext, eventProperties: eventProperties, hooksManager: mockHookManager)
        
        XCTAssertNotNil(mockHookManager.get())
        XCTAssertTrue(mockHookManager.setCalled, "HooksManager set should be called")
        XCTAssertTrue(mockHookManager.executeCalled, "HooksManager execute should be called")
        XCTAssertTrue(mockCallback.executeCalled, "IntegrationCallback execute should be called")
        XCTAssertEqual(mockHookManager.decision?["eventName"] as? String, eventName)
        XCTAssertEqual(mockHookManager.decision?["api"] as? String, ApiEnum.track.rawValue)
    }
    
    func testTrackEventNotFound() {
        mockHookManager.clear()
        let eventName = "nonexistent_event"
        let eventProperties = ["key": "value"]
        let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456, integrations: mockCallback)
        let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
        let processedMockSetting = mockClient.processedSettings!
        
        TrackEventAPI.track(settings: processedMockSetting, eventName: eventName, context: mockContext, eventProperties: eventProperties, hooksManager: mockHookManager)
        
        XCTAssertNil(mockHookManager.get())
        XCTAssertFalse(mockHookManager.setCalled, "HooksManager set should NOT be called")
        XCTAssertFalse(mockHookManager.executeCalled, "HooksManager execute should NOT be called")
        XCTAssertFalse(mockCallback.executeCalled, "IntegrationCallback execute should NOT be called")
        XCTAssertNil(mockHookManager.decision)
    }
    
    func testTrackEventWithMissingId() {
        mockHookManager.clear()
        let eventName = "custom1"
        let eventProperties = ["key": "value"]
        let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456, integrations: mockCallback)
        let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
        let contextData = VWOUserContext(id: "", customVariables: [:])
        
        mockClient.trackEvent(eventName: eventName, context: contextData, eventProperties: eventProperties)
        
        XCTAssertNil(mockHookManager.get())
        XCTAssertFalse(mockHookManager.setCalled, "HooksManager set should NOT be called")
        XCTAssertFalse(mockHookManager.executeCalled, "HooksManager execute should NOT be called")
        XCTAssertFalse(mockCallback.executeCalled, "IntegrationCallback execute should NOT be called")
        XCTAssertNil(mockHookManager.decision)
    }
    
    func testTrackEventWithNilId() {
        mockHookManager.clear()
        let eventName = "custom1"
        let eventProperties = ["key": "value"]
        let mockSettings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)
        let mockOptions: VWOInitOptions = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456, integrations: mockCallback)
        let mockClient = VWOClient(options: mockOptions, settingObj: mockSettings)
        let contextData = VWOUserContext(id: nil, customVariables: [:])
        
        mockClient.trackEvent(eventName: eventName, context: contextData, eventProperties: eventProperties)
        
        XCTAssertNil(mockHookManager.get())
        XCTAssertFalse(mockHookManager.setCalled, "HooksManager set should NOT be called")
        XCTAssertFalse(mockHookManager.executeCalled, "HooksManager execute should NOT be called")
        XCTAssertFalse(mockCallback.executeCalled, "IntegrationCallback execute should NOT be called")
        XCTAssertNil(mockHookManager.decision)
    }
}
