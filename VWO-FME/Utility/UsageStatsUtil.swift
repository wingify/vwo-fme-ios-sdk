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
import UIKit

struct UsageStatsKeys {
    static let logLevel = "ll"
    static let integrations = "ig"
    static let storage = "ss"
    static let cachedSettingsExpiryTime = "cse"
    static let pollInterval = "pi"
    static let eventBatching = "eb"
    static let eventBatchingSize = "ebs"
    static let eventBatchingTime = "ebt"
    static let offlineBatching = "ebo"
    static let logTransport = "cl"
    static let platform = "p"
    static let osVersion = "osv"
    static let appVersion = "av"
    static let packageManager = "pm"
    static let languageVersion = "lv"
    static let exampleApp = "_ea"
    static let gatewayService = "gs"
}

struct UsageStatsValues {
    
    enum HybridSdk {
        case reactNative
        case flutter
        
        var sdkName: String {
            switch self{
            case .reactNative:
                return "vwo-fme-react-native-sdk"
            case .flutter:
                return "vwo-fme-flutter-sdk"
            }
        }
        
        var sdkUsageStatsValue: String {
            switch self{
            case .reactNative:
                return "rn"
            case .flutter:
                return "fl"
            }
        }
    }
    
    static let platform = "ios"
    static let sdkNameNative = "ios"
    static let packageManagerCocoapods = "cp"
    static let packageManagerSPM = "spm"
}


class UsageStatsUtil {
        
    static private var usageStatsDict: [String: Any] = [:]
    static private var localStorageService = StorageService()

    static func setUsageStats(options: VWOInitOptions?) {
        
        guard let options = options else { return }
        if options.isUsageStatsDisabled { return }
        
        usageStatsDict[UsageStatsKeys.logLevel] = options.logLevel.level
        usageStatsDict[UsageStatsKeys.integrations] = (options.integrations != nil).toIntForDictValue()
        usageStatsDict[UsageStatsKeys.storage] = 1
        usageStatsDict[UsageStatsKeys.cachedSettingsExpiryTime] = (options.cachedSettingsExpiryTime != 0).toIntForDictValue()
        usageStatsDict[UsageStatsKeys.pollInterval] = (options.pollInterval != nil).toIntForDictValue()
        usageStatsDict[UsageStatsKeys.eventBatching] = (options.batchMinSize != nil || options.batchUploadTimeInterval != nil).toIntForDictValue()
        if let batchSize = options.batchMinSize {
            usageStatsDict[UsageStatsKeys.eventBatchingSize] = "\(batchSize)"
        }
        if let batchTimeInterval = options.batchUploadTimeInterval {
            usageStatsDict[UsageStatsKeys.eventBatchingTime] = "\(batchTimeInterval)"
        }
        
        if !options.gatewayService.isEmpty && options.gatewayService["url"] != nil {
            usageStatsDict[UsageStatsKeys.gatewayService] = 1
        }
        usageStatsDict[UsageStatsKeys.offlineBatching] = 1
        usageStatsDict[UsageStatsKeys.logTransport] = (options.logTransport != nil).toIntForDictValue()
        if options.sdkName.lowercased().contains(Constants.SDK_NAME.lowercased()) {
#if swift(>=6.0)
            usageStatsDict[UsageStatsKeys.languageVersion] = "sw>=6.0"
#elseif swift(>=5.10)
            usageStatsDict[UsageStatsKeys.languageVersion] = "sw>=5.10"
#elseif swift(>=5.9)
            usageStatsDict[UsageStatsKeys.languageVersion] = "sw>=5.9"
#elseif swift(>=5.8)
            usageStatsDict[UsageStatsKeys.languageVersion] = "sw>=5.8"
#elseif swift(>=5.7)
            usageStatsDict[UsageStatsKeys.languageVersion] = "sw>=5.7"
#elseif swift(>=5.6)
            usageStatsDict[UsageStatsKeys.languageVersion] = "sw>=5.6"
#else
            usageStatsDict[UsageStatsKeys.languageVersion] = "sw<5.6"
#endif
  
        }
        usageStatsDict[UsageStatsKeys.platform] = UsageStatsValues.platform
        usageStatsDict[UsageStatsKeys.osVersion] = UIDevice.current.systemVersion
        
        if let infoDictionary = Bundle.main.infoDictionary {
            if let version = infoDictionary["CFBundleShortVersionString"] as? String {
                usageStatsDict[UsageStatsKeys.appVersion] = version
            }
        }
        
#if SWIFT_PACKAGE
        usageStatsDict[UsageStatsKeys.packageManager] = UsageStatsValues.packageManagerSPM
#else
        usageStatsDict[UsageStatsKeys.packageManager] = UsageStatsValues.packageManagerCocoapods
#endif
                
        for (key, value) in options.vwoMeta {
            if key == UsageStatsKeys.exampleApp {
                usageStatsDict[UsageStatsKeys.exampleApp] = 1
            } else {
                usageStatsDict[key] = value
            }
        }
    }
    
    static func canSendStats() -> Bool {
        if let storedStatsDict = self.localStorageService.getUsageStats(), !storedStatsDict.isEmpty, !usageStatsDict.isEmpty {
            let isEqual = self.areDictionariesEqual(storedStatsDict, self.usageStatsDict)
            return !isEqual
        }
        return true
    }
    
    static func saveUsageStatsInStorage() {
        if !self.usageStatsDict.isEmpty {
            self.localStorageService.setUsageStats(data: self.usageStatsDict)
            self.emptyUsageStats()
        }
    }
    
    static func removeFalseValues(dict: [String: Any]) -> [String: Any] {
        return dict.filter { key, value in
            if let intValue = value as? Int {
                return intValue != 0
            }
            return true
        }
    }
    
    static func getUsageStatsDict() -> [String: Any] {
        return usageStatsDict
    }
    
    static func emptyUsageStats() {
        self.usageStatsDict.removeAll()
    }
    
    static func areDictionariesEqual(_ dict1: [String: Any], _ dict2: [String: Any]) -> Bool {
        guard dict1.count == dict2.count else {
            return false
        }
        
        for (key, value1) in dict1 {
            guard let value2 = dict2[key] else {
                return false
            }
            
            if !areValuesEqual(value1, value2) {
                return false
            }
        }
        return true
    }
    
    private static func areValuesEqual(_ value1: Any, _ value2: Any) -> Bool {
        switch (value1, value2) {
        case let (v1 as Int, v2 as Int):
            return v1 == v2
        case let (v1 as String, v2 as String):
            return v1 == v2
        case let (v1 as Double, v2 as Double):
            return v1 == v2
        case let (v1 as Bool, v2 as Bool):
            return v1 == v2
        case let (v1 as [String: Any], v2 as [String: Any]):
            return areDictionariesEqual(v1, v2)
        case let (v1 as [Any], v2 as [Any]):
            return areArraysEqual(v1, v2)
        default:
            return false
        }
    }

    private static func areArraysEqual(_ array1: [Any], _ array2: [Any]) -> Bool {
        guard array1.count == array2.count else {
            return false
        }
        
        for (index, value1) in array1.enumerated() {
            let value2 = array2[index]
            if !areValuesEqual(value1, value2) {
                return false
            }
        }
        
        return true
    }
}

fileprivate extension Bool {
    func toIntForDictValue() -> Int {
        return self ? 1 : 0
    }
}
