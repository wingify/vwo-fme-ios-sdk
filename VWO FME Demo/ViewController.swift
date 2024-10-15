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

import UIKit
import VWO_FME

class ViewController: UIViewController {
    
    var featureFlagObj: GetFlag? = nil
    var context: VWOContext?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addStackView()
        self.setVWOContext()
    }
    
    
    //MARK: - UI setup methods
    
    func addStackView() {
        
        let myLabel = createLabel(text: "FME SDK", fontSize: 25.0)
        
        let button1 = createButton(title: "Init SDK", action: #selector(button1Tapped))
        let button2 = createButton(title: "Get flag", action: #selector(button2Tapped))
        let button3 = createButton(title: "Get variable", action: #selector(button3Tapped))
        let button4 = createButton(title: "Track event", action: #selector(button4Tapped))
        let button5 = createButton(title: "Set attribute", action: #selector(button5Tapped))
        
        let stackView = UIStackView(arrangedSubviews: [myLabel, button1, button2, button3, button4, button5])
        stackView.axis = .vertical
        stackView.spacing = 15
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        
        self.view.addSubview(stackView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5)
        ])
    }
    
    func createButton(title: String, action: Selector) -> UIButton {
        
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.titleLabel?.textColor = .systemBlue
        button.backgroundColor = .systemBackground
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = 5.0
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 45).isActive = true
        return button
    }
    
    func createLabel(text: String, fontSize: CGFloat = 18.0, textColor: UIColor = .black, backgroundColor: UIColor = .white) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        label.textColor = textColor
        label.backgroundColor = backgroundColor
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(equalToConstant: 45).isActive = true
        return label
    }
    
    
    // MARK: - Button action methods
    
    @objc private func button1Tapped() {
        
        self.initVwoSdk()
    }
    
    @objc private func button2Tapped() {
        
        self.getFlag()
    }
    
    @objc private func button3Tapped() {
        
        self.getVariable()
    }
    
    @objc private func button4Tapped() {
        
        self.trackEvent()
    }
    
    @objc private func button5Tapped() {
        
        self.setAttribute()
    }
    
    //MARK: - VWO SDK methods
    
    func setVWOContext() {
        
        let myUserId = "unique_user_id"
        let customVariables = ["key_1":5, "key_2": 0] as [String : Any]
        self.context = VWOContext(id: myUserId, 
                                  customVariables: customVariables,
                                  ipAddress: "1.2.3.4", 
                                  userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148")
    }
    
    func initVwoSdk() {

        let sdkKey = "dummy_key"
        let accountId: Int = 123456
        let integrations = MyIntegrationCallback()
        let options = VWOInitOptions(sdkKey: sdkKey, accountId: accountId, logLevel: .trace, integrations: integrations)
        
        VWOFme.initialize(options: options) { result in
            switch result {
            case .success(let message):
                print("Demo app >>> \(message)")
                // do something else like get feature flag data
                
            case .failure(let error):
                print("Demo app >>> ", error)
            }
        }
    }
    
    func getFlag() {
        
        if !VWOFme.isInitialized {
            print("VWO is not initialized. Please initialize VWO before getting flags")
            return
        }
        
        guard let userContext = self.context else {
            print("VWOContext is required")
            return
        }
        
        let featureFlagName = "feature_flag_name"
        let featureFlag = VWOFme.getFlag(featureKey: featureFlagName, context: userContext)
        
        if let featureFlag = featureFlag {
            self.featureFlagObj = featureFlag
            print("Feature flag result: \(featureFlagName) || enabled: \(featureFlag.isEnabled())")
        }
    }
    
    func getVariable() {
        
        guard let featureFlag = self.featureFlagObj else {
            print("Feature flag object is nil")
            return
        }
        
        if featureFlag.isEnabled() {
            let variables = featureFlag.getVariables()
            let variable1 = featureFlag.getVariable(key: "feature_flag_variable1", defaultValue: "default-value1")
            let variable2 = featureFlag.getVariable(key: "feature_flag_variable2", defaultValue: "default-value2")
            print("Variables from feature flag: \(variables)")
            
        } else {
            print("Feature flag is not enabled")
        }
    }
    
    func trackEvent() {
        
        if !VWOFme.isInitialized {
            print("VWO is not initialized. Please initialize VWO before tracking events")
            return
        }
        
        guard let userContext = self.context else {
            print("VWOContext is required")
            return
        }
        
        let eventName = "movieevent"
        let eventProperties: [String: Any] = ["movie":"12345"]
        VWOFme.trackEvent(eventName: eventName, context: userContext, eventProperties: eventProperties)
    }
    
    func setAttribute() {
        
        if !VWOFme.isInitialized {
            print("VWO is not initialized. Please initialize VWO before setting attributes")
            return
        }
        
        guard let userContext = self.context else {
            print("VWOContext is required")
            return
        }
        
        let attributeName1 = "attribute-name"
        let attributeValue1 = "attribute-value-something"
        
        let attributeName2 = "attribute-name-float"
        let attributeValue2 = 7.0
        
        let attributeName3 = "attribute-name-boolean"
        let attributeValue3 = true
        
        let attributeName4 = "attribute-new"
        let attributeValue4 = "ios-sdk"
        
        VWOFme.setAttribute(attributeKey: attributeName1 , attributeValue: attributeValue1, context: userContext)
        VWOFme.setAttribute(attributeKey: attributeName2 , attributeValue: attributeValue2, context: userContext)
        VWOFme.setAttribute(attributeKey: attributeName3 , attributeValue: attributeValue3, context: userContext)
        VWOFme.setAttribute(attributeKey: attributeName4 , attributeValue: attributeValue4, context: userContext)
    }
}

class MyIntegrationCallback: IntegrationCallback {
    func execute(_ properties: [String: Any]) {
        // Handle the integration callback here
        print("Integration callback executed with properties: \(properties)")
    }
}
