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

final class SdkInitAndUsageStatsPayloadTests: XCTestCase {

    private let settingsFetchTime: Int64 = 120
    private let sdkInitTime: Int64 = 350
    private let usageStatsAccountId = 99999

    override func setUp() {
        super.setUp()
        UsageStatsUtil.shared.emptyUsageStats()
    }

    override func tearDown() {
        UsageStatsUtil.shared.emptyUsageStats()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTestOptions() -> WingifyInitOptions {
        WingifyInitOptions(
            sdkKey: "test-sdk-key",
            accountId: 12345,
            logLevel: .debug,
            logPrefix: "test-prefix",
            gatewayService: ["url": "https://gateway.example.com"],
            cachedSettingsExpiryTime: 120_000,
            cachedDecisionExpiryTime: 60_000,
            pollInterval: 30_000,
            batchMinSize: 10,
            batchUploadTimeInterval: 5_000,
            sdkName: "vwo-fme-ios-sdk",
            sdkVersion: "1.0.0-test",
            isUsageStatsDisabled: false,
            vwoMeta: ["customKey": "customValue"],
            isAliasingEnabled: true,
            shouldTriggerIntegrationCallbackAlways: true
        )
    }

    private func makeServiceContainer(options: WingifyInitOptions) -> ServiceContainer {
        let builder = WingifyBuilder(options: options)
        return builder.createServiceContainer(processedSettings: nil, options: options)
    }

    private func eventPropsData(from payload: [String: Any]) -> [String: Any]? {
        guard let d = payload["d"] as? [String: Any],
              let event = d["event"] as? [String: Any],
              let props = event["props"] as? [String: Any],
              let data = props["data"] as? [String: Any] else {
            return nil
        }
        return data
    }

    private func eventPropsVwoMeta(from payload: [String: Any]) -> [String: Any]? {
        guard let d = payload["d"] as? [String: Any],
              let event = d["event"] as? [String: Any],
              let props = event["props"] as? [String: Any],
              let vwoMeta = props["vwoMeta"] as? [String: Any] else {
            return nil
        }
        return vwoMeta
    }

    private func assertInitConfigMatches(_ initConfig: [String: Any], _ other: [String: Any], file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(initConfig["accountId"] as? Int, other["accountId"] as? Int, file: file, line: line)
        XCTAssertEqual(initConfig["sdkKey"] as? String, other["sdkKey"] as? String, file: file, line: line)
        XCTAssertEqual(initConfig["sdkName"] as? String, other["sdkName"] as? String, file: file, line: line)
        XCTAssertEqual(initConfig["sdkVersion"] as? String, other["sdkVersion"] as? String, file: file, line: line)
        XCTAssertEqual(initConfig["pollInterval"] as? Int64, other["pollInterval"] as? Int64, file: file, line: line)
        XCTAssertEqual(initConfig["cachedSettingsExpiryTime"] as? Int64, other["cachedSettingsExpiryTime"] as? Int64, file: file, line: line)
        XCTAssertEqual(initConfig["cachedDecisionExpiryTime"] as? Int64, other["cachedDecisionExpiryTime"] as? Int64, file: file, line: line)
        XCTAssertEqual(initConfig["batchMinSize"] as? Int, other["batchMinSize"] as? Int, file: file, line: line)
        XCTAssertEqual(initConfig["batchUploadTimeInterval"] as? Int64, other["batchUploadTimeInterval"] as? Int64, file: file, line: line)
        XCTAssertEqual(initConfig["isUsageStatsDisabled"] as? Bool, other["isUsageStatsDisabled"] as? Bool, file: file, line: line)
        XCTAssertEqual(initConfig["isAliasingEnabled"] as? Bool, other["isAliasingEnabled"] as? Bool, file: file, line: line)
        XCTAssertEqual(initConfig["shouldTriggerIntegrationCallbackAlways"] as? Bool, other["shouldTriggerIntegrationCallbackAlways"] as? Bool, file: file, line: line)
        XCTAssertEqual(initConfig["integrations"] as? Bool, other["integrations"] as? Bool, file: file, line: line)
        XCTAssertEqual(initConfig["storage"] as? Bool, other["storage"] as? Bool, file: file, line: line)
        XCTAssertEqual(initConfig["logTransport"] as? Bool, other["logTransport"] as? Bool, file: file, line: line)

        let gatewayService = initConfig["gatewayService"] as? [String: Any]
        let otherGatewayService = other["gatewayService"] as? [String: Any]
        XCTAssertEqual(gatewayService?["url"] as? String, otherGatewayService?["url"] as? String, file: file, line: line)

        let vwoMeta = initConfig["vwoMeta"] as? [String: Any]
        let otherVwoMeta = other["vwoMeta"] as? [String: Any]
        XCTAssertEqual(vwoMeta?["customKey"] as? String, otherVwoMeta?["customKey"] as? String, file: file, line: line)
    }

    // MARK: - toInitConfigDictionary

    func testToInitConfigDictionaryIncludesExpectedFields() {
        let options = makeTestOptions()
        let config = options.toInitConfigDictionary()

        XCTAssertEqual(config["accountId"] as? Int, 12345)
        XCTAssertEqual(config["sdkKey"] as? String, "test-sdk-key")
        XCTAssertEqual(config["pollInterval"] as? Int64, 30_000)
        XCTAssertEqual(config["cachedSettingsExpiryTime"] as? Int64, 120_000)
        XCTAssertEqual(config["cachedDecisionExpiryTime"] as? Int64, 60_000)
        XCTAssertEqual(config["batchMinSize"] as? Int, 10)
        XCTAssertEqual(config["batchUploadTimeInterval"] as? Int64, 5_000)
        XCTAssertEqual(config["sdkName"] as? String, "vwo-fme-ios-sdk")
        XCTAssertEqual(config["sdkVersion"] as? String, "1.0.0-test")
        XCTAssertEqual(config["isUsageStatsDisabled"] as? Bool, false)
        XCTAssertEqual(config["isAliasingEnabled"] as? Bool, true)
        XCTAssertEqual(config["shouldTriggerIntegrationCallbackAlways"] as? Bool, true)
        XCTAssertEqual(config["integrations"] as? Bool, false)
        XCTAssertEqual(config["storage"] as? Bool, false)
        XCTAssertEqual(config["logTransport"] as? Bool, false)

        let gatewayService = config["gatewayService"] as? [String: Any]
        XCTAssertEqual(gatewayService?["url"] as? String, "https://gateway.example.com")

        let vwoMeta = config["vwoMeta"] as? [String: Any]
        XCTAssertEqual(vwoMeta?["customKey"] as? String, "customValue")
    }

    // MARK: - getSDKInitEventData

    func testGetSDKInitEventDataIncludesOnlyIsSDKInitialized() {
        let data = NetworkUtil.getSDKInitEventData()

        XCTAssertEqual(data["isSDKInitialized"] as? Bool, true)
        XCTAssertNil(data["settingsFetchTime"])
        XCTAssertNil(data["sdkInitTime"])
        XCTAssertNil(data["initConfig"])
        XCTAssertEqual(data.count, 1)
    }

    // MARK: - getSDKUsageStatsEventData

    func testGetSDKUsageStatsEventDataIncludesTimingsAndInitConfig() {
        let options = makeTestOptions()
        let serviceContainer = makeServiceContainer(options: options)

        let data = NetworkUtil.getSDKUsageStatsEventData(
            settingsFetchTime: settingsFetchTime,
            sdkInitTime: sdkInitTime,
            serviceContainer: serviceContainer
        )

        XCTAssertNil(data["isSDKInitialized"])
        XCTAssertEqual(data["settingsFetchTime"] as? Int64, settingsFetchTime)
        XCTAssertEqual(data["sdkInitTime"] as? Int64, sdkInitTime)

        guard let initConfig = data["initConfig"] as? [String: Any] else {
            return XCTFail("initConfig should be present in usage stats data")
        }
        XCTAssertEqual(initConfig["accountId"] as? Int, 12345)
        XCTAssertEqual(initConfig["sdkKey"] as? String, "test-sdk-key")
        XCTAssertEqual(initConfig["sdkName"] as? String, SDKMetaUtil.name)
    }

    func testGetSDKUsageStatsEventDataWithoutServiceContainerHasEmptyInitConfig() {
        let data = NetworkUtil.getSDKUsageStatsEventData(
            settingsFetchTime: settingsFetchTime,
            sdkInitTime: sdkInitTime,
            serviceContainer: nil
        )

        XCTAssertNil(data["isSDKInitialized"])
        XCTAssertEqual(data["settingsFetchTime"] as? Int64, settingsFetchTime)
        XCTAssertEqual(data["sdkInitTime"] as? Int64, sdkInitTime)
        guard let initConfig = data["initConfig"] as? [String: Any] else {
            return XCTFail("initConfig should be present even without service container")
        }
        XCTAssertTrue(initConfig.isEmpty, "Without service container there are no init options to serialize")
    }

    // MARK: - Init event payload

    func testGetSDKInitEventPayloadIncludesOnlyIsSDKInitializedInEventData() {
        let options = makeTestOptions()
        let serviceContainer = makeServiceContainer(options: options)

        let payload = NetworkUtil.getSDKInitEventPayload(
            eventName: EventEnum.VWO_INIT_CALLED.rawValue,
            serviceContainer: serviceContainer
        )

        guard let data = eventPropsData(from: payload) else {
            return XCTFail("Init payload should include d.event.props.data")
        }

        XCTAssertEqual(data["isSDKInitialized"] as? Bool, true)
        XCTAssertNil(data["settingsFetchTime"])
        XCTAssertNil(data["sdkInitTime"])
        XCTAssertNil(data["initConfig"])
        XCTAssertEqual(data.count, 1)
    }

    // MARK: - Usage stats payload

    func testGetSDKUsageStatsEventPayloadNestsTimingsAndInitConfigUnderEventData() {
        let options = makeTestOptions()
        let serviceContainer = makeServiceContainer(options: options)

        let usageStatsPayload = NetworkUtil.getSDKUsageStatsEventPayload(
            event: .VWO_USAGE_STATS,
            usageStatsAccountId: usageStatsAccountId,
            settingsFetchTime: settingsFetchTime,
            sdkInitTime: sdkInitTime,
            serviceContainer: serviceContainer
        )

        guard let usageStatsData = eventPropsData(from: usageStatsPayload) else {
            return XCTFail("Usage stats payload should include d.event.props.data")
        }

        XCTAssertNil(usageStatsData["isSDKInitialized"])
        XCTAssertEqual(usageStatsData["settingsFetchTime"] as? Int64, settingsFetchTime)
        XCTAssertEqual(usageStatsData["sdkInitTime"] as? Int64, sdkInitTime)

        guard let usageStatsInitConfig = usageStatsData["initConfig"] as? [String: Any] else {
            return XCTFail("Usage stats payload should include initConfig in props.data")
        }

        let expectedInitConfig = NetworkUtil.getSDKUsageStatsEventData(
            settingsFetchTime: settingsFetchTime,
            sdkInitTime: sdkInitTime,
            serviceContainer: serviceContainer
        )["initConfig"] as? [String: Any] ?? [:]
        assertInitConfigMatches(usageStatsInitConfig, expectedInitConfig)
    }

    func testGetSDKUsageStatsEventPayloadIncludesVwoMetaWhenUsageStatsSet() {
        let options = makeTestOptions()
        UsageStatsUtil.shared.setUsageStats(options: options)
        let serviceContainer = makeServiceContainer(options: options)

        let usageStatsPayload = NetworkUtil.getSDKUsageStatsEventPayload(
            event: .VWO_USAGE_STATS,
            usageStatsAccountId: usageStatsAccountId,
            settingsFetchTime: settingsFetchTime,
            sdkInitTime: sdkInitTime,
            serviceContainer: serviceContainer
        )

        guard let data = eventPropsData(from: usageStatsPayload) else {
            return XCTFail("Usage stats payload should include d.event.props.data")
        }
        XCTAssertNil(data["isSDKInitialized"])
        XCTAssertNotNil(data["initConfig"])

        guard let vwoMeta = eventPropsVwoMeta(from: usageStatsPayload) else {
            return XCTFail("Usage stats payload should include vwoMeta when stats are collected")
        }
        XCTAssertNotNil(vwoMeta[UsageStatsKeys.logLevel])
    }

    func testGetSDKUsageStatsEventPayloadDoesNotIncludeVwoEnvKey() {
        let options = makeTestOptions()
        let serviceContainer = makeServiceContainer(options: options)

        let usageStatsPayload = NetworkUtil.getSDKUsageStatsEventPayload(
            event: .VWO_USAGE_STATS,
            usageStatsAccountId: usageStatsAccountId,
            settingsFetchTime: settingsFetchTime,
            sdkInitTime: sdkInitTime,
            serviceContainer: serviceContainer
        )

        guard let d = usageStatsPayload["d"] as? [String: Any],
              let event = d["event"] as? [String: Any],
              let props = event["props"] as? [String: Any] else {
            return XCTFail("Usage stats payload should include event props")
        }

        XCTAssertNil(props["vwo_envKey"], "Usage stats events should not include vwo_envKey")
        XCTAssertNil(d["visitor"], "Usage stats events should not include visitor")
    }
}
