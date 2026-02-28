/**
 * NetworkMonitorRaceTests.swift
 *
 * Reproduces the data race in NetworkMonitor that causes two production crashes,
 * both originating on the com.apple.root.background-qos concurrent queue:
 *
 *   CRASH 1 (EXC_BAD_ACCESS KERN_INVALID_ADDRESS) — 88 events / 88 users:
 *     dispatch thunk of DispatchWorkItem.cancel()
 *     closure #1 in NetworkMonitor.startMonitoring()      ← line 49
 *     nw_utilities_copy_local_entitlement_value
 *     _dispatch_call_block_and_release
 *     ← Two threads simultaneously call debounceWorkItem?.cancel().
 *       Thread B drops the last strong reference and ARC frees the object.
 *       Thread A is left calling .cancel() on deallocated memory.
 *
 *   CRASH 2 (EXC_BREAKPOINT) — 6 events / 6 users:
 *     _dispatch_Block_copy.cold.1
 *     _swift_dispatch_after
 *     closure #1 in NetworkMonitor.startMonitoring()      ← line 62
 *     nw_path_copy_effective_local_endpoint
 *     ← Thread A passes workItem to asyncAfter. Thread B has already replaced
 *       debounceWorkItem, freeing the block that Thread A holds. dispatch_after
 *       then copies a freed block pointer → EXC_BREAKPOINT in Block_copy.
 *
 * ROOT CAUSE:
 *   NWPathMonitor is started on DispatchQueue.global(qos: .background):
 *
 *     private let queue = DispatchQueue.global(qos: .background)  // CONCURRENT
 *     ...
 *     monitor.start(queue: queue)
 *
 *   A global queue is concurrent. When network conditions change in rapid
 *   succession (e.g. WiFi drops then reconnects), NWPathMonitor can invoke
 *   pathUpdateHandler from multiple threads simultaneously. Both invocations
 *   touch self.debounceWorkItem without any synchronisation:
 *
 *     self.debounceWorkItem?.cancel()          // line 49 — read + call on old item
 *     self.debounceWorkItem = DispatchWorkItem // line 50 — unguarded write
 *     ...
 *     if let workItem = self.debounceWorkItem  // line 61 — read
 *       debounceQueue.asyncAfter(..., execute: workItem)  // line 62 — use
 *
 *   This is a classic ARC retain-count race:
 *     Thread A reads old DispatchWorkItem, holds a temporary reference
 *     Thread B writes new DispatchWorkItem, releasing old one → refcount 0 → DEALLOC
 *     Thread A calls .cancel() or asyncAfter on the now-freed object → crash
 *
 * HOW TO RUN:
 *   Normal run:   swift test --filter NetworkMonitorRaceTests
 *                 Crash is non-deterministic but typically occurs within the
 *                 first outer iteration.
 *   With TSan:    Xcode → Edit Scheme → Diagnostics → Thread Sanitizer ✓
 *                 TSan will report the race deterministically on the first hit.
 */

import XCTest
@testable import VWO_FME

@available(macOS 10.14, *)
final class NetworkMonitorRaceTests: XCTestCase {

    // MARK: - Test 1: Full context reproduction via startMonitoring

    /// Starts the monitor as production code does, then fires concurrent simulated
    /// path-available callbacks to reproduce the handler racing on debounceWorkItem.
    ///
    /// This mirrors the production scenario: NWPathMonitor runs on a global concurrent
    /// queue and delivers rapid successive path updates (e.g. WiFi flapping), causing
    /// multiple simultaneous executions of the pathUpdateHandler closure.
    ///
    /// Expected result without fix: crash (EXC_BAD_ACCESS / EXC_BREAKPOINT) or
    /// TSan report "data race on NetworkMonitor.debounceWorkItem"
    func testConcurrentPathUpdatesRaceOnDebounceWorkItem() {

        // Start monitoring exactly as production code does.
        // This sets isMonitoring = true and wires up pathUpdateHandler on the
        // global concurrent background queue — the environment in which the crash occurs.
        NetworkMonitor.shared.startMonitoring()
        defer { NetworkMonitor.shared.stopMonitoring() }

        // ── Stress parameters ───────────────────────────────────────────────────
        // concurrency: simultaneous simulated path updates per storm
        // outerIterations: how many storms to run (increases total exposure)
        let concurrency = 200
        let outerIterations = 50

        for _ in 1...outerIterations {
            // concurrentPerform blocks until all iterations complete while running
            // them simultaneously across the thread pool. This maximises the chance
            // that two threads reach debounceWorkItem?.cancel() and the subsequent
            // assignment at the same instant.
            DispatchQueue.concurrentPerform(iterations: concurrency) { _ in
                // Each call replicates exactly what pathUpdateHandler does in the
                // .satisfied branch: cancel the old workItem, create and store a
                // new one, then schedule it with asyncAfter.
                //
                // Without synchronisation, two concurrent invocations race on the
                // optional debounceWorkItem property, producing the crashes above.
                NetworkMonitor.shared.simulateNetworkAvailable()
            }
        }
    }

    // MARK: - Test 2: Isolated reproduction directly on debounceWorkItem

    /// Bypasses startMonitoring and drives simulateNetworkAvailable() directly
    /// from many concurrent threads, isolating the exact racing operations:
    ///
    ///   self.debounceWorkItem?.cancel()          ← line 49 analogue
    ///   self.debounceWorkItem = DispatchWorkItem  ← line 50 analogue — THE RACE
    ///   asyncAfter(..., execute: workItem)        ← line 62 analogue
    ///
    /// This test is faster and more deterministic than the full-context test above
    /// because it eliminates NWPathMonitor scheduling latency from the picture.
    ///
    /// Expected result without fix: crash or TSan "data race" report immediately.
    func testDirectConcurrentSimulatedUpdatesRaceOnDebounceWorkItem() {

        let concurrency = 200    // threads hammering simultaneously
        let outerIterations = 50 // repeat to accumulate exposure

        for _ in 1...outerIterations {
            // THE RACING SEQUENCE — no lock guards debounceWorkItem across these lines:
            //   self.debounceWorkItem?.cancel()          ← read + ARC retain + call
            //   self.debounceWorkItem = DispatchWorkItem ← write, releases old value
            //   asyncAfter(..., execute: workItem)       ← read + use after potential free
            //
            // With 200 concurrent callers and no synchronisation, two threads will
            // simultaneously hold a reference to the old DispatchWorkItem while one
            // of them releases it, producing a double-free or use-after-free.
            DispatchQueue.concurrentPerform(iterations: concurrency) { _ in
                NetworkMonitor.shared.simulateNetworkAvailable()
            }
        }
    }
}
