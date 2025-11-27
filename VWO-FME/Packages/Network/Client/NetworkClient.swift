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

protocol NetworkClientInterface {
    func GET(request: RequestModel, completion: @escaping (ResponseModel) -> Void)
    func POST(request: RequestModel, completion: @escaping (ResponseModel) -> Void)
}

class NetworkClient: NetworkClientInterface {
    
    let END_Point = "endPoint"
    let ERR = "err"
    let DELAY = "delay"
    let ATTEMPT = "attempt"
    let MAX_RETRIES = "maxRetries"
    
    func POST(request: RequestModel, completion: @escaping (ResponseModel) -> Void) {
        var responseModel = ResponseModel()
        var newRequest = request
        newRequest.setOptions()
        let networkOptions = newRequest.options
        guard let url = URL(string: constructUrl(networkOptions: networkOptions)) else {
            responseModel.errorMessage = APIError.badUrl.localizedDescription
            responseModel.error = .badUrl
            completion(responseModel)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let headers = networkOptions["headers"] as? [String: String] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let body = networkOptions["body"] {
            if let bodyDict = body as? [String: Any] {
                do {
                    let sanitizedBody = sanitizeForJSONSerialization(bodyDict)
                    request.httpBody = try JSONSerialization.data(withJSONObject: sanitizedBody, options: [])
                } catch {
                    responseModel.errorMessage = APIError.invalidData.localizedDescription
                    responseModel.error = .invalidData
                    completion(responseModel)
                    return
                }
            } else if let bodyString = body as? String {
                request.httpBody = bodyString.data(using: .utf8)
            } else {
                responseModel.errorMessage = APIError.unsupportedBodyType(type: type(of: body)).localizedDescription
                responseModel.error = .unsupportedBodyType(type: type(of: body))
                completion(responseModel)
                return
            }
        }
        performRequestWithRetry(request: request,originalRequestModel: newRequest , completion: completion)
    }
    
    
    func GET(request: RequestModel, completion: @escaping (ResponseModel) -> Void) {
        
        var responseModel = ResponseModel()
        var newRequest = request
        newRequest.setOptions()
        let networkOptions = newRequest.options
        
        guard let url = URL(string: constructUrl(networkOptions: networkOptions)) else {
            responseModel.errorMessage = APIError.invalidData.localizedDescription
            responseModel.error = .badUrl
            completion(responseModel)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        
        performRequestWithRetry(request: request,originalRequestModel: newRequest ,completion: completion)
    }
    
    private func constructUrl(networkOptions: [String: Any?]) -> String {
        var hostname = networkOptions["hostname"] as? String ?? ""
        let path = networkOptions["path"] as? String ?? ""
        if let port = networkOptions["port"] as? Int, port != 0 {
            hostname += ":\(port)"
        }
        let scheme = (networkOptions["scheme"] as? String ?? "").lowercased()
        return "\(scheme)://\(hostname)\(path)"
    }
    
    
    private func performRequestWithRetry( request: URLRequest,originalRequestModel: RequestModel, completion: @escaping (ResponseModel) -> Void, retryCount: Int = 4,delay: TimeInterval = 1.0,
                                          attempt: Int = 1) {
        var responseModel = ResponseModel()
        let (data, response, error) = URLSession.shared.synchronousDataTask(with: request)

        var updatedRequestModel = originalRequestModel
        
        if let error = error as? URLError, error.code == .notConnectedToInternet {
            responseModel.errorMessage = APIError.noNetwork.localizedDescription
            responseModel.error = .noNetwork
            completion(responseModel)
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            if retryCount > 0 {
                if attempt > 1 {
                    let data: [String: Any] = [
                        END_Point: updatedRequestModel.path ?? "",
                        ERR: error?.localizedDescription ?? "",
                        DELAY: delay,
                        ATTEMPT: attempt - 1,
                        MAX_RETRIES: 4
                    ]
                    LoggerService.errorLog(
                        key: "ATTEMPTING_RETRY_FOR_FAILED_NETWORK_CALL",
                        data: data,
                        debugData: updatedRequestModel.getExtraInfo(),
                        shouldSendToVWO: false
                    )
                }

                updatedRequestModel.lastError = FunctionUtil.getFormattedErrorMessage(error)

                let newDelay = delay * 2
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.performRequestWithRetry(request: request,originalRequestModel: updatedRequestModel,completion: completion,retryCount: retryCount - 1,delay: newDelay,attempt: attempt + 1)
                }
            } else {
                responseModel.errorMessage = APIError.responseUnsuccessful.localizedDescription
                responseModel.error = .responseUnsuccessful
                responseModel.totalAttempts = attempt - 1  // Number of retries (excluding initial attempt)

                // Final retry failed - send debug event and log
                if attempt > 1 && !updatedRequestModel.eventName.contains(EventEnum.VWO_DEBUGGER_EVENT.rawValue){
                    let debugEventProps = createNetworkAndRetryDebugEvent(request: updatedRequestModel, response: responseModel)
                    DebuggerServiceUtil.sendDebugEventToVWO(eventProps: removeNullValues(debugEventProps))
                }

                if error != nil &&  !updatedRequestModel.eventName.contains(EventEnum.VWO_DEBUGGER_EVENT.rawValue) {
                    LoggerService.errorLog(
                        key: "NETWORK_CALL_FAILED_AFTER_MAX_RETRIES",
                        data: [
                            "endPoint": updatedRequestModel.path ?? "",
                            "err": error?.localizedDescription ?? ""
                        ],
                        debugData: updatedRequestModel.getExtraInfo(),
                        shouldSendToVWO: false
                    )
                }

                completion(responseModel)
            }
            return
        }

        responseModel.statusCode = httpResponse.statusCode

        if httpResponse.isResponseOK() {
            if let data = data, let responseData = String(data: data, encoding: .utf8) {
                responseModel.data = responseData
                responseModel.data2 = data
            } else {
                responseModel.errorMessage = APIError.jsonConversionFailure.localizedDescription
                responseModel.error = .jsonConversionFailure
            }

            responseModel.totalAttempts = attempt - 1  // Number of retries (excluding initial attempt)
            
            // Send debug event to dashboard only when request succeeds after retries
            if attempt > 1 && !updatedRequestModel.eventName.contains(EventEnum.VWO_DEBUGGER_EVENT.rawValue) {
                let debugEventProps = createNetworkAndRetryDebugEvent(request: updatedRequestModel, response: responseModel)
                DebuggerServiceUtil.sendDebugEventToVWO(eventProps: removeNullValues(debugEventProps))
            }
            
            completion(responseModel)
        } else {
            if let data = data, let _ = String(data: data, encoding: .utf8) {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let message = json["message"] as? String {
                    responseModel.errorMessage = message
                } else {
                    responseModel.errorMessage = APIError.requestFailed.localizedDescription
                }
            }

            responseModel.error = .requestFailed

            if retryCount > 0 {
                if attempt > 1 {
                    let data: [String: Any] = [
                        END_Point: updatedRequestModel.path ?? "",
                        ERR: responseModel.error?.localizedDescription ?? "",
                        DELAY: delay,
                        ATTEMPT: attempt - 1,
                        MAX_RETRIES: 4
                    ]
                    LoggerService.errorLog(
                        key: "ATTEMPTING_RETRY_FOR_FAILED_NETWORK_CALL",
                        data: data,
                        debugData: updatedRequestModel.getExtraInfo(),
                        shouldSendToVWO: false
                    )
                }

                updatedRequestModel.lastError = FunctionUtil.getFormattedErrorMessage(responseModel.error)

                let newDelay = delay * 2
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.performRequestWithRetry(
                        request: request,
                        originalRequestModel: updatedRequestModel,
                        completion: completion,
                        retryCount: retryCount - 1,
                        delay: newDelay,
                        attempt: attempt + 1
                    )
                }
            } else {
                responseModel.totalAttempts = attempt - 1  // Number of retries (excluding initial attempt)

                if attempt > 1 {
                    let debugEventProps = createNetworkAndRetryDebugEvent(request: updatedRequestModel, response: responseModel)
                    DebuggerServiceUtil.sendDebugEventToVWO(eventProps: removeNullValues(debugEventProps))
                }

                if !updatedRequestModel.eventName.contains(EventEnum.VWO_DEBUGGER_EVENT.rawValue) {
                    LoggerService.errorLog(
                        key: "NETWORK_CALL_FAILED_AFTER_MAX_RETRIES",
                        data: [
                            "endPoint": updatedRequestModel.path ?? "",
                            "err": responseModel.error?.localizedDescription ?? ""
                        ],
                        debugData: updatedRequestModel.getExtraInfo(),
                        shouldSendToVWO: false
                    )
                }

                completion(responseModel)
            }
        }
    }

