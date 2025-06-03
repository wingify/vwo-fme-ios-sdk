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

class FeatureTests: XCTestCase {
    
    func testFeatureDecoding() {
        let json = """
        {
            "key": "feature1",
            "metrics": [],
            "status": "active",
            "id": 1,
            "rules": [],
            "impactCampaign": null,
            "name": "Feature 1",
            "type": "experiment",
            "rulesLinkedCampaign": [],
            "isGatewayServiceRequired": true,
            "variables": []
        }
        """.data(using: .utf8)!
        
        do {
            let feature = try JSONDecoder().decode(Feature.self, from: json)
            XCTAssertEqual(feature.key, "feature1")
            XCTAssertEqual(feature.status, "active")
            XCTAssertEqual(feature.id, 1)
            XCTAssertEqual(feature.name, "Feature 1")
            XCTAssertEqual(feature.type, "experiment")
            XCTAssertTrue(feature.isGatewayServiceRequired)
        } catch {
            XCTFail("Decoding failed: \(error)")
        }
    }
}

class StructTests: XCTestCase {
    
    func testFeatureDecoding() throws {
        let json = """
        {
            "key": "featureKey",
            "id": 1,
            "isGatewayServiceRequired": true
        }
        """.data(using: .utf8)!
        
        let feature = try JSONDecoder().decode(Feature.self, from: json)
        
        XCTAssertEqual(feature.key, "featureKey")
        XCTAssertEqual(feature.id, 1)
        XCTAssertTrue(feature.isGatewayServiceRequired)
    }
    
    func testMetricDecoding() throws {
        let json = """
        {
            "mca": 100,
            "identifier": "metricIdentifier"
        }
        """.data(using: .utf8)!
        
        let metric = try JSONDecoder().decode(Metric.self, from: json)
        
        XCTAssertEqual(metric.mca, 100)
        XCTAssertEqual(metric.identifier, "metricIdentifier")
    }
    
    func testRuleDecoding() throws {
        let json = """
        {
            "ruleKey": "ruleKey",
            "variationId": 2
        }
        """.data(using: .utf8)!
        
        let rule = try JSONDecoder().decode(Rule.self, from: json)
        
        XCTAssertEqual(rule.ruleKey, "ruleKey")
        XCTAssertEqual(rule.variationId, 2)
    }
    
    func testImpactCampaignDecoding() throws {
        let json = """
        {
            "campaignId": 3,
            "type": "impactType"
        }
        """.data(using: .utf8)!
        
        let impactCampaign = try JSONDecoder().decode(ImpactCampaign.self, from: json)
        
        XCTAssertEqual(impactCampaign.campaignId, 3)
        XCTAssertEqual(impactCampaign.type, "impactType")
    }
    
    func testCampaignDecoding() throws {
        let json = """
        {
            "id": 4,
            "name": "campaignName",
            "weight": 0.5
        }
        """.data(using: .utf8)!
        
        let campaign = try JSONDecoder().decode(Campaign.self, from: json)
        
        XCTAssertEqual(campaign.id, 4)
        XCTAssertEqual(campaign.name, "campaignName")
        XCTAssertEqual(campaign.weight, 0.5)
    }
    
    func testVariableDecoding() throws {
        let json = """
        {
            "key": "variableKey",
            "id": 5
        }
        """.data(using: .utf8)!
        
        let variable = try JSONDecoder().decode(Variable.self, from: json)
        
        XCTAssertEqual(variable.key, "variableKey")
        XCTAssertEqual(variable.id, 5)
    }
    
    func testInitialization() {
        let group = Groups(name: "Test Group", campaigns: ["Campaign1", "Campaign2"], et: 2, p: ["Param1", "Param2"], wt: ["Weight1": 0.5, "Weight2": 0.5])
        
        XCTAssertEqual(group.name, "Test Group")
        XCTAssertEqual(group.campaigns, ["Campaign1", "Campaign2"])
        XCTAssertEqual(group.et, 2)
        XCTAssertEqual(group.p, ["Param1", "Param2"])
        XCTAssertEqual(group.wt, ["Weight1": 0.5, "Weight2": 0.5])
    }
    
    func testSetEt() {
        var group = Groups(name: nil, campaigns: nil, et: nil, p: nil, wt: nil)
        group.setEt(3)
        
        XCTAssertEqual(group.et, 3)
    }
    
    func testGetEtWithDefault() {
        let group = Groups(name: nil, campaigns: nil, et: nil, p: nil, wt: nil)
        
        XCTAssertEqual(group.getEt(), 1) // Default value
    }
    
    func testGetEtWithValue() {
        let group = Groups(name: nil, campaigns: nil, et: 4, p: nil, wt: nil)
        
        XCTAssertEqual(group.getEt(), 4)
    }
    
    func testEquatable() {
        let group1 = Groups(name: "Group1", campaigns: ["Campaign1"], et: 1, p: ["Param1"], wt: ["Weight1": 0.5])
        let group2 = Groups(name: "Group1", campaigns: ["Campaign1"], et: 1, p: ["Param1"], wt: ["Weight1": 0.5])
        let group3 = Groups(name: "Group3", campaigns: ["Campaign3"], et: 3, p: ["Param3"], wt: ["Weight3": 0.3])
        
        XCTAssertEqual(group1, group2)
        XCTAssertNotEqual(group1, group3)
    }
}
