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

class MockHooksManager: HooksManager {
    
    // MARK: - Properties
    
    var setCalled = false
    var executeCalled = false
    var decision: [String: Any]?
    
    // MARK: - Override Methods
    
    override func set(properties: [String: Any]?) {
        setCalled = true
        self.decision = properties
    }
    
    override func execute(properties: [String: Any]?) {
        executeCalled = true
        super.execute(properties: properties)
    }
    
    override func get() -> [String: Any]? {
        return decision
    }
    
    // MARK: - Helper Methods
    
    func clear() {
        setCalled = false
        executeCalled = false
        decision = nil
    }
}

class MockIntegrationCallback: IntegrationCallback {
    var executeCalled = false
    var lastProperties: [String: Any]?
    
    func execute(_ properties: [String: Any]) {
                
        executeCalled = true
        lastProperties = properties
    }
}
