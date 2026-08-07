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

// Define a protocol for the initialization callback
@objc protocol IWingifyInitCallback {
    func wingifyInitSuccess(_ wingify: WingifyFme, message: String)
    func wingifyInitFailed(_ message: String)
}

/**
 * Represents the initialization state of the Wingify SDK for a specific account.
 * These states ensure proper initialization flow and prevent race conditions.
 */
enum SDKState {
    case notInitialized
    case initializing
    case initialized
}

@objc public class WingifyFme: NSObject {
    
    /**
     * Tracks the current initialization state of the Wingify SDK per account.
     *
     * This dictionary ensures thread-safe access across multiple threads and prevents
     * concurrent initialization attempts for each account. The state transitions through:
     * - notInitialized: SDK hasn't been initialized or initialization failed
     * - initializing: SDK initialization is currently in progress
     * - initialized: SDK has been successfully initialized and is ready for use
     *
     * Key format: "accountId_sdkKey"
     */
    private static var accountStates: [String: SDKState] = [:]
    private static let stateQueue = DispatchQueue(label: "com.wingify.fme.accountStates")
    
    /**
     * Cache of Wingify instances per account to avoid re-initialization.
     * Key format: "accountId_sdkKey"
     */
    private static var wingifyInstances: [String: WingifyFme] = [:]
    private static let instancesQueue = DispatchQueue(label: "com.wingify.fme.instances")
    /// Account key used by static APIs (`getFlag`, `trackEvent`, etc.).
    /// Pinned to the first account that begins initialization so a later multi-account
    /// init cannot steal the default when its settings fetch finishes first.
    private static var defaultAccountKey: String?
    
    // Private instance variable for WingifyClient
    private var wingifyClient: WingifyClient?
    
    private init(wingifyClient: WingifyClient) {
        self.wingifyClient = wingifyClient
        super.init()
    }
    
    /**
     * Generates a unique key for an account based on accountId and sdkKey.
     * @param options VWO initialization options
     * @return Account key in format "accountId_sdkKey"
     */
    private static func getAccountKey(options: WingifyInitOptions) -> String {
        let accountId = options.accountId ?? 0
        let sdkKey = options.sdkKey ?? ""
        return "\(accountId)_\(sdkKey)"
    }
    
    /**
     * Gets the current state for a specific account.
     * @param accountKey The account key
     * @return Current SDKState for the account
     */
    private static func getAccountState(accountKey: String) -> SDKState {
        return stateQueue.sync {
            return accountStates[accountKey] ?? .notInitialized
        }
    }
    
    /**
     * Sets the state for a specific account.
     * @param accountKey The account key
     * @param state The new state
     */
    private static func setAccountState(accountKey: String, state: SDKState) {
        stateQueue.sync {
            accountStates[accountKey] = state
        }
    }
    
    /**
     * Pins the default account for static APIs to the first account that starts init.
     */
    private static func pinDefaultAccountKeyIfNeeded(_ accountKey: String) {
        instancesQueue.sync {
            if defaultAccountKey == nil {
                defaultAccountKey = accountKey
            }
        }
    }
    
    /**
     * Gets an existing Wingify instance for an account if available.
     * @param accountKey The account key
     * @return Existing Wingify instance or nil
     */
    private static func getExistingInstance(accountKey: String) -> WingifyFme? {
        return instancesQueue.sync {
            return wingifyInstances[accountKey]
        }
    }
    
    /**
     * Caches a VWO instance for an account.
     * Uses sync so the instance is available before init completion returns.
     * @param accountKey The account key
     * @param instance The VWO instance to cache
     */
    private static func cacheInstance(accountKey: String, instance: WingifyFme) {
        instancesQueue.sync {
            wingifyInstances[accountKey] = instance
            if defaultAccountKey == nil {
                defaultAccountKey = accountKey
            }
        }
    }
    
