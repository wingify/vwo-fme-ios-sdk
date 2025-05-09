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

class VWOClient {
    var processedSettings: Settings?
    var options: VWOInitOptions?
    
    // Initialize the VWOClient with settings and options
    
    init(options: VWOInitOptions?, settingObj: Settings?) {
        self.options = options
        if var settingToProcess = settingObj {
            SettingsUtil.processSettings(&settingToProcess)
            self.processedSettings = settingToProcess
            // init url version with collection prefix
            UrlService.initialize(collectionPrefix: settingToProcess .collectionPrefix)
            LoggerService.log(level: .info, key: "CLIENT_INITIALIZED", details: nil)
        } else {
            LoggerService.log(level: .error, message: "Exception occurred while parsing settings")
        }
    }
    
    // Update the settings
    func updateSettings(newSettings: Settings?) {
        if var newSettings = newSettings {
            SettingsUtil.processSettings(&newSettings)
            self.processedSettings = newSettings
        }
    }
    
    // Get the flag value for the given feature key
    func getFlag(featureKey: String?, context: VWOUserContext, completion: @escaping (GetFlag) -> Void) {
        let apiName = "getFlag"
        let getFlag = GetFlag()
        do {
            LoggerService.log(level: .debug, key: "API_CALLED", details: ["apiName": apiName])
            let hooksManager = HooksManager(callback: options?.integrations)
            guard let userId = context.id, !userId.isEmpty else {
                getFlag.setIsEnabled(isEnabled: false)
                throw NSError(domain: "User ID is required", code: 0, userInfo: nil)
            }
            
            guard let featureKey = featureKey, !featureKey.isEmpty else {
                getFlag.setIsEnabled(isEnabled: false)
                throw NSError(domain: "Feature Key is required", code: 0, userInfo: nil)
            }
            
            guard let procSettings = self.processedSettings else {
                getFlag.setIsEnabled(isEnabled: false)
                completion(getFlag)
                return
            }
            
            return GetFlagAPI.getFlag(featureKey: featureKey, settings: procSettings, context: context, hookManager: hooksManager, completion: completion)
        } catch {
            LoggerService.log(level: .error, key: "API_THROW_ERROR", details: ["apiName": apiName, "err": error.localizedDescription])
            getFlag.setIsEnabled(isEnabled: false)
            completion(getFlag)
        }
    }
    
    private func track(eventName: String, context: VWOUserContext?, eventProperties: [String: Any]) {
        let apiName = "trackEvent"
        var resultMap = [String: Bool]()
        do {
            LoggerService.log(level: .debug, key: "API_CALLED", details: ["apiName": apiName])
            let hooksManager = HooksManager(callback: options?.integrations)
            guard DataTypeUtil.isString(eventName) else {
                LoggerService.log(level: .error,
                                  key: "API_INVALID_PARAM",
                                  details: ["apiName": apiName,
                                            "key": "eventName",
                                            "type": DataTypeUtil.getType(eventName),
                                            "correctType": "String"])
                
                throw NSError(domain: "VWOClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "TypeError: Event-name should be a string"])
            }
            
            guard let userId = context?.id, !userId.isEmpty else {
                throw NSError(domain: "VWOClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "User ID is required"])
            }
            
            guard let pSettings = self.processedSettings else {
                resultMap[eventName] = false
                return
            }
            TrackEventAPI.track(settings: pSettings, eventName: eventName, context: context!, eventProperties: eventProperties, hooksManager: hooksManager)
        } catch {
            LoggerService.log(level: .error,
                              key: "API_THROW_ERROR",
                              details: ["apiName": apiName, "err": error.localizedDescription])
            resultMap[eventName] = false
        }
    }
    
    func trackEvent(eventName: String, context: VWOUserContext?, eventProperties: [String: Any]) {
        track(eventName: eventName, context: context, eventProperties: eventProperties)
    }
    
    func trackEvent(eventName: String, context: VWOUserContext?) {
        track(eventName: eventName, context: context, eventProperties: [:])
    }
    
    // Set attributes for a user in the context provided
    func setAttribute(attributes: [String: Any], context: VWOUserContext?) {
        let apiName = "setAttribute"
        do {
            LoggerService.log(level: .debug, key: "API_CALLED", details: ["apiName": apiName])
            
            if attributes.isEmpty {
                LoggerService.log(level: .warn,
                                  key: "ATTRIBUTES_NOT_FOUND",
                                  details: ["apiName": apiName,
                                            "key": "attributes",
                                            "expectedFormat": "a dictionary with expected keys and value types"])
                return
            }
            
            for (attributeKey, attributeValue) in attributes {
                guard DataTypeUtil.isString(attributeValue) || DataTypeUtil.isNumber(attributeValue) || DataTypeUtil.isBoolean(attributeValue) else {
                    LoggerService.log(level: .error,
                                      key: "API_INVALID_PARAM",
                                      details: ["apiName": apiName,
                                                "key": "attributeValue for attributeKey: \(attributeKey)",
                                                "type": DataTypeUtil.getType(attributeValue),
                                                "correctType": "String, Number, Boolean"])
                    throw NSError(domain: "TypeError: attributeValue should be a String, Number or Boolean", code: 0, userInfo: nil)
                }
            }
            
            guard let userId = context?.id, !userId.isEmpty else {
                throw NSError(domain: "User ID is required", code: 0, userInfo: nil)
            }
            
            guard let processedSettings = self.processedSettings else {
                return
            }
            
            SetAttributeAPI.setAttributes(settings: processedSettings, attributes: attributes, context: context!)
        } catch {
            LoggerService.log(level: .error, key: "API_THROW_ERROR", details: ["apiName": apiName, "err": error.localizedDescription])
        }
    }
    
    private func removeUnsupportedAttributeValues(attributes: [String: Any], apiName: String) -> [String: Any] {
        var validAttributes: [String: Any] = [:]
        for (attributeKey, attributeValue) in attributes {
            if DataTypeUtil.isString(attributeValue) || DataTypeUtil.isNumber(attributeValue) || DataTypeUtil.isBoolean(attributeValue) {
                validAttributes[attributeKey] = attributeValue
            } else {
                LoggerService.log(level: .error,
                                  key: "API_INVALID_PARAM",
                                  details: ["apiName": apiName,
                                            "key": "attributeValue for attributeKey: \(attributeKey)",
                                            "type": DataTypeUtil.getType(attributeValue),
                                            "correctType": "String, Number, Boolean"])
            }
        }
        return validAttributes
    }
}
