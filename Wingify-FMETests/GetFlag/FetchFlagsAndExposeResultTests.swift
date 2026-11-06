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

/// Covers `fetchFlags` (evaluate without variation-shown) and `exposeResult` (send that impression later).
final class FetchFlagsAndExposeResultTests: XCTestCase {

    private var storageService: StorageService!

    override func setUp() {
        super.setUp()
        storageService = StorageService()
        storageService.emptyLocalStorageSuite()
    }

    override func tearDown() {
        storageService.emptyLocalStorageSuite()
        storageService = nil
        WingifyFme.clearAllInstances()
        super.tearDown()
    }

    func testFetchFlagsReturnsTheDecisionWithoutMarkingVariationShownSent() {
        let (fme, client) = makeClient()
        let context = WingifyUserContext(id: "user_id", customVariables: [:])

        let collection = fetchFlags(fme, names: ["feature1"], context: context)
        let flag = collection.get("feature1")

        XCTAssertEqual(collection.size(), 1)
        XCTAssertTrue(collection.keys().contains("feature1"))
        XCTAssertTrue(flag.isEnabled())
        XCTAssertEqual(flag.getVariable(key: "int", defaultValue: 0) as? Int, 10)
        XCTAssertEqual(variationShownSent(featureKey: "feature1", context: context, client: client), false)
        XCTAssertFalse(flag.isImpressionAlreadySent())
    }

    func testExposeResultOnFetchedFlagSendsTheDeferredImpressionOnce() {
        let (fme, client) = makeClient()
        let context = WingifyUserContext(id: "user_id", customVariables: [:])
        let flag = fetchFlags(fme, names: ["feature1"], context: context).get("feature1")

        XCTAssertTrue(flag.exposeResult())
        XCTAssertTrue(flag.isImpressionAlreadySent())
        XCTAssertEqual(variationShownSent(featureKey: "feature1", context: context, client: client), true)

        XCTAssertFalse(flag.exposeResult())
        XCTAssertFalse(fme.exposeResult(featureKey: "feature1", context: context))
    }

    func testInstanceExposeResultRebuildsTheImpressionFromStorage() {
        let (fme, client) = makeClient()
        let context = WingifyUserContext(id: "user_id", customVariables: [:])
        let flag = fetchFlags(fme, names: ["feature1"], context: context).get("feature1")

        XCTAssertEqual(variationShownSent(featureKey: "feature1", context: context, client: client), false)
        XCTAssertTrue(fme.exposeResult(featureKey: "feature1", context: context))
        XCTAssertEqual(variationShownSent(featureKey: "feature1", context: context, client: client), true)

        XCTAssertFalse(fme.exposeResult(featureKey: "feature1", context: context))
        XCTAssertFalse(flag.exposeResult())
    }

    func testGetFlagsThatAlreadySentImpressionsMakesExposeResultANoOp() {
        let (fme, client) = makeClient()
        let context = WingifyUserContext(id: "user_id", customVariables: [:])
        let collection = getFlags(
            fme,
            names: ["feature1"],
            context: context,
            shouldSendTrackingCalls: true,
            shouldSendUserTrackCalls: false
        )
        let flag = collection.get("feature1")

        XCTAssertTrue(flag.isEnabled())
        XCTAssertEqual(variationShownSent(featureKey: "feature1", context: context, client: client), true)
        XCTAssertFalse(flag.exposeResult())
        XCTAssertFalse(fme.exposeResult(featureKey: "feature1", context: context))
    }

    func testFetchFlagsWithNilNamesEvaluatesEveryFeature() {
        let (fme, client) = makeClient(settingsFile: .SettingsWithSameSalt)
        let context = WingifyUserContext(id: "user_id", customVariables: [:])
        let expectedKeys = Set((client.processedSettings?.features ?? []).compactMap { $0.key }.filter { !$0.isEmpty })

        let collection = fetchFlags(fme, names: nil, context: context)

        XCTAssertEqual(collection.keys(), expectedKeys)
        XCTAssertEqual(collection.size(), expectedKeys.count)
        XCTAssertGreaterThan(collection.size(), 1)
    }

    func testFetchFlagsDeduplicatesRequestedNames() {
        let (fme, _) = makeClient()
        let context = WingifyUserContext(id: "user_id", customVariables: [:])

        let collection = fetchFlags(fme, names: ["feature1", "feature1"], context: context)

        XCTAssertEqual(collection.size(), 1)
        XCTAssertTrue(collection.get("feature1").isEnabled())
    }

