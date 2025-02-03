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

/**
 * Enumeration representing different API endpoints.
 *
 * This enum defines constants for API endpoints used in the application,
 * associating each endpoint with its corresponding string value.
 */
enum ApiEnum: String {
    /**
     * API endpoint for retrieving feature flags.
     */
    case getFlag = "getFlag"
    
    /**
     * API endpoint for tracking user events.
     */
    case track = "track"
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

enum APIError: Error, Equatable {
    
    case requestFailed
    case jsonConversionFailure
    case invalidData
    case responseUnsuccessful
    case jsonParsingFailure
    case badUrl
    case noNetwork
    case unsupportedBodyType(type: Any.Type)
    var localizedDescription: String {
        switch self {
        case .requestFailed: return "Request Failed"
        case .invalidData: return "Invalid Data"
        case .responseUnsuccessful: return "Response Unsuccessful"
        case .jsonParsingFailure: return "JSON Parsing Failure"
        case .jsonConversionFailure: return "JSON Conversion Failure"
        case .badUrl: return "Bad Url"
        case .unsupportedBodyType(let type): return "Unsupported body type: \(type)"
        case .noNetwork: return "No network connection"
        }
    }
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.requestFailed, .requestFailed),
            (.jsonConversionFailure, .jsonConversionFailure),
            (.invalidData, .invalidData),
            (.responseUnsuccessful, .responseUnsuccessful),
            (.jsonParsingFailure, .jsonParsingFailure),
            (.badUrl, .badUrl),
            (.noNetwork, .noNetwork):
            return true
        case (.unsupportedBodyType(let leftType), .unsupportedBodyType(let rightType)):
            return leftType == rightType
        default:
            return false
        }
    }
}
