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
    static func getEventsBaseProperties(eventName: String, visitorUserAgent: String?, ipAddress: String?) -> [String: String] {
        let settingManager = SettingsManager.instance
        let accountIdString = "\(SettingsManager.instance?.accountId ?? 0)"
        let sdkKey = "\(settingManager?.sdkKey ?? "")"
        let requestQueryParams = RequestQueryParams(en: eventName, a: accountIdString, env: sdkKey, visitorUa: visitorUserAgent!, visitorIp: ipAddress ?? "", url: generateEventUrl())
        return requestQueryParams.queryParams
    }
    
    static func getBatchEventsBaseProperties() -> [String:String] {
        let settingManager = SettingsManager.instance
        let accountId = "\(settingManager?.accountId ?? 0)"
        let sdkKey = "\(settingManager?.sdkKey ?? "")"
        let requestQueryParam = EventBatchQueryParams(i: sdkKey, env: sdkKey, a: accountId)
        return requestQueryParam.queryParams
    }
    
    // Creates the base payload for the event arch APIs
    static func getEventBasePayload(userId: String?, eventName: String, visitorUserAgent: String?, ipAddress: String?) -> EventArchPayload {
        
        let settingManager = SettingsManager.instance
        let stringAccountId = "\(settingManager?.accountId ?? 0)"
        let uuid = UUIDUtils.getUUID(userId: userId, accountId: stringAccountId)

        var eventArchData = EventArchData()
        
        eventArchData.msgId = NetworkUtil.generateMsgId(uuid: uuid)
        eventArchData.visId = uuid
        eventArchData.sessionId = NetworkUtil.generateSessionId()
        
        if let visitorUserAgent = visitorUserAgent {
            eventArchData.visitorUserAgent = visitorUserAgent
        }
        if let ipAddress = ipAddress {
            eventArchData.visitorIpAddress = ipAddress
        }
        
        let event = NetworkUtil.createEvent(eventName: eventName)
        eventArchData.event = event
        
        let visitor = NetworkUtil.createVisitor()
        eventArchData.visitor = visitor
        
        var eventArchPayload = EventArchPayload()
        eventArchPayload.d = eventArchData
        return eventArchPayload
    }
    
    // Creates the event model for the event arch APIs
    private static func createEvent(eventName: String) -> Event {
        var event = Event()
        let props = createProps()
        event.props = props
        event.name = eventName
        event.time = Date().currentTimeMillis()
        return event
    }
    
    // Creates the props model for the event arch APIs
    private static func createProps() -> Props {
        var props = Props()
        props.vwoSdkName = SDKMetaUtil.name
        props.vwoSdkVersion = SDKMetaUtil.version
        props.vwoEnvKey = SettingsManager.instance?.sdkKey ?? nil
        return props
    }
    
    // Creates the visitor model for the event arch APIs
    private static func createVisitor() -> Visitor {
        var visitorProps: [String: Any] = [:]
        visitorProps[Constants.VWO_FS_ENVIRONMENT] = SettingsManager.instance?.sdkKey ?? Constants.defaultString
        let visitor = Visitor(props: visitorProps)
        return visitor
    }
    
    // Returns the payload data for the track user API
    class func getTrackUserPayloadData(settings: Settings, userId: String?, eventName: String, campaignId: Int, variationId: Int, visitorUserAgent: String?, ipAddress: String?) -> [String: Any] {
        var properties = NetworkUtil.getEventBasePayload(userId: userId, eventName: eventName, visitorUserAgent: visitorUserAgent, ipAddress: ipAddress)
        
        properties.d?.event?.props?.id = campaignId
        properties.d?.event?.props?.variation = "\(variationId)"
        properties.d?.event?.props?.isFirst = 1
        
        if eventName == EventEnum.vwoVariationShown.rawValue {
            // for FME<>MI integration
            // isMII flag is set to true for vwoVariationShown event
            properties.d?.event?.props?.isMII = FmeConfig.checkIsMILinked()
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
    static func getTrackGoalPayloadData(settings: Settings, userId: String?, eventName: String, context: VWOContext, eventProperties: [String: Any]) -> [String: Any] {
        var properties = NetworkUtil.getEventBasePayload(userId: userId, eventName: eventName, visitorUserAgent: context.userAgent, ipAddress: context.ipAddress)
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
    static func getAttributePayloadData(settings: Settings, userId: String?, eventName: String, attributes: [String: Any]) -> [String: Any] {
        var properties = NetworkUtil.getEventBasePayload(userId: userId, eventName: eventName, visitorUserAgent: nil, ipAddress: nil)
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
        properties.d?.event?.props?.setProduct("fme")
        
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
                LoggerService.log(level: .error, key: "NETWORK_CALL_FAILED", details: ["method": "POST", "err": "\(error)"])
            }
        }
    }
    
    // Sends a POST request to the VWO server
    static func sendPostApiRequest(properties: [String: String], payload: [String: Any], userAgent: String?, ipAddress: String?) {
        NetworkManager.attachClient()
        
        let headers = createHeaders(userAgent: userAgent, ipAddress: ipAddress)
        let request = RequestModel(url: UrlService.baseUrl, method: HTTPMethod.post.rawValue, path: UrlEnum.events.rawValue, query: properties, body: payload, headers: headers, scheme: Constants.HTTPS_PROTOCOL, port: SettingsManager.instance?.port ?? 0)
        
        NetworkManager.postAsync(request) { result in
            
            if result.errorMessage != nil {
                LoggerService.log(level: .error, key: "NETWORK_CALL_FAILED", details: ["method": "POST", "err": "\(result.errorMessage ?? "")"])
            }
        }
    }
}
