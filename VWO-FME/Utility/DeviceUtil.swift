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

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DeviceUtil {

    private let unknownValue = "valueUnknown"
    private let Manufacturer = "Apple"
    private let WatchModel = "Apple Watch"
    private let DefaultLocale = "en"

    /// Gets the version name of the host application. e.g., "1.0.3"
    func getApplicationVersion() -> String {
        return SDKMetaUtil.sdkVersion
    }

    /// Gets the OS version. e.g., "14.4"
    func getOsVersion() -> String {
        let fullVersion = ProcessInfo.processInfo.operatingSystemVersionString
            // Example: "Version 18.2 (Build 22C150)"
            
            // Use regular expression to find the version number
            let pattern = #"Version (\d+\.\d+)"#
            
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: fullVersion, range: NSRange(fullVersion.startIndex..., in: fullVersion)),
               let range = Range(match.range(at: 1), in: fullVersion) {
                return String(fullVersion[range])
            }
            
        return unknownValue
    }

    /// Gets the device manufacturer. Always "Apple"
    func getManufacturer() -> String {
        return Manufacturer
    }

    /// Gets the device model. e.g., "iPhone", "MacBookPro"
    func getDeviceModel() -> String {
        #if os(iOS) || os(tvOS)
        return UIDevice.current.model
        #elseif os(watchOS)
        return WatchModel
        #elseif os(macOS)
        var model = unknownValue
        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        model = String(cString: machine)
        return model
        #else
        return unknownValue
        #endif
    }

    /// Gets the current locale. e.g., "en-US"
    func getLocale() -> String {
        let identifier = Locale.current.identifier
        let baseIdentifier = identifier.components(separatedBy: "@").first ?? identifier
        let candidate = baseIdentifier.replacingOccurrences(of: "_", with: "-")
        
        // Apple uses "_" in availableIdentifiers, so convert back for checking
        let candidateWithUnderscore = candidate.replacingOccurrences(of: "-", with: "_")
        
        if Locale.availableIdentifiers.contains(candidateWithUnderscore) {
            return candidate
        }
        
        // If not valid, fallback to just the language code (e.g. "en")
        #if os(iOS)
        if #available(iOS 16, *) {
            if let languageCode = Locale.current.language.languageCode?.identifier {
                return languageCode
            }
        }
        #elseif os(tvOS)
        if #available(tvOS 16, *) {
            if let languageCode = Locale.current.language.languageCode?.identifier {
                return languageCode
            }
        }
        #elseif os(macOS)
        if #available(macOS 13, *) {
            if let languageCode = Locale.current.language.languageCode?.identifier {
                return languageCode
            }
        }
        #elseif os(watchOS)
        if #available(watchOS 9, *) {
            if let languageCode = Locale.current.language.languageCode?.identifier {
                return languageCode
            }
        }
        #endif
        
        // Last fallback
        return DefaultLocale
    }


    /// Gathers all specified device details into a dictionary.
    func getAllDeviceDetails() -> [String: String] {
        return [
            Constants.APP_VERSION: getApplicationVersion(),
            Constants.OS_VERSION: getOsVersion(),
            Constants.MANUFACTURER: getManufacturer(),
            Constants.DEVICE_MODEL: getDeviceModel(),
            Constants.LOCALE: getLocale()
        ]
    }
}


