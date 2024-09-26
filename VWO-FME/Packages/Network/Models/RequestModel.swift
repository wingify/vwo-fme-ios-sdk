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
        options["scheme"] = scheme
        if port != 80 {
            options["port"] = port
        }
        options["headers"] = headers
        options["method"] = method

        if let body = body {
            let postBody = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted])
            headers?["Content-Type"] = "application/json"
            headers?["Content-Length"] = String(postBody?.count ?? 0)
            options["headers"] = headers
            options["body"] = body
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
}
