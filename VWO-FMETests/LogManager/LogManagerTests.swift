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

// Mock LogTransport for testing
class MockLogTransport: LogTransport {
    var loggedMessages: [(logType: String, message: String)] = []
    
    func log(logType: String, message: String) {
        loggedMessages.append((logType, message))
    }
    
    func reset() {
        loggedMessages.removeAll()
    }
}

// Mock LogMessageUtil for testing
class MockLogMessageUtil {
    static var sentMessages: [String] = []
    
    static func sendMessageEvent(message: String) {
        sentMessages.append(message)
    }
    
    static func reset() {
        sentMessages.removeAll()
    }
}

// Override LogMessageUtil for testing
extension LogMessageUtil {
    static func sendMessageEvent(message: String) {
        MockLogMessageUtil.sendMessageEvent(message: message)
    }
}

class LogManagerTests: XCTestCase {
    var mockLogTransport: MockLogTransport!
    var logManager: LogManager!
    
    override func setUp() {
        super.setUp()
        mockLogTransport = MockLogTransport()
        let config: [String: Any] = ["prefix": "TestPrefix"]
        logManager = LogManager(config: config, logLevel: .info, logTransport: mockLogTransport)

    }
    
    override func tearDown() {
        mockLogTransport = nil
        logManager = nil
        super.tearDown()
    }
    
    func testLogManagerInitialization() {
        let config: [String: Any] = ["prefix": "TestPrefix"]
        let logManager = LogManager(config: config, logLevel: .info, logTransport: mockLogTransport)
        
        XCTAssertEqual(logManager.level, .info)
        XCTAssertNotNil(LogManager.instance, "LogManager should be set as singleton instance")
    }
    
    func testLogMessageWithDifferentLevels() {
        logManager.log(level: .info, message: "Info message")
        XCTAssertEqual(mockLogTransport.loggedMessages.count, 1)
        XCTAssertEqual(mockLogTransport.loggedMessages[0].logType, "INFO")
        XCTAssertTrue(mockLogTransport.loggedMessages[0].message.contains("Info message"))
        
        logManager.log(level: .error, message: "Error message")
        XCTAssertEqual(mockLogTransport.loggedMessages.count, 2)
        XCTAssertEqual(mockLogTransport.loggedMessages[1].logType, "ERROR")
        XCTAssertTrue(mockLogTransport.loggedMessages[1].message.contains("Error message"))
    }
    
    func testLogLevelFiltering() {
        logManager.level = .warn
        
        logManager.log(level: .debug, message: "Debug message")
        logManager.log(level: .info, message: "Info message")
        logManager.log(level: .warn, message: "Warn message")
        logManager.log(level: .error, message: "Error message")
        
        XCTAssertEqual(mockLogTransport.loggedMessages.count, 2)
        XCTAssertTrue(mockLogTransport.loggedMessages[0].message.contains("Warn message"))
        XCTAssertTrue(mockLogTransport.loggedMessages[1].message.contains("Error message"))
    }
    
    func testMessageFormatting() {
        logManager.log(level: .info, message: "Test message")
        
        let loggedMessage = mockLogTransport.loggedMessages[0].message
        XCTAssertTrue(loggedMessage.contains("TestPrefix"))
        XCTAssertTrue(loggedMessage.contains("Info"))
        XCTAssertTrue(loggedMessage.contains("Test message"))
    }
    
    func testNilMessageHandling() {
        logManager.log(level: .info, message: nil)
        XCTAssertEqual(mockLogTransport.loggedMessages.count, 0, "Nil messages should not be logged")
    }
}
