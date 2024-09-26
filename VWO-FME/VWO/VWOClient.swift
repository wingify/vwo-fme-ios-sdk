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

// Define the VWOClient class
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
    func updateSettings(newSettings: String?) {
        do {
            if let newSettings = newSettings {
                let data = newSettings.data(using: .utf8)!
                self.processedSettings = try JSONDecoder().decode(Settings.self, from: data)
                if var processedSettings = self.processedSettings {
                    SettingsUtil.processSettings(&processedSettings)
                    self.processedSettings = processedSettings
                }
            }
        } catch {
            LoggerService.log(level: .error, message: "Exception occurred while updating settings \(error.localizedDescription)")
        }
    }
    
    // Get the flag value for the given feature key
    func getFlag(featureKey: String?, context: VWOContext) -> GetFlag {
        let apiName = "getFlag"
        var getFlag = GetFlag()
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
            
            guard let procSettings = self.processedSettings, SettingsSchema().isSettingsValid(procSettings) else {
                LoggerService.log(level: .error, key: "SETTINGS_SCHEMA_INVALID", details: nil)
                getFlag.setIsEnabled(isEnabled: false)
                return getFlag
            }
            
            return GetFlagAPI.getFlag(featureKey: featureKey, settings: procSettings, context: context, hookManager: hooksManager)
        } catch {
            LoggerService.log(level: .error, key: "API_THROW_ERROR", details: ["apiName": apiName, "err": error.localizedDescription])
            getFlag.setIsEnabled(isEnabled: false)
            return getFlag
        }
    }
    
    private func track(eventName: String, context: VWOContext?, eventProperties: [String: Any]) {
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
            
            guard let pSettings = self.processedSettings, SettingsSchema().isSettingsValid(pSettings) else {
                LoggerService.log(level: .error, key: "SETTINGS_SCHEMA_INVALID", details: nil)
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
    
    func trackEvent(eventName: String, context: VWOContext?, eventProperties: [String: Any]) {
        track(eventName: eventName, context: context, eventProperties: eventProperties)
    }
    
    func trackEvent(eventName: String, context: VWOContext?) {
        track(eventName: eventName, context: context, eventProperties: [:])
    }
    
    // Set an attribute for a user in the context provided
    func setAttribute(attributeKey: String, attributeValue: Any, context: VWOContext?) {
        let apiName = "setAttribute"
        do {
            LoggerService.log(level: .debug, key: "API_CALLED", details: ["apiName": apiName])
            guard DataTypeUtil.isString(attributeKey) else {
                LoggerService.log(level: .error,
                                  key: "API_INVALID_PARAM",
                                  details: ["apiName": apiName,
                                            "key": "attributeKey",
                                            "type": DataTypeUtil.getType(attributeKey),
                                            "correctType": "String"])
                throw NSError(domain: "TypeError: attributeKey should be a string", code: 0, userInfo: nil)
            }
            
            guard DataTypeUtil.isString(attributeValue) || DataTypeUtil.isNumber(attributeValue) || DataTypeUtil.isBoolean(attributeValue) else {
                LoggerService.log(level: .error,
                                  key: "API_INVALID_PARAM",
                                  details: ["apiName": apiName,
                                            "key": "attributeValue",
                                            "type": DataTypeUtil.getType(attributeValue),
                                            "correctType": "String, Number, Boolean"])
                throw NSError(domain: "TypeError: attributeValue should be a String, Number or Boolean", code: 0, userInfo: nil)
            }
            
            guard let userId = context?.id, !userId.isEmpty else {
                throw NSError(domain: "User ID is required", code: 0, userInfo: nil)
            }
            
            guard let processedSettings = self.processedSettings, SettingsSchema().isSettingsValid(processedSettings) else {
                LoggerService.log(level: .error, key: "SETTINGS_SCHEMA_INVALID", details: nil)
                return
            }
            
            SetAttributeAPI.setAttribute(settings: processedSettings, attributeKey: attributeKey, attributeValue: attributeValue, context: context!)
            
            
        } catch {
            LoggerService.log(level: .error, key: "API_THROW_ERROR", details: ["apiName": apiName, "err": error.localizedDescription])
        }
    }
}
