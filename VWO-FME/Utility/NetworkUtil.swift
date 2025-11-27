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

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64((self.timeIntervalSince1970) * 1000)
    }
    
    func currentTimeSeconds() -> Int64 {
        return Int64((self.timeIntervalSince1970))
    }
}


class NetworkUtil {
    
    // Generates a random string
    private static func generateRandom() -> String {
        return UUID().uuidString
    }
    
    // Generates the URL for the event
    private static func generateEventUrl() -> String {
        return Constants.HTTPS_PROTOCOL + UrlService.baseUrl + UrlEnum.events.rawValue
    }
    
    // Generates a message ID for the event
    private static func generateMsgId(uuid: String) -> String {
        return uuid + "-" + "\(Date().currentTimeMillis())"
    }
    
    // Generates a session ID for the event
    private static func generateSessionId() -> Int64 {
        return FmeConfig.generateSessionId()
    }
    
    // Creates the headers for the request
    private static func createHeaders(userAgent: String?, ipAddress: String?) -> [String: String] {
        var headers: [String: String] = [:]
        if let userAgent = userAgent, !userAgent.isEmpty {
            headers[HeadersEnum.userAgent.rawValue] = userAgent
        }
        if let ipAddress = ipAddress, !ipAddress.isEmpty {
            headers[HeadersEnum.ip.rawValue] = ipAddress
        }
        return headers
    }
    
    static func removeNullValues(originalMap: [String: Any?]) -> [String: Any] {
        var cleanedMap: [String: Any] = [:]
        
        for (key, value) in originalMap {
            if let nestedDict = value as? [String: Any?] {
                cleanedMap[key] = removeNullValues(originalMap: nestedDict)
            } else if let value = value {
                cleanedMap[key] = value
            }
        }
        
        return cleanedMap
    }
    
    // Creates the query parameters for the settings API
    static func getSettingsPath(apikey: String?, accountId: Int) -> [String: String] {
        let randomUuid = UUID().uuidString
        let accountIdString = "\(accountId)"
        let settingsQueryParams = SettingsQueryParams(i: apikey!, r: randomUuid, a: accountIdString)
        return settingsQueryParams.queryParams
    }
    
    // Creates the base properties for the event arch APIs
    static func getEventsBaseProperties(eventName: String, visitorUserAgent: String?, ipAddress: String?, isUsageStatsEvent: Bool? = false, usageStatsAccountId: Int? = 0) -> [String: String] {
        let settingManager = SettingsManager.instance
        let accountIdString = "\(SettingsManager.instance?.accountId ?? 0)"
        let sdkKey = "\(settingManager?.sdkKey ?? "")"
        if let visitorUserAgent = visitorUserAgent {
            let requestQueryParams = RequestQueryParams(en: eventName, a: accountIdString, env: sdkKey, visitorUa: visitorUserAgent, visitorIp: ipAddress ?? "", url: generateEventUrl())
            if (isUsageStatsEvent ?? false) {
                requestQueryParams.env = nil
                requestQueryParams.a = "\(String(describing: usageStatsAccountId))"
            }
            return requestQueryParams.queryParams
        }else{
            let requestQueryParams = RequestQueryParams(en: eventName, a: accountIdString, env: sdkKey, visitorUa: "", visitorIp: ipAddress ?? "", url: generateEventUrl())
            if (isUsageStatsEvent ?? false) {
                requestQueryParams.env = nil
                if let usageStatsAccountId = usageStatsAccountId {
                    requestQueryParams.a = "\(usageStatsAccountId)"
                }
                
            }
            return requestQueryParams.queryParams
        }
        
    }
    
    static func getBatchEventsBaseProperties() -> [String:String] {
        let settingManager = SettingsManager.instance
        let accountId = "\(settingManager?.accountId ?? 0)"
        let sdkKey = "\(settingManager?.sdkKey ?? "")"
        let requestQueryParam = EventBatchQueryParams(i: sdkKey, env: sdkKey, a: accountId)
        return requestQueryParam.queryParams
    }
    
