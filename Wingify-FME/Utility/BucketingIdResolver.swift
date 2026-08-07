/**
 * Copyright 2024-2026 Wingify Software Pvt. Ltd.
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

/// Utility responsible for resolving the identifier used for feature flag bucketing.
///
/// The resolver prioritizes `bucketingSeed` from `VWOUserContext` when it is available
/// and non-empty. If no custom seed is provided, it falls back to using `userId`.
/// This ensures deterministic bucketing while also allowing custom bucketing control.
enum BucketingIdResolver {

    /// Resolves the identifier used for bucketing.
    ///
    /// - Parameters:
    ///   - userId: The default user identifier.
    ///   - context: The user context that may contain a custom `bucketingSeed`.
    ///
    /// - Returns: `context.bucketingSeed` if it exists and is not empty; otherwise returns `userId`.
    static func resolve(userId: String?, context: WingifyUserContext?) -> String? {
        if let seed = context?.bucketingSeed,
           !seed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return seed
        }
        return userId
    }

    /// Clears an empty or whitespace-only `bucketingSeed` from the context so bucketing falls back to `userId`.
    ///
    /// - Parameter context: The user context that may contain an invalid `bucketingSeed`.
    /// - Returns: `true` if a present seed was invalid and cleared; otherwise `false`.
    @discardableResult
    static func clearInvalidBucketingSeed(_ context: WingifyUserContext?) -> Bool {
        guard let context = context, let seed = context.bucketingSeed else {
            return false
        }
        guard seed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        context.bucketingSeed = nil
        return true
    }

    /// Formats the user identifier for logging purposes.
    ///
    /// When a custom bucketing seed is used, the log output includes both values
    /// to make debugging easier.
    ///
    /// Example:
    /// `user123 (Seed: customSeed123)`
    ///
    /// - Parameters:
    ///   - userId: The original user identifier.
    ///   - bucketingId: The resolved identifier used for bucketing.
    ///
    /// - Returns: A formatted string for logging.
    static func formatUserIdForLogging(userId: String?, bucketingId: String?) -> String {
        if let uid = userId, let bid = bucketingId, bid != uid {
            return "\(uid) (Seed: \(bid))"
        }
        return userId ?? ""
    }

    /// Determines whether a custom bucketing seed is being used.
    ///
    /// - Parameters:
    ///   - userId: The original user identifier.
    ///   - bucketingId: The resolved identifier used for bucketing.
    ///
    /// - Returns: `true` if `bucketingId` is different from `userId`, indicating that
    /// a custom bucketing seed is in use; otherwise `false`.
    static func isUsingCustomSeed(userId: String?, bucketingId: String?) -> Bool {
        guard let uid = userId, let bid = bucketingId else { return false }
        return bid != uid
    }
}
