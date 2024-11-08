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

class SegmentationManager {
    private static var evaluator: SegmentEvaluator?

    /**
     * Attaches a custom segment evaluator.
     *
     * @param segmentEvaluator The segment evaluator to attach.
     */
    static func attachEvaluator(segmentEvaluator: SegmentEvaluator?) {
        self.evaluator = segmentEvaluator
    }

    /**
     * Attaches a default segment evaluator.
     */
    static func attachEvaluator() {
        self.evaluator = SegmentEvaluator()
    }

    /**
     * This method sets the contextual data required for segmentation.
     * @param settings  SettingsModel object containing the account settings.
     * @param feature   FeatureModel object containing the feature settings.
     * @param context   VWOContext object containing the user context.
     */
    static func setContextualData(settings: Settings, feature: Feature, context: VWOContext) {
        self.attachEvaluator()
        evaluator?.context = context
        evaluator?.settings = settings
        evaluator?.feature = feature

        // if user agent and ipAddress both are null or empty, return
        if context.userAgent.isEmpty && context.ipAddress.isEmpty {
            return
        }
        // If gateway service is required and the base URL is not the default one, fetch the data from the gateway service
        if feature.isGatewayServiceRequired && !UrlService.baseUrl.contains(Constants.HOST_NAME)
            && (context.vwo == nil) {
            
            var queryParams: [String: String] = [:]
            if context.userAgent.isEmpty && context.ipAddress.isEmpty {
                return
            }
            queryParams["userAgent"] = context.userAgent
            queryParams["ipAddress"] = context.ipAddress
            
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            
            let params = GatewayServiceUtil.getQueryParams(queryParams)
            GatewayServiceUtil.getFromGatewayService(queryParams: params, endpoint: UrlEnum.getUserData.rawValue) { gatewayResponse in
                if let modelData = gatewayResponse {
                    if let stringData = modelData.data {
                        do {
                            let gatewayData = stringData.data(using: .utf8)
                            let gatewayServiceModel = try JSONDecoder().decode(GatewayService.self, from: gatewayData!)
                            context.vwo = gatewayServiceModel
                        } catch {
                            LoggerService.log(level: .error, message: "Failed to decode GatewayService model")
                        }
                    }
                }
                dispatchGroup.leave()
            }
            dispatchGroup.wait()
        }
    }

    static func validateSegmentation(dsl: Any, properties: [String: Any]) -> Bool {
        do {
            let dslNodes: [String: CodableValue]
            if let dslString = dsl as? String, let data = dslString.data(using: .utf8) {
                dslNodes = try JSONDecoder().decode([String: CodableValue].self, from: data)
            } else if let dslDict = dsl as? [String: CodableValue] {
                dslNodes = dslDict
            } else {
                return false
            }
            return evaluator?.isSegmentationValid(dsl: dslNodes, properties: properties) ?? false
        } catch {
            LoggerService.log(level: .error, message: "Exception occurred validate segmentation \(error.localizedDescription)")
            return false
        }
    }
    
}
