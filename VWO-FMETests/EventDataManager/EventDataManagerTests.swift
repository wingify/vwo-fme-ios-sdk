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

final class EventDataManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        CoreDataStack.shared.clearCoreData()
    }
    
    override func tearDown() {
        CoreDataStack.shared.clearCoreData()
        super.tearDown()
    }

    func testConcurrentEventCreationAndFetchDelete() {

        let creationExpectation = XCTestExpectation(description: "Event Creation")
        let fetchDeleteExpectation = XCTestExpectation(description: "Fetch and Delete")
        let payload = ["key": "value"]

        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            EventDataManager.shared.createEvent(payload: payload)
        }

        CoreDataStack.shared.countEntries { count, error in
            XCTAssertNil(error)
            creationExpectation.fulfill()
        }

        wait(for: [creationExpectation], timeout: 2.0)

        CoreDataStack.shared.fetchManagedObjects { events, error in
            XCTAssertNotNil(events)
            XCTAssertNil(error)

            if let events = events {
                DispatchQueue.global(qos: .userInitiated).async {
                    CoreDataStack.shared.delete(events: events) { error in
                        XCTAssertNil(error)
                        fetchDeleteExpectation.fulfill()
                    }
                }
            }
        }

        wait(for: [fetchDeleteExpectation], timeout: 2.0)
    }
}
