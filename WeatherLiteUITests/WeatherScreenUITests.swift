import XCTest

final class WeatherScreenUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testInitialState_ShowSelectionLocationOrLoading() {
        let stateDropdown = app.otherElements["LocationDescriptionText"].firstMatch.exists
            ? app.otherElements["LocationDescriptionText"].firstMatch
            : app.buttons["LocationDescriptionText"].firstMatch

        XCTAssertTrue(stateDropdown.waitForExistence(timeout: 5))
        stateDropdown.tap()

        let doneButton = app.buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()
    }

    func testSelectLocation_ThenFetchesAndDisplaysData() {
        let stateDropdown = app.buttons["LocationDescriptionText"].firstMatch
        XCTAssertTrue(stateDropdown.waitForExistence(timeout: 5))
        stateDropdown.tap()

        let nyStateOption = app.buttons["New York"].firstMatch
        XCTAssertTrue(nyStateOption.waitForExistence(timeout: 5))
        nyStateOption.tap()

        let cityDropdown = app.buttons["CityDropdown"].firstMatch
        XCTAssertTrue(cityDropdown.waitForExistence(timeout: 5))
        cityDropdown.tap()

        let nyCityOption = app.buttons["New York"].firstMatch
        XCTAssertTrue(nyCityOption.waitForExistence(timeout: 5))
        nyCityOption.tap()

        let refreshButton = app.buttons["RefreshButton"].firstMatch
        XCTAssertTrue(refreshButton.exists)
        refreshButton.tap()

        let weatherDesc = app.staticTexts["WeatherDescriptionText"].firstMatch
        let weatherTemp = app.staticTexts["WeatherTemperatureText"].firstMatch
        XCTAssertTrue(weatherDesc.waitForExistence(timeout: 15))
        XCTAssertTrue(weatherTemp.exists)
        XCTAssertFalse(app.staticTexts["ErrorText"].exists)
    }

    func testCitySearchNonMajorCity() {
        let stateDropdown = app.buttons["LocationDescriptionText"].firstMatch
        XCTAssertTrue(stateDropdown.waitForExistence(timeout: 5))
        stateDropdown.tap()

        let caStateOption = app.buttons["California"].firstMatch
        XCTAssertTrue(caStateOption.waitForExistence(timeout: 5))
        caStateOption.tap()

        let cityDropdown = app.buttons["CityDropdown"].firstMatch
        XCTAssertTrue(cityDropdown.waitForExistence(timeout: 5))
        cityDropdown.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Acton")

        let actonOption = app.buttons["Acton"].firstMatch
        XCTAssertTrue(actonOption.waitForExistence(timeout: 5))
    }

    func testClickRefresh_WhenDataIsDisplayed_TriggersLoadingAgain() {
        testSelectLocation_ThenFetchesAndDisplaysData()

        let refreshButton = app.buttons["RefreshButton"].firstMatch
        XCTAssertTrue(refreshButton.exists)
        refreshButton.tap()

        let weatherDesc = app.staticTexts["WeatherDescriptionText"].firstMatch
        XCTAssertTrue(weatherDesc.waitForExistence(timeout: 15))
    }
}
