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
#if canImport(Wingify_FME)
@testable import Wingify_FME
#elseif canImport(VWO_FME)
@testable import VWO_FME
#endif

class InternalEventSamplingUtilTests: XCTestCase {

    private func makeSettings(
        samplingJSON: String = "",
        alwaysApplySamplingJSON: String = ""
    ) throws -> Settings {
        let json = """
        {
            "accountId": 1,
            "version": 1,
            "features": [],
            "campaigns": []
            \(samplingJSON.isEmpty ? "" : ",\(samplingJSON)")
            \(alwaysApplySamplingJSON.isEmpty ? "" : ",\(alwaysApplySamplingJSON)")
        }
        """
        return try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    }

    func testUsageStatsSamplingRateDefaultsTo1WhenMissing() throws {
        let settings = try makeSettings()
        XCTAssertEqual(InternalEventSamplingUtil.usageStatsSamplingRate(from: settings), 1)
        XCTAssertEqual(InternalEventSamplingUtil.usageStatsSamplingRate(from: nil), 1)
    }

    func testUsageStatsSamplingRateReadsClientUsageValue() throws {
        let settings = try makeSettings(samplingJSON: """
            "sampling": {
                "usage": { "server": 10, "client": 20, "serverless": 30 },
                "debug": { "server": 40, "client": 50, "serverless": 60 }
            }
        """)

        XCTAssertEqual(InternalEventSamplingUtil.usageStatsSamplingRate(from: settings), 20)
    }

    func testQualifiesForSamplingWhenRandomValueIsWithinRate() {
        XCTAssertTrue(InternalEventSamplingUtil.doesQualifyForSampling(samplingPercentage: 20, randomValue: 20))
        XCTAssertTrue(InternalEventSamplingUtil.doesQualifyForSampling(samplingPercentage: 20, randomValue: 0))
        XCTAssertFalse(InternalEventSamplingUtil.doesQualifyForSampling(samplingPercentage: 20, randomValue: 21))
    }

    func testQualifiesForSamplingWhenRateIs100() {
        XCTAssertTrue(InternalEventSamplingUtil.doesQualifyForSampling(samplingPercentage: 100, randomValue: 100))
    }

    func testQualifiesForSamplingWhenRateIsZero() {
        XCTAssertFalse(InternalEventSamplingUtil.doesQualifyForSampling(samplingPercentage: 0, randomValue: 0))
    }

    func testShouldAlwaysApplySamplingDefaultsToFalseWhenMissing() throws {
        let settings = try makeSettings()
        XCTAssertFalse(InternalEventSamplingUtil.shouldAlwaysApplySampling(settings: settings))
        XCTAssertFalse(InternalEventSamplingUtil.shouldAlwaysApplySampling(settings: nil))
    }

    func testShouldAlwaysApplySamplingReadsClientFlag() throws {
        let enabled = try makeSettings(alwaysApplySamplingJSON: """
            "alwaysApplySampling": { "server": false, "client": true, "serverless": false }
        """)
        let disabled = try makeSettings(alwaysApplySamplingJSON: """
            "alwaysApplySampling": { "server": true, "client": false, "serverless": true }
        """)

        XCTAssertTrue(InternalEventSamplingUtil.shouldAlwaysApplySampling(settings: enabled))
        XCTAssertFalse(InternalEventSamplingUtil.shouldAlwaysApplySampling(settings: disabled))
    }

    func testShouldSendUsageStatsEventUsesClientUsageSamplingWhenAlwaysApplyIsTrue() throws {
        let settings = try makeSettings(
            samplingJSON: """
            "sampling": {
                "usage": { "server": 100, "client": 25, "serverless": 100 }
            }
            """,
            alwaysApplySamplingJSON: """
            "alwaysApplySampling": { "server": true, "client": true, "serverless": true }
            """
        )

        XCTAssertTrue(InternalEventSamplingUtil.isUsageStatsEventQualified(settings: settings, randomValue: 25))
        XCTAssertFalse(InternalEventSamplingUtil.isUsageStatsEventQualified(settings: settings, randomValue: 26))
    }

    func testShouldAlwaysSendUsageStatsEventWhenAlwaysApplyIsFalse() throws {
        let settings = try makeSettings(
            samplingJSON: """
            "sampling": {
                "usage": { "server": 100, "client": 1, "serverless": 100 }
            }
            """,
            alwaysApplySamplingJSON: """
            "alwaysApplySampling": { "server": true, "client": false, "serverless": true }
            """
        )

        XCTAssertTrue(InternalEventSamplingUtil.isUsageStatsEventQualified(settings: settings, randomValue: 100))
    }

