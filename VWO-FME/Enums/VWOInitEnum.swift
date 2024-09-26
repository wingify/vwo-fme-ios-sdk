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

enum VWOInitSuccess: String {
    case initializationSuccess = "VWO is ready to use."
}

enum VWOInitError: Error {
    
    case missingSDKKey
    case missingAccountId
    case initializationFailed
    case custom(String)
        
    var localizedDescription: String {
        switch self {
        case .missingSDKKey:
            return "SDK key is required to initialize VWO. Please provide the sdkKey in the options."
        case .missingAccountId:
            return "Account ID is required to initialize VWO. Please provide the accountId in the options."
        case .initializationFailed:
            return "Failed to initialize VWO."
        case .custom(let message):
            return message
        }
    }
}
