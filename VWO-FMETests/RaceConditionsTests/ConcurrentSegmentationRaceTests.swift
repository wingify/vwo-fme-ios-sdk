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
 * WITHOUT WARRANTIES OR CONDITIONS under the License.
 */

/**
 * Tests that SegmentationManager is safe when many getFlag calls run at the same time.
 *
 * All getFlag calls use one shared ServiceContainer and one shared SegmentationManager.
 * If two threads update the internal evaluator at the same time (e.g. both do
 * self.evaluator = SegmentEvaluator()), the same old evaluator can be released
 * twice. That double-free can corrupt memory and crash the app. These tests
 * stress that code path so the race is fixed and does not happen in production.
 */

import XCTest
@testable import VWO_FME

final class ConcurrentSegmentationRaceTests: XCTestCase {

    // MARK: - Shared setup

    private var mockCallback: MockIntegrationCallback!
    private var mockHookManager: MockHooksManager!

    override func setUp() {
        super.setUp()
        mockCallback = MockIntegrationCallback()
        mockHookManager = MockHooksManager(callback: mockCallback)
    }

    override func tearDown() {
        mockHookManager = nil
        mockCallback = nil
        super.tearDown()
    }

    // MARK: - Test: Full stack reproduction via GetFlagAPI

    /// Runs getFlag from many threads at once, all using the same ServiceContainer.
    /// Each call eventually touches the shared SegmentationManager and can trigger
    /// the race on its internal evaluator. Without a fix this can crash or trigger
    /// Thread Sanitizer "data race" warnings.
    func testConcurrentGetFlagTriggersSegmentationManagerRace() {

        // Settings and one shared container (so all threads share the same SegmentationManager)
        let options = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let rawSettings = FlagTestDataLoader.loadTestData(
            jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName
        )
        let client = VWOClient(options: options, settingObj: rawSettings)
        let settings = client.processedSettings!

        let builder = VWOBuilder(options: options)
        _ = builder.setLogger().setSettingsManager()

        // One shared container means one shared SegmentationManager — that’s what exposes the race.
        let sharedContainer = builder.createServiceContainer(
            processedSettings: settings,
            options: options
        )

        // How many threads call getFlag at once, and how many times we repeat (to increase chance of catching the race).
        let concurrency = 50
        let outerIterations = 20

        for iteration in 1...outerIterations {

            let allDone = expectation(
                description: "Iteration \(iteration): \(concurrency) concurrent getFlag calls"
            )
            allDone.expectedFulfillmentCount = concurrency

            // Run many getFlag calls at the same time so they can race on the shared SegmentationManager.
            DispatchQueue.global(qos: .userInitiated).async {
                DispatchQueue.concurrentPerform(iterations: concurrency) { i in
                    let context = VWOUserContext(
                        id: "race-user-\(iteration)-\(i)",
                        customVariables: [:]
                    )
                    GetFlagAPI.getFlag(
                        featureKey: "feature1",
                        settings: settings,
                        context: context,
                        hookManager: self.mockHookManager,
                        serviceContainer: sharedContainer
                    ) { _ in
                        allDone.fulfill()
                    }
                }
            }

            wait(for: [allDone], timeout: 30.0)
        }
    }
}
