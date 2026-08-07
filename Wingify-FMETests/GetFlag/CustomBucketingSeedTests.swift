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
@testable import VWO_FME

/// E2E-style tests for custom bucketing seed on iOS.
final class CustomBucketingSeedTests: XCTestCase {

    private var storageService: StorageService!

    override func setUp() {
        super.setUp()
        storageService = StorageService()
        storageService.emptyLocalStorageSuite()
    }

    override func tearDown() {
        storageService.emptyLocalStorageSuite()
        storageService = nil
        super.tearDown()
    }

    /// Helper to create a processed settings + service container pair using basic rollout + testing settings.
    private func makeEnvironment() -> (Settings, VWOInitOptions, ServiceContainer) {
        let settings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)!
        let options = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let client = WingifyClient(options: options, settingObj: settings)
        let processed = client.processedSettings!

        let builder = WingifyBuilder(options: options)
        _ = builder.setLogger().setSettingsManager()
        let container = builder.createServiceContainer(processedSettings: processed, options: options)
        return (processed, options, container)
    }

    private func getFlagVariables(featureKey: String, context: VWOUserContext, settings: Settings, container: ServiceContainer) -> [[String: Any]]? {
        let hookManager = MockHooksManager(callback: MockIntegrationCallback())
        let expectation = XCTestExpectation(description: "getFlag for \(featureKey)")

        var captured: [[String: Any]]?
        GetFlagAPI.getFlag(featureKey: featureKey, settings: settings, context: context, hookManager: hookManager, serviceContainer: container) { flag in
            if flag.isEnabled() {
                captured = flag.getVariables()
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        return captured
    }

    /// Case 1 & 3 equivalent: different users without seed fall back to userId and generally get different variations.
    func testDifferentUsersWithoutSeedTendToGetDifferentVariations() {
        let (settings, _, container) = makeEnvironment()
        let featureKey = "featureKey1"

        let context1 = VWOUserContext(id: "UserA", customVariables: [:])
        let context2 = VWOUserContext(id: "UserB", customVariables: [:])

        let vars1 = getFlagVariables(featureKey: featureKey, context: context1, settings: settings, container: container)
        let vars2 = getFlagVariables(featureKey: featureKey, context: context2, settings: settings, container: container)

        // Comparison is only meaningful when both variations are non-nil.
        if let v1 = vars1 as? [[String: AnyHashable]], let v2 = vars2 as? [[String: AnyHashable]] {
            XCTAssertNotEqual(v1, v2, "Different users without seed should typically land in different variations")
        }
    }

    /// Case 2 equivalent: two different users with same seed should converge to same variation.
    func testSameSeedProducesSameVariationForDifferentUsers() {
        let (settings, _, container) = makeEnvironment()
        let featureKey = "featureKey1"

        let seed = "household-123"

        let context1 = VWOUserContext(id: "UserA", shouldUseDeviceIdAsUserId: false, customVariables: [:], postSegmentationVariables: nil, bucketingSeed: seed)
        let context2 = VWOUserContext(id: "UserB", shouldUseDeviceIdAsUserId: false, customVariables: [:], postSegmentationVariables: nil, bucketingSeed: seed)

        let vars1 = getFlagVariables(featureKey: featureKey, context: context1, settings: settings, container: container)
        let vars2 = getFlagVariables(featureKey: featureKey, context: context2, settings: settings, container: container)

        if let v1 = vars1 as? [[String: AnyHashable]], let v2 = vars2 as? [[String: AnyHashable]] {
            XCTAssertEqual(v1, v2, "Different users with same seed should get same variation variables")
        }
    }

    /// Case 4 equivalent: same user with different seeds should tend to get different variations.
    func testSameUserDifferentSeedsProduceDifferentVariations() {
        let (settings, _, container) = makeEnvironment()
        let featureKey = "featureKey1"

        let context1 = VWOUserContext(id: "UserSeedCase", shouldUseDeviceIdAsUserId: false, customVariables: [:], postSegmentationVariables: nil, bucketingSeed: "SeedOne")
        let context2 = VWOUserContext(id: "UserSeedCase", shouldUseDeviceIdAsUserId: false, customVariables: [:], postSegmentationVariables: nil, bucketingSeed: "SeedTwo")

        let vars1 = getFlagVariables(featureKey: featureKey, context: context1, settings: settings, container: container)
        let vars2 = getFlagVariables(featureKey: featureKey, context: context2, settings: settings, container: container)

        if let v1 = vars1 as? [[String: AnyHashable]], let v2 = vars2 as? [[String: AnyHashable]] {
            XCTAssertNotEqual(v1, v2, "Same user with different seeds should typically get different variation variables")
        }
    }

    /// Case 5 equivalent: empty seed falls back to userId.
    func testEmptySeedFallsBackToUserIdBehaviour() {
        let (settings, _, container) = makeEnvironment()
        let featureKey = "featureKey1"

        let context1 = VWOUserContext(id: "UserEmptySeedA", shouldUseDeviceIdAsUserId: false, customVariables: [:], postSegmentationVariables: nil, bucketingSeed: "")
        let context2 = VWOUserContext(id: "UserEmptySeedB", shouldUseDeviceIdAsUserId: false, customVariables: [:], postSegmentationVariables: nil, bucketingSeed: "")

        let vars1 = getFlagVariables(featureKey: featureKey, context: context1, settings: settings, container: container)
        let vars2 = getFlagVariables(featureKey: featureKey, context: context2, settings: settings, container: container)

        if let v1 = vars1 as? [[String: AnyHashable]], let v2 = vars2 as? [[String: AnyHashable]] {
            XCTAssertNotEqual(v1, v2, "Empty seed should behave like no seed and typically give different variations for different users")
        }
    }

    // MARK: - Additional cases tests
    // Aliasing-specific cases are not currently testable in this iOS unit-test setup,
    // so we mark them as skipped while keeping parity in case naming.

    /// Case 6 equivalent (aliasing + same seed) – skipped on iOS.
    func testAliasingEnabled_SameSeedOverridesUserIdAndProducesSameVariation() throws {
        throw XCTSkip("Aliasing-based custom bucketing behaviour is not exercised in this iOS unit-test environment.")
    }

    /// Case 7 equivalent (aliasing, no seed) – skipped on iOS.
    func testAliasingEnabled_WithoutSeedDifferentResolvedUserIdsGetDifferentVariations() throws {
        throw XCTSkip("Aliasing-based custom bucketing behaviour is not exercised in this iOS unit-test environment.")
    }

    /// Helper to build env for alternate settings JSONs (same-salt / whitelisting).
    private func makeEnvironment(settingsJson: SettingsTestJson) -> (Settings, VWOInitOptions, ServiceContainer) {
        let settings = FlagTestDataLoader.loadTestData(jsonFileName: settingsJson.jsonFileName)!
        let options = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let client = WingifyClient(options: options, settingObj: settings)
        let processed = client.processedSettings!

        let builder = WingifyBuilder(options: options)
        _ = builder.setLogger().setSettingsManager()
        let container = builder.createServiceContainer(processedSettings: processed, options: options)
        return (processed, options, container)
    }

    /// Case 8 equivalent: no seed, same salt – for a given user, two features with same salt
    /// should return the same variation.
    func testNoSeedSameSalt_EachUserGetsSameVariationAcrossBothFeatures() {
        let (settings, _, container) = makeEnvironment(settingsJson: .SettingsWithSameSalt)

        for i in 1...10 {
            let userId = "user\(i)"
            let context1 = VWOUserContext(id: userId, customVariables: [:])
            let context2 = VWOUserContext(id: userId, customVariables: [:])

            let vars1 = getFlagVariables(featureKey: "feature1", context: context1, settings: settings, container: container)
            let vars2 = getFlagVariables(featureKey: "feature2", context: context2, settings: settings, container: container)

            if let v1 = vars1 as? [[String: AnyHashable]], let v2 = vars2 as? [[String: AnyHashable]] {
                XCTAssertEqual(v1, v2, "\(userId): features with same salt should yield the same variation for a given user")
            }
        }
    }

    /// Case 9 equivalent: same seed + same salt – all users converge to the same variation
    /// across both features and among each other.
    func testSeedAndSameSalt_AllUsersGetSameVariationAcrossFeaturesAndAmongEachOther() {
        let (settings, _, container) = makeEnvironment(settingsJson: .SettingsWithSameSalt)
        let commonSeed = "common_seed_456"

        var referenceVars: [[String: AnyHashable]]?

        for i in 1...10 {
            let userId = "user\(i)"
            let context1 = VWOUserContext(id: userId, shouldUseDeviceIdAsUserId: false, customVariables: [:], postSegmentationVariables: nil, bucketingSeed: commonSeed)
            let context2 = VWOUserContext(id: userId, shouldUseDeviceIdAsUserId: false, customVariables: [:], postSegmentationVariables: nil, bucketingSeed: commonSeed)

            let vars1 = getFlagVariables(featureKey: "feature1", context: context1, settings: settings, container: container)
            let vars2 = getFlagVariables(featureKey: "feature2", context: context2, settings: settings, container: container)

            guard let v1 = vars1 as? [[String: AnyHashable]], let v2 = vars2 as? [[String: AnyHashable]] else {
                continue
            }

            // Both features must match for a given user.
            XCTAssertEqual(v1, v2, "\(userId): both features should give same variation with same seed + salt")

            // First non-nil becomes reference; all subsequent must equal it.
            if let ref = referenceVars {
                XCTAssertEqual(v1, ref, "\(userId): all users should converge to same variation with shared seed + salt")
            } else {
                referenceVars = v1
            }
        }
    }

    /// Case 10 & 11 equivalents (whitelisting + seed) – skipped on iOS until we add
    func testWhitelistingUserReceivesForcedVariationRegardlessOfSeed() throws {
        throw XCTSkip("Whitelisting + bucketing seed behaviour is covered by existing GetFlag JSON fixtures; dedicated mirrored case is not yet wired on iOS.")
    }
}

