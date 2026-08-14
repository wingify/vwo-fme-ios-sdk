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
 * Sampling category for error log keys used when sending `vwo_sdkDebug` events.
 *
 * - `alwaysSend`: The event is sent every time with no sampling applied.
 * - `sampled`: The event is subject to the debug sampling rate from DaCDN settings.
 */
enum ErrorLogSamplingCategory {
    /// Keys not listed for sampling; always reported to the server.
    case alwaysSend
    /// High-volume keys that may be dropped based on the configured sampling percentage.
    case sampled
}

/**
 * Manually maintained error log keys for `vwo_sdkDebug` sampling.
 *
 * Only `sampled` keys are listed explicitly (aligned with Node
 * `SAMPLED_DEBUG_ERROR_TEMPLATE_KEYS`). Any other key is treated as always-send.
 */
enum ErrorLogSamplingKeys {

    /**
     * Error keys subject to debug-event sampling before being sent to the server.
     *
     * Targets high-volume runtime errors (API failures, network retries, settings fetch).
     * Init/validation errors are intentionally excluded and always send.
     */
    static let sampled: Set<String> = [
        "ATTEMPTING_RETRY_FOR_FAILED_NETWORK_CALL",
        "ERROR_FETCHING_SETTINGS",
        "ERROR_FETCHING_SETTINGS_WITH_POLLING",
        "EXECUTION_FAILED",
        "IMPRESSION_BATCH_FAILED",
        "NETWORK_CALL_FAILED",
        "NETWORK_CALL_FAILURE_AFTER_MAX_RETRIES"
    ]

    /**
     * Resolves the sampling category for a given error log key.
     *
     * Keys in `sampled` return `.sampled`; all other non-nil keys return `.alwaysSend`.
     *
     * - Parameter key: The error message key (e.g. the `msg_t` field on debug events).
     * - Returns: `.alwaysSend`, `.sampled`, or `nil` when the key is missing.
     */
    static func category(for key: String?) -> ErrorLogSamplingCategory? {
        guard let key = key else { return nil }
        return sampled.contains(key) ? .sampled : .alwaysSend
    }

    /**
     * Returns whether the given error key is subject to debug-event sampling.
     *
     * A key is sampled only when it is listed in `sampled`.
     *
     * - Parameter key: The error message key from the debug event payload.
     * - Returns: `true` when the key is in `sampled`; `false` for always-send keys or a missing key.
     */
    static func isSampled(forKey key: String?) -> Bool {
        guard let key = key else { return false }
        return sampled.contains(key)
    }
}
