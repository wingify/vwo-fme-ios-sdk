/**
 * ConcurrentSegmentationRaceTests.swift
 *
 * Reproduces the data race in SegmentationManager that causes two production crashes:
 *
 *   CRASH 1 (com.apple.root.background-qos):
 *     _xzm_xzone_malloc_freelist_outlined — malloc freelist corrupted
 *     ← heap corruption downstream of the double-free below
 *
 *   CRASH 2 (com.vwo.fme.getflag):
 *     objc_class::realizeIfNeeded() in objc_destructInstance
 *     SegmentEvaluator.__deallocating_deinit (SegmentEvaluator.swift:19)
 *     ← isa pointer is garbage because the object was already freed
 *
 * ROOT CAUSE:
 *   GetFlagAPI.getFlag dispatches work onto a *concurrent* DispatchQueue:
 *
 *     let queueFlag = DispatchQueue(label: "com.vwo.fme.getflag",
 *                                   qos: .userInitiated,
 *                                   attributes: .concurrent)   // ← CONCURRENT
 *
 *   Multiple simultaneous getFlag calls all share the same ServiceContainer,
 *   which holds a single SegmentationManager instance. Each concurrent work
 *   item calls:
 *
 *     serviceContainer.getSegmentationManager()   // returns the SAME instance
 *         .setContextualData(...)                  // GetFlagAPI.swift:140
 *
 *   Inside setContextualData (SegmentationManager.swift:57):
 *
 *     self.attachEvaluator()
 *       → self.evaluator = SegmentEvaluator()     // ← NO LOCK, NO BARRIER
 *
 *   When two threads execute this simultaneously:
 *     Thread A reads old SegmentEvaluator, decrements its refcount → 0 → DEALLOC
 *     Thread B reads same old SegmentEvaluator, decrements its refcount → -1 → DEALLOC AGAIN
 *     Double-free corrupts the heap / isa pointer → crash on next alloc or dealloc
 *
 * HOW TO RUN:
 *   Normal run:   crash is non-deterministic but likely within a few iterations
 *   With TSan:    Xcode → Edit Scheme → Diagnostics → Thread Sanitizer ✓
 *                 TSan will report the race deterministically on the first hit
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

    // MARK: - Test 1: Full stack reproduction via GetFlagAPI

    /// Calls GetFlagAPI.getFlag from many threads simultaneously, all sharing one
    /// ServiceContainer. Each call dispatches onto a concurrent internal queue and
    /// calls setContextualData on the same SegmentationManager, triggering the race
    /// on self.evaluator.
    ///
    /// Expected result without fix: crash (EXC_BAD_ACCESS / heap corruption) or
    /// TSan report "data race on SegmentationManager.evaluator"
    func testConcurrentGetFlagTriggersSegmentationManagerRace() {

        // ── Settings & container setup ──────────────────────────────────────────
        let options = VWOInitOptions(sdkKey: "sdk-key", accountId: 123456)
        let rawSettings = FlagTestDataLoader.loadTestData(
            jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName
        )
        let client = VWOClient(options: options, settingObj: rawSettings)
        let settings = client.processedSettings!

        let builder = VWOBuilder(options: options)
        _ = builder.setLogger().setSettingsManager()

        // ONE shared container → ONE shared SegmentationManager.
        // This is the key: all concurrent getFlag calls share the same instance.
        let sharedContainer = builder.createServiceContainer(
            processedSettings: settings,
            options: options
        )

        // ── Stress parameters ───────────────────────────────────────────────────
        // concurrency: number of simultaneous getFlag calls per storm
        // outerIterations: how many storms to run (increases total exposure time)
        let concurrency = 50
        let outerIterations = 20

        for iteration in 1...outerIterations {

            let allDone = expectation(
                description: "Iteration \(iteration): \(concurrency) concurrent getFlag calls"
            )
            allDone.expectedFulfillmentCount = concurrency

            // DispatchQueue.concurrentPerform blocks until all iterations complete
            // while running them concurrently across the thread pool. This maximises
            // the chance that multiple calls reach self.evaluator = SegmentEvaluator()
            // simultaneously in SegmentationManager.setContextualData.
            DispatchQueue.global(qos: .userInitiated).async {
                DispatchQueue.concurrentPerform(iterations: concurrency) { i in
                    let context = VWOUserContext(
                        id: "race-user-\(iteration)-\(i)",
                        customVariables: [:]
                    )
                    // Each call internally:
                    //   1. Creates a new concurrent DispatchQueue
                    //   2. Dispatches work onto it (races with sibling calls)
                    //   3. In that work: calls sharedContainer.getSegmentationManager()
                    //      .setContextualData(...) → self.attachEvaluator()
                    //      → self.evaluator = SegmentEvaluator()   ← RACE HAPPENS HERE
                    GetFlagAPI.getFlag(
                        featureKey: "feature1",
                        settings: settings,
                        context: context,
                        hookManager: self.mockHookManager,
                        serviceContainer: sharedContainer   // shared → triggers the race
                    ) { _ in
                        allDone.fulfill()
                    }
                }
            }

            // Allow generous timeout; a crash will kill the test before this fires.
            wait(for: [allDone], timeout: 30.0)
        }
    }

    // MARK: - Test 2: Isolated reproduction directly on SegmentationManager

    /// Bypasses the full getFlag stack and directly hammers attachEvaluator()
    /// from many concurrent threads on a single shared SegmentationManager.
    ///
    /// This isolates the exact racing line:
    ///   self.evaluator = SegmentEvaluator()   (SegmentationManager.swift:39)
    ///
    /// Expected result without fix: crash or TSan "data race" report immediately.
    /// This test is faster and more deterministic than the full-stack test above.
    func testConcurrentAttachEvaluatorDirectlyRacesOnEvaluatorProperty() {

        // One shared manager — mirrors serviceContainer.getSegmentationManager()
        let sharedManager = SegmentationManager()

        let concurrency = 200    // threads hammering simultaneously
        let outerIterations = 50 // repeat to accumulate exposure

        for _ in 1...outerIterations {
            // concurrentPerform dispatches all iterations onto the global pool
            // and blocks until they all complete. With 200 simultaneous writers
            // and no lock on evaluator, double-free is highly likely.
            DispatchQueue.concurrentPerform(iterations: concurrency) { _ in
                // THE RACING LINE — no lock guards this write:
                //   self.evaluator = SegmentEvaluator()
                // When two threads replace evaluator simultaneously, the old
                // SegmentEvaluator's refcount hits zero twice → double-free.
                sharedManager.attachEvaluator()
            }
        }
    }
}
