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
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import CoreData

/**
 * Manages Core Data stack operations including saving, fetching, and deleting data.
 */
class CoreDataStack {
    static let shared = CoreDataStack()
    
    // Name of the Core Data model
    private let modelName = "OffineEventData"
    
    // SQLite database file for your Core Data store
    private let storeName = "OffineEventData.sqlite"

    // Name of the entity in the Core Data model
    private let entityName = "EventData"
    private let coreDataQueue = DispatchQueue(label: "com.vwo.fme.coredatastack", qos: .userInitiated, attributes: .concurrent)
    
    var context: NSManagedObjectContext!
    
    private init() {
        setupCoreDataStack()
    }
    
    private func setupCoreDataStack() {
        
#if SWIFT_PACKAGE
        // For Swift Package Manager
        let bundle = Bundle.module
#else
        // For CocoaPods
        let bundle = Bundle(for: type(of: self))
#endif
        guard let modelURL = bundle.url(forResource: self.modelName, withExtension: "momd") else {
            fatalError("Error loading model from bundle")
        }
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: mom)
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(self.storeName)")
        let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                             NSInferMappingModelAutomaticallyOption: true]
        
        do {
            try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
        } catch {
            fatalError("Unresolved error \(error), \(error.localizedDescription)")
        }
        
        self.context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.context.persistentStoreCoordinator = persistentStoreCoordinator
        self.context.automaticallyMergesChangesFromParent = true
    }
    
    /**
     * Saves changes in the context to the persistent store.
     */
    func saveContext(completion: @escaping (Bool, Error?) -> Void) {
        coreDataQueue.async {
            self.context.perform {
                if self.context.hasChanges {
                    do {
                        try self.context.save()
                        completion(true, nil)
                    } catch {
                        completion(false, error)
                        let nserror = error as NSError
                        fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                    }
                } else {
                    completion(true, nil)
                }
            }
        }
    }
    
    /**
     * Fetches managed objects from Core Data.
     *
     * - Parameter completion: A closure that is called with the fetched objects or an error.
     */
    func fetchManagedObjects(completion: @escaping ([EventData]?, Error?) -> Void) {
        coreDataQueue.async {
            let fetchRequest: NSFetchRequest<EventData> = EventData.fetchRequest()
            self.context.perform {
                do {
                    let result = try self.context.fetch(fetchRequest)
                    completion(result, nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
    }
    
    /**
     * Counts the number of entries in the Core Data store.
     *
     * - Parameter completion: A closure that is called with the count or an error.
     */
    func countEntries(completion: @escaping (Int?, Error?) -> Void) {
        coreDataQueue.async {
            let fetchRequest: NSFetchRequest<NSNumber> = NSFetchRequest(entityName: self.entityName)
            fetchRequest.resultType = .countResultType
            self.context.perform {
                do {
                    let countResult = try self.context.fetch(fetchRequest)
                    let count = countResult.first?.intValue ?? 0
                    completion(count, nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
    }
    
    /**
     * Deletes a batch of events from Core Data.
     *
     * - Parameters:
     *   - events: An array of EventData objects to be deleted.
     *   - completion: A closure that is called with an error if the operation fails.
     */
    func delete(events: [EventData], completion: @escaping (Error?) -> Void) {
        coreDataQueue.async {
            self.context.perform {
                for item in events {
                    self.context.delete(item)
                }
                self.saveContext { done, error in
                    if let err = error {
                        completion(err)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    /**
     * Clears all entries in the specified Core Data entity.
     * This is useful for running test cases in isolation, ensuring a clean state.
     */
    func clearCoreData() {
        coreDataQueue.async {
            self.countEntries { count , err in
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: self.entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                do {
                    try self.context.execute(deleteRequest)
                    try self.context.save()
                } catch {
                    print("Error \(error.localizedDescription)")
                }
            }
        }
    }
}
