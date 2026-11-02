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
 * Owns send vs defer vs expose for `vwo_variationShown` impressions.
 *
 * All getFlag-path variationShown sites route through `record`.
 * `expose` drains the in-memory stash or rebuilds from sticky storage + impact.
 */
enum ImpressionExposureHelper {

    /**
     * Dependencies needed to enqueue deferred impressions later via `GetFlag.exposeResult`.
     */
    struct ExposeDeps {
        let settings: Settings
        let featureKey: String
        let context: WingifyUserContext
        let serviceContainer: ServiceContainer
        let isEnabled: Bool
    }

    /**
     * Records impressions built during evaluation: enqueue now, or merge into `getFlag`'s stash.
     *
     * - Returns: `true` when a non-empty payload was actually sent to the server/batch.
     */
    @discardableResult
    static func record(
        settings: Settings,
        impressionPayload: ImpressionPayload,
        context: WingifyUserContext,
        serviceContainer: ServiceContainer,
        shouldSendTrackingCalls: Bool,
        getFlag: GetFlag,
        featureKey: String,
        feature: Feature?
    ) -> Bool {
        getFlag.attachExposeDeps(
            ExposeDeps(
                settings: settings,
                featureKey: featureKey,
                context: context,
                serviceContainer: serviceContainer,
                isEnabled: getFlag.isEnabled()
            )
        )

        guard impressionPayload.hasValidData() else {
            // Empty payload: do not rewrite variationShownSent (preserve sticky expose state).
            return false
        }

        if shouldSendTrackingCalls {
            ImpressionUtil.createAndSendImpressionForVariationShown(
                settings: settings,
                impressionPayload: impressionPayload,
                context: context,
                serviceContainer: serviceContainer
            )
            getFlag.markImpressionSent()
            persistVariationShownSent(
                featureKey: featureKey,
                context: context,
                serviceContainer: serviceContainer,
                sent: true
            )
            return true
        }

        getFlag.mergePendingImpressions(impressionPayload)
        persistVariationShownSent(
            featureKey: featureKey,
            context: context,
            serviceContainer: serviceContainer,
            sent: false
        )
        serviceContainer.getLoggerService()?.log(
            level: .info,
            key: "IMPRESSION_DEFERRED",
            details: [
                Constants.USER_ID: context.id ?? "",
                "featureKey": featureKey,
                "count": "\(impressionPayload.size())"
            ]
        )
        return false
    }

    /**
     * Enqueues a previously deferred (or rebuildable) variationShown impression.
     * Idempotent: no-ops when already sent (in-memory or durable storage).
     */
    @discardableResult
    static func expose(getFlag: GetFlag) -> Bool {
        if getFlag.isImpressionAlreadySent() {
            logExpose(getFlag, key: "IMPRESSION_EXPOSE_ALREADY_SENT")
            return false
        }

        guard let deps = getFlag.getExposeDeps() else {
            logExpose(getFlag, key: "IMPRESSION_EXPOSE_NOTHING")
            return false
        }

        if getFlag.isImpressionAlreadySent() {
            logExpose(getFlag, key: "IMPRESSION_EXPOSE_ALREADY_SENT")
            return false
        }

        let storageService = deps.serviceContainer.storage ?? StorageService()
        let rawStored = storageService.getFeatureFromStorage(featureKey: deps.featureKey, context: deps.context)
        let stored = readStorage(rawStored)
        if isAlreadySent(raw: rawStored, stored: stored) {
            getFlag.markImpressionSent()
            logExpose(getFlag, key: "IMPRESSION_EXPOSE_ALREADY_SENT")
            return false
        }

        var payload = getFlag.consumePendingImpressions()
        var rebuilt = false
        if payload.hasNoValidData() {
            payload = rebuildPayload(deps: deps, stored: stored ?? readStorageLenient(rawStored))
            rebuilt = payload.hasValidData()
        }

        guard payload.hasValidData() else {
            logExpose(getFlag, key: "IMPRESSION_EXPOSE_NOTHING")
            return false
        }

        // exposeResult always sends, regardless of getFlags tracking policy.
        let previous = deps.serviceContainer.areImpressionRequestsAllowed
        deps.serviceContainer.setImpressionRequestsAllowed(true)
        defer { deps.serviceContainer.setImpressionRequestsAllowed(previous) }

        ImpressionUtil.createAndSendImpressionForVariationShown(
            settings: deps.settings,
            impressionPayload: payload,
            context: deps.context,
            serviceContainer: deps.serviceContainer
        )
        getFlag.markImpressionSent()
        persistVariationShownSent(
            featureKey: deps.featureKey,
            context: deps.context,
            serviceContainer: deps.serviceContainer,
            sent: true
        )
        logExpose(getFlag, key: rebuilt ? "IMPRESSION_EXPOSE_REBUILD" : "IMPRESSION_EXPOSE_FROM_STASH")
        return true
    }

