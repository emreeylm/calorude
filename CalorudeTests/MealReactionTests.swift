import XCTest

@testable import Calorude

@MainActor final class MealReactionTests: XCTestCase {
  func items(_ values: [(String, Double)]) throws -> [MealDraftItem] {
    let foods = try FoodRepository().foods
    return try values.map { id, grams in
      MealDraftItem(food: try XCTUnwrap(foods.first { $0.id == id }), grams: grams, meal: .lunch)
    }
  }
  func testCompositionAndSingleFood() throws {
    let balanced = try items([("rice", 150), ("chicken", 200), ("yogurt", 100)])
    XCTAssertEqual(MealReactionEngine.verdict(items: balanced), .balanced)
    XCTAssertEqual(
      MealReactionEngine.verdict(items: try items([("chips", 100), ("cola", 330)])), .snackHeavy)
    XCTAssertEqual(MealReactionEngine.verdict(items: try items([("chocolate", 50)])), .snackHeavy)
    XCTAssertEqual(MealReactionEngine.verdict(items: try items([("apple", 150)])), .everyday)
    XCTAssertNotEqual(
      MealReactionEngine.verdict(items: balanced + (try items([("chocolate", 10)]))), .snackHeavy)
    XCTAssertEqual(MealReactionEngine.verdict(items: try items([("chicken", 5)])), .everyday)
  }
  func testOnlyCommittedChangesGetAReaction() throws {
    let original = try items([("rice", 150)])
    XCTAssertNil(
      MealReactionEngine.reaction(
        items: original, originals: original, date: .now, intensity: .normal))
    XCTAssertNil(
      MealReactionEngine.reaction(items: [], originals: original, date: .now, intensity: .normal))
    var dinner = try items([("chicken", 200)])
    dinner[0].meal = .dinner
    let result = try XCTUnwrap(
      MealReactionEngine.reaction(
        items: original + dinner, originals: original, date: .now, intensity: .normal))
    XCTAssertEqual(result.meal, .dinner)
    XCTAssertEqual(result.nutrition.calories, 330, accuracy: 0.01)
    XCTAssertEqual(original[0].grams, 150)
  }
  func testConsecutiveSavesNeverRepeatAcrossVerdictsAndIntensities() throws {
    let scenarios = try [
      items([("rice", 150), ("chicken", 200), ("yogurt", 100)]),
      items([("chocolate", 100)]), items([("apple", 150)]),
    ]
    for foods in scenarios {
      for intensity in CoachIntensity.allCases {
        var previous: String?
        var seen = Set<String>()
        for variant in -12..<12 {
          let result = try XCTUnwrap(
            MealReactionEngine.reaction(
              items: foods, originals: [], date: .now, intensity: intensity,
              variant: variant, excluding: previous))
          XCTAssertNotEqual(result.messageKey, previous)
          seen.insert(result.messageKey)
          previous = result.messageKey
        }
        XCTAssertEqual(seen.count, 3)
      }
    }
  }
  @MainActor func testAllMessagesLocalizedAndStoryExports() throws {
    for language in ["tr", "en"] {
      let l = AppLocalization(language: language)
      for verdict in MealVerdict.allCases {
        for intensity in CoachIntensity.allCases {
          for variant in 0..<3 {
            let key = "reaction.\(verdict.rawValue).\(intensity.rawValue).\(variant)"
            XCTAssertNotEqual(l.text(key), key)
            let filled = MealReaction(
              verdict: verdict, messageKey: key,
              nutrition: NutritionPlan(calories: 646, protein: 70, carbs: 47, fat: 18),
              meal: .lunch, date: .now
            ).message(l)
            XCTAssertFalse(filled.contains("{"), key)
          }
        }
        let result = MealReaction(
          verdict: verdict, messageKey: "reaction.\(verdict.rawValue).unhinged.0",
          nutrition: NutritionPlan(calories: 646, protein: 70, carbs: 47, fat: 18), meal: .lunch,
          date: .now)
        let url = try MealReactionRenderer.render(result, l: l)
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
        XCTAssertEqual(image.width, 1080)
        XCTAssertEqual(image.height, 1920)
        let attachment = XCTAttachment(contentsOfFile: url)
        attachment.name = "reaction-\(language)-\(verdict.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
        try FileManager.default.removeItem(at: url)
      }
    }
  }
}
