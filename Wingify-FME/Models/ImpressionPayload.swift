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

/**
 * Accumulates `vwo_variationShown` impression rows built during flag evaluation.
 */
final class ImpressionPayload {
    struct Item {
        let campaignId: Int
        let variationId: Int
        let featureId: Int
    }

    private(set) var impressionList: [Item] = []

    /**
     * Appends a variation-shown row. Rows with `campaignId == 0` are ignored.
     */
    func add(campaignId: Int, variationId: Int, featureId: Int = Constants.IMPRESSION_NO_FEATURE_ID) {
        guard campaignId != 0 else { return }
        impressionList.append(Item(campaignId: campaignId, variationId: variationId, featureId: featureId))
    }

    /**
     * Copies every row from `other` into this payload.
     */
    func merge(_ other: ImpressionPayload) {
        for item in other.impressionList {
            add(campaignId: item.campaignId, variationId: item.variationId, featureId: item.featureId)
        }
    }

    /**
     * Number of accumulated impression rows.
     */
    func size() -> Int {
        impressionList.count
    }

    /**
     * `true` when at least one valid impression row is present.
     */
    func hasValidData() -> Bool {
        !impressionList.isEmpty
    }

    /**
     * `true` when no impression rows have been accumulated.
     */
    func hasNoValidData() -> Bool {
        impressionList.isEmpty
    }

    /**
     * Removes all accumulated impression rows.
     */
    func clear() {
        impressionList.removeAll()
    }
}
