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

/**
 * Represents query parameters for API requests.
 *
 * This class constructs and provides access to a dictionary of query parameters used in API requests.
 * It includes parameters for environment, account ID, visitor information, and other metadata.
 */
class RequestQueryParams {
    private let en: String
    var a: String
    var env: String?
    private let visitorUa: String
    private let visitorIp: String
    private let url: String
    
    private let eTime: Int64
    private let random: Double
    private let p: String = "FS"
    
    private let sv: String
    private let sn: String
    
    /**
     * A dictionary containing the query parameters.
     * This dictionary is lazily initialized.
     */
    lazy var queryParams: [String: String] = {
        var path: [String: String] = [:]
        path["en"] = en
        path["a"] = a
        path["env"] = env
        path["eTime"] = String(eTime)
        path["random"] = String(random)
        path["p"] = p
        path["visitor_ua"] = visitorUa
        path["visitor_ip"] = visitorIp
        path["url"] = url
        path["sv"] = SDKMetaUtil.version
        path["sn"] = SDKMetaUtil.name
        
        return path
    }()
    
    /**
     * Initializes a new instance of RequestQueryParams.
     *
     * - Parameters:
     *   - en: The event name.
     *   - a: The account ID.
     *   - env: The environment name.
     *   - visitorUa: The visitor's user agent.
     *   - visitorIp: The visitor's IP address.
     *   - url: The requested URL.
     */
    init(en: String, a: String, env: String, visitorUa: String, visitorIp: String, url: String) {
        self.en = en
        self.a = a
        self.env = env
        self.visitorUa = visitorUa
        self.visitorIp = visitorIp
        self.url = url
        
        self.eTime = Date().currentTimeMillis()
        self.random = Double.random(in: 0...1)
        
        self.sv = SDKMetaUtil.version
        self.sn = SDKMetaUtil.name
    }
}
