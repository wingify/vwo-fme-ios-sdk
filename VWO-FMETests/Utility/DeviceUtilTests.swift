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

class DeviceUtilTests: XCTestCase {
    
    var deviceUtil: DeviceUtil!
    
    override func setUp() {
        super.setUp()
        deviceUtil = DeviceUtil()
    }
    
    override func tearDown() {
        deviceUtil = nil
        super.tearDown()
    }
    
    // MARK: - Application Version Tests
    
    func testGetApplicationVersion() {
        let version = deviceUtil.getApplicationVersion()
        
        // Should not be empty
        XCTAssertFalse(version.isEmpty, "Application version should not be empty")
        
        // Should be a valid version string (contains at least one dot)
        XCTAssertTrue(version.contains("."), "Application version should contain version numbers separated by dots")
        
        // Should not contain invalid characters
        XCTAssertFalse(version.contains(" "), "Application version should not contain spaces")
    }
    
    // MARK: - OS Version Tests
    
    func testGetOsVersion() {
        let osVersion = deviceUtil.getOsVersion()
        
        // Should not be empty
        XCTAssertFalse(osVersion.isEmpty, "OS version should not be empty")
        
        // Should contain version information
        XCTAssertTrue(osVersion.contains("."), "OS version should contain version numbers")
        
        // Should be a reasonable length (not too short, not too long)
        XCTAssertGreaterThan(osVersion.count, 3, "OS version should be at least 4 characters")
        XCTAssertLessThan(osVersion.count, 50, "OS version should not be excessively long")
    }
    
    // MARK: - Manufacturer Tests
    
    func testGetManufacturer() {
        let manufacturer = deviceUtil.getManufacturer()
        
        // Should always return "Apple"
        XCTAssertEqual(manufacturer, "Apple", "Manufacturer should always be Apple")
        
        // Should not be empty
        XCTAssertFalse(manufacturer.isEmpty, "Manufacturer should not be empty")
    }
    
    // MARK: - Device Model Tests
    
    func testGetDeviceModel() {
        let deviceModel = deviceUtil.getDeviceModel()
        
        // Should not be empty
        XCTAssertFalse(deviceModel.isEmpty, "Device model should not be empty")
        
        // Should not be the unknown value
        XCTAssertNotEqual(deviceModel, "valueUnknown", "Device model should not be unknown")
        
        // Should be a reasonable length
        XCTAssertGreaterThan(deviceModel.count, 0, "Device model should have at least 1 character")
        XCTAssertLessThan(deviceModel.count, 100, "Device model should not be excessively long")
    }
    
    func testGetDeviceModel_ValidModel() {
        let deviceModel = deviceUtil.getDeviceModel()
        
        // Should be one of the common Apple device models
        let validModels = ["iPhone", "iPad", "iPod", "Mac", "Apple TV", "Apple Watch"]
        let isValidModel = validModels.contains { deviceModel.contains($0) }
        
        // Note: In simulator, it might return "iPhone" or "iPad" depending on the simulator
        // In real device, it should return the actual device model
        XCTAssertTrue(isValidModel || deviceModel.contains("Simulator"), 
                     "Device model should be a valid Apple device or simulator")
    }
    
    // MARK: - Locale Tests
    
    func testGetLocale() {
        let locale = deviceUtil.getLocale()
        
        // Should not be empty
        XCTAssertFalse(locale.isEmpty, "Locale should not be empty")
        
        // Should contain a language code (at least 2 characters)
        XCTAssertGreaterThanOrEqual(locale.count, 2, "Locale should have at least 2 characters")
        
        // Should not contain underscores (should be replaced with hyphens)
        XCTAssertFalse(locale.contains("_"), "Locale should not contain underscores")
        
        // Should contain a hyphen (language-region format)
        XCTAssertTrue(locale.contains("-"), "Locale should be in language-region format")
        
        // Should be in valid format (e.g., "en-US", "fr-FR")
        let localePattern = "^[a-z]{2}-[A-Z]{2}$"
        let localeRegex = try! NSRegularExpression(pattern: localePattern)
        let range = NSRange(location: 0, length: locale.utf16.count)
        let matches = localeRegex.matches(in: locale, options: [], range: range)
        
        XCTAssertFalse(matches.isEmpty, "Locale should match the expected format (e.g., en-US)")
    }
    
    func testGetLocale_Format() {
        let locale = deviceUtil.getLocale()
        
        // Should be in the format "language-region"
        let components = locale.components(separatedBy: "-")
        XCTAssertEqual(components.count, 2, "Locale should have exactly 2 components separated by hyphen")
        
        let languageCode = components[0]
        let regionCode = components[1]
        
        // Language code should be lowercase
        XCTAssertEqual(languageCode, languageCode.lowercased(), "Language code should be lowercase")
        
        // Region code should be uppercase
        XCTAssertEqual(regionCode, regionCode.uppercased(), "Region code should be uppercase")
        
        // Both should be 2 characters
        XCTAssertEqual(languageCode.count, 2, "Language code should be 2 characters")
        XCTAssertEqual(regionCode.count, 2, "Region code should be 2 characters")
    }
    
    // MARK: - All Device Details Tests
    
