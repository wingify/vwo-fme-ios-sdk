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
 * Partitions requested feature keys into evaluation batches for getFlags().
 * Flags sharing a MEG group are batched together for sequential evaluation;
 * independent flags are evaluated as single-key batches eligible for parallelism.
 */
enum MegGroupPartitionUtil {

    /**
     * A set of feature keys that must be evaluated sequentially within one worker.
     */
    struct EvaluationBatch {
        let keys: [String]
    }

    /**
     * Partitions `requestedKeys` into evaluation batches for parallel getFlags().
     *
     * - Parameters:
     *   - requestedKeys: Distinct feature keys requested by the caller.
     *   - settings: Account settings used to resolve MEG group membership.
     * - Returns: Batches where MEG-linked keys share a batch and independent keys are alone.
     */
    static func getFeatureFlagBatches(requestedKeys: [String], settings: Settings) -> [EvaluationBatch] {
        if requestedKeys.isEmpty {
            return []
        }

        var batches: [EvaluationBatch] = []
        var assigned = Set<String>()

        for key in requestedKeys {
            if assigned.contains(key) {
                continue
            }

            let groups = CampaignUtil.findGroupsFeaturePartOf(settings: settings, featureKey: key)
            let groupId = groups.compactMap { Int($0["groupId"] ?? "") }.first

            if let groupId = groupId {
                let megFeatureKeys = (MegUtil.getFeatureKeysFromGroup(settings: settings, groupId: groupId)["featureKeys"] as? [String]) ?? []
                let megFeatureKeySet = Set(megFeatureKeys)
                let keysInBatch = requestedKeys.filter { megFeatureKeySet.contains($0) && !assigned.contains($0) }
                // MEG group lookup can miss the current key (empty/mismatched featureKeys).
                // Always evaluate at least this key so it is never silently dropped.
                let batchKeys = keysInBatch.isEmpty ? [key] : keysInBatch
                batches.append(EvaluationBatch(keys: batchKeys))
                assigned.formUnion(batchKeys)
            } else {
                batches.append(EvaluationBatch(keys: [key]))
                assigned.insert(key)
            }
        }

        return batches
    }
}
