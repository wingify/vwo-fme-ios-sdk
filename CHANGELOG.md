# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-09-26

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