    // Creates the base payload for the event arch APIs
    static func getEventBasePayload(userId: String?, eventName: String, visitorUserAgent: String?, ipAddress: String?, isUsageStatsEvent: Bool? = false, usageStatsAccountId: Int? = 0, shouldGenerateUUID : Bool? = true, sessionId : Int64? = nil) -> EventArchPayload {
        
        var stringAccountId : String
        
        if (isUsageStatsEvent ?? false) {
            stringAccountId = "\(String(describing: usageStatsAccountId))"
        } else {
            let settingManager = SettingsManager.instance
            stringAccountId = "\(settingManager?.accountId ?? 0)"
        }
        
        var uuid: String
        if shouldGenerateUUID ?? true {
            uuid = UUIDUtils.getUUID(userId: userId, accountId: stringAccountId)
        } else {
            if let userId = userId {
                uuid = "\(userId)"
            }else{
                uuid = UUIDUtils.getUUID(userId: userId, accountId: stringAccountId)
            }
            
        }

        var eventArchData = EventArchData()
        
        eventArchData.msgId = NetworkUtil.generateMsgId(uuid: uuid)
        eventArchData.visId = uuid
        eventArchData.sessionId = sessionId
        
        if let visitorUserAgent = visitorUserAgent {
            eventArchData.visitorUserAgent = visitorUserAgent
        }
        if let ipAddress = ipAddress {
            eventArchData.visitorIpAddress = ipAddress
        }
        
        let event = NetworkUtil.createEvent(eventName: eventName, isUsageStatsEvent: isUsageStatsEvent)
        eventArchData.event = event
        
        if !(isUsageStatsEvent ?? false){
            let visitor = NetworkUtil.createVisitor(isUsageStatsEvent: isUsageStatsEvent)
            eventArchData.visitor = visitor
        }
    
        var eventArchPayload = EventArchPayload()
        eventArchPayload.d = eventArchData
        return eventArchPayload
    }
    
    // Creates the event model for the event arch APIs
    private static func createEvent(eventName: String, isUsageStatsEvent: Bool? = false) -> Event {
        var event = Event()
        let props = createProps(isUsageStatsEvent: isUsageStatsEvent)
        event.props = props
        event.name = eventName
        event.time = Date().currentTimeMillis()
        return event
    }
    
    // Creates the props model for the event arch APIs
    private static func createProps(isUsageStatsEvent: Bool? = false) -> Props {
        var props = Props()
        props.vwoSdkName = SDKMetaUtil.name
        props.vwoSdkVersion = SDKMetaUtil.version
        if (!(isUsageStatsEvent ?? false)) {
            props.vwoEnvKey = SettingsManager.instance?.sdkKey ?? nil
        }
        return props
    }
    
    // Creates the visitor model for the event arch APIs
    private static func createVisitor(isUsageStatsEvent: Bool? = false) -> Visitor {
        var visitorProps: [String: Any] = [:]
        if (!(isUsageStatsEvent ?? false)) {
            visitorProps[Constants.VWO_FS_ENVIRONMENT] = SettingsManager.instance?.sdkKey ?? Constants.defaultString
        }
        let visitor = Visitor(props: visitorProps)
        return visitor
    }
    
    /**
     Adds custom variables to visitor props based on postSegmentationVariables.
     - Parameters:
        - properties: The payload data for the event.
        - context: The user context containing customVariables and postSegmentationVariables.
     */
    private static func addCustomVariablesToVisitorProps(
        properties: inout EventArchPayload,
        context: VWOUserContext?
    ) {
        // A temporary dictionary to hold all custom variables and device info to be added.
        var variablesToAdd = [String: Any]()

        // Check if the context has both post-segmentation keys and custom variables.
        if let postSegmentationVariables = context?.postSegmentationVariables ,let customVariables = context?.customVariables,
           !customVariables.isEmpty {
            
            // Iterate through the keys specified for post-segmentation.
            for key in postSegmentationVariables {
                // If a post-segmentation key exists in the custom variables dictionary,
                // add it to our temporary dictionary.
                if let value = customVariables[key] {
                    variablesToAdd[key] = value
                }
            }
        }

         let deviceInfo = DeviceUtil().getAllDeviceDetails()
            // Add all gathered device info to our temporary dictionary.
            for (key, value) in deviceInfo {
                variablesToAdd[key] = value
            }
        

        // Check if there are any variables to add to prevent unnecessary operations.
        if !variablesToAdd.isEmpty {
            var existingProps = properties.d?.visitor?.props ?? [String: Any]()

            // Merge the new variables (custom variables + device info) into the existing properties.
            for (key, value) in variablesToAdd {
                existingProps[key] = value
            }

            // Set the updated properties dictionary back into the event payload's visitor object.
            properties.d?.visitor?.props = existingProps
        }
    }

    
    // Returns the payload data for the track user API
    class func getTrackUserPayloadData(settings: Settings, userId: String?, eventName: String, campaignId: Int, variationId: Int, visitorUserAgent: String?, ipAddress: String?,sessionId: Int64?, context: VWOUserContext) -> [String: Any] {
        var properties = NetworkUtil.getEventBasePayload(userId: userId, eventName: eventName, visitorUserAgent: visitorUserAgent, ipAddress: ipAddress,sessionId: sessionId)
        
