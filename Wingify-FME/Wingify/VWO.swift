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

public typealias VWOInitCompletionHandler = WingifyInitCompletionHandler
public typealias VWOStorageConnector = WingifyStorageConnector

@available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
@objc public class VWOInitOptions : WingifyInitOptions {
    public override init(sdkKey: String? = nil,
                         accountId: Int? = nil,
                         logLevel: LogLevelEnum = .error,
                         logPrefix: String = "",
                         integrations: IntegrationCallback? = nil,
                         gatewayService: [String: Any] = [:],
                         cachedSettingsExpiryTime: Int64? = nil,
                         cachedDecisionExpiryTime: Int64? = nil,
                         pollInterval: Int64? = nil,
                         batchMinSize: Int? = nil,
                         batchUploadTimeInterval: Int64? = nil,
                         sdkName: String? = nil,
                         sdkVersion: String? = nil,
                         logTransport: LogTransport? = nil,
                         isUsageStatsDisabled: Bool = false,
                         vwoMeta: [String: Any] = [:],
                         storage: WingifyStorageConnector? = nil,
                         isAliasingEnabled: Bool? = false,
                         shouldTriggerIntegrationCallbackAlways: Bool = false) {
        ProductConfig.use(.vwo)
        super.init(sdkKey: sdkKey,
                   accountId: accountId,
                   logLevel: logLevel,
                   logPrefix: logPrefix,
                   integrations: integrations,
                   gatewayService: gatewayService,
                   cachedSettingsExpiryTime: cachedSettingsExpiryTime,
                   cachedDecisionExpiryTime: cachedDecisionExpiryTime,
                   pollInterval: pollInterval,
                   batchMinSize: batchMinSize,
                   batchUploadTimeInterval: batchUploadTimeInterval,
                   sdkName: sdkName ?? Constants.SDK_NAME,
                   sdkVersion: sdkVersion,
                   logTransport: logTransport,
                   isUsageStatsDisabled: isUsageStatsDisabled,
                   vwoMeta: vwoMeta,
                   storage: storage,
                   isAliasingEnabled: isAliasingEnabled,
                   shouldTriggerIntegrationCallbackAlways: shouldTriggerIntegrationCallbackAlways)
    }
}

@available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
@objc public class VWOUserContext : WingifyUserContext{
    public override init(id: String? = nil,
                         shouldUseDeviceIdAsUserId: Bool = false,
                         customVariables: [String: Any],
                         postSegmentationVariables: [String]? = nil,
                         bucketingSeed: String? = nil,
                         ipAddress: String? = nil) {
        ProductConfig.use(.vwo)
        super.init(id: id,
                   shouldUseDeviceIdAsUserId: shouldUseDeviceIdAsUserId,
                   customVariables: customVariables,
                   postSegmentationVariables: postSegmentationVariables,
                   bucketingSeed: bucketingSeed,
                   ipAddress: ipAddress)
    }
}

@available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
@objc public final class VWOFme: NSObject {
    private let baseInstance: WingifyFme

