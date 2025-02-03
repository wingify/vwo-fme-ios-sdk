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

struct SegmentDslModel: Codable {
    
    var or: [SegmentDslModel]?
    var and: [SegmentDslModel]?
    var not: NotDSL?
    
    var custom_variable : [String:String]?
    var app_version : String?
    var day_of_week : String?
    var country : String?
    var ios_version : String?
    var android_version : String?
    var returning_visitor : String?
    var height : String?
    var width : String?
    var hour_of_the_day : String?
    var city : String?
    var region : String?
    var device_type : String?
    var device : String?
    var battery  : String?
    var networkSpeed  : String?
    var os  : String?
}

struct NotDSL: Codable{
    
    var or: [SegmentDslModel]?
    var and: [SegmentDslModel]?

}
