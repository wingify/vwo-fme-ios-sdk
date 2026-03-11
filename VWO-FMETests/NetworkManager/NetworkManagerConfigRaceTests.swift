/**
 * NetworkManagerConfigRaceTests.swift
 *
 * Reproduces the data race on NetworkManager.config that causes production crashes
 * originating in RequestModel.setOptions() called from NetworkClient.POST:
 *
 *   CRASH — EXC_BREAKPOINT / heap corruption — 3 events / 3 users:
 *     _xzm_xzone_malloc_freelist_outlined
 *     swift::swift_slowAllocTyped(unsigned long, unsigned long, unsigned long long)
 *     swift_allocObject
 *     _allocateStringStorage(codeUnitCapacity:)
 *     _StringGuts.prepareForAppendInPlace(totalCount:otherUTF8Count:)
 *     _StringGuts.append(_:)
 *     RequestModel.setOptions()                     ← RequestModel.swift:38
 *     specialized NetworkClient.POST(request:completion:)  ← NetworkClient.swift:29
 *     closure #1 in static NetworkManager.postAsync(_:completion:)
 *
 * ROOT CAUSE:
 *   NetworkManager declares two static mutable properties with no synchronisation:
 *
 *     static var config: GlobalRequestModel? = nil       // internal — readable from tests
 *     private static var client: NetworkClientInterface? = nil
 *
 *   Both are written by attachClient() (called once during SDK initialisation) and
 *   read on every network request via createRequest(), which runs on a concurrent
 *   global background queue:
 *
 *     private static let executorService = DispatchQueue.global(qos: .background)
 *     ...
 *     static func postAsync(_ request: RequestModel, ...) {
 *         executorService.async {
 *             ...
 *             post(request) { ... }   // ← calls createRequest() → reads config
 *         }
 *     }
 *
 *   GlobalRequestModel contains COW collection types (query: [String: Any]?,
 *   headers: [String: String]?). When one thread writes NetworkManager.config
 *   while another thread reads it, the Swift runtime simultaneously retains and
 *   releases the same underlying COW buffer. The resulting ARC race corrupts the
 *   malloc freelist. The corruption surfaces on the next heap allocation — which
 *   happens to be inside RequestModel.setOptions() when it grows a string buffer —
 *   causing _xzm_xzone_malloc_freelist_outlined to trap.
 *
 * WHY IT APPEARS IN 11.13.0:
 *   The crash is marked SIGNAL_FRESH (first seen 4 days ago) and only appears in
 *   app version 11.13.0. It likely became reproducible after a change increased
 *   the rate of concurrent postAsync() calls during SDK initialisation, narrowing
 *   the window in which the race fires.
 *
 * SUGGESTED FIX:
 *   Protect config and client behind a serial queue or lock, or declare them with
 *   nonisolated(unsafe) and guard all accesses with an os_unfair_lock:
 *
 *     private static let configLock = NSLock()
 *     private static var _config: GlobalRequestModel? = nil
 *     static var config: GlobalRequestModel? {
 *         get { configLock.withLock { _config } }
 *         set { configLock.withLock { _config = newValue } }
 *     }
 *
 *   Alternatively, start() can be the sole writer of config and always run on a
 *   known serial queue, guaranteeing that all reads from postAsync() happen-after
 *   the write.
 *
 * HOW TO RUN:
 *   swift test --filter NetworkManagerConfigRaceTests
 *
 *   Expected result without fix: crash (heap corruption — signal 5 or 11, or
 *   SIGABRT from the malloc freelist check). With Thread Sanitizer enabled
 *   (Xcode → Edit Scheme → Diagnostics → Thread Sanitizer), TSan will report
 *   the data race on NetworkManager.config deterministically.
 *   With a proper fix the test suite completes normally.
 */

import XCTest
@testable import VWO_FME

final class NetworkManagerConfigRaceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset shared state between tests. NetworkManager.client is private and
        // cannot be reset, but attachClient() is guarded by `if self.client != nil`,
        // so whichever test runs first (alphabetically: testConcurrent... then
        // testPostAsync...) will find client == nil and install the stub.
        NetworkManager.config = nil
    }

    // MARK: - Stub network client (avoids real I/O in test 2)

    /// Conforms to NetworkClientInterface and immediately calls completion so that
    /// postAsync() finishes without making synchronous network requests — which
    /// use exponential-backoff retries and would stall the test for minutes.
    private class StubNetworkClient: NetworkClientInterface {
        func GET(request: RequestModel, completion: @escaping (ResponseModel) -> Void) {
            completion(ResponseModel())
        }
        func POST(request: RequestModel, completion: @escaping (ResponseModel) -> Void) {
            completion(ResponseModel())
        }
    }

    // MARK: - Test 1: Concurrent read/write on NetworkManager.config

    /// Drives simultaneous reads and writes of NetworkManager.config from a
    /// thread pool, reproducing the production race between attachClient() (writer)
    /// and postAsync() → createRequest() (reader).
    ///
    /// GlobalRequestModel contains COW dictionaries (query, headers). Concurrently
    /// retaining and releasing their underlying storage — which happens when Swift
    /// copies a GlobalRequestModel? on read while another thread replaces it on
    /// write — produces the ARC retain-count race that corrupts the malloc freelist.
    ///
    /// Expected result without fix: crash (heap corruption) or TSan "data race on
    /// NetworkManager.config".
    func testConcurrentReadWriteOnNetworkManagerConfig() {
        // Seed config with COW collection storage so there is a live reference-
        // counted buffer for the race to corrupt.
        var initial = GlobalRequestModel()
        initial.baseUrl = "https://dev.visualwebsiteoptimizer.com"
        initial.query = ["env": "test", "platform": "ios"]
        initial.headers = ["Authorization": "Bearer test-sdk-key"]
        NetworkManager.config = initial

        let concurrency = 200
        let outerIterations = 50

        for _ in 1...outerIterations {
            // concurrentPerform runs all iterations simultaneously across the thread
            // pool. Even iterations write a new GlobalRequestModel (replacing the
            // stored COW buffers); odd iterations read the current config. Without
            // synchronisation, the ARC operations on the shared buffers race.
            DispatchQueue.concurrentPerform(iterations: concurrency) { i in
                if i.isMultiple(of: 2) {
                    // Write path — mirrors attachClient() assigning config.
                    var updated = GlobalRequestModel()
                    updated.baseUrl = "https://dev.visualwebsiteoptimizer.com"
                    updated.query = ["env": "test", "iteration": "\(i)"]
                    updated.headers = ["Authorization": "Bearer key-\(i)"]
                    NetworkManager.config = updated
                } else {
                    // Read path — mirrors createRequest() consuming config.
                    _ = NetworkManager.config
                }
            }
        }
    }

    // MARK: - Test 2: Concurrent postAsync calls racing with config replacement

    /// Simulates the production scenario more directly: multiple postAsync() calls
    /// are dispatched to the global concurrent background queue while config is
    /// simultaneously replaced, reproducing the race between SDK initialisation
    /// and in-flight network requests.
    ///
    /// postAsync() reads NetworkManager.config inside createRequest() on the
    /// executor's concurrent queue. Replacing config from a second concurrent
    /// source while those reads are in flight races on the COW buffer reference
    /// counts.
    ///
    /// A StubNetworkClient is installed to prevent real synchronous network I/O
    /// (which retries with exponential backoff and would stall the test).
    /// attachClient() is guarded by `if self.client != nil { return }`, so the
    /// stub is installed only when client has not been set by a prior test;
    /// this holds when tests run in their default alphabetical order.
    ///
    /// Expected result without fix: crash or TSan "data race on NetworkManager.config".
    func testPostAsyncRacesWithConfigReplacement() {
        var base = GlobalRequestModel()
        base.baseUrl = "https://dev.visualwebsiteoptimizer.com"
        base.query = ["env": "test"]
        base.headers = ["Authorization": "Bearer test-key"]
        NetworkManager.config = base

        // Install the stub client. attachClient() also resets config to a fresh
        // empty GlobalRequestModel, so we re-seed COW buffers afterwards.
        NetworkManager.attachClient(client: StubNetworkClient())
        NetworkManager.config = base

        let group = DispatchGroup()
        let concurrency = 100

        for i in 0..<concurrency {
            group.enter()
            // Dispatch postAsync calls — these read config inside createRequest()
            // on DispatchQueue.global(qos: .background).
            var request = RequestModel(port: 443)
            request.url = "https://dev.visualwebsiteoptimizer.com"
            request.path = "/server-side/track-user"
            request.query = ["a": "\(i)"]
            NetworkManager.postAsync(request) { _ in
                group.leave()
            }

            // Simultaneously replace config from the current thread — this is the
            // write that races against the reads inside the dispatched postAsync blocks.
            var replacement = GlobalRequestModel()
            replacement.baseUrl = "https://dev.visualwebsiteoptimizer.com"
            replacement.query = ["env": "race-\(i)"]
            replacement.headers = ["Authorization": "Bearer race-key-\(i)"]
            NetworkManager.config = replacement
        }

        group.wait()
    }
}
