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
@testable import VWO_FME

enum SettingsTestJson: String {
    case OnlyRolloutSettings
    case RolloutAndTestingSettings
    case RolloutAndTestingSettingsWithPreSegment
    case MegAdvanceAlgoCampaignSettings
    case MegRandomAlgoCampaignSettings
    case NoRolloutAndOnlyTestingSettings
    case SettingsWithDifferentSalt
    case SettingsWithSameSalt
    case SettingsWithWhitelisting
    case UtilitySettings

    var jsonFileName: String {
        return self.rawValue
    }
}

struct GetFlagTestJson {
    
    static let jsonFileName = "GetFlagTest"
    
    static func getJsonFileForSetting(input: String) -> SettingsTestJson {
        switch input {
        case "NO_ROLLOUT_ONLY_TESTING_RULE_SETTINGS":
            return SettingsTestJson.NoRolloutAndOnlyTestingSettings
        case "BASIC_ROLLOUT_SETTINGS":
            return SettingsTestJson.OnlyRolloutSettings
        case "BASIC_ROLLOUT_TESTING_RULE_SETTINGS":
            return SettingsTestJson.RolloutAndTestingSettings
        case "ROLLOUT_TESTING_PRE_SEGMENT_RULE_SETTINGS":
            return SettingsTestJson.RolloutAndTestingSettingsWithPreSegment
        case "TESTING_WHITELISTING_SEGMENT_RULE_SETTINGS":
            return SettingsTestJson.SettingsWithWhitelisting
        default:
            return SettingsTestJson.OnlyRolloutSettings
        }
    }
}

class FlagTestDataLoader {
    static func loadTestData(jsonFileName: String) -> Settings? {
        guard let url = Bundle(for: GetFlagTests.self).url(forResource: jsonFileName, withExtension: "json") else {
            print("Failed to find file: \(jsonFileName).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)            
            let settingsObj = try JSONDecoder().decode(Settings.self, from: data)
            return settingsObj
        } catch {
            print("Error loading or decoding JSON: \(error)")
            return nil
        }
    }
}

// Define struct for expectation
struct Expectation: Codable {
    let isEnabled: Bool
    let intVariable: Int
    let stringVariable: String
    let floatVariable: Float
    let booleanVariable: Bool
    let jsonVariable: JsonVariable
    let storageData: StorageDataTestCase?
}

// Define struct for jsonVariable
struct StorageDataTestCase: Codable {
    let rolloutKey: String?
    let rolloutVariationId: Int?
    let experimentKey: String?
    let experimentVariationId: Int?
}

// Define struct for jsonVariable
struct JsonVariable: Codable {
    let campaign: String?
    let name: String?
    let variation: Int?
}

// Define struct for context
struct Context: Codable {
    let id: String?
    var customVariables: [String: Any]? = [:]
    
    enum CodingKeys: String, CodingKey {
        case id
        case customVariables
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        do {
            if let customVariablesEncoded = try container.decodeIfPresent([String: CodableValue].self, forKey: .customVariables) {
                let dataMapped = customVariablesEncoded.mapValues { $0.toJSONCompatible() }
                                
                self.customVariables = dataMapped
            } else {
                self.customVariables = [:]
            }
        } catch {
            self.customVariables = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        if let customVariables = customVariables {
            let data = try JSONSerialization.data(withJSONObject: customVariables, options: [])
            try container.encode(data, forKey: .customVariables)
        }
    }
}

struct FlagTestCase: Codable {
    
    let settings: String
    let description: String
    let context: Context
    let featureKey: String
    let expectation: Expectation
}

struct AllTestCase: Codable {
        
    let megRandom: [FlagTestCase]?
    let megAdvance: [FlagTestCase]?
    let withoutStorage: [FlagTestCase]?
    let withStorage: [FlagTestCase]?

    enum CodingKeys: String, CodingKey {
        case megRandom = "GETFLAG_MEG_RANDOM"
        case megAdvance = "GETFLAG_MEG_ADVANCE"
        case withoutStorage = "GETFLAG_WITHOUT_STORAGE"
        case withStorage = "GETFLAG_WITH_STORAGE"
    }
}

class FlagTestCaseLoader {
    static func loadTestData(jsonFileName: String) -> AllTestCase? {
        guard let url = Bundle(for: GetFlagTests.self).url(forResource: jsonFileName, withExtension: "json") else {
            print("Failed to find file: \(jsonFileName).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let obj = try JSONDecoder().decode(AllTestCase.self, from: data)
            return obj
        } catch {
            print("Error loading or decoding JSON: \(error)")
            return nil
        }
    }
}

func compareStorageData(_ data1: StorageDataTestCase, _ data2: StorageDataTestCase) -> Bool {
    return data1.rolloutKey == data2.rolloutKey &&
           data1.rolloutVariationId == data2.rolloutVariationId &&
           data1.experimentKey == data2.experimentKey &&
           data1.experimentVariationId == data2.experimentVariationId
}
