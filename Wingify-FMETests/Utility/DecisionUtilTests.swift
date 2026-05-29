/**
 * Copyright 2024-2026 Wingify Software Pvt. Ltd.
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
@testable import Wingify_FME

final class DecisionUtilTests: XCTestCase {
    
    func testMakeDecisionCustomVariablesKeepsOriginalContextUntouched() {
        let createdAt = Date()
        let bridgedCustomVariables = NSDictionary(dictionary: [
            "createdAt": createdAt,
            "plan": "pro"
        ]) as! [String: Any]
        let context = WingifyUserContext(id: "user-1", customVariables: bridgedCustomVariables)
        
        let decisionCustomVariables = DecisionUtil.makeDecisionCustomVariables(
            context: context,
            userId: "resolved-user-1"
        )
        
        XCTAssertEqual(decisionCustomVariables["_vwoUserId"] as? String, "resolved-user-1")
        XCTAssertEqual(decisionCustomVariables["plan"] as? String, "pro")
        XCTAssertTrue(decisionCustomVariables["createdAt"] is Date)
        
        XCTAssertNil(context.customVariables["_vwoUserId"])
        XCTAssertEqual(context.customVariables["plan"] as? String, "pro")
        XCTAssertTrue(context.customVariables["createdAt"] is Date)
    }
}
