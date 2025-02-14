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
protocol IVwoInitCallback {
    func vwoInitSuccess(_ vwo: VWOFme, message: String)
    func vwoInitFailed(_ message: String)
}

public class VWOFme {
    private static var vwoClient: VWOClient? = nil
    private static let shared = VWOFme()
    public static var isInitialized: Bool = false

    private init() {}
    
    // Initializes the VWO instance
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
            
            let vwoBuilder = options.vwoBuilder ?? VWOBuilder(options: options)
            vwoBuilder.setLogger()
                .setSettingsManager()
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
                DispatchQueue.main.async {
                    completion(.success(VWOInitSuccess.initializationSuccess.rawValue))
                }
            }
        }
    }
    
    // Updates the settings
    static func updateSettings(_ newSettings: Settings) {
        VWOFme.vwoClient?.updateSettings(newSettings: newSettings)
    }
    
    // Gets the flag value for the given feature key
    public static func getFlag(featureKey: String, context: VWOContext, completion: @escaping (GetFlag) -> Void) {
        VWOFme.vwoClient?.getFlag(featureKey: featureKey, context: context, completion: completion)
    }
    
    // Tracks an event with properties
    public static func trackEvent(eventName: String, context: VWOContext, eventProperties: [String: Any]? = nil) {
        VWOFme.vwoClient?.trackEvent(eventName: eventName, context: context, eventProperties: eventProperties ?? [:])
    }
    
    // Sets attributes for a user in the context provided
    public static func setAttribute(attributes: [String: Any], context: VWOContext) {
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
}
