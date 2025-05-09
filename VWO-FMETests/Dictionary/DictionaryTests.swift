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
}
