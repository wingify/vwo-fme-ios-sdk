import XCTest
#if SWIFT_PACKAGE
@testable import Wingify_FME
#else
@testable import VWO_FME
#endif

final class WingifyFacadeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ProductConfig.resetForTesting()
    }

    override func tearDown() {
        ProductConfig.resetForTesting()
        super.tearDown()
    }

    func testWingifyOptionsSwitchesBrandDefaults() {
        _ = WingifyInitOptions(sdkKey: "sdk-key", accountId: 12345)

        XCTAssertEqual(Constants.SDK_NAME, "wingify-fme-ios-sdk")
        XCTAssertEqual(Constants.SDK_USERDEFAULT_SUITE, "com.wingify.fme.userdefault.suite")
        XCTAssertEqual(WingifyInitSuccess.initializationSuccess.message, "Wingify is ready to use.")
    }

    func testWingifyUserContextUsesWingifyUserAgent() {
        let context = WingifyUserContext(id: "user-1", customVariables: [:])

        XCTAssertTrue(context.userAgent.contains("Wingify FME"))
    }

    func testWingifyUsesServingUrlForGetAndCollectionUrlForPost() {
        _ = WingifyInitOptions(sdkKey: "sdk-key", accountId: 12345)

        XCTAssertEqual(UrlService.getBaseUrl(for: .get), "edge.wingify.net")
        XCTAssertEqual(UrlService.getBaseUrl(for: .post), "collect.wingify.net")
    }

    func testRequestModelEncodesQueryParameters() {
        _ = WingifyInitOptions(sdkKey: "sdk-key", accountId: 12345)

        var request = RequestModel(
            url: UrlService.getBaseUrl(for: .post),
            method: HTTPMethod.post.rawValue,
            path: UrlEnum.events.rawValue,
            query: [
                "en": "vwo_sdkDebug",
                "a": "1258838",
                "env": "sdk-key"
            ],
            body: nil,
            headers: nil,
            scheme: Constants.HTTPS_PROTOCOL,
            port: 0
        )
        request.setOptions()

        let path = request.options["path"] as? String
        XCTAssertTrue(path?.contains("en=vwo_sdkDebug") == true)
        XCTAssertTrue(path?.contains("a=1258838") == true)
        XCTAssertFalse(path?.contains("url=") == true, "Event query should not include a recursive url param")
    }

    func testWingifyLocalizesLogTemplatesWithoutChangingEventNames() {
        _ = WingifyInitOptions(sdkKey: "sdk-key", accountId: 12345)

        XCTAssertEqual(
            ProductConfig.localizeLogMessage("VWO Client initialized"),
            "Wingify Client initialized"
        )
        XCTAssertEqual(
            ProductConfig.localizeLogMessage("Online event batching is disabled because gatewayService is configured in WingifyInitOptions."),
            "Online event batching is disabled because gatewayService is configured in WingifyInitOptions."
        )
        XCTAssertEqual(
            ProductConfig.localizeLogMessage("Impression built for vwo_variationShown event for Account ID:{accountId}"),
            "Impression built for vwo_variationShown event for Account ID:{accountId}"
        )
    }

    func testDefaultBrandRemainsVWOUntilWingifyFacadeIsUsed() {
        _ = WingifyInitOptions(sdkKey: "sdk-key", accountId: 12345)

        XCTAssertEqual(Constants.SDK_NAME, "vwo-fme-ios-sdk")
        XCTAssertEqual(WingifyInitSuccess.initializationSuccess.message, "VWO is ready to use.")
        XCTAssertEqual(UrlService.getBaseUrl(for: .get), "dev.visualwebsiteoptimizer.com")
        XCTAssertEqual(UrlService.getBaseUrl(for: .post), "dev.visualwebsiteoptimizer.com")
    }
}