    func testGetAllDeviceDetails() {
        let deviceDetails = deviceUtil.getAllDeviceDetails()
        
        // Should return a dictionary
        XCTAssertNotNil(deviceDetails, "Device details should not be nil")
        
        // Should contain all expected keys
        let expectedKeys = [
            Constants.APP_VERSION,
            Constants.OS_VERSION,
            Constants.MANUFACTURER,
            Constants.DEVICE_MODEL,
            Constants.LOCALE
        ]
        
        for key in expectedKeys {
            XCTAssertTrue(deviceDetails.keys.contains(key), "Device details should contain key: \(key)")
        }
        
        // Should have exactly 5 keys
        XCTAssertEqual(deviceDetails.count, 5, "Device details should have exactly 5 keys")
    }
    
    func testGetAllDeviceDetails_Values() {
        let deviceDetails = deviceUtil.getAllDeviceDetails()
        
        // Check that each value is not empty
        for (key, value) in deviceDetails {
            XCTAssertFalse(value.isEmpty, "Value for key '\(key)' should not be empty")
        }
        
        // Check specific values
        XCTAssertEqual(deviceDetails[Constants.MANUFACTURER], "Apple", "Manufacturer should be Apple")
        
        // Check that app version matches the individual method
        XCTAssertEqual(deviceDetails[Constants.APP_VERSION], deviceUtil.getApplicationVersion(), 
                      "App version in device details should match individual method")
        
        // Check that OS version matches the individual method
        XCTAssertEqual(deviceDetails[Constants.OS_VERSION], deviceUtil.getOsVersion(), 
                      "OS version in device details should match individual method")
        
        // Check that device model matches the individual method
        XCTAssertEqual(deviceDetails[Constants.DEVICE_MODEL], deviceUtil.getDeviceModel(), 
                      "Device model in device details should match individual method")
        
        // Check that locale matches the individual method
        XCTAssertEqual(deviceDetails[Constants.LOCALE], deviceUtil.getLocale(), 
                      "Locale in device details should match individual method")
    }
    
    func testGetAllDeviceDetails_Consistency() {
        // Call multiple times to ensure consistency
        let details1 = deviceUtil.getAllDeviceDetails()
        let details2 = deviceUtil.getAllDeviceDetails()
        
        // Should return the same values
        XCTAssertEqual(details1, details2, "Device details should be consistent across multiple calls")
    }
    
    // MARK: - Integration Tests
    
    func testDeviceUtil_CompleteIntegration() {
        // Test that all individual methods work together
        let appVersion = deviceUtil.getApplicationVersion()
        let osVersion = deviceUtil.getOsVersion()
        let manufacturer = deviceUtil.getManufacturer()
        let deviceModel = deviceUtil.getDeviceModel()
        let locale = deviceUtil.getLocale()
        
        // All should be valid
        XCTAssertFalse(appVersion.isEmpty, "App version should not be empty")
        XCTAssertFalse(osVersion.isEmpty, "OS version should not be empty")
        XCTAssertEqual(manufacturer, "Apple", "Manufacturer should be Apple")
        XCTAssertFalse(deviceModel.isEmpty, "Device model should not be empty")
        XCTAssertFalse(locale.isEmpty, "Locale should not be empty")
        
        // Test that getAllDeviceDetails returns the same values
        let allDetails = deviceUtil.getAllDeviceDetails()
        XCTAssertEqual(allDetails[Constants.APP_VERSION], appVersion)
        XCTAssertEqual(allDetails[Constants.OS_VERSION], osVersion)
        XCTAssertEqual(allDetails[Constants.MANUFACTURER], manufacturer)
        XCTAssertEqual(allDetails[Constants.DEVICE_MODEL], deviceModel)
        XCTAssertEqual(allDetails[Constants.LOCALE], locale)
    }
    
    // MARK: - Performance Tests
    
    func testGetAllDeviceDetails_Performance() {
        measure {
            for _ in 0..<100 {
                _ = deviceUtil.getAllDeviceDetails()
            }
        }
    }
    
    func testIndividualMethods_Performance() {
        measure {
            for _ in 0..<100 {
                _ = deviceUtil.getApplicationVersion()
                _ = deviceUtil.getOsVersion()
                _ = deviceUtil.getManufacturer()
                _ = deviceUtil.getDeviceModel()
                _ = deviceUtil.getLocale()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testDeviceUtil_MultipleInstances() {
        let deviceUtil1 = DeviceUtil()
        let deviceUtil2 = DeviceUtil()
        
        // Both instances should return the same values
        XCTAssertEqual(deviceUtil1.getApplicationVersion(), deviceUtil2.getApplicationVersion())
        XCTAssertEqual(deviceUtil1.getOsVersion(), deviceUtil2.getOsVersion())
        XCTAssertEqual(deviceUtil1.getManufacturer(), deviceUtil2.getManufacturer())
        XCTAssertEqual(deviceUtil1.getDeviceModel(), deviceUtil2.getDeviceModel())
        XCTAssertEqual(deviceUtil1.getLocale(), deviceUtil2.getLocale())
    }
    
    func testDeviceUtil_ThreadSafety() {
        let expectation = XCTestExpectation(description: "Thread safety test")
        let queue = DispatchQueue(label: "test.queue", attributes: .concurrent)
        
        var results: [String] = []
        let group = DispatchGroup()
        
        for _ in 0..<10 {
            group.enter()
            queue.async {
                let result = self.deviceUtil.getAllDeviceDetails()
                results.append(result[Constants.MANUFACTURER] ?? "")
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // All results should be "Apple"
            let allApple = results.allSatisfy { $0 == "Apple" }
            XCTAssertTrue(allApple, "All manufacturer values should be Apple")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
} 