import Foundation
import Observation

struct MealDraftItem: Identifiable, Equatable {
  var id: UUID = UUID()
  var food: Food
  var grams: Double
  var meal: MealType

  init(id: UUID = UUID(), food: Food, grams: Double, meal: MealType) {
    self.id = id
    self.food = food
    self.grams = grams
    self.meal = meal
  }

  // Use the historical nutrition snapshot, even if the food database has since changed.
  init(entry: FoodEntry) throws {
    guard entry.amountInGrams.isFinite, entry.amountInGrams > 0 else {
      throw CocoaError(.validationMissingMandatoryProperty)
    }
    let scale = 100 / entry.amountInGrams
    var food =
      entry.foodSnapshot.flatMap { try? JSONDecoder().decode(Food.self, from: $0) }
      ?? FoodRepository.bundled?.foods.first(where: { $0.id == entry.foodID })
      ?? Food(
        id: entry.foodID, localizedNameTR: entry.foodNameTR, localizedNameEN: entry.foodNameEN,
        category: entry.category, servingName: "portion", servingAmount: entry.amountInGrams,
        caloriesPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0)
    food.amountUnit = entry.unit
    food.caloriesPer100g = entry.calories * scale
    food.proteinPer100g = entry.protein * scale
    food.carbsPer100g = entry.carbs * scale
    food.fatPer100g = entry.fat * scale
    // The selected variant retains the historical per-100 snapshot until the user changes it.
    if let index = food.preparations?.firstIndex(where: { $0.id == food.selectedPreparation }) {
      food.preparations?[index].calories = food.caloriesPer100g
      food.preparations?[index].protein = food.proteinPer100g
      food.preparations?[index].carbs = food.carbsPer100g
      food.preparations?[index].fat = food.fatPer100g
    }
    self.init(id: entry.id, food: food, grams: entry.amountInGrams, meal: entry.mealType)
  }

  var nutrition: NutritionPlan { food.nutrition(grams: grams) }
  var isValid: Bool {
    grams.isFinite && (1...3000).contains(grams)
      && [food.caloriesPer100g, food.proteinPer100g, food.carbsPer100g, food.fatPer100g]
        .allSatisfy { $0.isFinite && $0 >= 0 }
  }
}

@MainActor @Observable final class MealEditorViewModel {
  var meal: MealType
  private(set) var items: [MealDraftItem] = []
  private(set) var originals: [MealDraftItem] = []
  private(set) var isLoaded = false

  init(meal: MealType = .lunch) { self.meal = meal }

  func load(entries: [FoodEntry]) throws {
    guard !isLoaded else { return }
    let loaded = try entries.sorted { $0.date < $1.date }.map { try MealDraftItem(entry: $0) }
    items = loaded
    originals = loaded
    isLoaded = true
  }

  var currentItems: [MealDraftItem] { items.filter { $0.meal == meal } }
  var hasChanges: Bool { items != originals }
  var canSave: Bool { isLoaded && hasChanges && items.allSatisfy(\.isValid) }
  var total: NutritionPlan {
    currentItems.reduce(NutritionPlan(calories: 0, protein: 0, carbs: 0, fat: 0)) { sum, item in
      let n = item.nutrition
      return NutritionPlan(
        calories: sum.calories + n.calories, protein: sum.protein + n.protein,
        carbs: sum.carbs + n.carbs, fat: sum.fat + n.fat)
    }
  }
  func add(food: Food, grams: Double) {
    items.append(MealDraftItem(food: food, grams: grams, meal: meal))
  }
  func update(id: UUID, grams: Double, food: Food? = nil) {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return }
    items[index].grams = grams
    if let food, food.id == items[index].food.id { items[index].food = food }
  }
  func remove(id: UUID) { items.removeAll { $0.id == id } }
  func add(savedMeal: SavedMeal) throws {
    let additions = try savedMeal.items.map { item -> MealDraftItem in
      guard let food = item.food else { throw CocoaError(.coderReadCorrupt) }
      let draft = MealDraftItem(food: food, grams: item.grams, meal: meal)
      guard draft.isValid else { throw CocoaError(.validationNumberTooLarge) }
      return draft
    }
    guard !additions.isEmpty else { throw CocoaError(.validationMissingMandatoryProperty) }
    items.append(contentsOf: additions)
  }
}
