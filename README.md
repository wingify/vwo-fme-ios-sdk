# VWO FME iOS SDK

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0)

## Installation

VWO FME is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```bash
pod 'VWO-FME'
```

## iOS Version Support

This library supports iOS version 12.0 and above.

## Basic Usage

```swift
import VWO_FME

// Initialize VWO SDK with your SDK_KEY and ACCOUNT_ID
let options = VWOInitOptions(sdkKey: SDK_KEY, accountId: ACCOUNT_ID)

VWOFme.initialize(options: options) { result in
    switch result {
        case .success(let message):
            print("VWO init success")

            // for targeting conditions
            let customVariables: [String : Any] = ["key_1": 2, "key_2": 0]
            // Create VWOContext object
            let userContext = VWOContext(id: "unique_user_id", customVariables: customVariables)

            // Get the GetFlag object for the feature key and context
            let featureFlagObj = VWOFme.getFlag(featureKey: "feature_flag_name", context: userContext)

            // Check if flag is enabled
            let isFlagEnabled = featureFlagObj?.isEnabled()

            // Get the variable value for the given variable key and default value
            let variable1 = featureFlagObj?.getVariable(key: "feature_flag_variable1", defaultValue: "default-value1")

            // Track the event for the given event name and context
            let eventProperties: [String: Any] = ["cart_value":"999"]
            VWOFme.trackEvent(eventName: "vwo_event_name", context: userContext, eventProperties: eventProperties)

            // Send attributes data
            let attributeName = "attribute-name"
            let attributeValue = "attribute-value"
            VWOFme.setAttribute(attributeKey: attributeName , attributeValue: attributeValue, context: userContext)


        case .failure(let error):
            break
    }
}
```

## Authors

* [Vishwajeet Singh](https://github.com/vishwajeet-wingify)

## Changelog

Refer [CHANGELOG.md](https://github.com/wingify/vwo-fme-ios-sdk/blob/master/CHANGELOG.md)

## Contributing

Please go through our [contributing guidelines](https://github.com/wingify/vwo-fme-ios-sdk/blob/master/CONTRIBUTING.md)

## Code of Conduct

[Code of Conduct](https://github.com/wingify/vwo-fme-ios-sdk/blob/master/CODE_OF_CONDUCT.md)

## License

[Apache License, Version 2.0](https://github.com/wingify/vwo-fme-ios-sdk/blob/master/LICENSE)

Copyright 2024 Wingify Software Pvt. Ltd.
