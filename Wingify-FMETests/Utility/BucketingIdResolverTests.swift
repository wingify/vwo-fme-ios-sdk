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

import XCTest
@testable import VWO_FME

/// Unit tests for `BucketingIdResolver`.
final class BucketingIdResolverTests: XCTestCase {

    func testResolveReturnsUserIdWhenSeedNotSet() {
        let userId = "user-123"
        let context = VWOUserContext(id: userId, customVariables: [:])

        let result = BucketingIdResolver.resolve(userId: userId, context: context)

        XCTAssertEqual(result, userId)
    }

    func testResolveReturnsUserIdWhenSeedIsNil() {
        let userId = "user-123"
        let context = VWOUserContext(id: userId, customVariables: [:], bucketingSeed: nil)

        let result = BucketingIdResolver.resolve(userId: userId, context: context)

        XCTAssertEqual(result, userId)
    }

    func testResolveReturnsUserIdWhenSeedIsEmpty() {
        let userId = "user-123"
        let context = VWOUserContext(id: userId, customVariables: [:], bucketingSeed: "")

        let result = BucketingIdResolver.resolve(userId: userId, context: context)

        XCTAssertEqual(result, userId)
    }

    func testClearInvalidBucketingSeedClearsEmptySeed() {
        let context = VWOUserContext(id: "user-123", customVariables: [:], bucketingSeed: "")

        let cleared = BucketingIdResolver.clearInvalidBucketingSeed(context)

        XCTAssertTrue(cleared)
        XCTAssertNil(context.bucketingSeed)
    }

    func testClearInvalidBucketingSeedClearsWhitespaceSeed() {
        let context = VWOUserContext(id: "user-123", customVariables: [:], bucketingSeed: "   ")

        let cleared = BucketingIdResolver.clearInvalidBucketingSeed(context)

        XCTAssertTrue(cleared)
        XCTAssertNil(context.bucketingSeed)
    }

    func testClearInvalidBucketingSeedKeepsValidSeed() {
        let seed = "custom-seed-456"
        let context = VWOUserContext(id: "user-123", customVariables: [:], bucketingSeed: seed)

        let cleared = BucketingIdResolver.clearInvalidBucketingSeed(context)

        XCTAssertFalse(cleared)
        XCTAssertEqual(context.bucketingSeed, seed)
    }

    func testClearInvalidBucketingSeedReturnsFalseWhenSeedIsNil() {
        let context = VWOUserContext(id: "user-123", customVariables: [:], bucketingSeed: nil)

        let cleared = BucketingIdResolver.clearInvalidBucketingSeed(context)

        XCTAssertFalse(cleared)
        XCTAssertNil(context.bucketingSeed)
    }

    func testResolveReturnsSeedWhenProvided() {
        let userId = "user-123"
        let seed = "custom-seed-456"
        let context = VWOUserContext(id: userId, customVariables: [:], bucketingSeed: seed)

        let result = BucketingIdResolver.resolve(userId: userId, context: context)

        XCTAssertEqual(result, seed)
    }

    func testResolveReturnsUserIdWhenContextIsNil() {
        let userId = "user-123"

        let result = BucketingIdResolver.resolve(userId: userId, context: nil)

        XCTAssertEqual(result, userId)
    }

    func testResolveReturnsSeedWhenUserIdNilButSeedProvided() {
        let seed = "custom-seed-456"
        let context = VWOUserContext(id: nil, customVariables: [:], bucketingSeed: seed)

        let result = BucketingIdResolver.resolve(userId: nil, context: context)

        XCTAssertEqual(result, seed)
    }

    func testFormatUserIdForLoggingWhenUsingCustomSeed() {
        let userId = "user-123"
        let bucketingId = "custom-seed-456"

        let result = BucketingIdResolver.formatUserIdForLogging(userId: userId, bucketingId: bucketingId)

        XCTAssertEqual(result, "user-123 (Seed: custom-seed-456)")
    }

    func testFormatUserIdForLoggingWhenNotUsingCustomSeed() {
        let userId = "user-123"

        let result = BucketingIdResolver.formatUserIdForLogging(userId: userId, bucketingId: userId)

        XCTAssertEqual(result, userId)
    }

    func testFormatUserIdForLoggingWhenBothNil() {
        let result = BucketingIdResolver.formatUserIdForLogging(userId: nil, bucketingId: nil)

        XCTAssertEqual(result, "")
    }

    func testIsUsingCustomSeedReturnsTrueWhenDifferent() {
        let userId = "user-123"
        let bucketingId = "custom-seed-456"

        XCTAssertTrue(BucketingIdResolver.isUsingCustomSeed(userId: userId, bucketingId: bucketingId))
    }

    func testIsUsingCustomSeedReturnsFalseWhenSame() {
        let userId = "user-123"

        XCTAssertFalse(BucketingIdResolver.isUsingCustomSeed(userId: userId, bucketingId: userId))
    }

    func testIsUsingCustomSeedReturnsFalseWhenUserIdNil() {
        let bucketingId = "custom-seed-456"

        XCTAssertFalse(BucketingIdResolver.isUsingCustomSeed(userId: nil, bucketingId: bucketingId))
    }

    func testIsUsingCustomSeedReturnsFalseWhenBucketingIdNil() {
        let userId = "user-123"

        XCTAssertFalse(BucketingIdResolver.isUsingCustomSeed(userId: userId, bucketingId: nil))
    }
}

