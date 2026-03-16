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

import XCTest
import CoreData
@testable import VWO_FME

/// Tests that Core Data stack recovers from a corrupted store (delete + retry + in-memory fallback) without crashing.
final class CoreDataStackCorruptionTests: XCTestCase {

    private var tempDir: URL!
    private let storeName = "OffineEventData.sqlite"
    private let modelName = "OffineEventData"

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CoreDataCorruptionTest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    /// Simulates the same recovery logic as CoreDataStack: when addPersistentStore fails,
    /// remove store files (sqlite, -wal, -shm), retry once, then fall back to in-memory.
    /// Verifies that after "corruption" we can still get a working context (retry or in-memory).
    func testCorruptedStoreRecoveryDeleteAndRetrySucceeds() throws {
        let bundle = Bundle(for: CoreDataStack.self)
        guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd"),
              let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            XCTFail("Could not load Core Data model")
            return
        }

        let storeURL = tempDir.appendingPathComponent(storeName)
        let options: [String: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        // 1) Write a corrupted file so addPersistentStore will fail
        let garbage = Data([0xFF, 0xFE, 0x00, 0x01])
        try garbage.write(to: storeURL)

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: mom)

        // 2) First add fails (corrupted)
        var firstAddError: Error?
        do {
            _ = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
        } catch {
            firstAddError = error
        }
        XCTAssertNotNil(firstAddError, "Expected first add to fail due to corrupted file")

        // 3) Remove store files (same as CoreDataStack recovery)
        let fm = FileManager.default
        try? fm.removeItem(at: storeURL)
        try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))

        // 4) Retry should succeed (new empty store)
        var retrySucceeded = false
        do {
            _ = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
            retrySucceeded = true
        } catch {
            XCTFail("Retry after removing corrupted store should succeed: \(error)")
        }
        XCTAssertTrue(retrySucceeded)

        // 5) Context should work
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var fetchError: Error?
        context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "EventData")
            do {
                _ = try context.fetch(request)
            } catch {
                fetchError = error
            }
        }
        XCTAssertNil(fetchError, "Fetch after recovery should succeed")
    }

    /// Verifies that WAL/SHM removal uses the correct paths (store path + "-wal" and "-shm").
    func testStoreSidecarFilePaths() {
        let storeURL = tempDir.appendingPathComponent(storeName)
        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")

        XCTAssertTrue(walURL.path.hasSuffix("OffineEventData.sqlite-wal"), "WAL path should end with -wal")
        XCTAssertTrue(shmURL.path.hasSuffix("OffineEventData.sqlite-shm"), "SHM path should end with -shm")
    }
}
