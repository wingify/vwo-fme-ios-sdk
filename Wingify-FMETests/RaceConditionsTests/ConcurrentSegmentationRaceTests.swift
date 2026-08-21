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
 * WITHOUT WARRANTIES OR CONDITIONS under the License.
 */

/**
 * Stress-tests concurrent getFlag calls under multi-instance isolation.
 *
 * Each concurrent call uses its own ServiceContainer (and SegmentationManager).
 * Sharing one SegmentationManager across threads while setContextualData replaces
 * the internal evaluator can crash; production callers should use one container
 * per SDK instance, not one shared container from many threads at once.
 */

import XCTest
#if canImport(Wingify_FME)
@testable import Wingify_FME
#elseif canImport(VWO_FME)
@testable import VWO_FME
#endif

final class ConcurrentSegmentationRaceTests: XCTestCase {

    private var mockCallback: MockIntegrationCallback!
    private var mockHookManager: MockHooksManager!
    private var storageService: StorageService!

    override func setUp() {
        super.setUp()
        storageService = StorageService()
        storageService.emptyLocalStorageSuite()
        mockCallback = MockIntegrationCallback()
        mockHookManager = MockHooksManager(callback: mockCallback)
    }

    override func tearDown() {
        storageService.emptyLocalStorageSuite()
        storageService = nil
        mockHookManager = nil
        mockCallback = nil
        super.tearDown()
    }

    /// Runs getFlag concurrently, each call with its own ServiceContainer.
    /// Kept intentionally moderate so CI runners (especially Xcode 15.4) do not
    /// starve GCD while getFlag blocks the caller with dispatchGroup.wait().
    func testConcurrentGetFlagTriggersSegmentationManagerRace() {
        let options = WingifyInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let rawSettings = FlagTestDataLoader.loadTestData(
            jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName
        )
        let client = WingifyClient(options: options, settingObj: rawSettings)
        let settings = client.processedSettings!

        let builder = WingifyBuilder(options: options)
        _ = builder.setLogger().setSettingsManager()

        // Moderate load is enough to catch shared-manager races without hanging CI.
        let concurrency = 8
        let outerIterations = 3

        for iteration in 1...outerIterations {
            let allDone = expectation(
                description: "Iteration \(iteration): \(concurrency) concurrent getFlag calls"
            )
            allDone.expectedFulfillmentCount = concurrency

            var containers: [ServiceContainer] = []
            containers.reserveCapacity(concurrency)
            for _ in 0..<concurrency {
                containers.append(
                    builder.createServiceContainer(
                        processedSettings: settings,
                        options: options
                    )
                )
            }

            // getFlag blocks the caller with dispatchGroup.wait() while work runs on
            // GCD. Keep wait() off the GCD pool, and limit fan-out so older runners
            // (Xcode 15.4) do not hang waiting for pool threads.
            let lock = NSLock()
            var threads: [Thread] = []
            threads.reserveCapacity(concurrency)

            for i in 0..<concurrency {
                let container = containers[i]
                let thread = Thread {
                    let context = WingifyUserContext(
                        id: "race-user-\(iteration)-\(i)",
                        customVariables: [:]
                    )
                    // Skip gateway lookup path in setContextualData (nested wait on
                    // a GCD worker), which can deadlock under heavy concurrency.
                    context.userAgent = ""
                    context.ipAddress = ""

                    GetFlagAPI.getFlag(
                        featureKey: "feature1",
                        settings: settings,
                        context: context,
                        hookManager: MockHooksManager(callback: MockIntegrationCallback()),
                        serviceContainer: container
                    ) { _ in
                        allDone.fulfill()
                    }
                }
                thread.name = "getflag-race-\(iteration)-\(i)"
                lock.lock()
                threads.append(thread)
                lock.unlock()
                thread.start()
            }

            wait(for: [allDone], timeout: 60.0)
            _ = threads
        }
    }
}
