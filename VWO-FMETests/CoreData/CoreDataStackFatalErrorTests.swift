/**
 * CoreDataStackFatalErrorTests.swift
 *
 * Reproduces the unrecoverable crash in CoreDataStack.setupCoreDataStack() that
 * terminates the host application when the SQLite persistent store fails to open.
 *
 *   CRASH — EXC_CRASH (SIGABRT) — 19 events / 15 users:
 *     specialized CoreDataStack.setupCoreDataStack()
 *     CoreDataStack.init()
 *     static CoreDataStack.shared.getter
 *     ← Swift fatalError() calls _assertionFailure() which calls abort(). Every call
 *       site that accesses CoreDataStack.shared before or after this failure terminates
 *       the process rather than returning an error to the caller.
 *
 * ROOT CAUSE:
 *   setupCoreDataStack() uses fatalError() for every failure path, including errors
 *   that are environmental and recoverable:
 *
 *     (a) SQLite store corrupted after an interrupted write or failed migration (line 74):
 *           do {
 *               try persistentStoreCoordinator.addPersistentStore(
 *                   ofType: NSSQLiteStoreType, ..., at: storeURL, options: options)
 *           } catch {
 *               fatalError("Unresolved error \(error), \(error.localizedDescription)")
 *           }
 *
 *     (b) Core Data migration failure caused by a schema change between app versions
 *         routed to the same fatalError at line 74.
 *
 *     (c) Directory creation failure on a nearly-full device (line 65).
 *
 *   None of these conditions signal programmer error. Using fatalError() turns a
 *   degraded-but-survivable state (offline event storage unavailable) into an
 *   immediate application crash visible to the end user.
 *
 * SUGGESTED FIX:
 *   Replace each fatalError() with graceful error handling — log the failure and
 *   disable offline storage rather than terminating the process:
 *
 *     } catch {
 *         // Offline storage unavailable; continue without persisting events locally.
 *         LogManager.instance?.log(level: .error, message: "CoreData unavailable: \(error)")
 *         return
 *     }
 *
 *   A more resilient approach deletes the corrupted store and retries before
 *   falling back to in-memory storage.
 *
 * HOW TO RUN:
 *   # 1. Compile the CoreData model (swift test does not run momc automatically):
 *   xcrun momc VWO-FME/CoreData/Model/OffineEventData.xcdatamodeld \
 *       .build/arm64-apple-macosx/debug/VWO-FME_VWO-FME.bundle/OffineEventData.momd
 *
 *   # 2. Run the test in isolation (must execute before any other test that accesses
 *   #    CoreDataStack.shared, since the crash happens on first singleton initialisation):
 *   swift test --filter CoreDataStackFatalErrorTests
 *
 *   In Xcode the momc step is automatic; run the test target normally with
 *   Cmd-U or Product → Test → CoreDataStackFatalErrorTests.
 *
 *   Expected result without fix: process terminates with SIGABRT from fatalError().
 *   XCTest reports the test as crashed rather than failed.
 *   With a proper fix the test suite completes normally.
 */

import XCTest
@testable import VWO_FME

final class CoreDataStackFatalErrorTests: XCTestCase {

    /// Writes non-SQLite bytes to the store path that CoreDataStack.setupCoreDataStack()
    /// will use, then accesses CoreDataStack.shared for the first time to trigger
    /// initialisation. NSPersistentStoreCoordinator.addPersistentStore(_:) throws when
    /// the file header does not match the SQLite magic bytes; the current implementation
    /// passes that error directly to fatalError(), terminating the process.
    ///
    /// This replicates the production scenario where the SQLite database was corrupted
    /// by an interrupted write or a failed Core Data migration.
    ///
    /// No production code is modified — the test simply pre-populates the store file
    /// with bad data so that the real setupCoreDataStack() code path encounters the
    /// same error as it does on affected devices.
    ///
    /// Expected result without fix: SIGABRT — XCTest reports "Test crashed with signal 6".
    func testCorruptedSharedStoreTriggersFatalError() throws {
        // Replicate the store path computed inside setupCoreDataStack() so we can
        // plant a corrupted file there before the singleton initialises.
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let storeDir = cachesDir.appendingPathComponent("VWO_FME/CoreData", isDirectory: true)
        let storeURL = storeDir.appendingPathComponent("OffineEventData.sqlite")

        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        // Overwrite the store file with bytes whose header is not the SQLite magic
        // sequence (53 51 4C 69 74 65…), causing addPersistentStore to throw
        // NSCocoaErrorDomain code 259: "couldn't be opened because it isn't in the
        // correct format."
        let corruptBytes = Data("not a sqlite database — simulating a corrupted store".utf8)
        try corruptBytes.write(to: storeURL)

        // First access of CoreDataStack.shared triggers:
        //   CoreDataStack.init()
        //     → setupCoreDataStack()
        //         → addPersistentStore(at: storeURL)   ← throws NSError code 259
        //         → fatalError(...)                    ← SIGABRT (line 74)
        //
        // Without a fix the process exits here.
        _ = CoreDataStack.shared
    }
}
