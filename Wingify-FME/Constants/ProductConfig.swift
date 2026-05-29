import Foundation

enum ProductType {
    case vwo
    case wingify
}

struct SDKConfigurationProfile {
    let displayName: String
    let sdkName: String
    let userDefaultsSuite: String
    let storageKeyNamespace: String
    let deviceIdService: String
    let deviceIdAccount: String
    let coreDataDirectoryName: String
    let loggerTag: String
    let hostName: String
    let servingUrl:String
    let collectionUrl:String
    let settingsEndpoint: String
    let eventBatchEndpoint: String
    let userContextTypeName: String
    let clientErrorDomain: String
    let hybridReactNativeSdkName: String
    let hybridFlutterSdkName: String
}

enum ProductConfig {
    private static var currentProduct: ProductType = .wingify

    private static let vwoConfiguration = SDKConfigurationProfile(
        displayName: "VWO",
        sdkName: "vwo-fme-ios-sdk",
        userDefaultsSuite: "com.vwo.fme.userdefault.suite",
        storageKeyNamespace: "com.vwo.fme",
        deviceIdService: "com.vwo.fme.deviceId",
        deviceIdAccount: "com.vwo.fme",
        coreDataDirectoryName: "VWO_FME",
        loggerTag: "VWO FME Logger",
        hostName: "dev.visualwebsiteoptimizer.com",
        servingUrl:"dev.visualwebsiteoptimizer.com",
        collectionUrl:"dev.visualwebsiteoptimizer.com",
        settingsEndpoint: "/server-side/v2-settings",
        eventBatchEndpoint: "/server-side/batch-events-v2",
        userContextTypeName: "VWOUserContext",
        clientErrorDomain: "VWOClient",
        hybridReactNativeSdkName: "vwo-fme-react-native-sdk",
        hybridFlutterSdkName: "vwo-fme-flutter-sdk"
    )

    // Keep Wingify-specific release values in one place so the new repo can override them without forking core logic.
    private static let wingifyConfiguration = SDKConfigurationProfile(
        displayName: "Wingify",
        sdkName: "wingify-fme-ios-sdk",
        userDefaultsSuite: "com.vwo.fme.userdefault.suite",
        storageKeyNamespace: "com.vwo.fme",
        deviceIdService: "com.wingify.fme.deviceId",
        deviceIdAccount: "com.wingify.fme",
        coreDataDirectoryName: "Wingify_FME",
        loggerTag: "Wingify FME Logger",
        hostName: "dev.visualwebsiteoptimizer.com",
        servingUrl:"edge.wingify.net",
        collectionUrl:"collect.wingify.net",
        settingsEndpoint: "/server-side/v2-settings",
        eventBatchEndpoint: "/server-side/batch-events-v2",
        userContextTypeName: "WingifyUserContext",
        clientErrorDomain: "WingifyClient",
        hybridReactNativeSdkName: "wingify-fme-react-native-sdk",
        hybridFlutterSdkName: "wingify-fme-flutter-sdk"
    )

    static var current: SDKConfigurationProfile {
        switch currentProduct {
        case .vwo:
            return vwoConfiguration
        case .wingify:
            return wingifyConfiguration
        }
    }

    static func use(_ brand: ProductType) {
        currentProduct = brand
    }

    static func localizeLogMessage(_ message: String?) -> String? {
        guard let message = message else { return nil }
        guard currentProduct == .wingify else { return message }

        let displayName = current.displayName
        let lowercaseDisplayName = displayName.lowercased()
        var localized = message

        let replacements: [(String, String)] = [
            ("VWOInitOptions", "\(displayName)InitOptions"),
            ("VWOUserContext", current.userContextTypeName),
            ("VWO-SDK", "\(displayName)-SDK"),
            ("VWO Gateway Service", "\(displayName) Gateway Service"),
            ("VWO Support", "\(displayName) Support"),
            ("VWO Client", "\(displayName) Client"),
            ("VWO client", "\(displayName) client"),
            ("VWO settings", "\(displayName) settings"),
            ("VWO account ID", "\(displayName) account ID")
        ]

        for (source, target) in replacements {
            localized = localized.replacingOccurrences(of: source, with: target)
        }

        localized = localized.replacingOccurrences(of: "\\bVWO\\b", with: displayName, options: .regularExpression)
        localized = localized.replacingOccurrences(of: "\\bvwo\\b", with: lowercaseDisplayName, options: .regularExpression)

        return localized
    }

    static func resetForTesting() {
        currentProduct = .wingify
    }
}
