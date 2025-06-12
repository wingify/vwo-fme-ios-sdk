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
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif


/// Utility struct for SDK metadata operations.
///
/// This struct provides helper methods for managing and accessing SDK metadata, such as retrieving
/// SDK version.
class SDKMetaUtil {
    
    /// Returns the SDK version
    static var sdkVersion: String {
        let bundle = Bundle(for: SDKMetaUtil.self)
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    /// Returns the bundle identifier of the framework
    static var sdkBundleIdentifier: String {
        let bundle = Bundle(for: SDKMetaUtil.self)
        return bundle.bundleIdentifier ?? "Unknown"
    }
    
    static var name = ""
    static var version = ""
}

struct PlatformInfo {
#if os(iOS) || os(tvOS)
    static let name =  UIDevice.current.systemName
    static let systemVersion = UIDevice.current.systemVersion
#elseif os(watchOS)
    static let name = WKInterfaceDevice.current().systemName
    static let systemVersion = WKInterfaceDevice.current().systemVersion
#elseif os(macOS)
    static let name = "macOS"
    static let systemVersion = "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)." +
                               "\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)." +
                               "\(ProcessInfo.processInfo.operatingSystemVersion.patchVersion)"
#else
    static let name = "unknown"
    static let systemVersion = "unknown"
#endif
}
