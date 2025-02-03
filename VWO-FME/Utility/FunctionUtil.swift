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

/**
 * Utility struct for functional operations.
 *
 * This struct provides helper methods for performing functional operations, such as applying
 * functions to collections, transforming data, or working with higher-order functions.
 */
struct FunctionUtil {
    /**
     * Clones an object using JSON serialization and deserialization.
     * @param obj  The object to clone.
     * @return   The cloned object.
     */
    static func cloneObject<T: Codable>(_ obj: T?) -> T? {
        guard let obj = obj else { return nil }
        
        do {
            let jsonData = try JSONEncoder().encode(obj)
            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            print("Error cloning object: \(error)")
            return nil
        }
    }
    
    /**
     * Retrieves the current Unix timestamp in seconds.
     * @return  The current Unix timestamp in seconds.
     */
    static var currentUnixTimestamp: Int64 {
        return Int64(Date().timeIntervalSince1970)
    }
    
    /**
     * Retrieves the current Unix timestamp in milliseconds.
     * @return  The current Unix timestamp in milliseconds.
     */
    static var currentUnixTimestampInMillis: Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    /**
     * Retrieves a random number between 0 and 1.
     * @return  A random number between 0 and 1.
     */
    static var randomNumber: Double {
        return Double.random(in: 0...1)
    }
    
    /**
     * Retrieves specific rules based on the type from a feature.
     * @param feature The feature model.
     * @param type The type of the rules to retrieve.
     * @return A list of rules that match the type.
     */
    static func getSpecificRulesBasedOnType(feature: Feature?, type: CampaignTypeEnum?) -> [Campaign] {
        guard let rules = feature?.rulesLinkedCampaign else { return [] }
        
        if let type = type {
            return rules.filter { $0.type == type.rawValue }
        } else {
            return rules
        }
    }
    
    /**
     * Retrieves all AB and Personalize rules from a feature.
     * @param feature The feature model.
     * @return A list of AB and Personalize rules.
     */
    static func getAllExperimentRules(feature: Feature?) -> [Campaign] {
        guard let rules = feature?.rulesLinkedCampaign else { return [] }
        return rules.filter { $0.type == CampaignTypeEnum.ab.rawValue || $0.type == CampaignTypeEnum.personalize.rawValue }
    }
    
    /**
     * Retrieves a feature by its key from the settings.
     * @param settings The settings model.
     * @param featureKey The key of the feature to find.
     * @return The feature if found, otherwise nil.
     */
    static func getFeatureFromKey(settings: Settings?, featureKey: String) -> Feature? {
        return settings?.features.first { $0.key == featureKey }
    }
    
    /**
     * Checks if an event belongs to any feature in the settings.
     *
     * @param eventName The name of the event to check.
     * @param settings The settings containing the features and their associated metrics.
     * @return `true` if the event belongs to any feature, `false` otherwise.
     */
    static func doesEventBelongToAnyFeature(eventName: String, settings: Settings) -> Bool {
        return settings.features.contains { feature in
            feature.metrics?.contains { metric in
                metric.identifier == eventName
            } ?? false
        }
    }
}
