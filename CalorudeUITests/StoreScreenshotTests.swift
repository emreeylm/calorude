import XCTest

/// Captures App Store screenshots. Run on a 6.9" simulator; PNGs land in
/// /private/tmp/calorude-shots/<lang>/ unless SHOTS_DIR is set.
final class StoreScreenshotTests: XCTestCase {
  let outDir = ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? "/private/tmp/calorude-shots"

  @MainActor func run(language: String) {
    continueAfterFailure = false
    let tr = language == "tr"
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--shots", "-language", language]
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
    app.launchArguments = ["--uitesting", "--shots", "-language", language]
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
    next.tap()
    XCTAssertTrue(app.buttons["dashboard.add"].waitForExistence(timeout: 10))
    app.tabBars.buttons[tr ? "İlerleme" : "Progress"].tap()
    let pro = app.buttons["progress.reports.pro"]
    reveal(pro, in: app)
    pro.tap()
    sleep(4)
    shot(language, "7-paywall")
  }
  // Hard coach styles (needs the debug-only `--shots-pro` flag): reaction, dashboard and coach card.
  @MainActor func runHard(language: String, level: String, label: String) {
    continueAfterFailure = false
    let tr = language == "tr"
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--shots", "--shots-pro", "-language", language]
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
    next.tap()
    let add = app.buttons["dashboard.add"]
    XCTAssertTrue(add.waitForExistence(timeout: 10))

    app.tabBars.buttons[tr ? "Ayarlar" : "Settings"].tap()
    let intensity = app.descendants(matching: .any)["settings.intensity"].firstMatch
    XCTAssertTrue(intensity.waitForExistence(timeout: 5))
    intensity.tap()
    sleep(1)
    shot(language, "\(label)-modes")
    app.buttons[level].firstMatch.tap()
    let confirm = app.buttons[tr ? "Anladım, aç" : "I understand, turn on"]
    if confirm.waitForExistence(timeout: 2) { confirm.tap() }
    app.tabBars.buttons[tr ? "Bugün" : "Today"].tap()

    func log(_ meal: String, _ foods: [(String, String, Int)], shotName: String) {
      XCTAssertTrue(add.waitForExistence(timeout: 5))
      add.tap()
      XCTAssertTrue(app.buttons["mealEditor.meal." + meal].waitForExistence(timeout: 5))
      app.buttons["mealEditor.meal." + meal].tap()
      for (id, query, portion) in foods { addFood(app, id: id, query: query, portion: portion) }
      app.buttons["mealEditor.save"].tap()
      let close = app.buttons["reaction.close"]
      XCTAssertTrue(close.waitForExistence(timeout: 8))
      sleep(1)
      shot(language, "\(label)-\(shotName)")
      close.tap()
    }
    log("lunch", [("burger", "Burger", 300), ("fries", tr ? "Patates kız" : "Fries", 250), ("cola", tr ? "Kola" : "Cola", 330)], shotName: "reaction-lunch")
    log("dinner", [("baklava", "Baklava", 200), ("chocolate", tr ? "Sütlü" : "Milk choc", 100)], shotName: "reaction-sweet")
    sleep(1)
    shot(language, "\(label)-dashboard")
    app.swipeUp()
    sleep(1)
    shot(language, "\(label)-coach")
    app.swipeDown()
    // Past 140% of the target the day line rotates with every entry; add small snacks until the
    // wanted line (if any) shows up, then capture the dashboard once more.
    guard let wanted = ProcessInfo.processInfo.environment["WANTED_LINE"] else { return }
    log("snack", [("chips", tr ? "cips" : "chips", 100)], shotName: "reaction-chips")
    for _ in 0..<14 {
      let hit = app.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS %@", wanted)).firstMatch
      app.swipeUp()
      if hit.exists { break }
      app.swipeDown()
      log("snack", [("apple", tr ? "Elma" : "Apple", 150)], shotName: "reaction-apple")
    }
    sleep(1)
    shot(language, "\(label)-wanted-coach")
    app.swipeDown()
    sleep(1)
    shot(language, "\(label)-wanted-dashboard")
  }
  @MainActor func testHardToxicTR() { runHard(language: "tr", level: "Toksik", label: "toxic") }
  @MainActor func testHardSavageTR() { runHard(language: "tr", level: "Sert", label: "savage") }
  // Toxic style, signed-off store lines: logs sweet dinners until each wanted reaction text shows.
  @MainActor func start(_ app: XCUIApplication, language: String, level: String) {
    let tr = language == "tr"
    app.launchArguments = ["--uitesting", "--shots", "--shots-pro", "-language", language]
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
    next.tap()
    XCTAssertTrue(app.buttons["dashboard.add"].waitForExistence(timeout: 10))
    app.tabBars.buttons[tr ? "Ayarlar" : "Settings"].tap()
    let intensity = app.descendants(matching: .any)["settings.intensity"].firstMatch
    XCTAssertTrue(intensity.waitForExistence(timeout: 5))
    intensity.tap()
    app.buttons[level].firstMatch.tap()
    let confirm = app.buttons[tr ? "Anladım, aç" : "I understand, turn on"]
    if confirm.waitForExistence(timeout: 2) { confirm.tap() }
    app.tabBars.buttons[tr ? "Bugün" : "Today"].tap()
  }