    func testShouldAlwaysSendUsageStatsEventWhenAlwaysApplyIsMissing() throws {
        let settings = try makeSettings(samplingJSON: """
            "sampling": {
                "usage": { "server": 100, "client": 1, "serverless": 100 }
            }
        """)

        XCTAssertTrue(InternalEventSamplingUtil.isUsageStatsEventQualified(settings: settings, randomValue: 100))
        XCTAssertTrue(InternalEventSamplingUtil.isUsageStatsEventQualified(settings: nil, randomValue: 100))
    }

    func testDebugSamplingRateDefaultsTo1WhenMissing() throws {
        let settings = try makeSettings()
        XCTAssertEqual(InternalEventSamplingUtil.debugSamplingRate(from: settings), 1)
        XCTAssertEqual(InternalEventSamplingUtil.debugSamplingRate(from: nil), 1)
    }

    func testDebugSamplingRateReadsClientDebugValue() throws {
        let settings = try makeSettings(samplingJSON: """
            "sampling": {
                "debug": { "server": 10, "client": 20, "serverless": 30 }
            }
        """)

        XCTAssertEqual(InternalEventSamplingUtil.debugSamplingRate(from: settings), 20)
    }

    func testShouldSendSampledDebugEventUsesClientDebugSamplingWhenAlwaysApplyIsTrue() throws {
        let settings = try makeSettings(
            samplingJSON: """
            "sampling": {
                "debug": { "server": 100, "client": 25, "serverless": 100 }
            }
            """,
            alwaysApplySamplingJSON: """
            "alwaysApplySampling": { "server": true, "client": true, "serverless": true }
            """
        )

        XCTAssertTrue(InternalEventSamplingUtil.isSampledDebugEventQualified(settings: settings, randomValue: 25))
        XCTAssertFalse(InternalEventSamplingUtil.isSampledDebugEventQualified(settings: settings, randomValue: 26))
    }

    func testShouldAlwaysSendSampledDebugEventWhenAlwaysApplyIsFalse() throws {
        let settings = try makeSettings(
            samplingJSON: """
            "sampling": {
                "debug": { "server": 100, "client": 1, "serverless": 100 }
            }
            """,
            alwaysApplySamplingJSON: """
            "alwaysApplySampling": { "server": true, "client": false, "serverless": true }
            """
        )

        XCTAssertTrue(InternalEventSamplingUtil.isSampledDebugEventQualified(settings: settings, randomValue: 100))
    }

    func testShouldAlwaysSendSampledDebugEventWhenAlwaysApplyIsMissing() throws {
        let settings = try makeSettings(samplingJSON: """
            "sampling": {
                "debug": { "server": 100, "client": 1, "serverless": 100 }
            }
        """)

        XCTAssertTrue(InternalEventSamplingUtil.isSampledDebugEventQualified(settings: settings, randomValue: 100))
        XCTAssertTrue(InternalEventSamplingUtil.isSampledDebugEventQualified(settings: nil, randomValue: 100))
    }

    func testErrorLogSamplingKeysCategorizesKeys() {
        XCTAssertEqual(ErrorLogSamplingKeys.category(for: "INVALID_CREDENTIALS"), .alwaysSend)
        XCTAssertEqual(ErrorLogSamplingKeys.category(for: "NETWORK_CALL_FAILED"), .sampled)
        XCTAssertEqual(ErrorLogSamplingKeys.category(for: "ERROR_FETCHING_SETTINGS"), .sampled)
        XCTAssertEqual(ErrorLogSamplingKeys.category(for: "FLAG_DECISION_GIVEN"), .alwaysSend)
        XCTAssertNil(ErrorLogSamplingKeys.category(for: nil))

        XCTAssertFalse(ErrorLogSamplingKeys.isSampled(forKey: "INVALID_CREDENTIALS"))
        XCTAssertTrue(ErrorLogSamplingKeys.isSampled(forKey: "NETWORK_CALL_FAILED"))
        XCTAssertTrue(ErrorLogSamplingKeys.isSampled(forKey: "ERROR_FETCHING_SETTINGS"))
        XCTAssertFalse(ErrorLogSamplingKeys.isSampled(forKey: "FLAG_DECISION_GIVEN"))
        XCTAssertFalse(ErrorLogSamplingKeys.isSampled(forKey: nil))
    }

    func testSettingsDecodeSamplingConfiguration() throws {
        let json = """
        {
            "accountId": 1,
            "version": 1,
            "features": [],
            "campaigns": [],
            "sampling": {
                "usage": { "server": 10, "client": 20, "serverless": 30 },
                "debug": { "server": 40, "client": 50, "serverless": 60 }
            },
            "alwaysApplySampling": {
                "server": true,
                "client": false,
                "serverless": true
            }
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(Settings.self, from: json)

        XCTAssertEqual(settings.sampling?.usage?.client, 20)
        XCTAssertEqual(settings.sampling?.debug?.client, 50)
        XCTAssertEqual(settings.alwaysApplySampling?.client, false)
    }
}
