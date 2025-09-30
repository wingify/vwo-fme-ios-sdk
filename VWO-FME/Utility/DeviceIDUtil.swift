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

import Security
import Foundation

struct DeviceIDUtil{
    
    private static let service = "com.vwo.fme.deviceId"
    private static let account = "com.vwo.fme"
    
    /**
     * Gets the device ID from the current context stored in StorageService.
     *
     * @return A device ID string, or null if context is not available
     */
    func getDeviceID() -> String? {
        return StorageService().getDeviceId()
    }
    
    
    static func genrateDeviceId() -> String {
        if let savedId = readFromKeychain() {
            return savedId
        }
        
        let newId = UUID().uuidString
        let success = saveToKeychain(id: newId)
        
        if !success {
            LoggerService.log(level:.info, message: "DeviceIDUtil: Keychain save failed, using temporary UUID")
        }
        
        return newId
    }
    
    /// Save ID safely to Keychain
    @discardableResult
    private static func saveToKeychain(id: String) -> Bool {
        guard let data = id.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary) // overwrite
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            LoggerService.log(level:.info, message: "Failed to save device ID (status: \(status))")
            return false
        }
        
        return true
    }
    
    /// Read ID safely from Keychain
    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let id = String(data: data, encoding: .utf8) {
            return id
        } else if status != errSecItemNotFound {
            LoggerService.log(level:.info, message: "DeviceIDUtil: Keychain read error (status: \(status)), generating temporary UUID")
        }
        
        return nil
    }
    
}
