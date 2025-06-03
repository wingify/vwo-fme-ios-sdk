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

/**
 * Validates the structure and content of VWO settings.
 *
 * This class provides a method to verify if the provided settings object conforms to the expected schema.
 * It checks for the presence and validity of required fields and nested objects within the settings.
 */
class SettingsSchema {
    
    /**
     * Checks if the provided settings object is valid.
     *
     * - Parameter settings: The settings object to validate.
     * - Returns: `true` if the settings are valid, `false` otherwise.
     */
    func isSettingsValid(_ settings: Settings?) -> Bool {
        guard let settings = settings else {
            return false
        }
        
        // Validate SettingsModel fields
        guard settings.version != nil, settings.accountId != nil else {
            return false
        }
        
        guard let campaigns = settings.campaigns else {
            return false
        }
        
        for campaign in campaigns {
            if !isValidCampaign(campaign) {
                return false
            }
        }
        
        for feature in settings.features {
            if !isValidFeature(feature) {
                return false
            }
        }
        
        return true
    }
    
    /**
     * Checks if a campaign object is valid.
     *
     * - Parameter campaign: The campaign object to validate.
     * - Returns: `true` if the campaign is valid, `false` otherwise.
     */
    private func isValidCampaign(_ campaign: Campaign) -> Bool {
        guard campaign.id != nil,
              campaign.type != nil,
              campaign.key != nil,
              campaign.status != nil,
              campaign.name != nil else {
            return false
        }
        
        guard let variations = campaign.variations, !variations.isEmpty else {
            return false
        }
        
        for variation in variations {
            if !isValidCampaignVariation(variation) {
                return false
            }
        }
        
        return true
    }
    
    /**
     * Checks if a campaign variation object is valid.
     *
     * - Parameter variation: The campaign variation object to validate.
     * - Returns: `true` if the variation is valid, `false` otherwise.
     */
    private func isValidCampaignVariation(_ variation: Variation) -> Bool {
        guard variation.id != nil, variation.name != nil else {
            return false
        }
        
        for variable in variation.variables {
            if !isValidVariableObject(variable) {
                return false
            }
        }
        
        return true
    }
    
    /**
     * Checks if a variable object is valid.
     *
     * - Parameter variable: The variable object to validate.
     * - Returns: `true` if the variable is valid, `false` otherwise.
     */
    private func isValidVariableObject(_ variable: Variable) -> Bool {
        return variable.id != nil && variable.type != nil && variable.key != nil && variable.value != nil
    }
    
    /**
     * Checks if a feature object is valid.
     *
     * - Parameter feature: The feature object to validate.
     * - Returns: `true` if the feature is valid, `false` otherwise.
     */
    private func isValidFeature(_ feature: Feature) -> Bool {
        guard feature.id != nil,
              feature.key != nil,
              feature.status != nil,
              feature.name != nil,
              feature.type != nil else {
            return false
        }
        
        guard let metrics = feature.metrics, !metrics.isEmpty else {
            return false
        }
        
        for metric in metrics {
            if !isValidCampaignMetric(metric) {
                return false
            }
        }
        
        if let rules = feature.rules {
            for rule in rules {
                if !isValidRule(rule) {
                    return false
                }
            }
        }
        
        if let variables = feature.variables {
            for variable in variables {
                if !isValidVariableObject(variable) {
                    return false
                }
            }
        }
        
        return true
    }
    
    /**
     * Checks if a campaign metric object is valid.
     *
     * - Parameter metric: The campaign metric object to validate.
     * - Returns: `true` if the metric is valid, `false` otherwise.
     */
    private func isValidCampaignMetric(_ metric: Metric) -> Bool {
        return metric.id != nil && metric.type != nil && metric.identifier != nil
    }
    
    /**
     * Checks if a rule object is valid.
     *
     * - Parameter rule: The rule object to validate.
     * - Returns: `true` if the rule is valid, `false` otherwise.
     */
    private func isValidRule(_ rule: Rule) -> Bool {
        return rule.type != nil && rule.ruleKey != nil && rule.campaignId != nil
    }
}
