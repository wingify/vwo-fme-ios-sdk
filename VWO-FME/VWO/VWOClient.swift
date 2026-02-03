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
    var vwoBuilder: VWOBuilder?
    
    var isSettingsValid = false
    var settingsFetchTime: Int64 = 0
    
    // Initialize the VWOClient with settings and options
    
    init(options: VWOInitOptions?, settingObj: Settings?) {
        self.options = options
        if var settingToProcess = settingObj {
            // Create ServiceContainer with unprocessed settings to get LoggerService for instance-specific logging
            // ServiceContainer can accept unprocessed settings - we'll update it with processed settings later
            let tempServiceContainer = createServiceContainer()
            
            // Process settings with ServiceContainer for instance-specific logging
            SettingsUtil.processSettings(&settingToProcess, serviceContainer: tempServiceContainer)
            self.processedSettings = settingToProcess
            // init url version with collection prefix
            UrlService.initialize(collectionPrefix: settingToProcess .collectionPrefix)
            
            // Log initialization
            tempServiceContainer?.getLoggerService()?.log(level: .info, key: "CLIENT_INITIALIZED", details: nil)
        } else {
            LoggerService.log(level: .error, message: "Exception occurred while parsing settings")
        }
    }
    
    init(options: VWOInitOptions?, settingObj: Settings?, vwoBuilder: VWOBuilder?) {
        self.options = options
        self.vwoBuilder = vwoBuilder
        
        if var settingToProcess = settingObj {
            // Create ServiceContainer with unprocessed settings to get LoggerService for instance-specific logging
            // ServiceContainer can accept unprocessed settings - we'll update it with processed settings later
            let tempServiceContainer = createServiceContainer()
            
            // Process settings with ServiceContainer for instance-specific logging
            SettingsUtil.processSettings(&settingToProcess, serviceContainer: tempServiceContainer)
            self.processedSettings = settingToProcess
            // init url version with collection prefix
            UrlService.initialize(collectionPrefix: settingToProcess .collectionPrefix)
            
            // Log initialization
            tempServiceContainer?.getLoggerService()?.log(level: .info, key: "CLIENT_INITIALIZED", details: nil)
        } else {
            LoggerService.log(level: .error, message: "Exception occurred while parsing settings")
        }
    }
    
    /**
     * Creates a ServiceContainer instance with the current settings and options
     * Following Android SDK pattern where ServiceContainer is created per API call
     * @return ServiceContainer instance
     */
    func createServiceContainer() -> ServiceContainer? {
        guard let options = self.options,
              let vwoBuilder = self.vwoBuilder else {
            return nil
        }
        
        return vwoBuilder.createServiceContainer(processedSettings: self.processedSettings, options: options)
    }
    
    // Update the settings
    func updateSettings(newSettings: Settings?) {
        if var newSettings = newSettings {
            // Get ServiceContainer if available for instance-specific logging
            let serviceContainer = createServiceContainer()
            SettingsUtil.processSettings(&newSettings, serviceContainer: serviceContainer)
            self.processedSettings = newSettings
        }
    }
    
    // Get the flag value for the given feature key
    func getFlag(featureKey: String?, context: VWOUserContext, completion: @escaping (GetFlag) -> Void) {
        let apiName = "getFlag"
        let getFlag = GetFlag()
        
        // Create ServiceContainer for this API call
        guard let serviceContainer = createServiceContainer() else {
            getFlag.setIsEnabled(isEnabled: false)
            completion(getFlag)
            return
        }
        
        do {
            serviceContainer.getLoggerService()?.log(level: .debug, key: "API_CALLED", details: ["apiName": apiName])
            
            // Use effective user ID (either provided userId or generated deviceId)
            let userId = UserIdUtil().getUserId(context: context, serviceContainer: serviceContainer)
            guard let userIdValue = userId.id, !userIdValue.isEmpty else {
                getFlag.setIsEnabled(isEnabled: false)
                throw NSError(domain: Constants.userIdErrorMessage, code: 0, userInfo: nil)
            }
            
            // Create a mutable copy to update with effective user ID if generated
            var effectiveContext = userId
            
            guard let featureKey = featureKey, !featureKey.isEmpty else {
                getFlag.setIsEnabled(isEnabled: false)
                throw NSError(domain: "Feature Key is required", code: 0, userInfo: nil)
            }
            
            guard let procSettings = self.processedSettings else {
                getFlag.setIsEnabled(isEnabled: false)
                completion(getFlag)
                return
            }
            
            let hooksManager = serviceContainer.getHooksManager()
            return GetFlagAPI.getFlag(featureKey: featureKey, settings: procSettings, context: effectiveContext, hookManager: hooksManager, serviceContainer: serviceContainer, completion: completion)
        } catch {

            serviceContainer.getLoggerService()?.errorLog(key: "API_THROW_ERROR",data: ["apiName":ApiEnum.getFlag.rawValue,"err": error.localizedDescription],debugData: ["an": ApiEnum.getFlag.rawValue])

            getFlag.setIsEnabled(isEnabled: false)
            completion(getFlag)
        }
    }
    
    private func track(eventName: String, context: VWOUserContext?, eventProperties: [String: Any]) {
        let apiName = "trackEvent"
        var resultMap = [String: Bool]()
        
        // Create ServiceContainer for this API call
        guard let serviceContainer = createServiceContainer() else {
            resultMap[eventName] = false
            return
        }
        
        do {
            serviceContainer.getLoggerService()?.log(level: .debug, key: "API_CALLED", details: ["apiName": apiName])
            
            guard DataTypeUtil.isString(eventName) else {
                serviceContainer.getLoggerService()?.errorLog(key: "INVALID_PARAM",data: ["apiName": apiName,
                                                                       "key": "eventName",
                                                                       "type": DataTypeUtil.getType(eventName),
                                                                       "correctType": "String"],debugData: ["an": ApiEnum.track.rawValue])
                
                throw NSError(domain: "VWOClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "TypeError: Event-name should be a string"])
            }
            
            guard let context = context else {
                throw NSError(domain: Constants.VWOContextErrorMessage, code: 0, userInfo: nil)
            }
            
            // Use effective user ID (either provided userId or generated deviceId)
            let userId = UserIdUtil().getUserId(context: context, serviceContainer: serviceContainer)
            guard let userIdValue = userId.id, !userIdValue.isEmpty else {
                throw NSError(domain: "VWOClient", code: 400, userInfo: [NSLocalizedDescriptionKey: Constants.userIdErrorMessage])
            }
            
            // Create a mutable copy to update with effective user ID if generated
            var effectiveContext = userId
            
            guard let pSettings = self.processedSettings else {
                resultMap[eventName] = false
                return
            }
            
            let hooksManager = serviceContainer.getHooksManager()
            TrackEventAPI.track(settings: pSettings, eventName: eventName, context: effectiveContext, eventProperties: eventProperties, hooksManager: hooksManager, serviceContainer: serviceContainer)
        } catch {
            serviceContainer.getLoggerService()?.errorLog(key: "API_THROW_ERROR",data: ["apiName":ApiEnum.track.rawValue,"err": error.localizedDescription],debugData: ["an": ApiEnum.track.rawValue])
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
        
        // Create ServiceContainer for this API call
        guard let serviceContainer = createServiceContainer() else {
            return
        }
        
        do {
            serviceContainer.getLoggerService()?.log(level: .debug, key: "API_CALLED", details: ["apiName": apiName])
            
            if attributes.isEmpty {
                serviceContainer.getLoggerService()?.errorLog(key: "ATTRIBUTES_NOT_FOUND",data: ["apiName": apiName,
                                                                          "key": "attributes",
                                                                          "expectedFormat": "a dictionary with expected keys and value types"],debugData: ["an": ApiEnum.setAttribute.rawValue])

                return
            }
            
            for (attributeKey, attributeValue) in attributes {
                
                let isValidType = DataTypeUtil.isString(attributeValue) || DataTypeUtil.isNumber(attributeValue) || DataTypeUtil.isBoolean(attributeValue)
                let isBlankKey = DataTypeUtil.isblank(attributeKey)
                
                guard !isBlankKey else{
                    serviceContainer.getLoggerService()?.errorLog(key: "INVALID_PARAM",data: ["key": "AttributeValue for attributeKey: \(attributeKey)",
                                                                           "apiName": apiName,
                                                                           "type": "Empty Key",
                                                                           "correctType": "String, Number, Boolean"],debugData: ["an": ApiEnum.setAttribute.rawValue])

                    throw NSError(domain: "TypeError: AttributeValue should be a String, Number or Boolean", code: 0, userInfo: nil)
                }
                
                guard isValidType  else {
                    serviceContainer.getLoggerService()?.errorLog(key: "INVALID_PARAM",data: ["key": "AttributeValue for attributeKey: \(attributeKey)",
                                                                           "apiName": apiName,
                                                                           "type": DataTypeUtil.getType(attributeValue),
                                                                           "correctType": "String, Number, Boolean"],debugData: ["an": ApiEnum.setAttribute.rawValue])

                    throw NSError(domain: "TypeError: AttributeValue should be a String, Number or Boolean", code: 0, userInfo: nil)
                }
            }
            
            guard let context = context else {
                throw NSError(domain: Constants.VWOContextErrorMessage, code: 0, userInfo: nil)
            }
            
            // Use effective user ID (either provided userId or generated deviceId)
            let userId = UserIdUtil().getUserId(context: context, serviceContainer: serviceContainer)
            guard let userIdValue = userId.id, !userIdValue.isEmpty else {
                throw NSError(domain: Constants.userIdErrorMessage, code: 0, userInfo: nil)
            }
            
            // Create a mutable copy to update with effective user ID if generated
            var effectiveContext = userId
            
            guard let processedSettings = self.processedSettings else {
                return
            }
            
            SetAttributeAPI.setAttributes(settings: processedSettings, attributes: attributes, context: effectiveContext, serviceContainer: serviceContainer)
        } catch {

            serviceContainer.getLoggerService()?.errorLog(key: "API_THROW_ERROR",data: ["apiName":ApiEnum.setAttribute.rawValue,"err": error.localizedDescription],debugData: ["an": ApiEnum.setAttribute.rawValue])

        }
    }
    
    private func removeUnsupportedAttributeValues(attributes: [String: Any], apiName: String, serviceContainer: ServiceContainer) throws -> [String: Any] {
        var validAttributes: [String: Any] = [:]
        for (attributeKey, attributeValue) in attributes {
            if DataTypeUtil.isString(attributeValue) || DataTypeUtil.isNumber(attributeValue) || DataTypeUtil.isBoolean(attributeValue) {
                validAttributes[attributeKey] = attributeValue
            } else {
                serviceContainer.getLoggerService()?.errorLog(key: "INVALID_PARAM",data: ["key": "attributeValue for attributeKey: \(attributeKey)",
                                                                                          "type": DataTypeUtil.getType(attributeValue),
                                                                                          "correctType": "String, Number, Boolean"],debugData: ["an": ApiEnum.setAttribute.rawValue])
                
            }
        }
        return validAttributes
    }
}
