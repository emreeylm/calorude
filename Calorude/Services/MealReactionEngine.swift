import Foundation

enum MealVerdict: String, CaseIterable { case balanced, snackHeavy, everyday }

struct MealReaction: Identifiable {
  let id = UUID()
  let verdict: MealVerdict
  let messageKey: String
  let nutrition: NutritionPlan
  let meal: MealType?
  let date: Date
  // Quotes the saved meal's own totals through {kcal}/{protein}/{carbs}/{fat} placeholders.
  @MainActor func message(_ l: AppLocalization) -> String {
    let values = [
      "kcal": nutrition.calories, "protein": nutrition.protein, "carbs": nutrition.carbs,
      "fat": nutrition.fat,
    ]
    return values.reduce(l.text(messageKey)) {
      $0.replacingOccurrences(of: "{\($1.key)}", with: l.number($1.value))
    }
  }
}

enum MealReactionEngine {
  // A lightweight composition heuristic, not a clinical food-quality score.
  // A little dessert never turns a mixed meal into a snack-heavy one.
  static func verdict(items: [MealDraftItem]) -> MealVerdict {
    let total = items.reduce(0) { $0 + $1.nutrition.calories }
    guard total.isFinite, total >= 80 else { return .everyday }
    let snackCalories = items.filter { item in
      ["fastFood", "sweet"].contains(item.food.category)
        || (item.food.category == "drink" && item.food.carbsPer100g >= 5)
    }.reduce(0) { $0 + $1.nutrition.calories }
    if snackCalories / total >= 0.6 { return .snackHeavy }
    let protein = items.reduce(0) { $0 + $1.nutrition.protein } * 4 / total
    let carbs = items.reduce(0) { $0 + $1.nutrition.carbs } * 4 / total
    let fat = items.reduce(0) { $0 + $1.nutrition.fat } * 9 / total
    if Set(items.map { $0.food.category }).count >= 2,
      (0.15...0.5).contains(protein), (0.2...0.7).contains(carbs), (0.1...0.45).contains(fat)
    {
      return .balanced
    }
    return .everyday
  }

  static func reaction(
    items: [MealDraftItem], originals: [MealDraftItem], date: Date,
    intensity: CoachIntensity, variant: Int = Int.random(in: 0..<3),
    excluding previousMessageKey: String? = nil
  ) -> MealReaction? {
    let before = Dictionary(uniqueKeysWithValues: originals.map { ($0.id, $0) })
    let changedMeals = Set(items.filter { before[$0.id] != $0 }.map(\.meal))
    // Cancel, unchanged saves and deletion-only saves never celebrate eating less.
    guard !changedMeals.isEmpty else { return nil }
    let relevant = items.filter { changedMeals.contains($0.meal) }
    guard !relevant.isEmpty else { return nil }
    let verdict = verdict(items: relevant)
    let prefix = "reaction.\(verdict.rawValue).\(intensity.rawValue)."
    let candidates = (0..<3).map { prefix + String($0) }
    // Start at a random variant, then use every variant before repeating this tone.
    let index =
      candidates.firstIndex(where: { $0 == previousMessageKey }).map {
        ($0 + 1) % candidates.count
      } ?? ((variant % candidates.count) + candidates.count) % candidates.count
    let total = relevant.reduce(NutritionPlan(calories: 0, protein: 0, carbs: 0, fat: 0)) {
      sum, item in
      let n = item.nutrition
      return NutritionPlan(
        calories: sum.calories + n.calories, protein: sum.protein + n.protein,
        carbs: sum.carbs + n.carbs, fat: sum.fat + n.fat)
    }
    return MealReaction(
      verdict: verdict,
      messageKey: candidates[index],
      nutrition: total, meal: changedMeals.count == 1 ? changedMeals.first : nil, date: date)
  }
}
