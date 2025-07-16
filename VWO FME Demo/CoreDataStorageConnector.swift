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
import VWO_FME

class CoreDataStorageConnector: VWOStorageConnector {
    static let shared = CoreDataStorageConnector()
    let entityName = "VWOData"
    let context: NSManagedObjectContext

    private init() {
        // Set up Core Data stack for demo (simple, not production-hardened)
        let modelURL = Bundle.main.url(forResource: "VWO_FME_Demo", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        let container = NSPersistentContainer(name: "VWO_FME_Demo", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Core Data error: \(error)") }
        }
        self.context = container.viewContext
    }

    func set(_ value: Any?, forKey key: String) {
        print("[CoreDataStorageConnector] set called for key: \(key), value: \(String(describing: value))")
        let fetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
        fetch.predicate = NSPredicate(format: "key == %@", key)
        if let results = try? context.fetch(fetch), let obj = results.first as? NSManagedObject {
            obj.setValue(try? NSKeyedArchiver.archivedData(withRootObject: value as Any, requiringSecureCoding: false), forKey: "value")
        } else {
            let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)!
            let obj = NSManagedObject(entity: entity, insertInto: context)
            obj.setValue(key, forKey: "key")
            obj.setValue(try? NSKeyedArchiver.archivedData(withRootObject: value as Any, requiringSecureCoding: false), forKey: "value")
        }
        try? context.save()
    }

    func getData(forKey key: String) -> Data? {
        print("[CoreDataStorageConnector] getData called for key: \(key)")
        let fetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
        fetch.predicate = NSPredicate(format: "key == %@", key)
        if let results = try? context.fetch(fetch), let obj = results.first as? NSManagedObject {
            return obj.value(forKey: "value") as? Data
        }
        return nil
    }

    func getValue(forKey key: String) -> Any? {
        print("[CoreDataStorageConnector] getValue called for key: \(key)")
        guard let data = getData(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)
    }

    func getString(forKey key: String) -> String? {
        print("[CoreDataStorageConnector] getString called for key: \(key)")
        return getValue(forKey: key) as? String
    }

    func get(forKey key: String) -> [String: Any]? {
        print("[CoreDataStorageConnector] getDictionary called for key: \(key)")
        return getValue(forKey: key) as? [String: Any]
    }

}
