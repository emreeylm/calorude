import Foundation
import SwiftData

enum Sex: String, Codable, CaseIterable { case female, male }
enum Goal: String, Codable, CaseIterable { case lose, maintain, gain }
enum Activity: String, Codable, CaseIterable {
  case sedentary, light, moderate, active, intense
  var factor: Double {
    switch self {
    case .sedentary: 1.2
    case .light: 1.375
    case .moderate: 1.55
    case .active: 1.725
    case .intense: 1.9
    }
  }
}
enum MealType: String, Codable, CaseIterable { case breakfast, lunch, dinner, snack, treat }
enum CoachIntensity: String, Codable, CaseIterable {
  case optimistic, normal, savage, unhinged, nuclear
  // Only Normal is free; a lapsed subscription falls back to it.
  func available(isPro: Bool) -> CoachIntensity { isPro ? self : .normal }
}
enum Personality: String, Codable, CaseIterable { case standard, bro, sergeant, savage }

@Model final class UserProfile {
  @Attribute(.unique) var id: UUID
  var name: String
  var age: Int
  var sex: Sex
  var height: Double
  var currentWeight: Double
  var startingWeight: Double
  var targetWeight: Double
  var activityLevel: Activity
  var goalType: Goal
  var weeklyGoal: Double
  var dailyCalorieTarget: Double
  var proteinTarget: Double
  var carbTarget: Double
  var fatTarget: Double
  var preferredLanguage: String
  var coachIntensity: CoachIntensity
  var isOnboardingCompleted: Bool
  var createdAt: Date
  init(
    name: String, age: Int, sex: Sex, height: Double, weight: Double, target: Double,
    activity: Activity, goal: Goal, weekly: Double, plan: NutritionPlan, language: String
  ) {
    id = UUID()
    self.name = name
    self.age = age
    self.sex = sex
    self.height = height
    currentWeight = weight
    startingWeight = weight
    targetWeight = target
    activityLevel = activity
    goalType = goal
    weeklyGoal = weekly
    dailyCalorieTarget = plan.calories
    proteinTarget = plan.protein
    carbTarget = plan.carbs
    fatTarget = plan.fat
    preferredLanguage = language
    coachIntensity = .normal
    isOnboardingCompleted = true
    createdAt = .now
  }
}
@Model final class FoodEntry {
  @Attribute(.unique) var id: UUID
  var foodID: String
  var foodNameSnapshot: String
  var foodNameTR: String
  var foodNameEN: String
  var category: String
  var foodSnapshot: Data? = nil
  var preparationTitleKey: String? {
    foodSnapshot.flatMap { try? JSONDecoder().decode(Food.self, from: $0) }?.preparationTitleKey
  }
  var amountUnit: String? = nil
  var unit: String { amountUnit ?? Food.legacyUnit(id: foodID, category: category) }
  var amountInGrams: Double
  var calories: Double
  var protein: Double
  var carbs: Double
  var fat: Double
  var mealType: MealType
  var date: Date
  var calorieTargetSnapshot: Double
  var proteinTargetSnapshot: Double
  init(
    food: Food, grams: Double, meal: MealType, date: Date = .now, target: Double,
    proteinTarget: Double
  ) {
    id = UUID()
    foodID = food.id
    foodNameSnapshot = food.localizedNameEN
    foodNameTR = food.localizedNameTR
    foodNameEN = food.localizedNameEN
    category = food.category
    amountUnit = food.unit
    foodSnapshot = try? JSONEncoder().encode(food)
    amountInGrams = grams
    let n = food.nutrition(grams: grams)
    calories = n.calories
    protein = n.protein
    carbs = n.carbs
    fat = n.fat
    mealType = meal
    self.date = date
    calorieTargetSnapshot = target
    proteinTargetSnapshot = proteinTarget
  }
  func name(_ language: String) -> String { language == "tr" ? foodNameTR : foodNameEN }
}
@Model final class CustomFood {
  var amountUnit: String = "g"
  @Attribute(.unique) var id: String
  var name: String
  var calories: Double
  var protein: Double
  var carbs: Double
  var fat: Double
  init(
    name: String, calories: Double, protein: Double, carbs: Double, fat: Double,
    amountUnit: String = "g"
  ) {
    self.amountUnit = amountUnit
    id = UUID().uuidString
    self.name = name
    self.calories = calories
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
  }
  var food: Food {
    Food(
      id: id, localizedNameTR: name, localizedNameEN: name, category: "custom",
      servingName: "portion", servingAmount: 100, caloriesPer100g: calories,
      proteinPer100g: protein, carbsPer100g: carbs, fatPer100g: fat, amountUnit: amountUnit)
  }
}
@Model final class FavoriteFood {
  @Attribute(.unique) var foodID: String
  init(_ id: String) { foodID = id }
}
@Model final class SavedMeal {
  @Attribute(.unique) var id: UUID
  var name: String
  @Relationship(deleteRule: .cascade) var items: [SavedMealItem]
  init(name: String, items: [SavedMealItem]) {
    id = UUID()
    self.name = name
    self.items = items
  }
}
@Model final class SavedMealItem {
  var foodData: Data
  var grams: Double
  init(food: Food, grams: Double) throws {
    foodData = try JSONEncoder().encode(food)
    self.grams = grams
  }
  var food: Food? { try? JSONDecoder().decode(Food.self, from: foodData) }
}
@Model final class WeightEntry {
  @Attribute(.unique) var id: UUID
  var weight: Double
  var date: Date
  init(weight: Double, date: Date = .now) {
    id = UUID()
    self.weight = weight
    self.date = date
  }
}
@Model final class DailySummary {
  @Attribute(.unique) var day: Date
  var calories: Double
  var protein: Double
  var target: Double
  init(day: Date, calories: Double, protein: Double, target: Double) {
    self.day = day
    self.calories = calories
    self.protein = protein
    self.target = target
  }
}
@Model final class StreakState {
  var current: Int = 0
  var best: Int = 0
  init() {}
}
@Model final class AchievementState {
  @Attribute(.unique) var key: String
  var unlockedAt: Date
  init(_ key: String) {
    self.key = key
    unlockedAt = .now
  }
}
@Model final class AppPreferences {
  var language: String
  var appearance: String = "dark"
  var notificationsEnabled: Bool = false
  var personality: Personality = Personality.standard
  init(language: String) { self.language = language }
}

