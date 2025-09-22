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

class SegmentOperandEvaluatorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - evaluateStringOperandDSL Tests
    
    func testEvaluateStringOperandDSL_EqualValue() {
        // Test basic equality
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "test", value: "test"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "test", value: "different"))
        
    }
    
    func testEvaluateStringOperandDSL_LowerValue() {
        // Test case insensitive comparison
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lower(TEST)", value: "test"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lower(test)", value: "TEST"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lower(Test)", value: "test"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lower(test)", value: "different"))
    }
    
    func testEvaluateStringOperandDSL_WildcardStartingStar() {
        // Test wildcard with starting star
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(*test)", value: "hellotest"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(*test)", value: "test"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(*test)", value: "testhello"))
    }
    
    func testEvaluateStringOperandDSL_WildcardEndingStar() {
        // Test wildcard with ending star
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(test*)", value: "testhello"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(test*)", value: "test"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(test*)", value: "hellotest"))
    }
    
    func testEvaluateStringOperandDSL_WildcardStartingEndingStar() {
        // Test wildcard with both starting and ending stars
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(*test*)", value: "hellotestworld"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(*test*)", value: "test"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(*test*)", value: "hello"))
    }
    
    func testEvaluateStringOperandDSL_RegexValue() {
        // Test regex patterns
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "regex(test.*)", value: "test123"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "regex(\\d+)", value: "123"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "regex(test.*)", value: "different"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "regex(\\d+)", value: "abc"))
    }
    
    func testEvaluateStringOperandDSL_GreaterThanValue() {
        // Test numeric comparisons
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gt(5)", value: "10"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gt(5.5)", value: "10.5"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gt(10)", value: "5"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gt(10)", value: "10"))
        
        // Test version comparisons
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gt(17.2)", value: "17.2.1"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gt(17.1)", value: "17.2"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gt(17.2.0)", value: "17.2.1"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gt(17.2.1)", value: "17.2"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gt(17.2)", value: "17.2"))
    }
    
    func testEvaluateStringOperandDSL_GreaterThanEqualToValue() {
        // Test greater than or equal
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(5)", value: "10"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(10)", value: "10"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(10)", value: "5"))
        
        // Test version comparisons
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(17.2)", value: "17.2.1"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(17.2)", value: "17.2"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(17.1)", value: "17.2"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(17.2.1)", value: "17.2"))
    }
    
    func testEvaluateStringOperandDSL_LessThanValue() {
        // Test less than
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(10)", value: "5"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(10.5)", value: "5.5"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(5)", value: "10"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(10)", value: "10"))
        
        // Test version comparisons
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(17.2.1)", value: "17.2"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(17.3)", value: "17.2"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(17.2.1)", value: "17.2.0"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(17.2)", value: "17.2.1"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(17.2)", value: "17.2"))
    }
    
    func testEvaluateStringOperandDSL_LessThanEqualToValue() {
        // Test less than or equal
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lte(10)", value: "5"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lte(10)", value: "10"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lte(5)", value: "10"))
        
        // Test version comparisons
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lte(17.2.1)", value: "17.2"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lte(17.2)", value: "17.2"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lte(17.3)", value: "17.2"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lte(17.2)", value: "17.2.1"))
    }
    
    func testEvaluateStringOperandDSL_InvalidOperand() {
        // Test with invalid operand that doesn't match any pattern
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "invalid(operand)", value: "test"))
    }
    
    func testEvaluateStringOperandDSL_EmptyValues() {
        // Test with empty values
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "", value: ""))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "", value: "test"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "test", value: ""))
    }
    
    func testEvaluateStringOperandDSL_WhitespaceHandling() {
        // Test whitespace handling
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "  test  ", value: "test"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "test", value: "  test  "))
    }
    
    // MARK: - New Enum Cases Tests
    
    func testSegmentOperatorValueEnum_NewCases() {
        // Test the new cases you added
        XCTAssertEqual(SegmentOperatorValueEnum.manufacturer.rawValue, "manufacturer")
        XCTAssertEqual(SegmentOperatorValueEnum.device_model.rawValue, "device_model")
        XCTAssertEqual(SegmentOperatorValueEnum.locale.rawValue, "locale")
        XCTAssertEqual(SegmentOperatorValueEnum.app_version.rawValue, "app_version")
        XCTAssertEqual(SegmentOperatorValueEnum.os_version.rawValue, "os_version")
    }
    
    func testSegmentOperatorValueEnum_FromValue() {
        // Test the fromValue method with new cases
        do {
            let manufacturer = try SegmentOperatorValueEnum.fromValue("manufacturer")
            XCTAssertEqual(manufacturer, .manufacturer)
            
            let deviceModel = try SegmentOperatorValueEnum.fromValue("device_model")
            XCTAssertEqual(deviceModel, .device_model)
            
            let locale = try SegmentOperatorValueEnum.fromValue("locale")
            XCTAssertEqual(locale, .locale)
            
            let appVersion = try SegmentOperatorValueEnum.fromValue("app_version")
            XCTAssertEqual(appVersion, .app_version)
            
            let osVersion = try SegmentOperatorValueEnum.fromValue("os_version")
            XCTAssertEqual(osVersion, .os_version)
        } catch {
            XCTFail("fromValue should not throw error for valid values")
        }
    }
    
    func testSegmentOperatorValueEnum_InvalidValue() {
        // Test with invalid value
        do {
            _ = try SegmentOperatorValueEnum.fromValue("invalid_value")
            XCTFail("fromValue should throw error for invalid value")
        } catch {
            // Expected to throw error
            XCTAssertTrue(error.localizedDescription.contains("No enum constant with value"))
        }
    }
    
    // MARK: - Integration Tests for New Device Properties
    
    func testEvaluateStringOperandDSL_Manufacturer() {
        // Test manufacturer property evaluation
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "Apple", value: "Apple"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lower(apple)", value: "Apple"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "Apple", value: "Samsung"))
    }
    
    func testEvaluateStringOperandDSL_DeviceModel() {
        // Test device model property evaluation
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "iPhone", value: "iPhone"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(*iPhone*)", value: "iPhone 14 Pro"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "iPhone", value: "iPad"))
    }
    
    func testEvaluateStringOperandDSL_Locale() {
        // Test locale property evaluation
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "en_US", value: "en_US"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "wildcard(en*)", value: "en_US"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "en_US", value: "fr_FR"))
    }
    
    func testEvaluateStringOperandDSL_AppVersion() {
        // Test app version property evaluation with version comparisons
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "1.0.0", value: "1.0.0"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(1.0.0)", value: "2.0.0"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(1.0.0)", value: "1.5.0"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(2.0.0)", value: "1.5.0"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(2.0.0)", value: "1.9.9"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(2.0.0)", value: "1.0.0"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(2.0.0)", value: "1.9.9"))
    }
    
    func testEvaluateStringOperandDSL_OSVersion() {
        // Test OS version property evaluation with version comparisons
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "17.0", value: "17.0"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(16.0)", value: "17.2"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(17.0)", value: "17.2"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(17.2)", value: "17.2.1"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(18.0)", value: "17.2"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(17.3)", value: "17.2"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(18.0)", value: "17.2"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gte(17.3)", value: "17.2"))
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testEvaluateStringOperandDSL_InvalidRegex() {
        // Test with invalid regex pattern
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "regex([invalid)", value: "test"))
    }
    
    func testEvaluateStringOperandDSL_NonNumericComparison() {
        // Test numeric comparison with non-numeric values
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "gt(5)", value: "abc"))
        XCTAssertFalse(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lt(10)", value: "xyz"))
    }
    
    // MARK: - Version Comparison Tests
    
    func testVersionComparison() {
        // Test the version comparison function directly
        XCTAssertEqual(SegmentOperandEvaluator.compareVersions("17.2", "17.2.1"), -1) // 17.2 < 17.2.1
        XCTAssertEqual(SegmentOperandEvaluator.compareVersions("17.2.1", "17.2"), 1)   // 17.2.1 > 17.2
        XCTAssertEqual(SegmentOperandEvaluator.compareVersions("17.2", "17.2"), 0)     // 17.2 == 17.2
        XCTAssertEqual(SegmentOperandEvaluator.compareVersions("17.1", "17.2"), -1)    // 17.1 < 17.2
        XCTAssertEqual(SegmentOperandEvaluator.compareVersions("17.3", "17.2"), 1)     // 17.3 > 17.2
        XCTAssertEqual(SegmentOperandEvaluator.compareVersions("17.2.0", "17.2.1"), -1) // 17.2.0 < 17.2.1
        XCTAssertEqual(SegmentOperandEvaluator.compareVersions("17.2.1", "17.2.0"), 1)  // 17.2.1 > 17.2.0
        XCTAssertEqual(SegmentOperandEvaluator.compareVersions("17.2", "17.2.0"), 0)   // 17.2 == 17.2.0 (should be equal)
        XCTAssertEqual(SegmentOperandEvaluator.compareVersions("17.2.0", "17.2"), 0)    // 17.2.0 == 17.2 (should be equal)
    }
    
    func testIsVersionString() {
        // Test the version string detection function
        XCTAssertTrue(SegmentOperandEvaluator.isVersionString("17.2"))
        XCTAssertTrue(SegmentOperandEvaluator.isVersionString("17.2.1"))
        XCTAssertTrue(SegmentOperandEvaluator.isVersionString("1.0.0"))
        XCTAssertTrue(SegmentOperandEvaluator.isVersionString("2.5.10"))
        XCTAssertFalse(SegmentOperandEvaluator.isVersionString("17"))
        XCTAssertFalse(SegmentOperandEvaluator.isVersionString("abc"))
        XCTAssertFalse(SegmentOperandEvaluator.isVersionString(""))
    }
    
    func testEvaluateStringOperandDSL_SpecialCharacters() {
        // Test with special characters
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "test@123", value: "test@123"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "regex(\\w+@\\w+)", value: "test@example.com"))
    }
    
    func testEvaluateStringOperandDSL_UnicodeCharacters() {
        // Test with unicode characters
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "café", value: "café"))
        XCTAssertTrue(SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "lower(CAFÉ)", value: "café"))
    }
    
    // MARK: - Performance Tests
    
    func testEvaluateStringOperandDSL_Performance() {
        // Test performance with multiple evaluations
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<1000 {
            _ = SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: "test", value: "test")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Should complete within reasonable time (adjust threshold as needed)
        XCTAssertLessThan(executionTime, 1.0, "Performance test took too long: \(executionTime) seconds")
    }
    
    // MARK: - SegmentOperandRegexEnum Tests
    
    func testSegmentOperandRegexEnum_AllCases() {
        // Test all regex patterns exist and are valid
        XCTAssertNotNil(SegmentOperandRegexEnum.lower.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.lowerMatch.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.wildcard.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.wildcardMatch.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.regex.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.regexMatch.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.startingStar.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.endingStar.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.greaterThanMatch.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.greaterThanEqualToMatch.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.lessThanMatch.rawValue)
        XCTAssertNotNil(SegmentOperandRegexEnum.lessThanEqualToMatch.rawValue)
    }
    
    func testSegmentOperandRegexEnum_RegexPatterns() {
        // Test that regex patterns are valid and can be compiled
        let patterns = [
            SegmentOperandRegexEnum.lower.rawValue,
            SegmentOperandRegexEnum.lowerMatch.rawValue,
            SegmentOperandRegexEnum.wildcard.rawValue,
            SegmentOperandRegexEnum.wildcardMatch.rawValue,
            SegmentOperandRegexEnum.regex.rawValue,
            SegmentOperandRegexEnum.regexMatch.rawValue,
            SegmentOperandRegexEnum.startingStar.rawValue,
            SegmentOperandRegexEnum.endingStar.rawValue,
            SegmentOperandRegexEnum.greaterThanMatch.rawValue,
            SegmentOperandRegexEnum.greaterThanEqualToMatch.rawValue,
            SegmentOperandRegexEnum.lessThanMatch.rawValue,
            SegmentOperandRegexEnum.lessThanEqualToMatch.rawValue
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                XCTAssertNotNil(regex, "Failed to compile regex pattern: \(pattern)")
            } catch {
                XCTFail("Invalid regex pattern: \(pattern), error: \(error)")
            }
        }
    }
    
    func testSegmentOperandRegexEnum_PatternMatching() {
        // Test that patterns match expected strings
        XCTAssertTrue(SegmentUtil.matchWithRegex(string: "lower(test)", regex: SegmentOperandRegexEnum.lowerMatch.rawValue))
        XCTAssertTrue(SegmentUtil.matchWithRegex(string: "wildcard(*test*)", regex: SegmentOperandRegexEnum.wildcardMatch.rawValue))
        XCTAssertTrue(SegmentUtil.matchWithRegex(string: "regex(pattern)", regex: SegmentOperandRegexEnum.regexMatch.rawValue))
        XCTAssertTrue(SegmentUtil.matchWithRegex(string: "*test", regex: SegmentOperandRegexEnum.startingStar.rawValue))
        XCTAssertTrue(SegmentUtil.matchWithRegex(string: "test*", regex: SegmentOperandRegexEnum.endingStar.rawValue))
        XCTAssertTrue(SegmentUtil.matchWithRegex(string: "gt(5)", regex: SegmentOperandRegexEnum.greaterThanMatch.rawValue))
        XCTAssertTrue(SegmentUtil.matchWithRegex(string: "gte(10)", regex: SegmentOperandRegexEnum.greaterThanEqualToMatch.rawValue))
        XCTAssertTrue(SegmentUtil.matchWithRegex(string: "lt(5)", regex: SegmentOperandRegexEnum.lessThanMatch.rawValue))
        XCTAssertTrue(SegmentUtil.matchWithRegex(string: "lte(10)", regex: SegmentOperandRegexEnum.lessThanEqualToMatch.rawValue))
        
        // Test negative cases
        XCTAssertFalse(SegmentUtil.matchWithRegex(string: "test", regex: SegmentOperandRegexEnum.lowerMatch.rawValue))
        XCTAssertFalse(SegmentUtil.matchWithRegex(string: "invalid", regex: SegmentOperandRegexEnum.wildcardMatch.rawValue))
    }
    
    func testSegmentOperandRegexEnum_ValueExtraction() {
        // Test value extraction from patterns
        let lowerValue = SegmentOperandEvaluator.extractOperandValue("lower(test)", SegmentOperandRegexEnum.lowerMatch.rawValue)
        XCTAssertEqual(lowerValue, "test")
        
        let wildcardValue = SegmentOperandEvaluator.extractOperandValue("wildcard(*test*)", SegmentOperandRegexEnum.wildcardMatch.rawValue)
        XCTAssertEqual(wildcardValue, "*test*")
        
        let regexValue = SegmentOperandEvaluator.extractOperandValue("regex(pattern)", SegmentOperandRegexEnum.regexMatch.rawValue)
        XCTAssertEqual(regexValue, "pattern")
        
        let gtValue = SegmentOperandEvaluator.extractOperandValue("gt(5.5)", SegmentOperandRegexEnum.greaterThanMatch.rawValue)
        XCTAssertEqual(gtValue, "5.5")
        
        let gteValue = SegmentOperandEvaluator.extractOperandValue("gte(10.0)", SegmentOperandRegexEnum.greaterThanEqualToMatch.rawValue)
        XCTAssertEqual(gteValue, "10.0")
        
        let ltValue = SegmentOperandEvaluator.extractOperandValue("lt(3.14)", SegmentOperandRegexEnum.lessThanMatch.rawValue)
        XCTAssertEqual(ltValue, "3.14")
        
        let lteValue = SegmentOperandEvaluator.extractOperandValue("lte(7.5)", SegmentOperandRegexEnum.lessThanEqualToMatch.rawValue)
        XCTAssertEqual(lteValue, "7.5")
    }
} 
