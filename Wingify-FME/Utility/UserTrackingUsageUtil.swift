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
 * Tracks whether a `vwo_variationShown` impression was dispatched during a single `getFlag` evaluation.
 *
 * Used to decide whether an additional user-tracking event is required for accounts with user-tracking
 * billing enabled. If any impression was sent in the current call, DaCDN handles usage through
 * `variationShown` instead.
 */
final class VariationShownTracker {

    /// `true` when at least one `variationShown` impression was sent during this `getFlag` call.
    private(set) var sent = false

    /**
     * Sends a `vwo_variationShown` impression and marks tracking as active for this evaluation.
     *
     * - Parameters:
     *   - settings: SDK settings for the current account.
     *   - campaignId: Campaign or holdout ID for the impression.
     *   - variationId: Variation ID shown to the user.
     *   - context: User context for the evaluation.
     *   - serviceContainer: Service container for network and logging access.
     */
    func recordVariationShown(
        settings: Settings,
        campaignId: Int,
        variationId: Int,
        context: WingifyUserContext,
        serviceContainer: ServiceContainer
    ) {
        ImpressionUtil.createAndSendImpressionForVariationShown(
            settings: settings,
            campaignId: campaignId,
            variationId: variationId,
            context: context,
            serviceContainer: serviceContainer
        )
        sent = true
    }

    /**
     * Sends holdout-related `variationShown` impressions and marks tracking as active.
     *
     * Holdout impressions include both "in holdout" and "not in holdout" reporting events.
     *
     * - Parameters:
     *   - settings: SDK settings for the current account.
     *   - impressions: Holdout impressions to dispatch.
     *   - context: User context for the evaluation.
     *   - serviceContainer: Service container for network and logging access.
     */
    func recordHoldoutImpressions(
        settings: Settings,
        impressions: [HoldoutImpression],
        context: WingifyUserContext,
        serviceContainer: ServiceContainer
    ) {
        guard !impressions.isEmpty else { return }
        for imp in impressions {
            recordVariationShown(
                settings: settings,
                campaignId: imp.campaignId,
                variationId: imp.variationId,
                context: context,
                serviceContainer: serviceContainer
            )
        }
    }
}

/**
 * Utility for per-user tracking and usage billing on accounts with user-tracking billing enabled.
 *
 * Accounts with `Settings.isMAU` set to `true` are billed per evaluated user rather than per
 * impression. When a `getFlag` evaluation completes without a `variationShown` impression, the SDK
 * emits a user-tracking event (`vwo_fmeMauEvaluated`) so DaCDN can record usage. If a `variationShown`
 * event was already sent for the evaluation, DaCDN records usage through that path instead and no
 * separate user-tracking event is required. Duplicate charges for the same user are deduplicated server-side.
 */
enum UserTrackingUsageUtil {

    /**
     * Returns whether user-tracking billing is enabled for the account.
     *
     * - Parameter settings: Parsed SDK settings from DaCDN.
     * - Returns: `true` only when `settings.isMAU` is explicitly `true`; absent or `null` defaults to per-impression billing (`false`).
     */
    static func isUserTrackingEnabled(settings: Settings) -> Bool {
        settings.isMAU == true
    }

    /**
     * Sends a user-tracking event for cached storage decisions when no `variationShown` was dispatched.
     *
     * Use this on storage early-return paths (stored holdout, experiment, or rollout). Unlike
     * `shouldTrackUsage`, this runs even when the returned flag is enabled, because a cached
     * decision may be served without a new campaign impression on this call.
     *
     * - Parameters:
     *   - settings: SDK settings, including the user-tracking billing flag (`isMAU`).
     *   - context: User context for the evaluation.
     *   - featureKey: Feature key being evaluated.
     *   - feature: Resolved feature model.
     *   - serviceContainer: Service container for network and logging access.
     *   - variationShownSent: `true` when a `variationShown` impression was already dispatched in this call.
     */
    static func shouldTrackStoredDecision(
        settings: Settings,
        context: WingifyUserContext,
        featureKey: String,
        feature: Feature?,
        serviceContainer: ServiceContainer,
        variationShownSent: Bool
    ) {
        if isUserTrackingEnabled(settings: settings) && !variationShownSent {
            sendTrackingUsage(
                settings: settings,
                context: context,
                featureKey: featureKey,
                feature: feature,
                serviceContainer: serviceContainer
            )
        }
    }

    /**
     * Sends a user-tracking event after a full `getFlag` evaluation when billing applies.
     *
     * Called at the end of the normal evaluation path. A user-tracking event is sent only when the
     * user was not assigned to a campaign (`flag` disabled) and no `variationShown` impression was dispatched.
     *
     * - Parameters:
     *   - settings: SDK settings, including the user-tracking billing flag (`isMAU`).
     *   - context: User context for the evaluation.
     *   - featureKey: Feature key being evaluated.
     *   - feature: Resolved feature model, or `nil` when the feature was not found.
     *   - serviceContainer: Service container for network and logging access.
     *   - flag: The `GetFlag` result produced by the evaluation.
     *   - variationShownSent: `true` when a `variationShown` impression was already dispatched in this call.
     */
    static func shouldTrackUsage(
        settings: Settings,
        context: WingifyUserContext,
        featureKey: String,
        feature: Feature?,
        serviceContainer: ServiceContainer,
        flag: GetFlag,
        variationShownSent: Bool
    ) {
        if isUserTrackingEnabled(settings: settings) && !flag.isEnabled() && !variationShownSent {
            sendTrackingUsage(
                settings: settings,
                context: context,
                featureKey: featureKey,
                feature: feature,
                serviceContainer: serviceContainer
            )
        }
    }

    /**
     * Builds and sends a user-tracking event (`vwo_fmeMauEvaluated`) to DaCDN.
     *
     * The request uses the standard event pipeline (`POST /events/t`), same as `variationShown`.
     *
     * - Parameters:
     *   - settings: SDK settings, including account and user-tracking configuration.
     *   - context: User context for the evaluation.
     *   - featureKey: Feature key being evaluated.
     *   - feature: Resolved feature model, or `nil` when the feature was not found.
     *   - serviceContainer: Service container for network, batching, and logging access.
     */
    static func sendTrackingUsage(
        settings: Settings,
        context: WingifyUserContext,
        featureKey: String,
        feature: Feature?,
        serviceContainer: ServiceContainer
    ) {
        let properties = NetworkUtil.getEventsBaseProperties(
            eventName: EventEnum.vwoFmeUserTrackingEvaluated.rawValue,
            visitorUserAgent: ImpressionUtil.encodeURIComponent(context.userAgent),
            ipAddress: context.ipAddress,
            serviceContainer: serviceContainer
        )

        let payload = NetworkUtil.getUserTrackingPayloadData(
            settings: settings,
            context: context,
            userId: context.id,
            featureKey: featureKey,
            featureId: feature?.id,
            serviceContainer: serviceContainer
        )

        NetworkUtil.sendPostApiRequest(
            properties: properties,
            payload: payload,
            userAgent: context.userAgent,
            ipAddress: context.ipAddress,
            campaignInfo: [
                "featureName": feature?.name ?? "",
                "featureKey": featureKey
            ],
            serviceContainer: serviceContainer
        )

        serviceContainer.getLoggerService()?.log(
            level: .debug,
            key: "USER_TRACKED",
            details: [
                "accountId": "\(settings.accountId ?? 0)",
                "userId": context.id ?? "",
                "featureKey": featureKey
            ]
        )
    }
}