    // Initializes the VWO instance
    @available(macOS 10.14, *)
    public static func initialize(options: WingifyInitOptions, completion: @escaping WingifyInitCompletionHandler) {
        let accountKey = getAccountKey(options: options)
        let currentState = getAccountState(accountKey: accountKey)
        
        // Check if this specific account is already initializing
        if currentState == .initializing {
            LoggerService.log(level: .info, message: "Account \(accountKey) is already initializing")
            DispatchQueue.main.async {
                completion(.success(WingifyInitSuccess.initializationInProgress.message))
            }
            return
        }
        
        // Check if this specific account is already initialized
        if currentState == .initialized {
            if let existingInstance = getExistingInstance(accountKey: accountKey) {
                LoggerService.log(level: .info, message: "Account \(accountKey) has already been initialized")
                DispatchQueue.main.async {
                    completion(.success(WingifyInitSuccess.allreadyInitialized.message))
                }
                return
            } else {
                // Instance was somehow lost, reset state and continue with initialization
                setAccountState(accountKey: accountKey, state: .notInitialized)
            }
        }
        
        // Set state to initializing
        setAccountState(accountKey: accountKey, state: .initializing)
        // Keep static APIs on the first account the app started initializing
        pinDefaultAccountKeyIfNeeded(accountKey)
        
        DispatchQueue.global(qos: .background).async {
            guard let sdkKey = options.sdkKey, !sdkKey.isEmpty else {
                setAccountState(accountKey: accountKey, state: .notInitialized)
                DispatchQueue.main.async {
                    completion(.failure(WingifyInitError.missingSDKKey))
                }
                return
            }
            
            guard let _ = options.accountId else {
                setAccountState(accountKey: accountKey, state: .notInitialized)
                DispatchQueue.main.async {
                    completion(.failure(WingifyInitError.missingAccountId))
                }
                return
            }
            
            let sdkStartTime = Date().currentTimeMillis()
            
            let wingifyBuilder = options.wingifyBuilder ?? WingifyBuilder(options: options)
            wingifyBuilder.setLogger()
                .setSettingsManager()
                .setStorage()
                .setNetworkManager()
                .setNetworkMonitoring()
                .setSegmentation()
                .initPolling()
                .getSettings(forceFetch: false) { result in
                    
                    guard let settingObj = result else {
                        setAccountState(accountKey: accountKey, state: .notInitialized)
                        DispatchQueue.main.async {
                            completion(.failure(WingifyInitError.initializationFailed))
                        }
                        return
                    }
                    
                    let client = WingifyClient(options: options, settingObj: settingObj, wingifyBuilder: wingifyBuilder)
                    client.isSettingsValid = wingifyBuilder.isSettingsValid
                    client.settingsFetchTime = wingifyBuilder.settingsFetchTime
                    wingifyBuilder.setWingifyClient(client)
                    wingifyBuilder.initSyncManager()
                    
                    guard client != nil else {
                        setAccountState(accountKey: accountKey, state: .notInitialized)
                        DispatchQueue.main.async {
                            completion(.failure(WingifyInitError.initializationFailed))
                        }
                        return
                    }
                    
                    // Create VWOFme instance with the client
                    let vwoInstance = WingifyFme(wingifyClient: client)
                    
                    // Cache the instance and mark as initialized for this account
                    cacheInstance(accountKey: accountKey, instance: vwoInstance)
                    setAccountState(accountKey: accountKey, state: .initialized)
                    
                    let sdkEndTime = Date().currentTimeMillis()
                    let sdkInitTime = sdkEndTime - sdkStartTime
                    
                    // Create service container for events
                    let serviceContainer = client.createServiceContainer()
                    
                    if options.sdkName == Constants.SDK_NAME {  // Don't call sendSdkInitEvent for hybrid SDKs
                        sendSdkInitEvent(sdkInitTime: sdkInitTime, client: client, serviceContainer: serviceContainer)
                    }
                    sendUsageStats(client: client, serviceContainer: serviceContainer)
                    
                    DispatchQueue.main.async {
                        completion(.success(WingifyInitSuccess.initializationSuccess.message))
                    }
                }
        }
    }
    
    
    /**
     * Gets an existing Wingify instance for the specified account.
     * @param accountId The account ID
     * @param sdkKey The SDK key
     * @return Existing WingifyFme instance or nil if not initialized
     */
    public static func getInstance(accountId: Int?, sdkKey: String?) -> WingifyFme? {
        let accountKey = "\(accountId ?? 0)_\(sdkKey ?? "")"
        return getExistingInstance(accountKey: accountKey)
    }
    
