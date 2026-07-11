#if canImport(UIKit)
import XCTest
@testable import ExternalControllerKitUI

final class ExternalControllerKitUITests: XCTestCase {
    func testUIKitModuleBuildsOnSupportedPlatforms() {
        XCTAssertTrue(true)
    }

    func testUIConfigurationDefaultsDoNotProvideHeaderContent() {
        let configuration = ExternalControllerUIConfiguration()

        XCTAssertNil(configuration.headerDescription)
        XCTAssertNil(configuration.learnMoreTitle)
        XCTAssertNil(configuration.onLearnMore)
    }

    func testUIConfigurationStoresHeaderContent() {
        var didTriggerLearnMore = false
        let configuration = ExternalControllerUIConfiguration(
            headerDescription: "Connect a controller before assigning actions.",
            learnMoreTitle: "Learn More",
            onLearnMore: {
                didTriggerLearnMore = true
            }
        )

        XCTAssertEqual(configuration.headerDescription, "Connect a controller before assigning actions.")
        XCTAssertEqual(configuration.learnMoreTitle, "Learn More")

        configuration.onLearnMore?()

        XCTAssertTrue(didTriggerLearnMore)
    }
}
#endif
