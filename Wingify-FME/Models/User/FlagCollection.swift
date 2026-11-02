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
 * Immutable collection of evaluated feature flags keyed by feature key.
 */
@objc public class FlagCollection: NSObject {
    private let flags: [String: GetFlag]
    private let fallbackContext: WingifyUserContext

    private init(flags: [String: GetFlag], fallbackContext: WingifyUserContext) {
        self.flags = flags
        self.fallbackContext = fallbackContext
        super.init()
    }

    /**
     * Returns the evaluated flag for `featureKey`, or a disabled flag when the key is absent.
     */
    @objc public func get(_ featureKey: String) -> GetFlag {
        if let flag = flags[featureKey] {
            return flag
        }
        let disabled = GetFlag()
        disabled.setIsEnabled(isEnabled: false)
        return disabled
    }

    /**
     * The set of feature keys present in this collection.
     */
    @objc public func keys() -> Set<String> {
        Set(flags.keys)
    }

    /**
     * The number of evaluated flags in this collection.
     */
    @objc public func size() -> Int {
        flags.count
    }

    /**
     * Iterates over feature-key to `GetFlag` entries.
     */
    @objc public func forEach(_ body: (String, GetFlag) -> Void) {
        for (key, flag) in flags {
            body(key, flag)
        }
    }

    /**
     * Builds a collection from already-evaluated flags.
     */
    static func create(flags: [String: GetFlag], fallbackContext: WingifyUserContext) -> FlagCollection {
        FlagCollection(flags: flags, fallbackContext: fallbackContext)
    }

    /**
     * Builds a collection with an explicitly disabled flag for each requested key.
     * Used on validation/execution failure.
     */
    static func createDisabled(flagNames: [String]?, fallbackContext: WingifyUserContext) -> FlagCollection {
        let keys = flagNames?
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .reduce(into: [String]()) { result, key in
                if !result.contains(key) {
                    result.append(key)
                }
            } ?? []

        if keys.isEmpty {
            return create(flags: [:], fallbackContext: fallbackContext)
        }

        var disabledFlags: [String: GetFlag] = [:]
        for key in keys {
            let flag = GetFlag()
            flag.setIsEnabled(isEnabled: false)
            disabledFlags[key] = flag
        }
        return create(flags: disabledFlags, fallbackContext: fallbackContext)
    }
}
