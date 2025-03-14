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
 Represents an event with associated properties, name, and timestamp.

 This class is used to encapsulate information about events that occur within the application.
 */
 
struct Event {
    /**
     * Custom properties associated with the event.
     */
    var props: Props?
    /**
     * The name of the event.
     */
    var name: String?
    /**
     * The timestamp of when the event occurred (in milliseconds).
     */
    
    var time: Int64?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let props = props {
            dict["props"] = props.toDictionary()
        }
        if let name = name {
            dict["name"] = name
        }
        if let time = time {
            dict["time"] = time
        }
        return dict
    }
    
}
