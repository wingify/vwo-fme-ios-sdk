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
 * Utility class for processing settings.
 *
 * This class provides methods to process and modify settings, including handling campaigns and features.
 */
class SettingsUtil {
    
    /**
     * Processes the given settings by updating campaigns and adding necessary flags.
     *
     * - Parameter settings: The settings to be processed.
     */
    static func processSettings(_ settings: inout Settings) {
        guard var campaigns = settings.campaigns else { return }
        
        // Iterate over each campaign and set variation allocation
        for i in 0..<campaigns.count {
            CampaignUtil.setVariationAllocation(&campaigns[i])
        }
        settings.campaigns = campaigns
        
        // Add linked campaigns and gateway service flag to settings
        addLinkedCampaignsToSettings(&settings)
        addIsGatewayServiceRequiredFlag(&settings)
    }
    
    /**
     * Adds linked campaigns to the settings based on feature rules.
     *
     * - Parameter settings: The settings to be updated with linked campaigns.
     */
    private static func addLinkedCampaignsToSettings(_ settings: inout Settings) {
        
        guard let campaigns = settings.campaigns else { return }
        
        // Create a map of campaigns by their ID
        let campaignMap = Dictionary(uniqueKeysWithValues: campaigns.map { ($0.id ?? 0, $0) })
        
        for i in 0..<settings.features.count {
            var feature = settings.features[i]
            let rulesLinkedCampaignModel = feature.rules?.compactMap { rule -> Campaign? in
                guard var originalCampaign = campaignMap[rule.campaignId ?? 0] else { return nil }
                originalCampaign.ruleKey = rule.ruleKey
                var campaign = Campaign()
                campaign.setModelFromDictionary(originalCampaign)
                
                // Filter variations based on rule's variation ID
                if let variationId = rule.variationId {
                    if let variation = campaign.variations?.first(where: { $0.id == variationId }) {
                        campaign.variations = [variation]
                    }
                }
                return campaign
            }
            feature.rulesLinkedCampaign = rulesLinkedCampaignModel ?? []
            settings.features[i] = feature
        }
    }
        
    /**
     * Adds a flag to indicate if gateway service is required based on feature rules.
     *
     * - Parameter settings: The settings to be updated with the gateway service flag.
     */
    private static func addIsGatewayServiceRequiredFlag(_ settings: inout Settings) {
        
        // Define regex pattern to match specific segments or custom variables
        let patternString = "\\b(country|region|city|os|device_type|browser_string|ua)\\b|\"custom_variable\"\\s*:\\s*\\{\\s*\"name\"\\s*:\\s*\"inlist\\([^)]*\\)\""
        
        guard let regex = try? NSRegularExpression(pattern: patternString, options: []) else {
            LoggerService.log(level: .error, message: "Invalid regex pattern")
            return
        }

        // Iterate over each feature to check if gateway service is required
        for i in 0..<settings.features.count {
            var feature = settings.features[i]
            guard let rules = feature.rulesLinkedCampaign else { continue }
            
            for rule in rules {
                // Determine segments based on campaign type
                let segments = (rule.type == CampaignTypeEnum.rollout.rawValue || rule.type == CampaignTypeEnum.personalize.rawValue) ? rule.variations?.first?.segments : rule.segments
                if let segments = segments {
                    
                    do {
                        // Convert segments to JSON-compatible structure
                        let jsonCompatibleStructure = segments.mapValues { $0.toJSONCompatible() }
                        
                        // Serialize segments to JSON string
                        let jsonData = try JSONSerialization.data(withJSONObject: jsonCompatibleStructure, options: [.prettyPrinted])
                        let jsonString = String(data: jsonData, encoding: .utf8)!
                        
                        // Match regex pattern in JSON string
                        let matches = regex.matches(in: jsonString, options: [], range: NSRange(location: 0, length: jsonString.count))
                        
                        for match in matches {
                            let matchString = (jsonString as NSString).substring(with: match.range)
                            // Check if match is within a custom variable
                            if matchString.range(of: "\\b(country|region|city|os|device_type|browser_string|ua)\\b", options: .regularExpression) != nil {
                                if !isWithinCustomVariable(startIndex: match.range.location, input: jsonString) {
                                    feature.isGatewayServiceRequired = true
                                    break
                                }
                            } else {
                                feature.isGatewayServiceRequired = true
                                break
                            }
                        }
                        
                    } catch {
                        LoggerService.log(level: .error, message: "Exception occurred while processing settings \(error.localizedDescription)")
                    }
                    
                }
            }
            settings.features[i] = feature
        }
    }
    
    /**
     * Checks if a match is within a custom variable in the input string.
     *
     * - Parameters:
     *   - startIndex: The start index of the match.
     *   - input: The input string to be checked.
     * - Returns: A boolean indicating if the match is within a custom variable.
     */
    private static func isWithinCustomVariable(startIndex: Int, input: String) -> Bool {
        guard let index = input.range(of: "\"custom_variable\"", options: .backwards, range: input.startIndex..<input.index(input.startIndex, offsetBy: startIndex))?.lowerBound else {
            return false
        }
        
        if let closingBracketIndex = input.range(of: "}", options: [], range: index..<input.endIndex)?.lowerBound {
            return startIndex < input.distance(from: input.startIndex, to: closingBracketIndex)
        }
        
        return false
    }
}
