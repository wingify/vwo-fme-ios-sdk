/**
 * Copyright 2024 Wingify Software Pvt. Ltd.
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

protocol IStorageDecorator {
    func getFeatureFromStorage(featureKey: String, context: VWOContext, storageService: StorageService) -> [String: Any]?
    func setDataInStorage(data: [String: Any], storageService: StorageService) -> Variation?
}

class StorageDecorator: IStorageDecorator {
    
    func getFeatureFromStorage(featureKey: String, context: VWOContext, storageService: StorageService) -> [String: Any]? {
        return storageService.getDataInStorage(featureKey: featureKey, context: context)
    }
    
    func setDataInStorage(data: [String: Any], storageService: StorageService) -> Variation? {
        guard let featureKey = data["featureKey"] as? String, !featureKey.isEmpty else {
            LoggerService.log(level: .error, key: "STORING_DATA_ERROR", details: ["key": "featureKey"])
            return nil
        }
        
        guard let userId = data["user"] as? String, !userId.isEmpty else {
            LoggerService.log(level: .error, key: "STORING_DATA_ERROR", details: ["key": "Context or Context.id"])
            return nil
        }
        
        let rolloutKey = data["rolloutKey"] as? String
        let experimentKey = data["experimentKey"] as? String
        let rolloutVariationId = data["rolloutVariationId"] as? Int
        let experimentVariationId = data["experimentVariationId"] as? Int
        
        if let rolloutKey = rolloutKey, !rolloutKey.isEmpty, experimentKey == nil, rolloutVariationId == nil {
            LoggerService.log(level: .error, key: "STORING_DATA_ERROR", details: ["key": "Variation:(rolloutKey, experimentKey or rolloutVariationId)"])
            return nil
        }
        
        if let experimentKey = experimentKey, !experimentKey.isEmpty, experimentVariationId == nil {
            LoggerService.log(level: .error, key: "STORING_DATA_ERROR", details: ["key": "Variation:(experimentKey or rolloutVariationId)"])
            return nil
        }
        
        storageService.setDataInStorage(data: data)
        return nil //Variation()
    }
}
