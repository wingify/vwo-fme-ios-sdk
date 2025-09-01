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

// Define a protocol for the initialization callback
@objc protocol IVwoInitCallback {
    func vwoInitSuccess(_ vwo: VWOFme, message: String)
    func vwoInitFailed(_ message: String)
}

@objc public class VWOFme: NSObject {
    private static var vwoClient: VWOClient? = nil
    private static let shared = VWOFme()
    @objc public static var isInitialized: Bool = false

    private override init() {}
    
    // Initializes the VWO instance
    @available(macOS 10.14, *)
    public static func initialize(options: VWOInitOptions, completion: @escaping VWOInitCompletionHandler) {
        DispatchQueue.global(qos: .background).async {
            guard let sdkKey = options.sdkKey, !sdkKey.isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(VWOInitError.missingSDKKey))
                }
                return
            }
            
            guard let _ = options.accountId else {
                DispatchQueue.main.async {
                    completion(.failure(VWOInitError.missingAccountId))
                }
                return
            }
            let sdkStartTime = Date().currentTimeMillis()
            
            let vwoBuilder = options.vwoBuilder ?? VWOBuilder(options: options)
            vwoBuilder.setLogger()
                .setSettingsManager()
                .setStorage()
                .setNetworkManager()
                .setNetworkMonitoring()
                .setSegmentation()
                .initPolling()
                .getSettings(forceFetch: false) { result in
                    
                    guard let settingObj = result else {
                        DispatchQueue.main.async {
                            completion(.failure(VWOInitError.initializationFailed))
                        }
                        return
                    }
                    
                    self.vwoClient = VWOClient(options: options, settingObj: settingObj)
                    self.vwoClient?.isSettingsValid = vwoBuilder.isSettingsValid
                    self.vwoClient?.settingsFetchTime = vwoBuilder.settingsFetchTime
                    vwoBuilder.setVWOClient(self.vwoClient!)
                    
                    guard self.vwoClient != nil else {
                        DispatchQueue.main.async {
                            completion(.failure(VWOInitError.initializationFailed))
                        }
                        return
                    }
                    vwoBuilder.setVWOClient(self.vwoClient!)
                    vwoBuilder.initSyncManager()
                    self.isInitialized = true
                    
                    let sdkEndTime = Date().currentTimeMillis()
                    let sdkInitTime = sdkEndTime - sdkStartTime
                    
                    if options.sdkName == Constants.SDK_NAME {  // Don't call sendSdkInitEvent for hybrid SDKs
                        sendSdkInitEvent(sdkInitTime: sdkInitTime)
                    }
                    sendUsageStats()
                    DispatchQueue.main.async {
                        completion(.success(VWOInitSuccess.initializationSuccess.rawValue))
                    }
                }
        }
    }
    
    
    /**
     * Sends an SDK initialization event.
     *
     * This function checks if the VWO instance is valid, if its settings have been processed,
     * and critically, if the SDK has not been marked as initialized previously in the current
     * session or from cached settings. If all conditions are true, it proceeds to send
     * an "SDK initialized" tracking event, including the time it took for settings to be fetched
     * and the time it took for the SDK to complete its initialization process.
     *
     * This helps in tracking the initial setup performance and ensuring that the
     * initialization event is sent only once per effective SDK start.
     *
     * @param sdkInitTime The timestamp (in milliseconds) marking the completion of the SDK's initialization process.
     */
    
     public static func sendSdkInitEvent(sdkInitTime: Int64) {
        let wasInitializedEarlier =  VWOFme.vwoClient?.processedSettings?.sdkMetaInfo?.wasInitializedEarlier
        
        if (VWOFme.vwoClient?.isSettingsValid == true && (wasInitializedEarlier == false || wasInitializedEarlier == nil)) {
            EventsUtils().sendSdkInitEvent(settingsFetchTime: VWOFme.vwoClient?.settingsFetchTime, sdkInitTime: sdkInitTime)
        }
    }
    
    // Updates the settings
   public static func updateSettings(_ newSettings: Settings) {
        VWOFme.vwoClient?.updateSettings(newSettings: newSettings)
    }
    
    // Gets the flag value for the given feature key
    public static func getFlag(featureKey: String, context: VWOUserContext, completion: @escaping (GetFlag) -> Void) {
        VWOFme.vwoClient?.getFlag(featureKey: featureKey, context: context, completion: completion)
    }
    
    // Tracks an event with properties
    public static func trackEvent(eventName: String, context: VWOUserContext, eventProperties: [String: Any]? = nil) {
        VWOFme.vwoClient?.trackEvent(eventName: eventName, context: context, eventProperties: eventProperties ?? [:])
    }
    
    // Sets attributes for a user in the context provided
    public static func setAttribute(attributes: [String: Any], context: VWOUserContext) {
        VWOFme.vwoClient?.setAttribute(attributes: attributes, context: context)
    }
    
    /**
     * Manually triggers the synchronization of saved events.
     * This function can be used to ensure that all pending events are sent to the server.
     * It is particularly useful in scenarios where the app supports background modes,
     * allowing events to be synced even when the app is not in the foreground.
     * This is an optional feature for users who have enabled background tasks at the app level.
     */
    public static func performEventSync() {
        SyncManager.shared.syncSavedEvents(manually: true, ignoreThreshold: true)
    }
    
    /** Sends SDK usage statistics.
     *
     * This function retrieves the usage statistics account ID from settings.
     * If the account ID is found, it triggers an event to send SDK usage statistics.
     * This helps in understanding how the SDK is being utilized.
     * If the `usageStatsAccountId` is not available in the settings, the function will return early
     * and no event will be sent.
     */
    private static func sendUsageStats() {
        // Get usage stats account id from settings
        guard let usageStatsAccountId = VWOFme.vwoClient?.processedSettings?.usageStatsAccountId else {
            return
        }
        
        EventsUtils().sendSDKUsageStatsEvent(usageStatsAccountId: usageStatsAccountId)
    }
    
}
