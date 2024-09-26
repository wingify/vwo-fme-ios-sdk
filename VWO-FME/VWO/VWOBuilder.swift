/**
 * Copyright 2024 Wingify Software Pvt. Ltd.
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

class VWOBuilder {
    private var vwoClient: VWOClient?
    private var options: VWOInitOptions?
    private var settingFileManager: SettingsManager?

    init(options: VWOInitOptions?) {
        self.options = options
    }

    // Set VWOClient instance
    func setVWOClient(_ vwoClient: VWOClient?) {
        self.vwoClient = vwoClient
    }

    /**
     * Sets the network manager with the provided client and development mode options.
     * @return The VWOBuilder instance.
     */
    func setNetworkManager() -> VWOBuilder {
        if let options = self.options, let networkClientInterface = options.networkClientInterface {
            NetworkManager.attachClient(client: networkClientInterface)
        } else {
            NetworkManager.attachClient()
        }
        NetworkManager.config?.developmentMode = false
        LoggerService.log(level: .debug, key: "SERVICE_INITIALIZED", details: ["service": "Network Layer"])
        return self
    }

    /**
     * Sets the segmentation evaluator with the provided segmentation options.
     * @return The instance of this builder.
     */
    func setSegmentation() -> VWOBuilder {
        if let segmentEvaluator = options?.segmentEvaluator {
            SegmentationManager.attachEvaluator(segmentEvaluator: segmentEvaluator)
        }
        LoggerService.log(level: .debug, key: "SERVICE_INITIALIZED", details: ["service": "Segmentation Evaluator"])
        return self
    }

    /**
     * Fetches settings asynchronously, ensuring no parallel fetches.
     * @param forceFetch - Force fetch ignoring cache.
     * @return The fetched settings.
     */
    private func fetchSettings(forceFetch: Bool, completion: @escaping (Settings?) -> Void) {
        guard let settingMangager = settingFileManager else { return }
        settingMangager.getSettings(forceFetch: forceFetch, completion: completion)
    }

    /**
     * Gets the settings, fetching them if not cached or if forced.
     * @param forceFetch - Force fetch ignoring cache.
     * @return The fetched settings.
     */
    func getSettings(forceFetch: Bool, completion: @escaping (Settings?) -> Void) {
        fetchSettings(forceFetch: forceFetch, completion: completion)
    }

    /**
     * Sets the storage connector for the VWO instance.
     * @return  The instance of this builder.
     */
    func setStorage() -> VWOBuilder {
        if let storage = options?.storage {
//            StorageOps.attachConnector(storage)
        }
        return self
    }

    /**
     * Sets the settings manager for the VWO instance.
     * @return The instance of this builder.
     */
    func setSettingsManager() -> VWOBuilder {
        if options == nil {
            return self
        }
        settingFileManager = SettingsManager(options: options!)
        return self
    }

    /**
     * Sets the logger for the VWO instance.
     * @return The instance of this builder.
     */
    func setLogger() -> VWOBuilder {
        
        if let options = options, !options.logger.isEmpty {
            _ = LoggerService(config: options.logger, logLevel: options.logLevel)
        } else {
            _ = LoggerService(config: [:], logLevel: .error)
        }
        LoggerService.log(level: .debug, key: "SERVICE_INITIALIZED", details: ["service": "Logger"])
        return self
    }

    /**
     * Initializes the polling with the provided poll interval.
     * @return The instance of this builder.
     */
    func initPolling() -> VWOBuilder {
        guard let pollInterval = options?.pollInterval else {
            return self
        }

        if !DataTypeUtil.isInteger(pollInterval) {
            LoggerService.log(level: .error, key: "INIT_OPTIONS_INVALID", details: ["key": "pollInterval", "correctType": "number"])
            return self
        }

        if pollInterval < 1000 {
            LoggerService.log(level: .error, key: "INIT_OPTIONS_INVALID", details: ["key": "pollInterval", "correctType": "number"])
            return self
        }

        DispatchQueue.global().async {
            self.checkAndPoll()
        }
        return self
    }

    /**
     * Checks and polls for settings updates at the provided interval.
     */
    private func checkAndPoll() {
        let pollingInterval = options?.pollInterval ?? 1000
        
        while true {
            do {
                guard let settingMangager = settingFileManager else { return }
                settingMangager.getSettings(forceFetch: true) { setting in
                    if let objSetting = setting {
                        // update setting here
                    } else {
                        LoggerService.log(level: .error, key: "POLLING_FETCH_SETTINGS_FAILED", details: nil)
                    }
                }
            }
        }
    }
}
