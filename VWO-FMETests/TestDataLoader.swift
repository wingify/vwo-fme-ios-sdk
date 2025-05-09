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

import Foundation
@testable import VWO_FME

struct TestCase: Codable {
    let dsl: [String: CodableValue]?
    let expectation: Bool
    var customVariables: [String: Any]? = [:]
    let userAgent: String?
    let location: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case dsl
        case expectation
        case customVariables
        case userAgent
        case location
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dsl = try container.decodeIfPresent([String: CodableValue].self, forKey: .dsl)
        self.expectation = try container.decode(Bool.self, forKey: .expectation)
        self.userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent)
        self.location = try container.decodeIfPresent([String: String].self, forKey: .location)
        do {
            if let customVariablesEncoded = try container.decodeIfPresent([String: CodableValue].self, forKey: .customVariables) {
                let dataMapped = customVariablesEncoded.mapValues { $0.toJSONCompatible() }
                self.customVariables = dataMapped
            } else {
                self.customVariables = [:]
            }
        } catch {
            self.customVariables = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(dsl, forKey: .dsl)
        try container.encode(expectation, forKey: .expectation)
        try container.encodeIfPresent(userAgent, forKey: .userAgent)
        try container.encodeIfPresent(location, forKey: .location)

        if let customVariables = customVariables {
            let data = try JSONSerialization.data(withJSONObject: customVariables, options: [])
            try container.encode(data, forKey: .customVariables)
        }
    }
}

struct TestData: Codable {
    let andOperator: [String: TestCase]?
    let insensitiveEqualityOperand: [String: TestCase]?
    let complexAndOrs: [String: TestCase]?
    let complexDsl1: [String: TestCase]?
    let complexDsl2: [String: TestCase]?
    let complexDsl3: [String: TestCase]?
    let complexDsl4: [String: TestCase]?
    let containsOperand: [String: TestCase]?
    let endsWithOperand: [String: TestCase]?
    let equalityOperand: [String: TestCase]?
    let newCasesForDecimalMismatch: [String: TestCase]?
    let notOperator: [String: TestCase]?
    let orOperator: [String: TestCase]?
    let regex: [String: TestCase]?
    let simpleAndOrs: [String: TestCase]?
    let startsWithOperand: [String: TestCase]?
    let specialCharacters: [String: TestCase]?
    let userOperandEvaluator: [String: TestCase]?
    let userOperandEvaluatorWithCustomVariables: [String: TestCase]?
    let greaterThanOperator: [String: TestCase]?
    let lessThanOperator: [String: TestCase]?
    let greaterThanEqualToOperator: [String: TestCase]?
    let lessThanEqualToOperator: [String: TestCase]?
    let emptyDsl: [String: TestCase]?
    let userAgentDsl: [String: TestCase]?

    
    enum CodingKeys: String, CodingKey {
        case andOperator = "and_operator"
        case insensitiveEqualityOperand = "case_insensitive_equality_operand"
        case complexAndOrs = "complex_and_ors"
        case complexDsl1 = "complex_dsl_1"
        case complexDsl2 = "complex_dsl_2"
        case complexDsl3 = "complex_dsl_3"
        case complexDsl4 = "complex_dsl_4"
        case containsOperand = "contains_operand"
        case endsWithOperand = "ends_with_operand"
        case equalityOperand = "equality_operand"
        case newCasesForDecimalMismatch = "new_cases_for_decimal_mismatch"
        case notOperator = "not_operator"
        case orOperator = "or_operator"
        case regex = "regex"
        case simpleAndOrs = "simple_and_ors"
        case startsWithOperand = "starts_with_operand"
        case specialCharacters = "special_characters"
        case userOperandEvaluator = "user_operand_evaluator"
        case userOperandEvaluatorWithCustomVariables = "user_operand_evaluator_with_customVariables"
        case greaterThanOperator = "greater_than_operator"
        case lessThanOperator = "less_than_operator"
        case greaterThanEqualToOperator = "greater_than_equal_to_operator"
        case lessThanEqualToOperator = "less_than_equal_to_operator"
        case emptyDsl = "empty_dsl"
        case userAgentDsl = "ua_agent_test"

    }
}

class TestDataLoader {
    
    static func loadTestData(jsonFileName: String) -> TestData? {
        guard let url = Bundle(for: SegmentEvaluatorTests.self).url(forResource: jsonFileName, withExtension: "json") else {
            print("Failed to find file: \(jsonFileName).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(TestData.self, from: data)
        } catch {
            print("Error loading or decoding JSON: \(error)")
            return nil
        }
    }
}