    /**
     * Clears the cached instance for a specific account.
     * This will force re-initialization on next init() call.
     * @param accountId The account ID
     * @param sdkKey The SDK key
     */
   
    public static func clearInstance(accountId: Int?, sdkKey: String?) {
        let accountKey = "\(accountId ?? 0)_\(sdkKey ?? "")"
        instancesQueue.sync {
            wingifyInstances.removeValue(forKey: accountKey)
            if defaultAccountKey == accountKey {
                defaultAccountKey = wingifyInstances.keys.first
            }
        }
        setAccountState(accountKey: accountKey, state: .notInitialized)
        
        // Clean up AliasIdentifierManager and SyncManager for this account
        if let accountId = accountId, let sdkKey = sdkKey {
            AliasIdentifierManager.removeInstance(accountId: accountId, sdkKey: sdkKey)
            SyncManager.removeInstance(accountId: accountId, sdkKey: sdkKey)
        }
    }
    
    /**
     * Clears all cached instances and resets all account states.
     * This will force re-initialization for all accounts on next init() calls.
     */
    public static func clearAllInstances() {
        instancesQueue.sync {
            wingifyInstances.removeAll()
            defaultAccountKey = nil
        }
        stateQueue.sync {
            accountStates.removeAll()
        }
    }
    
    /**
     * Sends an SDK initialization event.
     *
     * This function checks if the Wingify instance is valid, if its settings have been processed,
     * and critically, if the SDK has not been marked as initialized previously in the current
     * session or from cached settings. If all conditions are true, it proceeds to send
     * an "SDK initialized" tracking event, including the time it took for settings to be fetched
     * and the time it took for the SDK to complete its initialization process.
     *
     * This helps in tracking the initial setup performance and ensuring that the
     * initialization event is sent only once per effective SDK start.
     *
     * @param sdkInitTime The timestamp (in milliseconds) marking the completion of the SDK's initialization process.
     * @param client The WingifyClient instance to use
     */
    
    private static func sendSdkInitEvent(sdkInitTime: Int64, client: WingifyClient, serviceContainer: ServiceContainer?) {
        let wasInitializedEarlier = client.processedSettings?.sdkMetaInfo?.wasInitializedEarlier
        if client.isSettingsValid && (wasInitializedEarlier == false || wasInitializedEarlier == nil) {
            EventsUtils().sendSdkInitEvent(settingsFetchTime: client.settingsFetchTime, sdkInitTime: sdkInitTime, serviceContainer: serviceContainer)
        }
    }
    
    /**
     * Sends SDK usage statistics.
     *
     * This function retrieves the usage statistics account ID from settings.
     * If the account ID is found, it triggers an event to send SDK usage statistics.
     * This helps in understanding how the SDK is being utilized.
     * If the `usageStatsAccountId` is not available in the settings, the function will return early
     * and no event will be sent.
     *
     * @param client The WingifyClient instance to use
     */
    private static func sendUsageStats(client: WingifyClient, serviceContainer: ServiceContainer?) {
        guard let usageStatsAccountId = client.processedSettings?.usageStatsAccountId else {
            return
        }
        EventsUtils().sendSDKUsageStatsEvent(usageStatsAccountId: usageStatsAccountId, serviceContainer: serviceContainer)
    }
    
