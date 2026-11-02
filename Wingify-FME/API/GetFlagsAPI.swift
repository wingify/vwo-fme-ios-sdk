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
 * Evaluates multiple feature flags in parallel for `WingifyClient.getFlags`.
 *
 * Flags that share a MEG group are evaluated sequentially within a batch; independent
 * flags run concurrently up to `Constants.MAX_CONCURRENT_FLAG_EVALUATIONS`.
 */
enum GetFlagsAPI {

    /**
     * Evaluates the requested feature flags and returns them as a `FlagCollection`.
     *
     * - Parameters:
     *   - flagNames: Feature keys to evaluate, or nil/empty to evaluate all flags from `settings`.
     *   - settings: Account settings used for evaluation.
     *   - context: User context (resolved once; each flag gets an isolated copy).
     *   - serviceContainer: Shared services for logging, storage, and batch uploads.
     *   - shouldSendTrackingCalls: When true, sends `vwo_variationShown` impressions. Defaults to false.
     *   - shouldSendUserTrackCalls: When true, sends MAU / user-tracking events. Defaults to true; set false to disable.
     * - Returns: `FlagCollection` keyed by feature key.
     */
    static func getFlags(
        flagNames: [String]?,
        settings: Settings,
        context: WingifyUserContext,
        serviceContainer: ServiceContainer,
        shouldSendTrackingCalls: Bool = true,
        shouldSendUserTrackCalls: Bool = true
    ) -> FlagCollection {
        // Enforce tracking policy for this getFlags call only.
        serviceContainer.configureGetFlagsTracking(
            sendTrackingCalls: shouldSendTrackingCalls,
            sendUserTrackCalls: shouldSendUserTrackCalls
        )

        let keys = resolveFlagKeys(flagNames: flagNames, settings: settings)
        if keys.isEmpty {
            return FlagCollection.create(flags: [:], fallbackContext: context)
        }

        let batches = MegGroupPartitionUtil.getFeatureFlagBatches(requestedKeys: keys, settings: settings)
        let resultsStore = ResultsStore()

        let shouldDeferUploads = shouldSendTrackingCalls || shouldSendUserTrackCalls
        if shouldDeferUploads {
            serviceContainer.beginDeferImmediateBatchUpload()
        }
        defer {
            // End leftover decision-cache write mode if any (fetchFlags persists sticky + variationShownSent).
            serviceContainer.clearGetFlagsDecisionCache()
            if shouldDeferUploads {
                // Flush only when the outermost nested defer ends so concurrent getFlags
                // calls cannot re-enable mid-batch uploads for each other.
                let shouldFlush = serviceContainer.endDeferImmediateBatchUpload()
                if shouldFlush && !serviceContainer.getSyncManager().isOnlineBatchingAllowed {
                    DispatchQueue.global(qos: .utility).async {
                        serviceContainer.getSyncManager().syncSavedEvents(manually: true, ignoreThreshold: true)
                    }
                }
            }
        }

        let concurrencyLimit = Constants.MAX_CONCURRENT_FLAG_EVALUATIONS
        let semaphore = DispatchSemaphore(value: concurrencyLimit)
        let dispatchGroup = DispatchGroup()
        let evaluationQueue = DispatchQueue(label: "com.wingify.fme.getflags", qos: .userInitiated, attributes: .concurrent)

        for batch in batches {
            dispatchGroup.enter()
            evaluationQueue.async {
                semaphore.wait()
                defer {
                    semaphore.signal()
                    dispatchGroup.leave()
                }
                evaluateBatch(
                    batch: batch,
                    settings: settings,
                    baseContext: context,
                    serviceContainer: serviceContainer,
                    resultsStore: resultsStore
                )
            }
        }

        dispatchGroup.wait()
        return FlagCollection.create(flags: resultsStore.snapshot(), fallbackContext: context)
    }

    /**
     * Resolves the distinct feature keys to evaluate.
     * When `flagNames` is nil or empty, all feature keys from `settings` are used.
     */
    private static func resolveFlagKeys(flagNames: [String]?, settings: Settings) -> [String] {
        if flagNames == nil || flagNames?.isEmpty == true {
            var seen = Set<String>()
            var keys: [String] = []
            for feature in settings.features {
                guard let key = feature.key, !key.isEmpty, !seen.contains(key) else { continue }
                seen.insert(key)
                keys.append(key)
            }
            return keys
        }

        var seen = Set<String>()
        var keys: [String] = []
        for name in flagNames ?? [] {
            if seen.contains(name) { continue }
            seen.insert(name)
            keys.append(name)
        }
        return keys
    }

    /**
     * Evaluates every key in `batch` sequentially and writes results into `resultsStore`.
     */
    private static func evaluateBatch(
        batch: MegGroupPartitionUtil.EvaluationBatch,
        settings: Settings,
        baseContext: WingifyUserContext,
        serviceContainer: ServiceContainer,
        resultsStore: ResultsStore
    ) {
        for key in batch.keys {
            let flag = evaluateSingleFlag(
                featureKey: key,
                settings: settings,
                baseContext: baseContext,
                serviceContainer: serviceContainer
            )
            resultsStore.set(flag, forKey: key)
        }
    }

    /// Thread-safe map of feature key → evaluated flag.
    private final class ResultsStore {
        private let lock = NSLock()
        private var flags: [String: GetFlag] = [:]

        /**
         * Stores an evaluated flag for `key`.
         */
        func set(_ flag: GetFlag, forKey key: String) {
            lock.lock()
            flags[key] = flag
            lock.unlock()
        }

        /**
         * Returns a copy of all evaluated flags.
         */
        func snapshot() -> [String: GetFlag] {
            lock.lock()
            defer { lock.unlock() }
            return flags
        }
    }

    /**
     * Evaluates a single feature flag on a cloned context with a thread-local segmentation manager.
     */
    private static func evaluateSingleFlag(
        featureKey: String,
        settings: Settings,
        baseContext: WingifyUserContext,
        serviceContainer: ServiceContainer
    ) -> GetFlag {
        let clonedContext = baseContext.clone()
        let evalSegmentationManager = SegmentationManager()
        evalSegmentationManager.attachEvaluator()
        serviceContainer.setEvalSegmentationManager(evalSegmentationManager)
        defer {
            serviceContainer.clearEvalSegmentationManager()
        }

        var result = GetFlag()
        result.setIsEnabled(isEnabled: false)
        GetFlagAPI.getFlag(
            featureKey: featureKey,
            settings: settings,
            context: clonedContext,
            hookManager: serviceContainer.getHooksManager(),
            serviceContainer: serviceContainer,
            shouldSendTrackingCalls: serviceContainer.areImpressionRequestsAllowed
        ) { flag in
            result = flag
        }
        return result
    }
}
