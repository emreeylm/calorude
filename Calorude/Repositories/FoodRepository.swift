import Foundation
import SwiftData

struct FoodRepository {
  static let bundled = try? FoodRepository()
  let foods: [Food]
  init(bundle: Bundle = .main) throws {
    guard let url = bundle.url(forResource: "foods", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    foods = try JSONDecoder().decode([Food].self, from: Data(contentsOf: url))
  }
  func search(_ query: String, language: String) -> [Food] {
    query.isEmpty ? foods : foods.filter { $0.name(language).localizedStandardContains(query) }
  }
  @MainActor static func log(
    food: Food, grams: Double, meal: MealType, date: Date, profile: UserProfile,
    context: ModelContext
  ) throws {
    guard grams.isFinite, (1...3000).contains(grams) else {
      throw CocoaError(.validationNumberTooLarge)
    }
    context.insert(
      FoodEntry(
        food: food, grams: grams, meal: meal, date: date, target: profile.dailyCalorieTarget,
        proteinTarget: profile.proteinTarget))
    do { try context.save() } catch {
      context.rollback()
      throw error
    }
  }
}
