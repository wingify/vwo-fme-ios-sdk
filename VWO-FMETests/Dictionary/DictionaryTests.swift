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


final class DictionaryTests: XCTestCase {
    
    
    func testPropsToDictionary() {

        var props = Props()
        props.vwoSdkName = "TestSDK"
        props.vwoSdkVersion = "1.0.0"
        props.vwoEnvKey = "TestEnvKey"
        props.variation = "A"
        props.id = 123
        props.isFirst = 1
        props.isMII = true
        props.isCustomEvent = true
        props.product = "TestProduct"
        props.additionalProperties = ["extraKey": "extraValue"]
        props.data = ["dataKey": "dataValue"]
        props.vwoMeta = ["stats" : "data"]
        
        let mirror = Mirror(reflecting: props)
        let numberOfVariables = mirror.children.count
        
        let dict = props.toDictionary()
        XCTAssertEqual(dict["vwo_sdkName"] as? String, "TestSDK")
        XCTAssertEqual(dict["vwo_sdkVersion"] as? String, "1.0.0")
        XCTAssertEqual(dict["vwo_envKey"] as? String, "TestEnvKey")
        XCTAssertEqual(dict["variation"] as? String, "A")
        XCTAssertEqual(dict["id"] as? Int, 123)
        XCTAssertEqual(dict["isFirst"] as? Int, 1)
        XCTAssertEqual(dict["isMII"] as? Bool, true)
        XCTAssertEqual(dict["isCustomEvent"] as? Bool, true)
        XCTAssertEqual(dict["product"] as? String, "TestProduct")
        XCTAssertEqual(dict["extraKey"] as? String, "extraValue")
        XCTAssertEqual((dict["data"] as? [String: Any])?["dataKey"] as? String, "dataValue")
        XCTAssertEqual(numberOfVariables, dict.keys.count)
    }
    
    func testSetProps() {
        var visitor = Visitor(props: [:])
        let newProps: [String: Any] = ["name": "John Doe", "age": 30]
        
        visitor.setProps(newProps)
        
        XCTAssertEqual(visitor.props["name"] as? String, "John Doe")
        XCTAssertEqual(visitor.props["age"] as? Int, 30)
    }
    
    func testToDictionary() {
        let props: [String: Any] = ["name": "Jane Doe", "age": 25]
        let visitor = Visitor(props: props)
        
        let dict = visitor.toDictionary()
        
        XCTAssertNotNil(dict["props"])
        
        if let propsDict = dict["props"] as? [String: Any] {
            XCTAssertEqual(propsDict["name"] as? String, "Jane Doe")
            XCTAssertEqual(propsDict["age"] as? Int, 25)
        } else {
            XCTFail("props should be a dictionary")
        }
    }
    
    func testEmptyProps() {
        let visitor = Visitor(props: [:])
        
        let dict = visitor.toDictionary()
        
        XCTAssertNotNil(dict["props"])
        
        if let propsDict = dict["props"] as? [String: Any] {
            XCTAssertTrue(propsDict.isEmpty)
        } else {
            XCTFail("props should be a dictionary")
        }
    }
    
    func testInitialization() {
        let iValue = "value1"
        let rValue = "value2"
        let aValue = "value3"
        
        let settingsQueryParams = SettingsQueryParams(i: iValue, r: rValue, a: aValue)
        
        XCTAssertEqual(settingsQueryParams.queryParams["i"], iValue, "The 'i' parameter should be set correctly.")
        XCTAssertEqual(settingsQueryParams.queryParams["r"], rValue, "The 'r' parameter should be set correctly.")
        XCTAssertEqual(settingsQueryParams.queryParams["a"], aValue, "The 'a' parameter should be set correctly.")
    }
    
    func testQueryParamsDictionary() {
        let iValue = "test1"
        let rValue = "test2"
        let aValue = "test3"
        
        let settingsQueryParams = SettingsQueryParams(i: iValue, r: rValue, a: aValue)
        
        let expectedDictionary: [String: String] = [
            "i": iValue,
            "r": rValue,
            "a": aValue
        ]
        
        XCTAssertEqual(settingsQueryParams.queryParams, expectedDictionary, "The queryParams dictionary should match the expected dictionary.")
    }
}



class SettingsQueryParamsTests: XCTestCase {

    func testQueryParamsDictionary() {
        let iValue = "test1"
        let rValue = "test2"
        let aValue = "test3"
        
        let settingsQueryParams = SettingsQueryParams(i: iValue, r: rValue, a: aValue)
        
        let expectedDictionary: [String: String] = [
            "i": iValue,
            "r": rValue,
            "a": aValue
        ]

        XCTAssertEqual(settingsQueryParams.queryParams, expectedDictionary, "The queryParams dictionary should match the expected dictionary.")
        XCTAssertEqual(settingsQueryParams.queryParams.count, 3, "There should be exactly three query parameters.")
    }
}

class EventBatchQueryParamsTests: XCTestCase {
    
    func testQueryParamsDictionary() {
        let i = "testID"
        let env = "production"
        let a = "action"

        let eventBatchQueryParams = EventBatchQueryParams(i: i, env: env, a: a)

        XCTAssertEqual(eventBatchQueryParams.queryParams["i"], i, "The 'i' parameter should be correctly set.")
        XCTAssertEqual(eventBatchQueryParams.queryParams["env"], env, "The 'env' parameter should be correctly set.")
        XCTAssertEqual(eventBatchQueryParams.queryParams["a"], a, "The 'a' parameter should be correctly set.")
        XCTAssertEqual(eventBatchQueryParams.queryParams.count, 3, "There should be exactly three query parameters.")
    }
}