        properties.d?.event?.props?.id = campaignId
        properties.d?.event?.props?.variation = "\(variationId)"
        properties.d?.event?.props?.isFirst = 1
        
        if eventName == EventEnum.vwoVariationShown.rawValue {
            
            // for FME<>MI integration
            // isMII flag is set to true for vwoVariationShown event
            properties.d?.event?.props?.isMII = FmeConfig.checkIsMILinked()
            
            // Add custom variables to visitor props for VWO_VARIATION_SHOWN events
            NetworkUtil.addCustomVariablesToVisitorProps(properties: &properties, context: context)
        }

        LoggerService.log(level: .debug, 
                          key: "IMPRESSION_FOR_TRACK_USER",
                          details: ["accountId": "\(String(describing: settings.accountId))",
                                    "userId": userId ?? "",
                                    "campaignId": "\(String(describing: campaignId))"])
        
        let payloadDict = properties.toDictionary()
        let cleanedPayload = removeNullValues(originalMap: payloadDict)
        return cleanedPayload
    }
    
    // Returns the payload data for the goal API
    static func getTrackGoalPayloadData(settings: Settings, userId: String?, eventName: String, context: VWOUserContext, eventProperties: [String: Any]) -> [String: Any] {
        var properties = NetworkUtil.getEventBasePayload(userId: userId, eventName: eventName, visitorUserAgent: context.userAgent, ipAddress: context.ipAddress,sessionId: context.sessionId)
        properties.d?.event?.props?.setIsCustomEvent(true)
        properties.d?.event?.props?.setAdditionalProperties(eventProperties)
        
        LoggerService.log(level: .debug,
                          key: "IMPRESSION_FOR_TRACK_GOAL",
                          details: ["eventName": eventName,
                                    "accountId": String(describing: settings.accountId),
                                    "userId": userId ?? ""])
                
        let payloadDict: [String: Any] = properties.toDictionary()
        let cleanedPayload = removeNullValues(originalMap: payloadDict)
        return cleanedPayload
    }
    
    // Returns the payload data for the attribute API
    static func getAttributePayloadData(settings: Settings, userId: String?, eventName: String,sessionId: Int64?, attributes: [String: Any]) -> [String: Any] {
        var properties = NetworkUtil.getEventBasePayload(userId: userId, eventName: eventName, visitorUserAgent: nil, ipAddress: nil,sessionId: sessionId)
        properties.d?.event?.props?.setIsCustomEvent(true)
        let visitorProp: [String: Any] = attributes
        properties.d?.visitor?.props = visitorProp
                
        LoggerService.log(level: .debug,
                          key: "IMPRESSION_FOR_SYNC_VISITOR_PROP",
                          details: ["eventName": eventName,
                                    "accountId": String(describing: settings.accountId),
                                    "userId": userId ?? ""])

        
        let payloadDict: [String: Any] = properties.toDictionary()
        let cleanedPayload = removeNullValues(originalMap: payloadDict)
        return cleanedPayload
    }
    
