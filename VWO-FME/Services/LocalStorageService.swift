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

class LocalStorageService {
    
    
    // MARK: - Properties
    private let userDefaults: UserDefaults
    
    private struct Keys {
        static let settings = "com.vwo.fme.settings"
        static let version = "com.vwo.fme.version"
    }
    
    // MARK: - Initialization
    
    init() {
        if let defaults = UserDefaults(suiteName: Constants.SDK_USERDEFAULT_SUITE) {
            self.userDefaults = defaults
        } else {
            fatalError("Unable to initialize UserDefaults with suite")
        }
    }
    
    // MARK: - Public Methods (Internal)
    
    func saveSettings(_ settings: Settings) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: Keys.settings)
        } catch {
            LoggerService.log(level: .error, key: "SETTINGS_SCHEMA_INVALID", details: [:])
        }
    }
    
    func loadSettings() -> Settings? {
        if let data = userDefaults.data(forKey: Keys.settings) {
            let decoder = JSONDecoder()
            do {
                let settings = try decoder.decode(Settings.self, from: data)
                return settings
            } catch {
                LoggerService.log(level: .error, key: "SETTINGS_SCHEMA_INVALID", details: [:])
            }
        }
        return nil
    }
    
    func clearSettings() {
        userDefaults.removeObject(forKey: Keys.settings)
    }
    
    func saveVersion(_ version: String) {
        userDefaults.set(version, forKey: Keys.version)
    }
    
    func loadVersion() -> String? {
        return userDefaults.string(forKey: Keys.version)
    }
    
    func emptyLocalStorageSuite() {
        userDefaults.removeSuite(named: Constants.SDK_USERDEFAULT_SUITE)
    }
}
