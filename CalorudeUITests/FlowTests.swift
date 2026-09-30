import XCTest

final class FlowTests: XCTestCase {
  @MainActor func runFlow(language: String) {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "-language", language]
    app.launch()
    let name = app.textFields["onboarding.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 15))
    attach(app, "\(language)-onboarding")
    app.switches["onboarding.eligibility"].tap()
    name.tap()
    name.typeText("Emre\n")
    let next = app.buttons["onboarding.next"]
    next.tap()
    XCTAssertTrue(
      app.staticTexts[language == "tr" ? "ÖNCE\nGERÇEKLER." : "FIRST,\nTHE FACTS."]
        .waitForExistence(timeout: 5))
    next.tap()
    XCTAssertTrue(
      app.staticTexts[language == "tr" ? "PLANI\nKURALIM." : "MAKE\nA PLAN."].waitForExistence(
        timeout: 5))
    next.tap()
    XCTAssertTrue(
      app.staticTexts[language == "tr" ? "PLANIN HAZIR" : "YOUR PLAN IS READY"].waitForExistence(
        timeout: 5))
    attach(app, "\(language)-plan")
    next.tap()
    let add = app.buttons["dashboard.add"]
    XCTAssertTrue(add.waitForExistence(timeout: 10))
    attach(app, "\(language)-dashboard-empty")
    app.swipeUp()
    add.tap()
    let breakfast = app.buttons["mealEditor.meal.breakfast"]
    XCTAssertTrue(breakfast.waitForExistence(timeout: 5))
    breakfast.tap()
    XCTAssertTrue(breakfast.isSelected)
    let lunch = app.buttons["mealEditor.meal.lunch"]
    lunch.tap()
    XCTAssertTrue(lunch.isSelected)
    attach(app, "\(language)-meal-cards")
    let treat = app.buttons["mealEditor.meal.treat"]
    treat.tap()
    XCTAssertTrue(treat.isSelected)
    lunch.tap()
    let breakfastFilter = app.buttons["food.filter.breakfast"]
    reveal(breakfastFilter, in: app)
    breakfastFilter.tap()
    XCTAssertFalse(app.buttons["food.result.chicken"].exists)
    app.buttons["food.filter.popular"].tap()
    addFood(app, id: "rice", query: language == "tr" ? "Pirinç" : "Rice", grams: 150)
    addFood(app, id: "chicken", query: language == "tr" ? "Tavuk" : "Chicken", grams: 200)
    addFood(app, id: "yogurt", query: language == "tr" ? "Yoğurt" : "Yogurt", grams: 100)
    // Every food returns to the same editor; none closes the sheet or commits alone.
    let save = app.buttons["mealEditor.save"]
    XCTAssertTrue(save.isEnabled)
    app.swipeDown()
    attach(app, "\(language)-meal-draft")
    save.tap()
    closeReaction(
      app, title: language == "tr" ? "Vay be. Beklemiyordum." : "Well. Didn’t see that coming.")
    let edit = app.buttons["meal.edit.lunch"]
    reveal(edit, in: app)
    XCTAssertTrue(edit.waitForExistence(timeout: 5))
    attach(app, "\(language)-dashboard-logged")
    edit.tap()
    let rice = app.buttons["mealEditor.item.rice"]
    XCTAssertTrue(rice.waitForExistence(timeout: 5))
    rice.tap()
    app.buttons["portion.200"].tap()
    app.buttons["portion.confirm"].tap()
    let remove = app.buttons["mealEditor.remove.chicken"]
    XCTAssertTrue(remove.waitForExistence(timeout: 5))
    remove.tap()
    attach(app, "\(language)-meal-edited")
    save.tap()
    closeReaction(
      app, title: language == "tr" ? "Koçun bir çift lafı var." : "Coach has a few words.")
    reveal(edit, in: app)
    edit.tap()
    XCTAssertTrue(app.buttons["mealEditor.item.rice"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["mealEditor.item.chicken"].exists)
    XCTAssertTrue(app.buttons["mealEditor.item.yogurt"].exists)
    XCTAssertTrue(app.buttons["mealEditor.item.rice"].label.contains("200"))
    // A later canceled portion edit must leave the saved diary untouched.
    app.buttons["mealEditor.item.rice"].tap()
    app.buttons["portion.50"].tap()
    app.buttons["portion.confirm"].tap()
    app.buttons["mealEditor.cancel"].tap()
    app.buttons[language == "tr" ? "Değişiklikleri sil" : "Discard changes"].tap()
    reveal(edit, in: app)
    edit.tap()
    XCTAssertTrue(app.buttons["mealEditor.item.rice"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["mealEditor.item.rice"].label.contains("200"))
    app.buttons["mealEditor.cancel"].tap()
    XCTAssertFalse(app.buttons["reaction.close"].exists)
    reveal(edit, in: app)
    edit.tap()
    addFood(app, id: "chocolate", query: language == "tr" ? "çikolata" : "chocolate", grams: 200)
    save.tap()
    closeReaction(app, title: language == "tr" ? "Yapma dostum." : "Bro. Come on.")
    reveal(edit, in: app)
    edit.tap()
    let drinkSearch = app.textFields["food.search"]
    reveal(drinkSearch, in: app)
    drinkSearch.tap()
    drinkSearch.typeText((language == "tr" ? "Kola" : "Cola") + "\n")
    let cola = app.buttons["food.result.cola"]
    reveal(cola, in: app)
    cola.tap()
    XCTAssertTrue(
      app.staticTexts[language == "tr" ? "Mililitre miktarı" : "Amount in milliliters"].exists)
    XCTAssertEqual(app.buttons["portion.330"].label, "330 ml")
    app.descendants(matching: .any)["portion.unit"].firstMatch.tap()
    app.buttons[language == "tr" ? "Su bardağı" : "Glass"].tap()
    let quantity = app.textFields["portion.grams"]
    quantity.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
    let oldAmount = quantity.value as? String ?? ""
    quantity.typeText(
      String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldAmount.count) + "2")
    app.buttons["portion.keyboardDone"].tap()
    XCTAssertTrue(app.staticTexts["portion.calories"].label.contains("168"))
    attach(app, "drink-glass-detail")
    app.buttons["portion.330"].tap()
    app.buttons["portion.confirm"].tap()
    save.tap()
    closeReaction(app, title: language == "tr" ? "Yapma dostum." : "Bro. Come on.")
    XCTAssertTrue(app.staticTexts["330 ml"].exists)
    app.tabBars.buttons[language == "tr" ? "İlerleme" : "Progress"].tap()
    attach(app, "\(language)-progress")
    app.tabBars.buttons[language == "tr" ? "Ayarlar" : "Settings"].tap()
    app.descendants(matching: .any)["settings.language"].firstMatch.tap()
    app.buttons[language == "tr" ? "English" : "Türkçe"].tap()
    XCTAssertTrue(
      app.navigationBars[language == "tr" ? "Settings" : "Ayarlar"].waitForExistence(timeout: 5))
    attach(app, "\(language)-switched")
    app.descendants(matching: .any)["settings.appearance"].firstMatch.tap()
    app.buttons[language == "tr" ? "Light" : "Açık"].tap()
    attach(app, "\(language)-light")
  }
  @MainActor func closeReaction(_ app: XCUIApplication, title: String) {
    let close = app.buttons["reaction.close"]
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts[title].exists)
    XCTAssertTrue(app.staticTexts["reaction.message"].exists)
    XCTAssertTrue(app.buttons["reaction.share"].exists)
    let message = app.staticTexts["reaction.message"].label
    attach(app, "meal-reaction-" + title)
    close.tap()
    let card = app.descendants(matching: .any)["coach.card"].firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    XCTAssertFalse(
      card.label.contains(message),
      "Dashboard must evaluate the day, separately from the meal popup")
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
  @MainActor func addFood(_ app: XCUIApplication, id: String, query: String, grams: Int) {
    let search = app.textFields["food.search"]
    reveal(search, in: app)
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText(query + "\n")
    let result = app.buttons["food.result." + id]
    reveal(result, in: app)
    XCTAssertTrue(result.waitForExistence(timeout: 5))
    result.tap()
    if id == "chicken" {
      let picker = app.descendants(matching: .any)["portion.preparation"].firstMatch
      XCTAssertTrue(picker.waitForExistence(timeout: 5))
      picker.tap()
      let raw = app.buttons.matching(
        NSPredicate(format: "label IN %@", ["Çiğ / kuru tartım", "Raw / dry weight"])
      ).firstMatch
      raw.tap()
      app.buttons["portion.100"].tap()
      XCTAssertTrue(app.staticTexts["portion.calories"].label.contains("120"))
      attach(app, "chicken-raw-detail")
      picker.tap()
      app.buttons.matching(NSPredicate(format: "label IN %@", ["Pişmiş tartım", "Cooked weight"]))
        .firstMatch.tap()
      XCTAssertTrue(app.staticTexts["portion.calories"].label.contains("165"))
    }
    app.buttons["portion.\(grams)"].tap()
    app.buttons["portion.confirm"].tap()
    XCTAssertTrue(app.buttons["mealEditor.save"].waitForExistence(timeout: 5))
  }
  @MainActor func attach(_ app: XCUIApplication, _ name: String) {
    let a = XCTAttachment(screenshot: app.screenshot())
    a.name = name
    a.lifetime = .keepAlways
    add(a)
  }
  @MainActor func testTurkishFlow() { runFlow(language: "tr") }
  @MainActor func testEnglishFlow() { runFlow(language: "en") }
}
