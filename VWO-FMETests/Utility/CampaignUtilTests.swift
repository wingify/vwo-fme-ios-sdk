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

import XCTest
@testable import VWO_FME

class CampaignUtilTests: XCTestCase {
    
    var settings: Settings!
    
    override func setUp() {
        super.setUp()
        settings = FlagTestDataLoader.loadTestData(jsonFileName: SettingsTestJson.RolloutAndTestingSettings.jsonFileName)
    }
    
    override func tearDown() {
        settings = nil
        super.tearDown()
    }
    
    func testSetVariationAllocation() {
        var campaign = settings.campaigns![0]
        CampaignUtil.setVariationAllocation(&campaign)
        XCTAssertEqual(campaign.variations?[0].startRangeVariation, 1)
        XCTAssertEqual(campaign.variations?[0].endRangeVariation, 10000)
    }
        
    func testAssignRangeValues() {
        let campaign = settings.campaigns![0]
        var variation = campaign.variations![0]
        let stepFactor = CampaignUtil.assignRangeValues(&variation, currentAllocation: 0)
        XCTAssertEqual(stepFactor, 10000)
        XCTAssertEqual(variation.startRangeVariation, 1)
        XCTAssertEqual(variation.endRangeVariation, 10000)
    }

    func testScaleVariationWeights() {
        let campaign = settings.campaigns![0]
        var variations = campaign.variations!
        CampaignUtil.scaleVariationWeights(&variations)
        XCTAssertEqual(variations[0].weight, 100.0)
    }

    func testGetBucketingSeed() {
        let campaign = settings.campaigns![0]
        let seed = CampaignUtil.getBucketingSeed(userId: "user123", campaign: campaign, groupId: nil)
        XCTAssertEqual(seed, "1_user123")
    }

    func testGetVariationFromCampaignKey() {
        let variation = CampaignUtil.getVariationFromCampaignKey(settings: settings, campaignKey: "feature1_rolloutRule1", variationId: 1)
        XCTAssertNotNil(variation)
        XCTAssertEqual(variation?.name, "Rollout-rule-1")
    }

    func testGetGroupDetailsIfCampaignPartOfIt() {
        let groupDetails = CampaignUtil.getGroupDetailsIfCampaignPartOfIt(settings: settings, campaignId: 1, variationId: 1)
        XCTAssertTrue(groupDetails.isEmpty)
    }

    func testFindGroupsFeaturePartOf() {
        let groups = CampaignUtil.findGroupsFeaturePartOf(settings: settings, featureKey: "featureKey")
        XCTAssertTrue(groups.isEmpty)
    }

    func testGetCampaignsByGroupId() {
        let campaigns = CampaignUtil.getCampaignsByGroupId(settings: settings, groupId: 1)
        XCTAssertTrue(campaigns.isEmpty)
    }

    func testGetFeatureKeysFromCampaignIds() {
        let featureKeys = CampaignUtil.getFeatureKeysFromCampaignIds(settings: settings, campaignIdWithVariation: ["1_1"])
        XCTAssertFalse(featureKeys.isEmpty)
    }

    func testGetCampaignIdsFromFeatureKey() {
        let campaignIds = CampaignUtil.getCampaignIdsFromFeatureKey(settings: settings, featureKey: "featureKey")
        XCTAssertTrue(campaignIds.isEmpty)
    }

    func testGetRuleTypeUsingCampaignIdFromFeature() {
        let feature = settings.features.first!
        let ruleType = CampaignUtil.getRuleTypeUsingCampaignIdFromFeature(feature: feature, campaignId: 1)
        XCTAssertEqual(ruleType, "FLAG_ROLLOUT")
    }
}