    func removeNullValues(_ dictionary: [String: Any?]) -> [String: Any] {
        return dictionary.compactMapValues { $0 }
    }
    
    private func createNetworkAndRetryDebugEvent(
        request: RequestModel,
        response: ResponseModel
    ) -> [String: Any?] {
        
        let category: DebuggerCategoryEnum = (response.error == nil) ? .RETRY : .NETWORK
        let msgT = (response.error == nil) ? Constants.NETWORK_CALL_SUCCESS_WITH_RETRIES : Constants.NETWORK_CALL_FAILURE_AFTER_MAX_RETRIES
        let logLevel = (response.error == nil) ? LogLevelEnum.info.rawValue : LogLevelEnum.error.rawValue
        
        do {
            let bodyDict = request.body
            let dataDict = bodyDict?["d"] as? [String: Any] ?? [:]
            let eventDict = dataDict["event"] as? [String: Any] ?? [:]
            let propsDict = eventDict["props"] as? [String: Any] ?? [:]
            
            var msgPlaceholder: [String: String?] = [
                END_Point: request.path,
                "apiName": request.path,
                "extraData": request.path,
                "attempts": "\(response.totalAttempts)",
                ERR: FunctionUtil.getFormattedErrorMessage(response.error ?? request.lastError)
            ]
            
            var apiEnum: ApiEnum = .Init 
            var extraDataForMessage = ""
            
            if let eventName = eventDict["name"] as? String {
                if eventName == EventEnum.vwoVariationShown.rawValue {
                    apiEnum = .getFlag
                    
                    if let campaignInfo = request.campaignInfo {
                        let type = campaignInfo["campaignType"] as? String
                        let featureName = campaignInfo["featureName"] as? String ?? ""
                        let variationName = campaignInfo["variationName"] as? String ?? ""
                        let campaignKey = campaignInfo["campaignKey"] as? String ?? ""

                        let isRolloutOrPersonalize = (type == CampaignTypeEnum.rollout.rawValue) || (type == CampaignTypeEnum.personalize.rawValue)
                        
                        extraDataForMessage = isRolloutOrPersonalize
                            ? "feature: \(featureName), rule: \(variationName)"
                            : "feature: \(featureName), rule: \(campaignKey) and variation: \(variationName)"
                    }
                    msgPlaceholder["apiName"] = apiEnum.rawValue
                } else if eventName == EventEnum.vwoSyncVisitorProp.rawValue {
                    apiEnum = .setAttribute
                    extraDataForMessage = apiEnum.rawValue
                } else if eventName != EventEnum.VWO_DEBUGGER_EVENT.rawValue &&
                            eventName != EventEnum.VWO_INIT_CALLED.rawValue {
                    apiEnum = .track
                    msgPlaceholder["apiName"] = apiEnum.rawValue
                    extraDataForMessage = "event: \(eventName)"
                }
            } else if ((request.path?.contains(UrlEnum.setUserAlias.rawValue)) != nil) {
                apiEnum = .setUserAlias
                msgPlaceholder["apiName"] = apiEnum.rawValue
            }
            
            
            msgPlaceholder["extraData"] = msgPlaceholder["extraData"] ?? "" + extraDataForMessage
            
            // Message resolution
            let template = LoggerService.getLogFile(level: response.error == nil ? .info : .error)
            var msg = ""
            
            if response.error == nil {
                msg = (apiEnum == .getFlag)
                    ? LogMessageUtil.buildMessage(template: template[Constants.NETWORK_CALL_SUCCESS_WITH_RETRIES_FOR_GET_FLAG], data: msgPlaceholder) ?? "Unknown message"
                    : LogMessageUtil.buildMessage(template: template[Constants.NETWORK_CALL_SUCCESS_WITH_RETRIES], data: msgPlaceholder) ?? "Unknown message"
            } else {
                msg = (apiEnum == .getFlag)
                    ? LogMessageUtil.buildMessage(template: template[Constants.NETWORK_CALL_FAILURE_AFTER_MAX_RETRIES_FOR_GET_FLAG], data: msgPlaceholder) ?? "Unknown message"
                    : LogMessageUtil.buildMessage(template: template[Constants.NETWORK_CALL_FAILURE_AFTER_MAX_RETRIES], data: msgPlaceholder) ?? "Unknown message"
            }
            
            // Build final debug event props
            var debugEventProps: [String: Any?] = [
                "cg": category.rawValue,
                "tRa": response.totalAttempts,
                "sc": response.statusCode,
                ERR: FunctionUtil.getFormattedErrorMessage(response.error),
                "uuid": dataDict["visId"] as? String,
                "eId": propsDict["id"],
                "msg_t": msgT,
                "lt": logLevel,
                "msg": msg
            ]
            
            if let variation = propsDict["variation"] {
                debugEventProps["vId"] = variation
            }
            
            
            if let eventName = eventDict["name"] as? String {
                if let apiName = getApiNameFromEventName(eventName), !apiName.isEmpty {
                    debugEventProps["an"] = apiName
                }
            }
            
            
            
            let sessionId = dataDict["sessionId"] as? Int64 ?? Int64(Date().timeIntervalSince1970)
            debugEventProps["sId"] = sessionId
            
            return debugEventProps
        } catch {
            return [
                "cg": category.rawValue,
                ERR: "\(error)"
            ]
        }
    }

