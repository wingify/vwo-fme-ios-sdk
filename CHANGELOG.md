# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2025-01-10

### Added

- Added support for storing impression events while the device is offline, ensuring no data loss. These events are batched and seamlessly synchronized with VWO servers once the device reconnects to the internet. 
- Online event batching, allowing synchronization of impression events while the device is online. This feature can be configured by setting either the minimum batch size or the batch upload time interval during SDK initialization.


## [1.2.0] - 2024-12-20

### Added

- Support for passing SDK name and version for hybrid SDKs i.e. React Native & Flutter SDKs


## [1.1.0] - 2024-11-08

### Added

- Added support for Personalise rules within Mutually Exclusive Groups.
- Storage support: Built in storage capabilities to manage feature and variation data and preventing changes in variations upon each initialization.
- Settings cache: Cached settings will be used till it expires. Client can set the expiry time of cache.
- Added SPM support.

```swift
import VWO_FME

let options = VWOInitOptions(sdkKey: SDK_KEY,
                             accountId: ACCOUNT_ID,
                             gatewayService: ["url": "REPLACE_WITH_GATEWAY_URL"],
                             cachedSettingsExpiryTime: 10 * 60 * 1000) // in milliseconds

VWOFme.initialize(options: options) { result in
    switch result {
        case .success(let message):
            print("VWO init success")

        case .failure(let error):
            print("VWO init failed")
    }
}
```

## [1.0.0] - 2024-10-15

### Added

- Added integration support with [VWO Gateway Service](https://hub.docker.com/r/wingifysoftware/vwo-fme-gateway-service)

```swift
import VWO_FME

let options = VWOInitOptions(sdkKey: sdkKey, accountId: accountId, gatewayService: ["url": "REPLACE_WITH_GATEWAY_URL"])

VWOFme.initialize(options: options) { result in
    switch result {
        case .success(let message):
            print("VWO init success")

        case .failure(let error):
            print("VWO init failed")
    }
}

let userContext = VWOContext(
    id: USER_ID,
    ipAddress: "1.2.3.4", // pass actual IP Address
    userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148" // pass actual user agent
)

let featureFlagObj = VWOFme.getFlag(featureKey: FEATURE_KEY, context: userContext)
```

## [0.1.0] - 2024-09-26

### Added

- First release of VWO Feature Management and Experimentation capabilities

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