    /**
     * Gets the default Wingify instance for static APIs.
     * Uses the first account that began initialization (see `defaultAccountKey`).
     * For multi-account apps, prefer `getInstance(accountId:sdkKey:)`.
     */
    private static func getDefaultInstance() -> WingifyFme? {
        return instancesQueue.sync {
            if let key = defaultAccountKey, let instance = wingifyInstances[key] {
                return instance
            }
            return wingifyInstances.values.first
        }
    }
    
    // MARK: - Static Methods (Backward Compatibility)
    
    // Updates the settings
    public static func updateSettings(_ newSettings: Settings) {
        getDefaultInstance()?.updateSettings(newSettings)
    }
    
    // Gets the flag value for the given feature key
    public static func getFlag(featureKey: String, context: WingifyUserContext, completion: @escaping (GetFlag) -> Void) {
        guard let instance = getDefaultInstance() else {
            let flag = GetFlag()
            flag.setIsEnabled(isEnabled: false)
            completion(flag)
            return
        }
        instance.getFlag(featureKey: featureKey, context: context, completion: completion)
    }
    
    // Tracks an event with properties
    public static func trackEvent(eventName: String, context: WingifyUserContext, eventProperties: [String: Any]? = nil) {
        getDefaultInstance()?.trackEvent(eventName: eventName, context: context, eventProperties: eventProperties ?? [:])
    }
    
    // Sets attributes for a user in the context provided
    public static func setAttribute(attributes: [String: Any], context: WingifyUserContext) {
        getDefaultInstance()?.setAttribute(attributes: attributes, context: context)
    }
    
    // Sets alias for a user
    public static func setAlias(from userContext: WingifyUserContext, to alias: String) {
        getDefaultInstance()?.setAlias(from: userContext, to: alias)
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
    
    // MARK: - Instance Methods
    
    // Updates the settings
    public func updateSettings(_ newSettings: Settings) {
        wingifyClient?.updateSettings(newSettings: newSettings)
    }
    
    // Gets the flag value for the given feature key
    public func getFlag(featureKey: String, context: WingifyUserContext, completion: @escaping (GetFlag) -> Void) {
        guard let client = wingifyClient else {
            let flag = GetFlag()
            flag.setIsEnabled(isEnabled: false)
            completion(flag)
            return
        }
        client.getFlag(featureKey: featureKey, context: context, completion: completion)
    }
    
    // Tracks an event with properties
    public func trackEvent(eventName: String, context: WingifyUserContext, eventProperties: [String: Any]? = nil) {
        wingifyClient?.trackEvent(eventName: eventName, context: context, eventProperties: eventProperties ?? [:])
    }
    
    // Sets attributes for a user in the context provided
    public func setAttribute(attributes: [String: Any], context: WingifyUserContext) {
        wingifyClient?.setAttribute(attributes: attributes, context: context)
    }
    
    // Sets alias for a user
    public func setAlias(from userContext: WingifyUserContext, to alias: String) {
        // Get ServiceContainer for this instance to ensure correct account context
        let serviceContainer = wingifyClient?.createServiceContainer()
        // Use instance-specific alias manager from ServiceContainer
        if let container = serviceContainer {
            container.getAliasIdentifierManager().setAlias(from: userContext, to: alias, serviceContainer: container)
        } else {
            // Fallback to shared for backward compatibility
            AliasIdentifierManager.shared.setAlias(from: userContext, to: alias, serviceContainer: nil)
        }
    }
    
    /**
         * Public helper for hybrid SDKs (e.g. Flutter) to send the SDK init event.
         *
         * Looks up the default instance, builds a service container and delegates to the
         * internal sendSdkInitEvent(sdkInitTime:client:serviceContainer:) helper.
         *
         * - Parameter sdkInitTime: The duration (in ms) it took to initialize the SDK.
         */
        public func sendSdkInitEvent(sdkInitTime: Int64) {
            guard let client = wingifyClient else { return }
            let serviceContainer = client.createServiceContainer()
            WingifyFme.sendSdkInitEvent(sdkInitTime: sdkInitTime, client: client, serviceContainer: serviceContainer)
        }
}