    private func getApiNameFromEventName(_ eventName: String) -> String? {
        if eventName == EventEnum.vwoVariationShown.rawValue {
            return ApiEnum.getFlag.rawValue
        } else if eventName == EventEnum.vwoSyncVisitorProp.rawValue {
            return ApiEnum.setAttribute.rawValue
        } else if eventName != EventEnum.VWO_DEBUGGER_EVENT.rawValue &&
                  eventName != EventEnum.VWO_INIT_CALLED.rawValue {
            return ApiEnum.track.rawValue
        }

        return nil
    }
    
    // MARK: - JSON Sanitization
    
    /// Sanitizes a dictionary to ensure it can be safely serialized to JSON
    /// Removes or converts non-JSON-serializable objects like NSError
    private func sanitizeForJSONSerialization(_ object: Any) -> Any {
        switch object {
        case let dict as [String: Any]:
            var sanitizedDict: [String: Any] = [:]
            for (key, value) in dict {
                sanitizedDict[key] = sanitizeForJSONSerialization(value)
            }
            return sanitizedDict
        case let array as [Any]:
            return array.map { sanitizeForJSONSerialization($0) }
        case is NSError:
            // Convert NSError to a dictionary with error information
            if let error = object as? NSError {
                return [
                    "domain": error.domain,
                    "code": error.code,
                    "localizedDescription": error.localizedDescription
                ]
            }
            return "Error object"
        case is Error:
            // Convert Swift Error to string
            return "Error: \(object)"
        case let data as Data:
            // Convert Data to base64 string
            return data.base64EncodedString()
        case let date as Date:
            // Convert Date to ISO8601 string
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: date)
        case let url as URL:
            // Convert URL to string
            return url.absoluteString
        default:
            // For other types, check if they're JSON serializable
            if JSONSerialization.isValidJSONObject([object]) {
                return object
            } else {
                // Convert to string representation
                return String(describing: object)
            }
        }
    }


}

extension URLSession {
    func synchronousDataTask(with request: URLRequest) -> (Data?, URLResponse?, Error?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let dataTask = self.dataTask(with: request) { (responseData, urlResponse, responseError) in
            data = responseData
            response = urlResponse
            error = responseError
            semaphore.signal()
        }
        
        dataTask.resume()
        semaphore.wait()
        
        return (data, response, error)
    }
}

extension HTTPURLResponse {
    func isResponseOK() -> Bool {
        return (200...299).contains(self.statusCode)
    }
}
