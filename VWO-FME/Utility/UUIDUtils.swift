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
import CommonCrypto

/// Utility class for UUID (Universally Unique Identifier) operations.
///
/// This class provides helper methods for generating and working with UUIDs.
class UUIDUtils {
    
    // Define the DNS and URL namespaces for UUID v5
    private static let DNS_NAMESPACE = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
    private static let URL_NAMESPACE = UUID(uuidString: "6ba7b811-9dad-11d1-80b4-00c04fd430c8")!
    // Define the SEED_URL constant
    private static let SEED_URL = "https://vwo.com"
    
    /**
     * Generates a random UUID based on an API key.
     * @param sdkKey The API key used to generate a namespace for the UUID.
     * @return A random UUID string.
     */
    static func getRandomUUID(sdkKey: String) -> String {
        // Generate a namespace based on the API key using DNS namespace
        let namespace = generateUUID(name: sdkKey, namespace: DNS_NAMESPACE)
        // Generate a random UUID (UUIDv4)
        let randomUUID = UUID()
        // Generate a UUIDv5 using the random UUID and the namespace
        let uuidv5 = generateUUID(name: randomUUID.uuidString, namespace: namespace)
        
        return uuidv5.uuidString
    }
    
    /**
     * Generates a UUID for a user based on their userId and accountId.
     * @param userId The user's ID.
     * @param accountId The account ID associated with the user.
     * @return A UUID string formatted without dashes and in uppercase.
     */
    static func getUUID(userId: String?, accountId: String?) -> String {
        // Generate a namespace UUID based on SEED_URL using URL namespace
        let VWO_NAMESPACE = generateUUID(name: SEED_URL, namespace: URL_NAMESPACE)
        // Ensure userId and accountId are strings
        let userIdStr = userId ?? ""
        let accountIdStr: String = accountId ?? ""
        // Generate a namespace UUID based on the accountId
        let userIdNamespace = generateUUID(name: accountIdStr, namespace: VWO_NAMESPACE)
        // Generate a UUID based on the userId and the previously generated namespace
        let uuidForUserIdAccountId = generateUUID(name: userIdStr, namespace: userIdNamespace)
        
        // Remove all dashes from the UUID and convert it to uppercase
        let desiredUuid = uuidForUserIdAccountId.uuidString.replacingOccurrences(of: "-", with: "").uppercased()
        return desiredUuid
    }
    
    /**
     * Helper function to generate a UUID v5 based on a name and a namespace.
     * @param name The name from which to generate the UUID.
     * @param namespace The namespace used to generate the UUID.
     * @return A UUID.
     */
    private static func generateUUID(name: String, namespace: UUID) -> UUID {
        let namespaceBytes = toBytes(uuid: namespace)
        let nameBytes = Array(name.utf8)
        let combined = namespaceBytes + nameBytes
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        combined.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(combined.count), &hash)
        }
        
        // Set version to 5 (name-based using SHA-1)
        hash[6] = (hash[6] & 0x0f) | 0x50 // Clear version and set to version 5
        hash[8] = (hash[8] & 0x3f) | 0x80 // Clear variant and set to IETF variant

        let truncatedHash = Array(hash.prefix(16))
        return fromBytes(bytes: truncatedHash)
    }
    
    /**
     * Helper function to convert a UUID to a byte array.
     * @param uuid The UUID to convert.
     * @return A byte array.
     */
    private static func toBytes(uuid: UUID) -> [UInt8] {
        var uuid = uuid
        let uuidBytes = withUnsafePointer(to: &uuid) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<UUID>.size) {
                Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<UUID>.size))
            }
        }
        return uuidBytes
    }
    
    /**
     * Helper function to convert a byte array to a UUID.
     * @param bytes The byte array to convert.
     * @return A UUID.
     */
    private static func fromBytes(bytes: [UInt8]) -> UUID {
        precondition(bytes.count == 16, "UUID bytes must be 16 bytes long")
        let uuidBytes: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        
        return UUID(uuid: uuidBytes)
    }
}
