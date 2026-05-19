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
 * Tests that NetworkManager.config is safe when many threads read and write it at the same time.
 *
 * In production, config is set once during SDK init and read on every network request.
 * If one thread writes config while another reads it, Swift’s copy-on-write collections
 * can be retained and released at the same time. That can corrupt memory and crash
 * (e.g. in RequestModel.setOptions() or in the allocator). These tests stress that
 * path so the race is fixed. Run with Thread Sanitizer to see the data race if the fix is missing.
 */

import XCTest
@testable import VWO_FME

final class NetworkManagerConfigRaceTests: XCTestCase {

    private let stubClient = StubNetworkClient()

    override func setUp() {
        super.setUp()
        // attachClient is one-shot in the process; install the stub before any test in this class runs.
        NetworkManager.attachClient(client: stubClient)
        NetworkManager.config = nil
        // Other test classes may leave online batching enabled; postAsync skips completion when it is on.
        SyncManager.shared.stopSyncing()
        SyncManager.shared.initialize(minBatchSize: 0, timeInterval: 0)
    }

    // MARK: - Stub network client (avoids real I/O in test 2)

    /// Fake network client that returns immediately so tests don’t wait on real requests or retries.
    private class StubNetworkClient: NetworkClientInterface {
        func GET(request: RequestModel, completion: @escaping (ResponseModel) -> Void) {
            completion(ResponseModel())
        }
        func POST(request: RequestModel, completion: @escaping (ResponseModel) -> Void) {
            completion(ResponseModel())
        }
    }

    // MARK: - Test 1: Concurrent read/write on NetworkManager.config

    /// Many threads read and write config at the same time to trigger the race.
    /// Without a fix this can crash (heap corruption) or Thread Sanitizer will report a data race.
    func testConcurrentReadWriteOnNetworkManagerConfig() {
        // Set initial config so we have real data (dictionaries) for threads to read and replace.
        var initial = GlobalRequestModel()
        initial.baseUrl = "https://dev.visualwebsiteoptimizer.com"
        initial.query = ["env": "test", "platform": "ios"]
        initial.headers = ["Authorization": "Bearer test-sdk-key"]
        NetworkManager.config = initial

        let concurrency = 200
        let outerIterations = 50

        for _ in 1...outerIterations {
            // Even threads write a new config; odd threads read. This mimics one thread
            // setting config at init time while others read it during requests.
            DispatchQueue.concurrentPerform(iterations: concurrency) { i in
                if i.isMultiple(of: 2) {
                    var updated = GlobalRequestModel()
                    updated.baseUrl = "https://dev.visualwebsiteoptimizer.com"
                    updated.query = ["env": "test", "iteration": "\(i)"]
                    updated.headers = ["Authorization": "Bearer key-\(i)"]
                    NetworkManager.config = updated
                } else {
                    _ = NetworkManager.config
                }
            }
        }
    }

    // MARK: - Test 2: Concurrent post calls racing with config replacement

    /// Fires many network posts on a background queue while the test thread keeps replacing config.
    /// Mirrors postAsync’s background read of config without the online-batching early return
    /// (which does not invoke the completion handler and can hang CI when other tests enable batching).
    /// Without a fix this can crash or Thread Sanitizer will report a data race.
    func testPostAsyncRacesWithConfigReplacement() {
        var base = GlobalRequestModel()
        base.baseUrl = "https://dev.visualwebsiteoptimizer.com"
        base.query = ["env": "test"]
        base.headers = ["Authorization": "Bearer test-key"]
        NetworkManager.config = base

        let concurrency = 100
        let expectation = XCTestExpectation(description: "background post completions")
        expectation.expectedFulfillmentCount = concurrency

        for i in 0..<concurrency {
            var request = RequestModel(port: 443)
            request.url = "https://dev.visualwebsiteoptimizer.com"
            request.path = "/server-side/track-user"
            request.query = ["a": "\(i)"]

            // Same queue semantics as NetworkManager.postAsync (background), without batching branch.
            DispatchQueue.global(qos: .background).async {
                NetworkManager.post(request) { _ in
                    expectation.fulfill()
                }
            }

            // Replace config while the background work reads it — that’s the race.
            var replacement = GlobalRequestModel()
            replacement.baseUrl = "https://dev.visualwebsiteoptimizer.com"
            replacement.query = ["env": "race-\(i)"]
            replacement.headers = ["Authorization": "Bearer race-key-\(i)"]
            NetworkManager.config = replacement
        }

        wait(for: [expectation], timeout: 30.0)
    }
}
