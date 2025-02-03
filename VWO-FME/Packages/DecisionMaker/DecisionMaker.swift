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

class DecisionMaker {
    /**
     * Generates a bucket value for a user by hashing the user ID with murmurHash
     * and scaling it down to a specified maximum value.
     *
     * @param hashValue The hash value generated after hashing
     * @param maxValue The maximum value up to which the hash value needs to be scaled
     * @param multiplier Multiplier to adjust the scale in case the traffic allocation is less than 100
     * @return The bucket value of the user
     */
    static func generateBucketValue(hashValue: UInt64, maxValue: Int, multiplier: Int) -> Int {
        let ratio = Double(hashValue) / pow(2.0, 32.0) // Calculate the ratio of the hash value to the maximum hash value
        let multipliedValue = (Double(maxValue) * ratio + 1) * Double(multiplier) // Apply the multiplier after scaling the hash value
        return Int(floor(multipliedValue)) // Floor the value to get an integer bucket value
    }

    /**
     * Generates a bucket value for a user by hashing the user ID with murmurHash
     * and scaling it down to a specified maximum value.
     *
     * @param hashValue The hash value generated after hashing
     * @param maxValue The maximum value up to which the hash value needs to be scaled
     */
    static func generateBucketValue(hashValue: UInt64, maxValue: Int) -> Int {
        let multiplier = 1
        let ratio = Double(hashValue) / pow(2.0, 32.0) // Calculate the ratio of the hash value to the maximum hash value
        let multipliedValue = (Double(maxValue) * ratio + 1) * Double(multiplier) // Apply the multiplier after scaling the hash value
        return Int(floor(multipliedValue)) // Floor the value to get an integer bucket value
    }

    /**
     * Validates the user ID and generates a bucket value for the user by hashing the user ID with murmurHash
     * and scaling it down.
     *
     * @param userId The unique ID assigned to the user
     * @param maxValue The maximum value for bucket scaling (default is 100)
     * @return The bucket value allotted to the user (between 1 and maxValue)
     */
    static func getBucketValueForUser(userId: String?, maxValue: Int) -> Int {
        guard let userId = userId, !userId.isEmpty else {
            fatalError("User ID cannot be null or empty")
        }
        let hashValue = generateHashValue(hashKey: userId) // Generate the hash value using murmurHash
        return generateBucketValue(hashValue: hashValue, maxValue: maxValue, multiplier: 1) // Generate the bucket value using the hash value (default multiplier)
    }

    /**
     * Calculates the bucket value for a given user ID.
     *
     * This function generates a bucket value within a specified range based on the user ID. The
     * bucket value is determined using a hashing algorithm and can be used for various purposes
     * like user segmentation or feature rollout.
     *
     * @param userId The ID of the user.
     * @return The calculated bucket value for the user.
     * @throws IllegalArgumentException If the user ID is null or empty.
     */
    static func getBucketValueForUser(userId: String?) -> Int {
        let maxValue = 100
        guard let userId = userId, !userId.isEmpty else {
            fatalError("User ID cannot be null or empty")
        }
        let hashValue = generateHashValue(hashKey: userId) // Generate the hash value using murmurHash
        return generateBucketValue(hashValue: hashValue, maxValue: maxValue, multiplier: 1) // Generate the bucket value using the hash value (default multiplier)
    }

    /**
     * Calculates the bucket value for a given string and optional multiplier and maximum value.
     *
     * @param str The string to hash
     * @param multiplier Multiplier to adjust the scale (default is 1)
     * @param maxValue Maximum value for bucket scaling (default is 10000)
     * @return The calculated bucket value
     */
    public static func calculateBucketValue(str: String, multiplier: Int, maxValue: Int) -> Int {
        let hashValue = generateHashValue(hashKey: str) // Generate the hash value for the string
        return generateBucketValue(hashValue: hashValue, maxValue: maxValue, multiplier: multiplier) // Generate and return the bucket value
    }

    /**
     * Calculates the bucket value for a given string.
     *
     * This function generates a bucket value within a specified range based on the input string.
     * The bucket value is determined using a hashing algorithm and can be used for various
     * purposes like consistent hashing or data partitioning.
     *
     * @param str The input string.
     * @return The calculated bucket value for the string.
     */
    static func calculateBucketValue(str: String) -> Int {
        let multiplier = 1
        let maxValue = 10000
        let hashValue = generateHashValue(hashKey: str) // Generate the hash value for the string
        return generateBucketValue(hashValue: hashValue, maxValue: maxValue, multiplier: multiplier) // Generate and return the bucket value
    }

    /**
     * Generates a hash value for a given key using murmurHash.
     *
     * @param hashKey The key to hash
     * @return The generated hash value
     */
    static func generateHashValue(hashKey: String) -> UInt64 {
        // MurmurHash3 implementation in Swift
        let data = hashKey.data(using: .utf8)!
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> UInt32 in
            let seed: UInt32 = 1
            return MurmurHash3.hash32(bytes: bytes, seed: seed)
        }
        return UInt64(hash) & 0xFFFFFFFF
    }

    static let SEED_VALUE: UInt32 = 1 // Seed value for the hash function
    static let MAX_TRAFFIC_VALUE: Int = 10000 // Maximum traffic value used as a default scale
    static let MAX_CAMPAIGN_VALUE: Int = 100
}

// MurmurHash3 implementation in Swift
struct MurmurHash3 {
    static func hash32(bytes: UnsafeRawBufferPointer, seed: UInt32) -> UInt32 {
        let c1: UInt32 = 0xcc9e2d51
        let c2: UInt32 = 0x1b873593
        let r1: UInt32 = 15
        let r2: UInt32 = 13
        let m: UInt32 = 5
        let n: UInt32 = 0xe6546b64

        var hash = seed
        let chunkSize = MemoryLayout<UInt32>.size
        let chunkCount = bytes.count / chunkSize

        for chunkIndex in 0..<chunkCount {
            let chunkOffset = chunkIndex * chunkSize
            let k1 = bytes.load(fromByteOffset: chunkOffset, as: UInt32.self)
            var k = k1 &* c1
            k = (k << r1) | (k >> (32 - r1))
            k = k &* c2

            hash ^= k
            hash = (hash << r2) | (hash >> (32 - r2))
            hash = hash &* m &+ n
        }

        let tailIndex = chunkCount * chunkSize
        var k1: UInt32 = 0
        let tailSize = bytes.count - tailIndex
        if tailSize > 0 {
            for i in 0..<tailSize {
                k1 ^= UInt32(bytes[tailIndex + i]) << (i * 8)
            }
            k1 = k1 &* c1
            k1 = (k1 << r1) | (k1 >> (32 - r1))
            k1 = k1 &* c2
            hash ^= k1
        }

        hash ^= UInt32(bytes.count)
        hash ^= (hash >> 16)
        hash = hash &* 0x85ebca6b
        hash ^= (hash >> 13)
        hash = hash &* 0xc2b2ae35
        hash ^= (hash >> 16)

        return hash
    }
}
