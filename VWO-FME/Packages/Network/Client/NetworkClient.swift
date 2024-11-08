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

protocol NetworkClientInterface {
    func GET(request: RequestModel, completion: @escaping (ResponseModel) -> Void)
    func POST(request: RequestModel, completion: @escaping (ResponseModel) -> Void)
}

class NetworkClient: NetworkClientInterface {
    
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
                    request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
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
        performRequestWithRetry(request: request, completion: completion)
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
        
        performRequestWithRetry(request: request, completion: completion)
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
    
    private func performRequestWithRetry(request: URLRequest, completion: @escaping (ResponseModel) -> Void, retryCount: Int = 3, delay: TimeInterval = 1.0) {
        
        var responseModel = ResponseModel()
        
        let (data, response, error) = URLSession.shared.synchronousDataTask(with: request)
        
        if let error = error as? URLError {
            // Check if the error is due to no network connection
            if error.code == .notConnectedToInternet {
                responseModel.errorMessage = APIError.noNetwork.localizedDescription
                responseModel.error = .noNetwork
                completion(responseModel)
                // Return early to avoid retrying the request
                return
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            if retryCount > 0 {
                let newDelay = delay * 2
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.performRequestWithRetry(request: request, completion: completion, retryCount: retryCount - 1, delay: newDelay)
                }
            } else {
                responseModel.errorMessage = APIError.responseUnsuccessful.localizedDescription
                responseModel.error = .responseUnsuccessful
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
            completion(responseModel)
        } else {
            if let data = data, let _ = String(data: data, encoding: .utf8) {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let message = json["message"] as? String {
                    responseModel.errorMessage = message
                } else {
                    responseModel.errorMessage = APIError.requestFailed.localizedDescription
                }
            }
            responseModel.error = .requestFailed
            if retryCount > 0 {
                let newDelay = delay * 2
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.performRequestWithRetry(request: request, completion: completion, retryCount: retryCount - 1, delay: newDelay)
                }
            } else {
                completion(responseModel)
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