    private init(baseInstance: WingifyFme) {
        self.baseInstance = baseInstance
        super.init()
    }
    
    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    @available(macOS 10.14, *)
    public static func initialize(options: VWOInitOptions, completion: @escaping VWOInitCompletionHandler) {
        ProductConfig.use(.vwo)
        WingifyFme.initialize(options: options, completion: completion)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public static func getInstance(accountId: Int?, sdkKey: String?) -> VWOFme? {
        ProductConfig.use(.vwo)
        guard let instance = WingifyFme.getInstance(accountId: accountId, sdkKey: sdkKey) else {
            return nil
        }
        return VWOFme(baseInstance: instance)
    }
    
    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public static func clearInstance(accountId: Int?, sdkKey: String?) {
        ProductConfig.use(.vwo)
        WingifyFme.clearInstance(accountId: accountId, sdkKey: sdkKey)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public static func clearAllInstances() {
        ProductConfig.use(.vwo)
        WingifyFme.clearAllInstances()
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public static func updateSettings(_ newSettings: Settings) {
        ProductConfig.use(.vwo)
        WingifyFme.updateSettings(newSettings)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public static func getFlag(featureKey: String, context: VWOUserContext, completion: @escaping (GetFlag) -> Void) {
        ProductConfig.use(.vwo)
        WingifyFme.getFlag(featureKey: featureKey, context: context, completion: completion)
    }

    /**
     * Evaluates multiple feature flags and returns a `FlagCollection`.
     *
     * Pass `nil` or an empty array for `flagNames` to evaluate all feature keys from settings.
     * By default only MAU tracking is sent (no variation-shown impressions).
     * Pass `shouldSendUserTrackCalls: false` for fully offline evaluation, or
     * `shouldSendTrackingCalls: true` to also send impressions.
     *
     * - Parameters:
     *   - flagNames: Feature keys to evaluate, or `nil`/empty to evaluate all flags from settings.
     *   - context: User context used for evaluation.
     *   - shouldSendTrackingCalls: When `true`, sends variation-shown impressions. Defaults to `false`.
     *   - shouldSendUserTrackCalls: When `true`, sends MAU / user-tracking events. Defaults to `true`.
     *   - completion: Called with the resulting `FlagCollection`.
     */
    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyFme.getFlags instead.")
    public static func getFlags(
        flagNames: [String]?,
        context: VWOUserContext,
        shouldSendTrackingCalls: Bool = true,
        shouldSendUserTrackCalls: Bool = true,
        completion: @escaping (FlagCollection) -> Void
    ) {
        ProductConfig.use(.vwo)
        WingifyFme.getFlags(
            flagNames: flagNames,
            context: context,
            shouldSendTrackingCalls: shouldSendTrackingCalls,
            shouldSendUserTrackCalls: shouldSendUserTrackCalls,
            completion: completion
        )
    }

    /**
     * Fetches multiple feature flags without variation-shown impressions.
     * Always sends MAU / user-tracking events only. Call `exposeResult` later to send impressions.
     *
     * Pass `nil` or an empty array for `flagNames` to evaluate all feature keys from settings.
     *
     * - Parameters:
     *   - flagNames: Feature keys to evaluate, or `nil`/empty to evaluate all flags from settings.
     *   - context: User context used for evaluation.
     *   - completion: Called with the resulting `FlagCollection`.
     */
    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyFme.fetchFlags instead.")
    public static func fetchFlags(
        flagNames: [String]?,
        context: VWOUserContext,
        completion: @escaping (FlagCollection) -> Void
    ) {
        ProductConfig.use(.vwo)
        WingifyFme.fetchFlags(
            flagNames: flagNames,
            context: context,
            completion: completion
        )
    }

    /**
     * Sends a deferred `vwo_variationShown` impression for a feature previously evaluated
     * via `fetchFlags` / `getFlags(shouldSendTrackingCalls: false)`.
     * Idempotent: no-ops when the impression has already been sent.
     *
     * - Parameters:
     *   - featureKey: Feature key whose deferred impression should be sent.
     *   - context: User context that matches the earlier `fetchFlags` / `getFlags` call.
     * - Returns: `true` when an impression was sent; `false` when there was nothing to send
     *   or it had already been sent.
     */
    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyFme.exposeResult instead.")
    @discardableResult
    public static func exposeResult(featureKey: String, context: VWOUserContext) -> Bool {
        ProductConfig.use(.vwo)
        return WingifyFme.exposeResult(featureKey: featureKey, context: context)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public static func trackEvent(eventName: String, context: VWOUserContext, eventProperties: [String: Any]? = nil) {
        ProductConfig.use(.vwo)
        WingifyFme.trackEvent(eventName: eventName, context: context, eventProperties: eventProperties)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public static func setAttribute(attributes: [String: Any], context: VWOUserContext) {
        ProductConfig.use(.vwo)
        WingifyFme.setAttribute(attributes: attributes, context: context)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public static func setAlias(from userContext: VWOUserContext, to alias: String) {
        ProductConfig.use(.vwo)
        WingifyFme.setAlias(from: userContext, to: alias)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public static func performEventSync() {
        ProductConfig.use(.vwo)
        WingifyFme.performEventSync()
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public func updateSettings(_ newSettings: Settings) {
        ProductConfig.use(.vwo)
        baseInstance.updateSettings(newSettings)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public func getFlag(featureKey: String, context: VWOUserContext, completion: @escaping (GetFlag) -> Void) {
        ProductConfig.use(.vwo)
        baseInstance.getFlag(featureKey: featureKey, context: context, completion: completion)
    }

    /**
     * Evaluates multiple feature flags and returns a `FlagCollection`.
     *
     * Pass `nil` or an empty array for `flagNames` to evaluate all feature keys from settings.
     * By default only MAU tracking is sent (no variation-shown impressions).
     * Pass `shouldSendUserTrackCalls: false` for fully offline evaluation, or
     * `shouldSendTrackingCalls: true` to also send impressions.
     *
     * - Parameters:
     *   - flagNames: Feature keys to evaluate, or `nil`/empty to evaluate all flags from settings.
     *   - context: User context used for evaluation.
     *   - shouldSendTrackingCalls: When `true`, sends variation-shown impressions. Defaults to `false`.
     *   - shouldSendUserTrackCalls: When `true`, sends MAU / user-tracking events. Defaults to `true`.
     *   - completion: Called with the resulting `FlagCollection`.
     */
    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyFme.getFlags instead.")
    public func getFlags(
        flagNames: [String]?,
        context: VWOUserContext,
        shouldSendTrackingCalls: Bool = true,
        shouldSendUserTrackCalls: Bool = true,
        completion: @escaping (FlagCollection) -> Void
    ) {
        ProductConfig.use(.vwo)
        baseInstance.getFlags(
            flagNames: flagNames,
            context: context,
            shouldSendTrackingCalls: shouldSendTrackingCalls,
            shouldSendUserTrackCalls: shouldSendUserTrackCalls,
            completion: completion
        )
    }

    /**
     * Fetches multiple feature flags without variation-shown impressions.
     * Always sends MAU / user-tracking events only. Call `exposeResult` later to send impressions.
     *
     * Pass `nil` or an empty array for `flagNames` to evaluate all feature keys from settings.
     *
     * - Parameters:
     *   - flagNames: Feature keys to evaluate, or `nil`/empty to evaluate all flags from settings.
     *   - context: User context used for evaluation.
     *   - completion: Called with the resulting `FlagCollection`.
     */
    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyFme.fetchFlags instead.")
    public func fetchFlags(
        flagNames: [String]?,
        context: VWOUserContext,
        completion: @escaping (FlagCollection) -> Void
    ) {
        ProductConfig.use(.vwo)
        baseInstance.fetchFlags(
            flagNames: flagNames,
            context: context,
            completion: completion
        )
    }

    /**
     * Sends a deferred `vwo_variationShown` impression for a feature previously evaluated
     * via `fetchFlags` / `getFlags(shouldSendTrackingCalls: false)`.
     * Idempotent: no-ops when the impression has already been sent.
     *
     * - Parameters:
     *   - featureKey: Feature key whose deferred impression should be sent.
     *   - context: User context that matches the earlier `fetchFlags` / `getFlags` call.
     * - Returns: `true` when an impression was sent; `false` when there was nothing to send
     *   or it had already been sent.
     */
    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyFme.exposeResult instead.")
    @discardableResult
    public func exposeResult(featureKey: String, context: VWOUserContext) -> Bool {
        ProductConfig.use(.vwo)
        return baseInstance.exposeResult(featureKey: featureKey, context: context)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public func trackEvent(eventName: String, context: VWOUserContext, eventProperties: [String: Any]? = nil) {
        ProductConfig.use(.vwo)
        baseInstance.trackEvent(eventName: eventName, context: context, eventProperties: eventProperties)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public func setAttribute(attributes: [String: Any], context: VWOUserContext) {
        ProductConfig.use(.vwo)
        baseInstance.setAttribute(attributes: attributes, context: context)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public func setAlias(from userContext: VWOUserContext, to alias: String) {
        ProductConfig.use(.vwo)
        baseInstance.setAlias(from: userContext, to: alias)
    }

    @available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
    public func sendSdkInitEvent(sdkInitTime: Int64) {
        ProductConfig.use(.vwo)
        baseInstance.sendSdkInitEvent(sdkInitTime: sdkInitTime)
    }
}