    // Returns the payload data for the messaging event
    static func getMessagingEventPayload(messageType: String, message: String, eventName: String) -> [String: Any] {
        let settingManager = SettingsManager.instance
        let stringAccountId = "\(settingManager?.accountId ?? 0)"
        let sdkKey = "\(settingManager?.sdkKey ?? "")"
        
        let userId = stringAccountId + "_" + sdkKey
        var properties = NetworkUtil.getEventBasePayload(userId: userId, eventName: eventName, visitorUserAgent: nil, ipAddress: nil)
        properties.d?.event?.props?.setProduct(Constants.PRODUCT_NAME)
        
        var data = [String: Any]()
        data["type"] = messageType
        
        var messageContent = [String: Any]()
        messageContent["title"] = message
        messageContent["dateTime"] = Date().currentTimeMillis()
        data["content"] = messageContent
        properties.d?.event?.props?.setData(data)
        
        let payloadDict: [String: Any] = properties.toDictionary()
        let cleanedPayload = removeNullValues(originalMap: payloadDict)
        return cleanedPayload
    }
    

    static func getSDKInitEventPayload(eventName: String, settingsFetchTime: Int64? = nil, sdkInitTime: Int64? = nil) -> [String: Any] {
        let settingsManager = SettingsManager.instance
        guard let accountId = settingsManager?.accountId, let sdkKey = settingsManager?.sdkKey else {
            return [:] // Return an empty dictionary if either accountId or sdkKey is nil
        }
        
        let uniqueKey = "\(accountId)_\(sdkKey)"
        var properties = NetworkUtil.getEventBasePayload(userId: uniqueKey, eventName: eventName, visitorUserAgent: nil, ipAddress: nil)
        
        // Set the required fields as specified
        properties.d?.event?.props?.additionalProperties = [Constants.VWO_FS_ENVIRONMENT: sdkKey]
        properties.d?.event?.props?.product = Constants.PRODUCT_NAME
        
        
        var data: [String: Any] = ["isSDKInitialized": true]
        if let settingsFetchTime = settingsFetchTime {
            data["settingsFetchTime"] = settingsFetchTime
        }
        if let sdkInitTime = sdkInitTime {
            data["sdkInitTime"] = sdkInitTime
        }
        
        properties.d?.event?.props?.data = data
        
        // Convert properties to dictionary, removing null values
        let payloadDict = properties.toDictionary()
        let payload = NetworkUtil.removeNullValues(originalMap:payloadDict)
        return payload
    }

    
    // Sends a messaging event to DACDN
    static func sendMessagingEvent(properties: [String: String], payload: [String: Any]) {
        
        let request = RequestModel(url: Constants.HOST_NAME,
                                   method: HTTPMethod.post.rawValue,
                                   path: UrlEnum.events.rawValue,
                                   query: properties,
                                   body: payload,
                                   headers: nil,
                                   scheme: Constants.HTTPS_PROTOCOL,
                                   port: 0)
        
        NetworkManager.postAsync(request) { result in
            
            if let error = result.errorMessage {
                LoggerService.log(level: .debug, key: "NETWORK_CALL_FAILED", details: ["method": "POST", "err": "\(error)"])
            }
        }
    }
    
    
    // Sends a messaging event to DACDN
    static func sendGatewayEvent(queryParams: [String: String], payload: [String: Any],eventName: String) {
        let settingsManager = SettingsManager.instance
        var request = RequestModel(url: UrlService.baseUrl,
                                   method: HTTPMethod.post.rawValue,
                                   path: UrlEnum.events.rawValue,
                                   query: queryParams,
                                   body: payload,
                                   headers: nil,
                                   scheme: settingsManager?.protocolType ?? "https",
                                   port: settingsManager?.port ?? 0)
        
        request.eventName = eventName
        NetworkManager.postAsync(request) { result in
            
            if let error = result.errorMessage {
                LoggerService.log(level: .error, key: "NETWORK_CALL_FAILED", details: ["method": "POST", "err": "\(error)"])
            }
        }
    }
    
    // Sends a POST request to the VWO server
    static func sendPostApiRequest(properties: [String: String], payload: [String: Any], userAgent: String?, ipAddress: String?, campaignInfo: [String: Any]? = nil) {
        NetworkManager.attachClient()
        
        let headers = createHeaders(userAgent: userAgent, ipAddress: ipAddress)
    
        var request = RequestModel(url: UrlService.baseUrl, method: HTTPMethod.post.rawValue, path: UrlEnum.events.rawValue, query: properties, body: payload, headers: headers, scheme: Constants.HTTPS_PROTOCOL, port: SettingsManager.instance?.port ?? 0)
        
        request.campaignInfo = campaignInfo
        
        NetworkManager.postAsync(request) { result in
                        
            if result.errorMessage != nil {
                LoggerService.log(level: .debug, key: "NETWORK_CALL_FAILED", details: ["method": "POST", "err": "\(result.errorMessage ?? "")"])
            } else {
                UsageStatsUtil.shared.saveUsageStatsInStorage()
            }
        }
    }
    
