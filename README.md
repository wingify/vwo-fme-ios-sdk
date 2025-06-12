# VWO Feature Management and Experimentation SDK for iOS

[![pod version](https://img.shields.io/cocoapods/v/VWO-FME?style=for-the-badge&color=grey)](https://github.com/wingify/vwo-fme-ios-sdk)
[![License](https://img.shields.io/github/license/wingify/vwo-fme-ios-sdk?style=for-the-badge&color=blue)](http://www.apache.org/licenses/LICENSE-2.0)

[![CI](https://img.shields.io/github/actions/workflow/status/wingify/vwo-fme-ios-sdk/main.yml?style=for-the-badge&logo=github)](https://github.com/wingify/vwo-fme-ios-sdk/actions?query=workflow%3ACI)

## Overview

The **VWO Feature Management and Experimentation SDK** (VWO FME iOS SDK) enables developers to integrate feature flagging and experimentation into their applications across Apple platforms. This SDK provides full control over feature rollout, A/B testing, and event tracking, allowing teams to manage features dynamically and gain insights into user behavior.


## Supported Platforms

The SDK is compatible with the following Apple platforms and minimum OS versions:

- iOS 12.0 and later
- watchOS 7.0 and later
- tvOS 12.0 and later
- macOS 10.14 and later


## Installation

### CocoaPods


VWO FME is available through [CocoaPods](http://cocoapods.org).

To install
it, simply add the following line to your Podfile:

```bash
pod 'VWO-FME'
```

And then run:
```bash
pod install
```

### Swift Package Manager

To install VWO FME using [Swift Package Manager](https://github.com/swiftlang/swift-package-manager) you can follow the [tutorial published by Apple](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app) using the URL for the VWO FME repo with the current version:

1. In Xcode, select “File” → “Add Package Dependencies...”
1. Enter https://github.com/wingify/vwo-fme-ios-sdk
1. Add package


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
            // Create VWOUserContext object
            let userContext = VWOUserContext(id: "unique_user_id", customVariables: customVariables)

            // Get the GetFlag object for the feature key and context
            VWOFme.getFlag(featureKey: "feature_flag_name", context: userContext, completion: { featureFlagObj in
                // Check if flag is enabled
                let isFlagEnabled = featureFlagObj.isEnabled()
                            
                // Get the variable value for the given variable key and default value
                let variable1 = featureFlagObj.getVariable(key: "feature_flag_variable", defaultValue: "default-value")
            })

            // Track the event for the given event name and context
            let eventProperties: [String: Any] = ["cart_value":"999"]
            VWOFme.trackEvent(eventName: "vwo_event_name", context: userContext, eventProperties: eventProperties)

            // Send attributes data
            let attributeName1 = "attribute-name-string"
            let attributeValue1 = "attribute-value-text"
            let attributeName2 = "attribute-name-float"
            let attributeValue2 = 7.0

            let attributeDict: [String: Any] = [attributeName1: attributeValue1,
                                                attributeName2: attributeValue2]

            VWOFme.setAttribute(attributes: attributeDict, context: userContext)



        case .failure(let error):
            break
    }
}
```

## Advanced Configuration Options
To customize the SDK further, additional parameters can be passed to the `VWOInitOptions` initializer. Here’s a table describing each option:

| **Parameter**                | **Description**                                                                                                                                             | **Required** | **Type** | **Example**                     |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | -------- | ------------------------------- |
| `accountId`                  | VWO Account ID for authentication.                                                                                                                          | Yes          | Int      | `123456`                        |
| `sdkKey`                     | SDK key corresponding to the specific environment to initialize the VWO SDK Client. You can get this key from VWO Application.                              | Yes          | String   | `"32-alpha-numeric-sdk-key"`    |
| `logLevel`                   | The level of logging to be used.                                                                                                                            | No           | Enum     | `.error`                        |
| `logPrefix`                  | A prefix to be added to log messages.                                                                                                                        | No           | String   | `"VWO"`                         |
| `pollInterval`               | Time interval for fetching updates from VWO servers (in milliseconds).                                                                                      | No           | Int64    | `60000`                         |
| `integrations`               | Callback for integrations.                                                                                                                                  | No           | IntegrationCallback | See [Integrations](#integrations) section |
| `cachedSettingsExpiryTime`   | Expiry time for cached settings in milliseconds.                                                                                                            | No           | Int64    | `3600000`                       |
| `batchMinSize`               | Minimum size of batch to upload.                                                                                                                            | No           | Int      | `10`                            |
| `batchUploadTimeInterval`    | Batch upload time interval in milliseconds.                                                                                                                 | No           | Int64    | `300000`                        |
| `logTransport`               | Custom log transport for handling log messages.                                                                                                             | No           | LogTransport  | See [LogTransport](#logtransport) section |

Refer to the [official VWO documentation](https://developers.vwo.com/v2/docs/fme-ios-install) for additional parameter details.

### User Context

The `context` object uniquely identifies users and is crucial for consistent feature rollouts. A typical `context` includes an `id` for identifying the user. It can also include other attributes that can be used for targeting and segmentation, such as `customVariables`.

#### Parameters Table

The following table explains all the parameters in the `context` object:

| **Parameter**     | **Description**                                                            | **Required** | **Type** | **Example**                       |
| ----------------- | -------------------------------------------------------------------------- | ------------ | -------- | --------------------------------- |
| `id`              | Unique identifier for the user.                                            | Yes          | String   | `"unique_user_id"`                |
| `customVariables` | Custom attributes for targeting.                                           | No           | Dictionary   | `["key_1": 2, "key_2": 0]`     |

#### Example

```swift
let customVariables: [String : Any] = ["key_1": 2, "key_2": 0]
let userContext = VWOUserContext(id: "unique_user_id", customVariables: customVariables)
```

### Basic Feature Flagging

Feature Flags serve as the foundation for all testing, personalization, and rollout rules within FME. To implement a feature flag, first use the `getFlag` API to retrieve the flag configuration. The `getFlag` API provides a simple way to check if a feature is enabled for a specific user and access its variables. It returns a feature flag object that contains methods for checking the feature's status and retrieving any associated variables.

| **Parameter** | **Description**                                                      | **Required** | **Type** | **Example**          |
| ------------- | -------------------------------------------------------------------- | ------------ | -------- | -------------------- |
| `featureKey`  | Unique identifier of the feature flag                                | Yes          | String   | `"new_checkout"`     |
| `context`     | Object containing user identification and contextual information     | Yes          | VWOUserContext | `VWOUserContext(id: "user_123", customVariables: ["key": "value"])` |

Example usage:

```swift
let userContext = VWOUserContext(id: "user_123", customVariables: ["key": "value"])

VWOFme.getFlag(featureKey: "feature_flag_name", context: userContext) { featureFlagObj in
    // Check if flag is enabled
    let isFlagEnabled = featureFlagObj.isEnabled()
    
    // Get all variables for a feature flag                      
    let variables = featureFlag.getVariables()
    
    // Get the variable value for the given variable key and default value
    let variable1 = featureFlagObj.getVariable(key: "feature_flag_variable", defaultValue: "default-value")
}
```

### Custom Event Tracking

Feature flags can be enhanced with connected metrics to track key performance indicators (KPIs) for your features. These metrics help measure the effectiveness of your testing rules by comparing control versus variation performance, and evaluate the impact of personalization and rollout campaigns. Use the `trackEvent` API to track custom events like conversions, user interactions, and other important metrics:

| **Parameter**     | **Description**                                                            | **Required** | **Type** | **Example**                                      |
| ----------------- | -------------------------------------------------------------------------- | ------------ | -------- | ------------------------------------------------ |
| `eventName`       | Name of the event you want to track                                        | Yes          | String   | `"purchase_completed"`                           |
| `context`         | Object containing user identification and other contextual information     | Yes          | VWOUserContext | `VWOUserContext(id: "user_123", customVariables: ["key": "value"])` |
| `eventProperties` | Additional properties/metadata associated with the event                   | No           | Dictionary | `["amount": 49.99]`                              |

Example usage:

```swift
// Create user context
let userContext = VWOUserContext(id: "user_123", customVariables: ["key": "value"])

// Track the event for the given event name and context
let eventProperties: [String: Any] = ["cart_value": 999]

VWOFme.trackEvent(eventName: "vwo_event_name", context: userContext, eventProperties: eventProperties)
```
See [Tracking Conversions](https://developers.vwo.com/v2/docs/fme-ios-metrics#usage) documentation for more information.

### Pushing Attributes

User attributes provide rich contextual information about users, enabling powerful personalization. The `setAttribute` method provides a simple way to associate these attributes with users in VWO for advanced segmentation. Here's what you need to know about the method parameters:


| **Parameter**    | **Description**                                                            | **Required** | **Type**   | **Example**                                                                                          |
| ---------------- | -------------------------------------------------------------------------- | ------------ | ---------- | ---------------------------------------------------------------------------------------------------- |
| `attributeKey`   | The unique identifier/name of the attribute you want to set                | Yes          | String     | `"attribute-name"`                                                  |
| `attributeValue` | The value to be assigned to the attribute                                  | Yes          | String, Number, Boolean        | `"attribute-value-text"`, `7.0, true`                                                                      |
| `context`        | Object containing user identification and other contextual information     | Yes          | VWOUserContext | `VWOUserContext(id: "user_123", customVariables: ["key": "value"])`                                      |

Example usage:

```swift
// Create user context
let userContext = VWOUserContext(id: "user_123", customVariables: ["key": "value"])

// Send attributes data
let attributeName1 = "attribute-name-string"
let attributeValue1 = "attribute-value-text"
let attributeName2 = "attribute-name-float"
let attributeValue2 = 7.0

let attributeDict: [String: Any] = [
    attributeName1: attributeValue1,
    attributeName2: attributeValue2
]

VWOFme.setAttribute(attributes: attributeDict, context: userContext)
```

See [Pushing Attributes](https://developers.vwo.com/v2/docs/fme-ios-attributes#usage) documentation for additional information.


### Integrations

VWO SDKs help you integrate with several third-party destinations. SDKs help you integrate with any kind of tool, be it analytics, monitoring, customer data platforms, messaging, etc. by implementing a very basic and generic callback that is capable of receiving VWO-specific properties.

Example usage:

```swift
class MyClass: IntegrationCallback {
    func execute(_ properties: [String: Any]) {
        // Handle the integration callback here
        print("Integration callback executed with properties: \(properties)")
    }
}

// Create an instance of your class
let integrationClass = MyClass()

let options = VWOInitOptions(sdkKey: SDK_KEY, accountId: ACCOUNT_ID, integrations: integrationClass)
```
See [Integrations](https://developers.vwo.com/v2/docs/fme-ios-integrations#usage) documentation for additional information.


### Log Transport

You can implement the `LogTransport` protocol to customize how logs are handled and sent to external systems

Example usage:

```swift
// Define a class that conforms to the LogTransport protocol
class MyClass: LogTransport {
    // Implement the log method to handle log messages
    func log(logType: String, message: String) {
        // Send log to a third-party service or handle it as needed
        print("Log Type: \(logType), Message: \(message)")
    }
}

// Create an instance of your class
let logClass = MyClass()

// Initialize VWOInitOptions with the custom log transport
let options = VWOInitOptions(sdkKey: SDK_KEY, accountId: ACCOUNT_ID,  logTransport:logClass)
```
See [Logging](https://developers.vwo.com/v2/docs/fme-ios-logging) documentation for additional information.


### Polling Interval Adjustment

The `pollInterval` is an optional parameter that allows the SDK to automatically fetch and update settings from the VWO server at specified intervals. Setting this parameter ensures your application always uses the latest configuration.

Example usage:

```swift
// Initialize VWOInitOptions with a custom polling interval in milliseconds
let options = VWOInitOptions(sdkKey: SDK_KEY, accountId: ACCOUNT_ID,  pollInterval:600000)
```
See [Polling](https://developers.vwo.com/v2/docs/polling) documentation for additional information.

### Cached Settings Expiry Time

The `cachedSettingsExpiryTime` parameter allows you to specify how long the cached settings should be considered valid before fetching new settings from the VWO server. This helps in managing the freshness of the configuration data.

Example usage:

```swift
// Initialize VWOInitOptions with a custom cached settings expiry time
let options = VWOInitOptions(sdkKey: SDK_KEY, accountId: ACCOUNT_ID, cachedSettingsExpiryTime:600000)
```

### Event Batching Configuration

The VWO SDK supports storing impression events while the device is offline, ensuring no data loss. These events are batched and seamlessly synchronized with VWO servers once the device reconnects to the internet. Additionally, online event batching allows synchronization of impression events while the device is online. This feature can be configured by setting either the minimum batch size or the batch upload time interval during SDK initialization. 

#### NOTE: The uploading of events will get triggered based on whichever condition is met first if using both options.

| **Parameter**               | **Description**                                                                                     | **Required** | **Type** | **Example** |
| --------------------------- | --------------------------------------------------------------------------------------------------- | ------------ | -------- | ----------- |
| `batchMinSize`              | Minimum size of the batch to upload.                                                               | No           | Int      | `10`        |
| `batchUploadTimeInterval`   | Batch upload time interval in milliseconds. Please specify at least a few minutes.                  | No           | Int64    | `300000`    |

Example usage:

```swift
// Initialize VWOInitOptions with batch configuration
let options = VWOInitOptions(sdkKey: SDK_KEY, accountId: ACCOUNT_ID, batchMinSize:10, batchUploadTimeInterval: 300000)
```

## Running Tests

To ensure the reliability of our iOS SDK, follow these steps to run tests in Xcode:

1. **Clone the Repository**: 
   ```bash
   git clone https://github.com/wingify/vwo-fme-ios-sdk.git
   cd vwo-fme-ios-sdk
   ```

2. **Open the Project**: Launch Xcode and open the project.

3. **Choose Target**: Select the test target VWO-FMETests.

4. **Run Tests**: Press `Cmd + U` to execute all tests. Alternatively, you can go to the menu bar and select `Product > Test`.

5. **View Results**: Check the Test Navigator for results and logs.


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

Copyright 2024-2025 Wingify Software Pvt. Ltd.
