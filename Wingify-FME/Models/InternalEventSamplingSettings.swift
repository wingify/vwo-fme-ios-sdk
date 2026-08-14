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
 * Platform-specific sampling rates received from DaCDN settings.
 *
 * Each platform (`server`, `client`, `serverless`) has its own sampling percentage (0–100).
 * The iOS SDK reads the `client` value.
 */
struct PlatformSamplingRates: Codable, Equatable {
    /// Sampling rate for server-side SDKs.
    var server: Double?
    /// Sampling rate for client/mobile SDKs (used by iOS).
    var client: Double?
    /// Sampling rate for serverless SDKs.
    var serverless: Double?
}

/**
 * Sampling rates grouped by internal event category.
 *
 * Maps to the `sampling` object in DaCDN settings:
 * `{ usage: { server, client, serverless }, debug: { server, client, serverless } }`
 */
struct EventCategorySamplingRates: Codable, Equatable {
    /// Sampling rates for `vwo_sdkUsageStats`.
    var usage: PlatformSamplingRates?
    /// Sampling rates for sampled `vwo_sdkDebug` error events.
    var debug: PlatformSamplingRates?
}

/**
 * Flags indicating whether sampling should always be applied per platform.
 *
 * Maps to the `alwaysApplySampling` object in DaCDN settings.
 * The iOS SDK reads `client`. When true, configured sampling rates are applied;
 * when false or missing, events are always sent without sampling.
 */
struct AlwaysApplySampling: Codable, Equatable {
    /// Whether sampling is always applied for server-side SDKs.
    var server: Bool?
    /// Whether sampling is always applied for client/mobile SDKs.
    var client: Bool?
    /// Whether sampling is always applied for serverless SDKs.
    var serverless: Bool?
}