    /**
     * Rebuilds a variationShown payload from sticky storage + feature impact campaign.
     */
    static func rebuildPayload(deps: ExposeDeps, stored: Storage?) -> ImpressionPayload {
        let payload = ImpressionPayload()
        let feature = FunctionUtil.getFeatureFromKey(settings: deps.settings, featureKey: deps.featureKey)
        let featureId = feature?.id ?? Constants.IMPRESSION_NO_FEATURE_ID

        if let stored = stored {
            if let experimentId = stored.experimentId,
               let experimentVariationId = stored.experimentVariationId {
                payload.add(campaignId: experimentId, variationId: experimentVariationId)
            }
            if let rolloutId = stored.rolloutId,
               let rolloutVariationId = stored.rolloutVariationId {
                payload.add(campaignId: rolloutId, variationId: rolloutVariationId)
            }
            for holdoutId in stored.holdoutIds ?? stored.holdoutId ?? stored.holdoutGroupId ?? [] {
                payload.add(
                    campaignId: holdoutId,
                    variationId: Constants.Holdouts.VARIATION_IS_PART_OF_HOLDOUT,
                    featureId: featureId
                )
            }
        }

        if let impactId = feature?.impactCampaign?.campaignId {
            payload.add(
                campaignId: impactId,
                variationId: deps.isEnabled ? 2 : 1
            )
        }

        return payload
    }

    // MARK: - Private

    private static func isAlreadySent(raw: [String: Any]?, stored: Storage?) -> Bool {
        if let sent = raw?[Constants.KEY_VARIATION_SHOWN_SENT] as? Bool {
            return sent
        }
        if let sent = stored?.variationShownSent {
            return sent
        }
        // Legacy sticky without the key: treat as already sent if a decision exists.
        return hasDecisionInRaw(raw)
    }

    private static func hasDecisionInRaw(_ raw: [String: Any]?) -> Bool {
        guard let raw = raw else { return false }
        if raw["experimentVariationId"] != nil { return true }
        if raw["rolloutVariationId"] != nil { return true }
        if let holdouts = raw[Constants.Holdouts.KEY_STORAGE_HOLDOUT_IDS] as? [Any], !holdouts.isEmpty {
            return true
        }
        return false
    }

    private static func readStorage(_ raw: [String: Any]?) -> Storage? {
        guard let raw = raw else { return nil }
        do {
            let normalized = FunctionUtil.normalizeStorageMapForDecoding(raw)
            let data = try JSONSerialization.data(withJSONObject: normalized, options: [])
            return try JSONDecoder().decode(Storage.self, from: data)
        } catch {
            return nil
        }
    }

    private static func readStorageLenient(_ raw: [String: Any]?) -> Storage? {
        if let parsed = readStorage(raw) { return parsed }
        guard let raw = raw else { return nil }
        var storage = Storage()
        storage.featureKey = raw["featureKey"] as? String
        storage.user = (raw["userId"] as? String) ?? (raw["user"] as? String)
        storage.rolloutId = intValue(raw["rolloutId"])
        storage.rolloutKey = raw["rolloutKey"] as? String
        storage.rolloutVariationId = intValue(raw["rolloutVariationId"])
        storage.experimentId = intValue(raw["experimentId"])
        storage.experimentKey = raw["experimentKey"] as? String
        storage.experimentVariationId = intValue(raw["experimentVariationId"])
        storage.variationShownSent = raw[Constants.KEY_VARIATION_SHOWN_SENT] as? Bool
        if let holdouts = raw[Constants.Holdouts.KEY_STORAGE_HOLDOUT_IDS] as? [Any] {
            storage.holdoutIds = holdouts.compactMap { intValue($0) }
        }
        return storage
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        return nil
    }

    private static func persistVariationShownSent(
        featureKey: String,
        context: WingifyUserContext,
        serviceContainer: ServiceContainer,
        sent: Bool
    ) {
        let storageService = serviceContainer.storage ?? StorageService()
        // Never downgrade an already-sent sticky decision (fetchFlags after exposeResult).
        if !sent {
            if let raw = storageService.getFeatureFromStorage(featureKey: featureKey, context: context),
               (raw[Constants.KEY_VARIATION_SHOWN_SENT] as? Bool) == true {
                return
            }
        }
        _ = storageService.updateDataInStorage(
            featureKey: featureKey,
            context: context,
            data: [Constants.KEY_VARIATION_SHOWN_SENT: sent]
        )
    }

    private static func logExpose(_ getFlag: GetFlag, key: String) {
        guard let deps = getFlag.getExposeDeps() else { return }
        deps.serviceContainer.getLoggerService()?.log(
            level: .info,
            key: key,
            details: [
                Constants.USER_ID: deps.context.id ?? "",
                "featureKey": deps.featureKey
            ]
        )
    }
}
