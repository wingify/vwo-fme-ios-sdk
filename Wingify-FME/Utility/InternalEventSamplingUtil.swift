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
 * Shared helpers for sampling internal SDK events based on DaCDN settings.
 *
 * Used by `vwo_sdkUsageStats` and sampled `vwo_sdkDebug` error events to decide
 * whether an event should be sent to the server.
 */
enum InternalEventSamplingUtil {

    /// Default sampling rate (1%) applied when DaCDN does not provide a value.
    private static let defaultSamplingRate: Double = 1

    /**
     * Returns whether an event qualifies to be sent for the given sampling percentage.
     *
     * Generates a random integer between 0 and 100 (inclusive). The event qualifies when
     * the random value is less than or equal to the configured sampling rate.
     * For example, at 20% sampling, values 0–20 qualify and 21–100 do not.
     *
     * - Parameters:
     *   - samplingPercentage: The sampling rate from DaCDN settings (0–100).
     *   - randomValue: Optional fixed value for testing. When `nil`, a random value is generated.
     * - Returns: `true` if the event should be sent; `false` otherwise.
     */
    static func doesQualifyForSampling(samplingPercentage: Double, randomValue: Int? = nil) -> Bool {
        let clampedRate = min(max(samplingPercentage, 0), Double(Constants.MAX_TRAFFIC_PERCENT))
        if clampedRate >= Double(Constants.MAX_TRAFFIC_PERCENT) {
            return true
        }
        if clampedRate <= 0 {
            return false
        }

        let value = randomValue ?? Int.random(in: 0...Constants.MAX_TRAFFIC_PERCENT)
        return value <= Int(clampedRate)
    }

    /**
     * Returns the client usage-stats sampling rate from DaCDN settings.
     *
     * Reads `sampling.usage.client` for the iOS SDK.
     *
     * - Parameter settings: The processed account settings, if available.
     * - Returns: The sampling percentage (0–100). Defaults to `1` when not provided.
     */
    static func usageStatsSamplingRate(from settings: Settings?) -> Double {
        settings?.sampling?.usage?.client ?? defaultSamplingRate
    }

    /**
     * Returns whether sampling should be applied for the iOS (client) SDK.
     *
     * Reads `alwaysApplySampling.client` from DaCDN settings.
     * When false or missing, events are always sent without sampling.
     *
     * - Parameter settings: The processed account settings, if available.
     * - Returns: `true` when sampling must be applied; `false` to always send.
     */
    static func shouldAlwaysApplySampling(settings: Settings?) -> Bool {
        settings?.alwaysApplySampling?.client ?? false
    }

    /**
     * Returns whether `vwo_sdkUsageStats` qualifies to be sent based on configured sampling.
     *
     * When `alwaysApplySampling.client` is false or missing, the event is always sent.
     * When true, the event is subject to `sampling.usage.client`.
     *
     * - Parameters:
     *   - settings: The processed account settings used to read the sampling rate.
     *   - randomValue: Optional fixed value for testing. When `nil`, a random value is generated.
     * - Returns: `true` if the usage-stats event qualifies to be sent; `false` otherwise.
     */
    static func isUsageStatsEventQualified(settings: Settings?, randomValue: Int? = nil) -> Bool {
        if !shouldAlwaysApplySampling(settings: settings) {
            return true
        }
        return doesQualifyForSampling(
            samplingPercentage: usageStatsSamplingRate(from: settings),
            randomValue: randomValue
        )
    }

    /**
     * Returns the client debug-event sampling rate from DaCDN settings.
     *
     * Reads `sampling.debug.client` for the iOS SDK.
     *
     * - Parameter settings: The processed account settings, if available.
     * - Returns: The sampling percentage (0–100). Defaults to `1` when not provided.
     */
    static func debugSamplingRate(from settings: Settings?) -> Double {
        settings?.sampling?.debug?.client ?? defaultSamplingRate
    }

    /**
     * Returns whether a sampled `vwo_sdkDebug` event qualifies to be sent.
     *
     * Only called for debug events whose `msg_t` is in `ErrorLogSamplingKeys.sampled`.
     * When `alwaysApplySampling.client` is false or missing, the event is always sent.
     * When true, the event is subject to `sampling.debug.client`.
     *
     * - Parameters:
     *   - settings: The account settings used to read the debug sampling rate.
     *   - randomValue: Optional fixed value for testing. When `nil`, a random value is generated.
     * - Returns: `true` if the debug event qualifies to be sent; `false` otherwise.
     */
    static func isSampledDebugEventQualified(settings: Settings?, randomValue: Int? = nil) -> Bool {
        if !shouldAlwaysApplySampling(settings: settings) {
            return true
        }
        return doesQualifyForSampling(
            samplingPercentage: debugSamplingRate(from: settings),
            randomValue: randomValue
        )
    }
}