  @MainActor func testHuntToxicTR() {
    continueAfterFailure = false
    let app = XCUIApplication()
    start(app, language: "tr", level: "Toksik")
    let wanted = ["dizi çekilir": "dizi", "sipariş numarası": "siparis"]
    var found = Set<String>()
    for _ in 0..<30 where found.count < wanted.count {
      app.buttons["dashboard.add"].tap()
      XCTAssertTrue(app.buttons["mealEditor.meal.dinner"].waitForExistence(timeout: 5))
      app.buttons["mealEditor.meal.dinner"].tap()
      addFood(app, id: "baklava", query: "Baklava", portion: 100)
      app.buttons["mealEditor.save"].tap()
      let close = app.buttons["reaction.close"]
      XCTAssertTrue(close.waitForExistence(timeout: 8))
      sleep(1)
      for (text, tag) in wanted where !found.contains(tag) {
        let hit = app.descendants(matching: .any).matching(
          NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if hit.exists {
          shot("tr", "toxic-reaction-" + tag)
          found.insert(tag)
        }
      }
      close.tap()
    }
  }

  // A light toxic day (1,002 kcal) plus the food search, for the plain dashboard and search shots.
  @MainActor func testToxicLightTR() {
    continueAfterFailure = false
    let app = XCUIApplication()
    start(app, language: "tr", level: "Toksik")
    let add = app.buttons["dashboard.add"]
    func log(_ meal: String, _ foods: [(String, String, Int)]) {
      add.tap()
      XCTAssertTrue(app.buttons["mealEditor.meal." + meal].waitForExistence(timeout: 5))
      app.buttons["mealEditor.meal." + meal].tap()
      for (id, query, portion) in foods { addFood(app, id: id, query: query, portion: portion) }
      app.buttons["mealEditor.save"].tap()
      let close = app.buttons["reaction.close"]
      XCTAssertTrue(close.waitForExistence(timeout: 8))
      close.tap()
    }
    log("breakfast", [("menemen", "Menemen", 200), ("simit", "Simit", 100)])
    log("lunch", [("meatbeans", "Etli kuru", 240), ("ayran", "Ayran", 200)])
    sleep(1)
    shot("tr", "toxic-light-dashboard")
    app.swipeUp()
    sleep(1)
    shot("tr", "toxic-light-coach")
    app.swipeDown()
    add.tap()
    XCTAssertTrue(app.buttons["mealEditor.meal.dinner"].waitForExistence(timeout: 5))
    app.buttons["mealEditor.meal.dinner"].tap()
    let search = app.textFields["food.search"]
    reveal(search, in: app)
    search.tap()
    search.typeText("Me")
    sleep(1)
    shot("tr", "search-me")
  }
  // Settings scrolled to the style menu with Toxic selected, and the search results for "Menemen".
  @MainActor func testToxicExtrasTR() {
    continueAfterFailure = false
    let app = XCUIApplication()
    start(app, language: "tr", level: "Toksik")
    app.tabBars.buttons["Ayarlar"].tap()
    let intensity = app.descendants(matching: .any)["settings.intensity"].firstMatch
    XCTAssertTrue(intensity.waitForExistence(timeout: 5))
    reveal(intensity, in: app)
    intensity.tap()
    sleep(1)
    shot("tr", "toxic-modes-scrolled")
    app.buttons["Toksik"].firstMatch.tap()
    let confirm = app.buttons["Anladım, aç"]
    if confirm.waitForExistence(timeout: 2) { confirm.tap() }
    app.tabBars.buttons["Bugün"].tap()
    app.buttons["dashboard.add"].tap()
    XCTAssertTrue(app.buttons["mealEditor.meal.dinner"].waitForExistence(timeout: 5))
    app.buttons["mealEditor.meal.dinner"].tap()
    let search = app.textFields["food.search"]
    reveal(search, in: app)
    search.tap()
    search.typeText("Menemen\n")
    sleep(1)
    shot("tr", "search-menemen")
  }
  @MainActor func testPaywallTurkish() { runPaywall(language: "tr") }
  @MainActor func testPaywallEnglish() { runPaywall(language: "en") }
  @MainActor func testTurkish() { run(language: "tr") }
  @MainActor func testEnglish() { run(language: "en") }
}
