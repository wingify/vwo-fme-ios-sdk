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

public class VWOInitOptions {
    var sdkKey: String?
    var accountId: Int?
    var integrations: IntegrationCallback?
    var logger: [String: Any] = [:]
    var logLevel: LogLevelEnum = .error
    var networkClientInterface: NetworkClientInterface?
    var segmentEvaluator: SegmentEvaluator?
    var storage: ConnectorProtocol?
    var pollInterval: Int?
    var vwoBuilder: VWOBuilder?
    var gatewayService: [String: Any] = [:]
    
    public init(sdkKey: String? = nil, 
                accountId: Int? = nil,
                logLevel: LogLevelEnum = .error,
                integrations: IntegrationCallback? = nil,
                gatewayService: [String: Any] = [:]) {

        self.sdkKey = sdkKey
        self.accountId = accountId
        self.logLevel = logLevel
        self.logger = ["level": "\(logLevel.rawValue)"]
        self.integrations = integrations
        self.gatewayService = gatewayService
    }
}