    /// Constructs the payload for an SDK usage statistics event.
    ///
    /// This function generates a dictionary representing the data payload that will be sent
    /// to track SDK usage. It incorporates essential information such as the
    /// event type, account identifiers, and collected usage statistics.
    ///
    /// - Parameters:
    ///   - event: The type of SDK usage event being tracked (enum `EventEnum`).
    ///   - usageStatsAccountId: The account ID specifically designated for tracking usage statistics.
    ///                          This might be different from the main VWO account ID.
    /// - Returns: A dictionary containing the non-nil key-value pairs representing the payload
    ///            for the SDK usage statistics event. This dictionary is ready to be serialized
    ///            (e.g., to JSON) and sent to the server.
    static func getSDKUsageStatsEventPayload(event: EventEnum, usageStatsAccountId: Int) -> [String: Any] {
        let settingsManager = SettingsManager.instance
        guard let accountId = settingsManager?.accountId, let sdkKey = settingsManager?.sdkKey else {
            return [:] // Return an empty dictionary if either accountId or sdkKey is nil
        }
       
        let userId = "\(accountId)_\(sdkKey)"
        
        var properties = NetworkUtil.getEventBasePayload(userId: userId, eventName: event.rawValue, visitorUserAgent: nil, ipAddress: nil,isUsageStatsEvent: true,usageStatsAccountId: usageStatsAccountId)
        
        properties.d?.event?.props?.product = Constants.PRODUCT_NAME
        
       
        let stats = UsageStatsUtil.shared.getUsageStatsDict()
        let cleanedStats = UsageStatsUtil.shared.removeFalseValues(dict: stats)
        if !cleanedStats.isEmpty {
            properties.d?.event?.props?.vwoMeta = cleanedStats
        }
                    
        let payloadDict = properties.toDictionary()
        let payload = NetworkUtil.removeNullValues(originalMap:payloadDict)
        
        return payload
    }
    
    /// Returns the payload data for the debugger event.
    /// - Parameter eventProps: The properties for the debugger event.
    /// - Returns: A dictionary containing the payload data.
    static func getDebuggerEventPayload(eventProps: [String: Any] = [:]) -> [String: Any] {
        let settingsManager = SettingsManager.instance
        guard let accountId = settingsManager?.accountId, let sdkKey = settingsManager?.sdkKey else {
            return [:] // Return an empty dictionary if either accountId or sdkKey is nil
        }
        var userId: String
        var shouldGenerateUUID = true

        if let uuid = eventProps["uuid"] as? String {
            userId = uuid
            shouldGenerateUUID = false
        } else {
            userId = "\(accountId)_\(sdkKey)"
        }

        // Generate base payload
        var properties = NetworkUtil.getEventBasePayload(userId: userId, eventName: EventEnum.VWO_DEBUGGER_EVENT.rawValue, visitorUserAgent: nil, ipAddress: nil, shouldGenerateUUID : shouldGenerateUUID)

      

        if !shouldGenerateUUID, let uuid = eventProps["uuid"] {
            properties.d?.visId = String(describing: uuid)
        }
        
        // Optional session ID
        if let sessionId = eventProps["sId"] as? Int64 {
            properties.d?.sessionId = sessionId
        }

        properties.d?.event?.props = Props()
        var vwoMeta: [String: Any] = eventProps
        vwoMeta["a"] = SettingsManager.instance?.accountId ?? ""
        vwoMeta["product"] = Constants.PRODUCT_NAME
        vwoMeta["sn"] = SDKMetaUtil.name
        vwoMeta["sv"] = SDKMetaUtil.sdkVersion
        vwoMeta["eventId"] = UUIDUtils.getRandomUUID(sdkKey: sdkKey)

        properties.d?.event?.props?.vwoMeta = vwoMeta
        
        let payloadDict = properties.toDictionary()
        let payload = NetworkUtil.removeNullValues(originalMap:payloadDict)
        
        return payload
    }
    
   
   



}
