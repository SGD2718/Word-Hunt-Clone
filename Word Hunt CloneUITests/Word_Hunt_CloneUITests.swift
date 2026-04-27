//
//  Word_Hunt_CloneUITests.swift
//  Word Hunt CloneUITests
//
//  Created by Benjamin Lee on 4/26/26.
//

import XCTest

final class Word_Hunt_CloneUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testGameScreenLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["New Game"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Reveal"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["tile-0"].exists)
    }

    @MainActor
    func testRevealOpensSolverReview() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Reveal"].waitForExistence(timeout: 5))
        app.buttons["Reveal"].tap()

        XCTAssertTrue(app.navigationBars["Solver Review"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