    func testFetchFlagsUnknownKeyIsDisabledAndExposeResultDoesNothing() {
        let (fme, client) = makeClient()
        let context = WingifyUserContext(id: "user_id", customVariables: [:])

        let flag = fetchFlags(fme, names: ["missing_feature"], context: context).get("missing_feature")

        XCTAssertFalse(flag.isEnabled())
        XCTAssertFalse(flag.exposeResult())
        XCTAssertFalse(fme.exposeResult(featureKey: "missing_feature", context: context))
        XCTAssertNil(variationShownSent(featureKey: "missing_feature", context: context, client: client))
    }

    func testExposeResultWithoutAPriorDecisionReturnsFalse() {
        let (fme, _) = makeClient()
        let context = WingifyUserContext(id: "user_id", customVariables: [:])

        XCTAssertFalse(fme.exposeResult(featureKey: "feature1", context: context))
        XCTAssertFalse(GetFlag().exposeResult())
    }

    func testExposeResultWithEmptyUserIdReturnsFalse() {
        let (fme, _) = makeClient()
        let context = WingifyUserContext(id: "", customVariables: [:])

        XCTAssertFalse(fme.exposeResult(featureKey: "feature1", context: context))
    }

    func testFetchFlagsWithEmptyUserIdReturnsDisabledFlags() {
        let (fme, _) = makeClient()
        let context = WingifyUserContext(id: "", customVariables: [:])

        let collection = fetchFlags(fme, names: ["feature1"], context: context)

        XCTAssertFalse(collection.get("feature1").isEnabled())
        XCTAssertFalse(collection.get("feature1").exposeResult())
    }

    // MARK: - Helpers

    private func makeClient(
        settingsFile: SettingsTestJson = .OnlyRolloutSettings
    ) -> (WingifyFme, WingifyClient) {
        let settings = FlagTestDataLoader.loadTestData(jsonFileName: settingsFile.jsonFileName)
        XCTAssertNotNil(settings)
        let options = WingifyInitOptions(sdkKey: "sdk-key", accountId: 123456, isUsageStatsDisabled: true)
        let builder = WingifyBuilder(options: options)
        _ = builder.setLogger().setSettingsManager()
        let client = WingifyClient(options: options, settingObj: settings, wingifyBuilder: builder)
        client.isSettingsValid = true
        return (WingifyFme(wingifyClient: client), client)
    }

    private func fetchFlags(
        _ fme: WingifyFme,
        names: [String]?,
        context: WingifyUserContext
    ) -> FlagCollection {
        getFlags(
            fme,
            names: names,
            context: context,
            shouldSendTrackingCalls: false,
            shouldSendUserTrackCalls: true,
            useFetchFlags: true
        )
    }

    private func getFlags(
        _ fme: WingifyFme,
        names: [String]?,
        context: WingifyUserContext,
        shouldSendTrackingCalls: Bool,
        shouldSendUserTrackCalls: Bool,
        useFetchFlags: Bool = false
    ) -> FlagCollection {
        let expectation = expectation(description: useFetchFlags ? "fetchFlags" : "getFlags")
        var collection: FlagCollection?
        if useFetchFlags {
            fme.fetchFlags(flagNames: names, context: context) { result in
                collection = result
                expectation.fulfill()
            }
        } else {
            fme.getFlags(
                flagNames: names,
                context: context,
                shouldSendTrackingCalls: shouldSendTrackingCalls,
                shouldSendUserTrackCalls: shouldSendUserTrackCalls
            ) { result in
                collection = result
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
        return collection ?? FlagCollection.create(flags: [:], fallbackContext: context)
    }

    private func variationShownSent(
        featureKey: String,
        context: WingifyUserContext,
        client: WingifyClient
    ) -> Bool? {
        let stored = client.createServiceContainer()?.storage?.getFeatureFromStorage(
            featureKey: featureKey,
            context: context
        )
        if let sent = stored?[Constants.KEY_VARIATION_SHOWN_SENT] as? Bool {
            return sent
        }
        if let number = stored?[Constants.KEY_VARIATION_SHOWN_SENT] as? NSNumber {
            return number.boolValue
        }
        return nil
    }
}
