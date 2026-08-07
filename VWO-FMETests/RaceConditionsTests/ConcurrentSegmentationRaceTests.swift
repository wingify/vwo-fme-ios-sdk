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
 * Stress-tests concurrent getFlag calls under multi-instance isolation.
 *
 * Each concurrent call uses its own ServiceContainer (and SegmentationManager).
 * Sharing one SegmentationManager across threads while setContextualData replaces
 * the internal evaluator can crash; production callers should use one container
 * per SDK instance, not one shared container from many threads at once.
 */

import XCTest
@testable import VWO_FME

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

    /// Runs many getFlag calls concurrently, each with its own ServiceContainer.
    func testConcurrentGetFlagTriggersSegmentationManagerRace() {
        let options = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let rawSettings = FlagTestDataLoader.loadTestData(
            jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName
        )
        let client = VWOClient(options: options, settingObj: rawSettings)
        let settings = client.processedSettings!

        let builder = VWOBuilder(options: options)
        _ = builder.setLogger().setSettingsManager()

        let concurrency = 50
        let outerIterations = 5

        for iteration in 1...outerIterations {
            let allDone = expectation(
                description: "Iteration \(iteration): \(concurrency) concurrent getFlag calls"
            )
            allDone.expectedFulfillmentCount = concurrency

            DispatchQueue.concurrentPerform(iterations: concurrency) { i in
                // Per-thread container = per-thread SegmentationManager (matches multi-instance usage).
                let container = builder.createServiceContainer(
                    processedSettings: settings,
                    options: options
                )
                let context = VWOUserContext(
                    id: "race-user-\(iteration)-\(i)",
                    customVariables: [:]
                )
                GetFlagAPI.getFlag(
                    featureKey: "feature1",
                    settings: settings,
                    context: context,
                    hookManager: self.mockHookManager,
                    serviceContainer: container
                ) { _ in
                    allDone.fulfill()
                }
            }

            wait(for: [allDone], timeout: 30.0)
        }
    }
}
