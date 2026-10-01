import XCTest

/// Captures App Store screenshots. Run on a 6.9" simulator; PNGs land in
/// /private/tmp/calorude-shots/<lang>/ unless SHOTS_DIR is set.
final class StoreScreenshotTests: XCTestCase {
  let outDir = ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? "/private/tmp/calorude-shots"

  @MainActor func run(language: String) {
    continueAfterFailure = false
    let tr = language == "tr"
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "-language", language]
    app.launch()
    let next = app.buttons["onboarding.next"]
    XCTAssertTrue(next.waitForExistence(timeout: 15))
    next.tap()
    let name = app.textFields["onboarding.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.tap()
    name.typeText("Deniz\n")
    for _ in 0..<5 { next.tap() }
    app.switches["onboarding.eligibility"].tap()
    next.tap()
    XCTAssertTrue(app.staticTexts["onboarding.result"].waitForExistence(timeout: 15))
    shot(language, "1-plan")
    next.tap()

    let add = app.buttons["dashboard.add"]
    XCTAssertTrue(add.waitForExistence(timeout: 10))
    add.tap()
    XCTAssertTrue(app.buttons["mealEditor.meal.breakfast"].waitForExistence(timeout: 5))
    app.buttons["mealEditor.meal.breakfast"].tap()
    addFood(app, id: "menemen", query: tr ? "Menemen" : "Menemen", portion: 200)
    addFood(app, id: "simit", query: "Simit", portion: 100)
    app.buttons["mealEditor.save"].tap()
    let close = app.buttons["reaction.close"]
    XCTAssertTrue(close.waitForExistence(timeout: 8))
    sleep(1)
    shot(language, "2-reaction")
    close.tap()

    XCTAssertTrue(add.waitForExistence(timeout: 5))
    add.tap()
    XCTAssertTrue(app.buttons["mealEditor.meal.lunch"].waitForExistence(timeout: 5))
    app.buttons["mealEditor.meal.lunch"].tap()
    addFood(app, id: "meatbeans", query: tr ? "Etli kuru" : "White bean", portion: 240)
    addFood(app, id: "ayran", query: "Ayran", portion: 200)
    app.buttons["mealEditor.save"].tap()
    XCTAssertTrue(close.waitForExistence(timeout: 8))
    close.tap()
    sleep(1)
    shot(language, "3-dashboard")
    app.swipeUp()
    sleep(1)
    shot(language, "3b-coach")
    app.swipeDown()
    sleep(1)

    add.tap()
    XCTAssertTrue(app.buttons["mealEditor.meal.dinner"].waitForExistence(timeout: 5))
    app.buttons["mealEditor.meal.dinner"].tap()
    let search = app.textFields["food.search"]
    reveal(search, in: app)
    search.tap()
    search.typeText((tr ? "Mercimek" : "Lentil") + "\n")
    sleep(1)
    shot(language, "4-search")
    app.buttons["mealEditor.cancel"].tap()
    let discard = app.buttons[tr ? "Değişiklikleri sil" : "Discard changes"]
    if discard.waitForExistence(timeout: 2) { discard.tap() }

    app.tabBars.buttons[tr ? "Ayarlar" : "Settings"].tap()
    let intensity = app.descendants(matching: .any)["settings.intensity"].firstMatch
    if intensity.waitForExistence(timeout: 5) {
      intensity.tap()
      sleep(1)
      shot(language, "5-coach-modes")
      app.swipeDown()
    }

    app.tabBars.buttons[tr ? "İlerleme" : "Progress"].tap()
    sleep(1)
    shot(language, "6-progress")
    let pro = app.buttons["progress.reports.pro"]
    reveal(pro, in: app)
    if pro.exists {
      pro.tap()
      sleep(3)
      shot(language, "7-paywall")
    }
  }

  @MainActor func shot(_ language: String, _ name: String) {
    let dir = "\(outDir)/\(language)"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let data = XCUIScreen.main.screenshot().pngRepresentation
    try? data.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
  }

  @MainActor func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<10 {
      if element.exists && element.isHittable && element.frame.minY > app.frame.minY + 140
        && element.frame.maxY < app.frame.maxY - 130
      {
        return
      }
      let downward = element.exists && element.frame.minY <= app.frame.minY + 140
      let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: downward ? 0.72 : 0.28))
      start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    }
  }

  @MainActor func addFood(_ app: XCUIApplication, id: String, query: String, portion: Int) {
    let search = app.textFields["food.search"]
    reveal(search, in: app)
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText(query + "\n")
    let result = app.buttons["food.result." + id]
    reveal(result, in: app)
    XCTAssertTrue(result.waitForExistence(timeout: 5))
    result.tap()
    let chip = app.buttons["portion.\(portion)"]
    if chip.waitForExistence(timeout: 3) { chip.tap() }
    app.buttons["portion.confirm"].tap()
    XCTAssertTrue(app.buttons["mealEditor.save"].waitForExistence(timeout: 5))
  }


  @MainActor func runPaywall(language: String) {
    continueAfterFailure = false
    let tr = language == "tr"
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "-language", language]
    app.launch()
    let name = app.textFields["onboarding.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 15))
    app.switches["onboarding.eligibility"].tap()
    name.tap()
    name.typeText("Deniz\n")
    let next = app.buttons["onboarding.next"]
    next.tap(); next.tap(); next.tap(); next.tap()
    app.tabBars.buttons[tr ? "İlerleme" : "Progress"].tap()
    let pro = app.buttons["progress.reports.pro"]
    reveal(pro, in: app)
    pro.tap()
    sleep(4)
    shot(language, "7-paywall")
    app.swipeUp()
    sleep(1)
    shot(language, "8-paywall-prices")
  }
  @MainActor func testPaywallTurkish() { runPaywall(language: "tr") }
  @MainActor func testPaywallEnglish() { runPaywall(language: "en") }
  @MainActor func testTurkish() { run(language: "tr") }
  @MainActor func testEnglish() { run(language: "en") }
}
