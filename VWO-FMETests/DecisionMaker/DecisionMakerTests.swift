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

class DecisionMakerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()

    }
    
    override func tearDown() {

        super.tearDown()
    }
    
    // MARK: - generateBucketValue Tests
    
    func testGenerateBucketValue() {
        let hashValue: UInt64 = 2147483647 // Example hash value
        let maxValue = 100
        let multiplier = 1
        
        let bucketValue = DecisionMaker.generateBucketValue(hashValue: hashValue, maxValue: maxValue, multiplier: multiplier)
        
        let ratio = Double(hashValue) / pow(2.0, 32.0)
        let expectedBucketValue = Int(floor((Double(maxValue) * ratio + 1) * Double(multiplier)))
        XCTAssertEqual(bucketValue, expectedBucketValue, "Bucket value should be calculated correctly")
    }
    
    func testGenerateBucketValueWithoutMultiplier() {
        let hashValue: UInt64 = 2147483647
        let maxValue = 100
        
        let bucketValue = DecisionMaker.generateBucketValue(hashValue: hashValue, maxValue: maxValue)
        
        let ratio = Double(hashValue) / pow(2.0, 32.0)
        let expectedBucketValue = Int(floor((Double(maxValue) * ratio + 1) * 1.0))
        XCTAssertEqual(bucketValue, expectedBucketValue, "Bucket value should be calculated correctly without multiplier")
    }
    
    // MARK: - getBucketValueForUser Tests
    
    func testGetBucketValueForUser() {
        let userId = "user123"
        let maxValue = 100
        
        let bucketValue = DecisionMaker.getBucketValueForUser(userId: userId, maxValue: maxValue)
        
        XCTAssertGreaterThanOrEqual(bucketValue, 1, "Bucket value should be at least 1")
        XCTAssertLessThanOrEqual(bucketValue, maxValue, "Bucket value should not exceed maxValue")
    }
    
    func testGetBucketValueForUserWithDefaultMaxValue() {
        let userId = "user123"
        
        let bucketValue = DecisionMaker.getBucketValueForUser(userId: userId)
        
        XCTAssertGreaterThanOrEqual(bucketValue, 1, "Bucket value should be at least 1")
        XCTAssertLessThanOrEqual(bucketValue, DecisionMaker.MAX_CAMPAIGN_VALUE, "Bucket value should not exceed default maxValue")
    }
    
    // MARK: - calculateBucketValue Tests
    
    func testCalculateBucketValue() {
        let str = "testString"
        let multiplier = 1
        let maxValue = 10000
        
        let bucketValue = DecisionMaker.calculateBucketValue(str: str, multiplier: multiplier, maxValue: maxValue)
        
        XCTAssertGreaterThanOrEqual(bucketValue, 1, "Bucket value should be at least 1")
        XCTAssertLessThanOrEqual(bucketValue, maxValue, "Bucket value should not exceed maxValue")
    }
    
    func testCalculateBucketValueWithDefaultParameters() {
        let str = "testString"
        
        let bucketValue = DecisionMaker.calculateBucketValue(str: str)
        
        XCTAssertGreaterThanOrEqual(bucketValue, 1, "Bucket value should be at least 1")
        XCTAssertLessThanOrEqual(bucketValue, DecisionMaker.MAX_TRAFFIC_VALUE, "Bucket value should not exceed default maxValue")
    }
    
    // MARK: - generateHashValue Tests
    
    func testGenerateHashValue() {
        let hashKey = "key123"
        
        let hashValue = DecisionMaker.generateHashValue(hashKey: hashKey)
        
        XCTAssertGreaterThanOrEqual(hashValue, 0, "Hash value should be non-negative")
        XCTAssertLessThanOrEqual(hashValue, UInt64(pow(2.0, 32.0)) - 1, "Hash value should be within 32-bit range")
    }
    
    func testGenerateHashValueConsistency() {
        let hashKey = "key123"
        
        let hashValue1 = DecisionMaker.generateHashValue(hashKey: hashKey)
        let hashValue2 = DecisionMaker.generateHashValue(hashKey: hashKey)
        
        XCTAssertEqual(hashValue1, hashValue2, "Hash value should be consistent for the same input")
    }
    
    func testGenerateHashValueDifferentInputs() {
        let hashKey1 = "key123"
        let hashKey2 = "key124"
        
        let hashValue1 = DecisionMaker.generateHashValue(hashKey: hashKey1)
        let hashValue2 = DecisionMaker.generateHashValue(hashKey: hashKey2)
        
        XCTAssertNotEqual(hashValue1, hashValue2, "Hash values should be different for different inputs")
    }
}
