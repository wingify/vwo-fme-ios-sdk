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
                         isAliasingEnabled: Bool? = false) {
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
                   isAliasingEnabled: isAliasingEnabled)
    }
}

@available(*, deprecated, message: "VWO-branded API is deprecated. Use WingifyInitOptions instead.")
@objc public class VWOUserContext : WingifyUserContext{
    public override init(id: String? = nil,
                         shouldUseDeviceIdAsUserId: Bool = false,
                         customVariables: [String: Any],
                         postSegmentationVariables: [String]? = nil,
                         ipAddress: String? = nil) {
        ProductConfig.use(.vwo)
        super.init(id: id,
                   shouldUseDeviceIdAsUserId: shouldUseDeviceIdAsUserId,
                   customVariables: customVariables,
                   postSegmentationVariables: postSegmentationVariables,
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
