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

class SegmentEvaluatorTests: XCTestCase {
    var segmentEvaluator: SegmentEvaluator!
    var mockContext: VWOUserContext!
    var mockSettings: Settings?
    var mockFeature: Feature?
    var testData: TestData!
    
    override func setUp() {
        super.setUp()
        segmentEvaluator = SegmentEvaluator()
        mockContext = VWOUserContext(id: "user-2", customVariables: [:])
        mockContext.userAgent = "VWO-FME (iOS 17.2)"
        
        mockSettings = nil
        mockFeature = nil
        
        segmentEvaluator.context = mockContext
        segmentEvaluator.settings = mockSettings
        segmentEvaluator.feature = mockFeature
        
        testData = TestDataLoader.loadTestData(jsonFileName: "SegmentEvaluatorTest")

        XCTAssertNotNil(testData, "Failed to load test data")
    }
    
    override func tearDown() {
        segmentEvaluator = nil
        mockContext = nil
        mockSettings = nil
        mockFeature = nil
        super.tearDown()
    }
    
    // MARK: - AND Operator Tests
    
    
    func testAndOperator() {
        guard let segmentationTests = testData.andOperator else {
            XCTFail("No test data found for case andOperator")
            return
        }
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "AND operator test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }
    
    // MARK: - Case Insensitive Equality Operand Tests

    
    func testCaseInsensitiveEqualityOperand() {
        
        guard let segmentationTests = testData.insensitiveEqualityOperand else {
            XCTFail("No test data found for case insensitiveEqualityOperand")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "InsensitiveEqualityOperand test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }
    
    // MARK: - Complex AND/OR Tests
    
    func testCaseComplexAndOrs() {
        
        guard let segmentationTests = testData.complexAndOrs else {
            XCTFail("No test data found for case complexAndOrs")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "ComplexAndOrs test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - Complex DSL Tests
    
    func testCaseComplexDsl() {
        
        guard let segmentationTestsComplexDsl1 = testData.complexDsl1 else {
            XCTFail("No test data found for case complexDsl1")
            return
        }
        
        for (key, testCase) in segmentationTestsComplexDsl1 {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "ComplexDsl1 test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
        
        
        guard let segmentationTestsComplexDsl2 = testData.complexDsl2 else {
            XCTFail("No test data found for case complexDsl2")
            return
        }
        
        for (key, testCase) in segmentationTestsComplexDsl2 {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "ComplexDsl2 test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
        
        guard let segmentationTestsComplexDsl3 = testData.complexDsl3 else {
            XCTFail("No test data found for case complexDsl3")
            return
        }
        
        for (key, testCase) in segmentationTestsComplexDsl3 {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "ComplexDsl3 test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
        
        
        guard let segmentationTestsComplexDsl4 = testData.complexDsl4 else {
            XCTFail("No test data found for case complexDsl4")
            return
        }
        
        for (key, testCase) in segmentationTestsComplexDsl4 {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "ComplexDsl4 test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - Contains Operand Tests
    
    func testCaseContainsOperand() {
        
        guard let segmentationTests = testData.containsOperand else {
            XCTFail("No test data found for case containsOperand")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "ContainsOperand test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - Ends With Operand Tests

    func testCaseEndsWithOperand() {
        
        guard let segmentationTests = testData.endsWithOperand else {
            XCTFail("No test data found for case endsWithOperand")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "EndsWithOperand test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }
    
    // MARK: - Equality Operand Tests
    
    func testCaseEqualityOperand() {
        
        guard let segmentationTests = testData.equalityOperand else {
            XCTFail("No test data found for case equalityOperand")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "EqualityOperand test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - New Cases for Decimal Mismatch Tests
    
    func testCaseNewCasesForDecimalMismatch() {
        
        guard let segmentationTests = testData.newCasesForDecimalMismatch else {
            XCTFail("No test data found for case newCasesForDecimalMismatch")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "NewCasesForDecimalMismatch test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - NOT Operator Tests
    
    func testCaseNotOperator() {
        
        guard let segmentationTests = testData.notOperator else {
            XCTFail("No test data found for case notOperator")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "NotOperator test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - OR Operator Tests
    
    func testCaseOrOperator() {
        
        guard let segmentationTests = testData.orOperator else {
            XCTFail("No test data found for case orOperator")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "OrOperator test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - Regex Tests
    
    func testCaseRegex() {
        
        guard let segmentationTests = testData.regex else {
            XCTFail("No test data found for case regex")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "Regex test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - Simple AND/OR Tests
    
    func testCaseSimpleAndOrs() {
        
        guard let segmentationTests = testData.simpleAndOrs else {
            XCTFail("No test data found for case simpleAndOrs")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "SimpleAndOrs test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }


    // MARK: - Starts With Operand Tests
    
    func testCaseStartsWithOperand() {
        
        guard let segmentationTests = testData.startsWithOperand else {
            XCTFail("No test data found for case startsWithOperand")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "StartsWithOperand test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - Special Characters Tests
    
    func testCaseSpecialCharacters() {
        
        guard let segmentationTests = testData.specialCharacters else {
            XCTFail("No test data found for case specialCharacters")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "specialCharacters test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - User Operand Evaluator Tests
    
    func testCaseUserOperandEvaluator() {
        
        guard let segmentationTests = testData.userOperandEvaluator else {
            XCTFail("No test data found for case userOperandEvaluator")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)
                
                XCTAssertEqual(result, testCase.expectation, "userOperandEvaluator test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }

    // MARK: - User Operand Evaluator with Custom Variables Tests
    
    func testCaseUserOperandEvaluatorWithCustomVariables() {
        
        guard let segmentationTests = testData.userOperandEvaluatorWithCustomVariables else {
            XCTFail("No test data found for case userOperandEvaluatorWithCustomVariables")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "userOperandEvaluatorWithCustomVariables test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }


    // MARK: - Greater Than Operator Tests
    
    func testCaseGreaterThanOperator() {
        
        guard let segmentationTests = testData.greaterThanOperator else {
            XCTFail("No test data found for case greaterThanOperator")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "greaterThanOperator test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }
    
    // MARK: - Less Than Operator Tests

    func testCaseLessThanOperator() {
        
        guard let segmentationTests = testData.lessThanOperator else {
            XCTFail("No test data found for case lessThanOperator")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "lessThanOperator test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }
    
    // MARK: - Greater Than Equal To Operator Tests
    
    func testCaseGreaterThanEqualToOperator() {
        
        guard let segmentationTests = testData.greaterThanEqualToOperator else {
            XCTFail("No test data found for case greaterThanEqualToOperator")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "greaterThanEqualToOperator test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }
    
    // MARK: - Less Than Equal To Operator Tests

    func testCaseLessThanEqualToOperator() {
        
        guard let segmentationTests = testData.lessThanEqualToOperator else {
            XCTFail("No test data found for case lessThanEqualToOperator")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "lessThanEqualToOperator test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }
    
    // MARK: - Empty Dsl Tests
    
    func testCaseEmptyDsl() {
        
        guard let segmentationTests = testData.emptyDsl else {
            XCTFail("No test data found for case emptyDsl")
            return
        }
        
        for (key, testCase) in segmentationTests {
            if let dsl = testCase.dsl,
               let customVariables = testCase.customVariables {
                let result = segmentEvaluator.isSegmentationValid(dsl: dsl, properties: customVariables)

                XCTAssertEqual(result, testCase.expectation, "emptyDsl test failed for test case \(key)")
            } else {
                XCTFail("DSL or custom variables missing for test case \(key)")
            }
        }
    }
}