struct FoodPreparation: Codable, Identifiable, Hashable {
  var id: String
  var titleKey: String
  var calories: Double
  var protein: Double
  var carbs: Double
  var fat: Double
}
struct FoodPortion: Codable, Identifiable, Hashable {
  var id: String
  var titleKey: String
  var amount: Double
}
struct Food: Codable, Identifiable, Hashable {
  var id: String
  var localizedNameTR: String
  var localizedNameEN: String
  var category: String
  var servingName: String
  var servingAmount: Double
  var caloriesPer100g: Double
  var proteinPer100g: Double
  var carbsPer100g: Double
  var fatPer100g: Double
  // Legacy property names are retained for decoding saved foods. Values are per 100 of `unit`.
  var amountUnit: String? = nil
  var unit: String { amountUnit ?? Self.legacyUnit(id: id, category: category) }
  // Records saved before `amountUnit` existed carry no unit; ayran was the only non-drink liquid.
  static func legacyUnit(id: String, category: String) -> String {
    category == "drink" || id == "ayran" ? "ml" : "g"
  }
  var preparations: [FoodPreparation]? = nil
  var selectedPreparation: String? = nil
  var portions: [FoodPortion]? = nil
  var preparationTitleKey: String? {
    preparations?.first { $0.id == selectedPreparation }?.titleKey
  }
  func prepared(_ id: String) -> Food {
    guard let variant = preparations?.first(where: { $0.id == id }) else { return self }
    var result = self
    result.selectedPreparation = id
    result.caloriesPer100g = variant.calories
    result.proteinPer100g = variant.protein
    result.carbsPer100g = variant.carbs
    result.fatPer100g = variant.fat
    return result
  }
  var availablePortions: [FoodPortion] {
    if selectedPreparation == "raw", (preparations?.count ?? 0) > 1, id != "egg" { return [] }
    return portions ?? []
  }
  var unitKey: String { "unit." + unit }
  var per100Key: String { unit == "ml" ? "kcal.per100ml" : "kcal.per100" }
  func name(_ language: String) -> String { language == "tr" ? localizedNameTR : localizedNameEN }
  func nutrition(grams: Double) -> NutritionPlan {
    let scale = max(0, grams) / 100
    return NutritionPlan(
      calories: caloriesPer100g * scale, protein: proteinPer100g * scale,
      carbs: carbsPer100g * scale, fat: fatPer100g * scale)
  }
}
// V1 is the shape shipped at first release. Add SchemaV2 (copying the changed models into it)
// and a stage below before making any non-lightweight model change.
enum CalorudeSchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)
  static var models: [any PersistentModel.Type] {
    [
      UserProfile.self, FoodEntry.self, CustomFood.self, FavoriteFood.self, SavedMeal.self,
      SavedMealItem.self, WeightEntry.self, DailySummary.self, StreakState.self,
      AchievementState.self, AppPreferences.self,
    ]
  }
}

enum CalorudeMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] { [CalorudeSchemaV1.self] }
  static var stages: [MigrationStage] { [] }
}
