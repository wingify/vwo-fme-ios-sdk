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

struct RequestModel {
    var url: String?
    var method: String = HTTPMethod.get.rawValue
    var path: String?
    var query: [String: String]?
    var body: [String: Any]?
    var headers: [String: String]?
    var scheme: String = "http"
    var port: Int
    var timeout: Int = 0
    internal var eventName: String = ""
    internal var lastError: String = ""
    internal var campaignInfo: [String: Any]? 
    /**
     * A map containing various options for the request.
     */
    var options: [String: Any] = [:]

    mutating func setOptions() {
        
        var queryParams = ""
        if let query = query {
            for (key, value) in query {
                queryParams.append("\(key)=\(value)&")
            }
        }

        var options: [String: Any] = [:]
        options["hostname"] = url
        options["agent"] = false
        let urlValue = url ?? ""
        options["scheme"] = urlValue.hasPrefix("localhost") ? "http" : scheme // this is added for gateway integration testing
        if port != 80 {
            options["port"] = port
        }
        options["headers"] = headers
        options["method"] = method

        if let body = body {
            let sanitizedBody = sanitizeForJSONSerialization(body)
            let postBody = try? JSONSerialization.data(withJSONObject: sanitizedBody, options: [.prettyPrinted])
            headers?["Content-Type"] = "application/json"
            headers?["Content-Length"] = String(postBody?.count ?? 0)
            options["headers"] = headers
            options["body"] = sanitizedBody
        }

        if var combinedPath = path {
            if !queryParams.isEmpty {
                combinedPath += "?" + queryParams.dropLast()
            }
            options["path"] = combinedPath
        }

        if timeout > 0 {
            options["timeout"] = timeout
        }
        self.options = options
    }
    
    /// Retrieves the extra information of the HTTP request.
    /// - Returns: A dictionary representing the extra information.
    func getExtraInfo() -> [String: Any] {
        var result: [String: Any] = [:]

        // Add non-nil entries from options
        for (key, value) in options {
            if !(value is NSNull) {
                result[key] = value
            }
        }

        // Add individual properties if available
        if let url = url {
            result["url"] = url
        }

        
        result["method"] = method
        

        if let query = query {
            result["query"] = query
        }

        if let path = path {
            result["path"] = path
        }

        if let body = body {
            result["body"] = body
        }

        if let headers = headers {
            result["headers"] = headers
        }

        
        result["scheme"] = scheme
        

        result["port"] = port

        return result
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
