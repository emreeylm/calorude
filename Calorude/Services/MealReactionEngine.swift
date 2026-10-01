import Foundation

// How a saved meal reads against the whole day. Whether the food is balanced and whether it fits
// the day are judged separately, so the same dish can earn different comments.
enum MealState: String, CaseIterable {
  case goodFits, bigButFits, balancedSqueezes, unbalancedWithin, unbalancedOver, incomplete
}

struct MealFacts: Equatable {
  var mealCalories: Double
  var mealProtein: Double
  // The whole day after this save. The edited meal is counted once, as part of the saved items.
  var dayTotal: Double
  var target: Double
  var left: Double { max(0, target - dayTotal) }
  var over: Double { max(0, dayTotal - target) }
  var percent: Int { target > 0 ? Int((mealCalories / target * 100).rounded()) : 0 }
}

struct MealReaction: Identifiable {
  let id = UUID()
  let state: MealState
  let messageKey: String
  let nutrition: NutritionPlan
  let facts: MealFacts
  let meal: MealType?
  let date: Date

  private var tokens: [String: Double] {
    [
      "meal": facts.mealCalories, "total": facts.dayTotal, "target": facts.target,
      "left": facts.left, "over": facts.over, "pct": Double(facts.percent),
      "protein": facts.mealProtein,
    ]
  }
  @MainActor private func fill(_ template: String, _ l: AppLocalization) -> String {
    tokens.reduce(template) {
      $0.replacingOccurrences(of: "{\($1.key)}", with: l.number($1.value))
    }.replacingOccurrences(of: " kcal", with: "\u{00A0}kcal")
  }
  var showsSafetyNote: Bool { state == .unbalancedOver || state == .incomplete || facts.over > 0 }
  // The main line: a short, shareable quote.
  @MainActor func message(_ l: AppLocalization) -> String { fill(l.text(messageKey), l) }
  // The secondary line: the numbers behind the quote.
  @MainActor func detail(_ l: AppLocalization) -> String {
    fill(l.text(facts.over > 0 ? "reaction.detail.over" : "reaction.detail.left"), l)
  }
}

enum MealReactionEngine {
  static let variants = 8
  static let recentLimit = 8
  // Context lines are only eligible when the saved data supports their claim.
  private static let tagOrder = [
    "thirdSweet", "repeatOver", "repeatTreat", "riceChicken", "sugaryDrink", "lowProtein", "craving",
    "bigPortion", "nightMale", "nightFemale", "evening",
  ]
  private static let riceIDs: Set<String> = ["rice", "brownrice", "chickenrice"]
  private static let chickenIDs: Set<String> = [
    "chicken", "chickenrice", "chickensote", "chickensalad", "chickensandwich",
  ]
  private static let mainMeals: Set<MealType> = [.breakfast, .lunch, .dinner]

  private static func isSnacky(_ item: MealDraftItem) -> Bool {
    ["fastFood", "sweet"].contains(item.food.category)
      || (item.food.category == "drink" && item.food.carbsPer100g >= 5)
  }

  // A lightweight composition heuristic, not a clinical food-quality score.
  static func isBalanced(_ items: [MealDraftItem]) -> Bool {
    let calories = items.reduce(0) { $0 + $1.nutrition.calories }
    guard calories > 0 else { return true }
    let snack = items.filter(isSnacky).reduce(0) { $0 + $1.nutrition.calories }
    if snack / calories >= 0.6 { return false }
    if calories < 250 { return true }
    let protein = items.reduce(0) { $0 + $1.nutrition.protein } * 4 / calories
    let carbs = items.reduce(0) { $0 + $1.nutrition.carbs } * 4 / calories
    let fat = items.reduce(0) { $0 + $1.nutrition.fat } * 9 / calories
    return protein >= 0.15 && fat <= 0.5 && (0.15...0.75).contains(carbs)
      && Set(items.map { $0.food.category }).count >= 2
  }

  static func classify(
    relevant: [MealDraftItem], facts: MealFacts, isLastMeal: Bool
  ) -> MealState {
    let meals = Set(relevant.map(\.meal))
    if facts.mealCalories < 120 && meals.isSubset(of: mainMeals) { return .incomplete }
    let balanced = isBalanced(relevant)
    if facts.dayTotal > facts.target * 1.02 { return balanced ? .balancedSqueezes : .unbalancedOver }
    if !balanced { return .unbalancedWithin }
    let big = facts.percent >= 35
    let remaining = facts.target - facts.dayTotal
    if big && !isLastMeal && remaining < facts.target * 0.2 { return .balancedSqueezes }
    if big && remaining >= facts.target * 0.15 { return .bigButFits }
    return .goodFits
  }

  // `cravingDays` counts the days of the last week that had sweets or fast food and `overDays` the
  // days over target, both including this one, so "again" lines only appear when the log shows it.
  // The night-out jokes follow the sex chosen in onboarding; the neutral `evening` lines stay in.
  static func tags(
    relevant: [MealDraftItem], all: [MealDraftItem], facts: MealFacts, isLateMeal: Bool,
    cravingDays: Int = 0, overDays: Int = 0, sex: Sex = .male
  ) -> Set<String> {
    var tags = Set<String>()
    let ids = Set(relevant.map(\.food.id))
    if !ids.isDisjoint(with: riceIDs) && !ids.isDisjoint(with: chickenIDs) { tags.insert("riceChicken") }
    if !ids.isDisjoint(with: chickenIDs) { tags.insert("chicken") }
    if facts.percent >= 40 { tags.insert("bigPortion") }
    let meals = Set(relevant.map(\.meal))
    if meals.isSubset(of: [.snack, .treat]) && facts.mealCalories >= 300 { tags.insert("bigSnack") }
    if facts.mealCalories >= 400 {
      if !relevant.contains(where: { $0.food.category == "vegetable" }) { tags.insert("noVeg") }
      if facts.mealProtein < 15 { tags.insert("lowProtein") }
    }
    if relevant.contains(where: { $0.food.category == "drink" && $0.food.carbsPer100g >= 5 }) {
      tags.insert("sugaryDrink")
    }
    if relevant.contains(where: { ["sweet", "fastFood"].contains($0.food.category) }) {
      tags.insert("craving")
    }
    if relevant.count >= 4 { tags.insert("buffet") }
    if cravingDays >= 3 { tags.insert("repeatTreat") }
    if overDays >= 3 && facts.over > 0 { tags.insert("repeatOver") }
    if isLateMeal {
      tags.insert("evening")
      tags.insert(sex == .female ? "nightFemale" : "nightMale")
    }
    if all.filter({ $0.food.category == "sweet" }).count >= 3 { tags.insert("thirdSweet") }
    return tags
  }

  static func candidateKeys(
    state: MealState, voice: CoachVoice, tags: Set<String>, exists: (String) -> Bool
  ) -> [String] {
    let base = "coach.meal.\(state.rawValue).\(voice.level.key)"
    let generic = (0..<variants).map { "\(base).\($0)" }
    var special: [String] = []
    for tag in tagOrder where tags.contains(tag) {
      for index in 0..<8 where exists("\(base).\(tag).\(index)") {
        special.append("\(base).\(tag).\(index)")
      }
    }
    // Lines that fit this exact meal weigh double against the general ones.
    return special + special + generic
  }

  static func reaction(
    items: [MealDraftItem], originals: [MealDraftItem], date: Date, target: Double,
    now: Date = .now, voice: CoachVoice, variant: Int = Int.random(in: 0..<10_000),
    recentKeys: [String] = [], cravingDays: Int = 0, overDays: Int = 0, sex: Sex = .male,
    calendar: Calendar = .current, exists: (String) -> Bool
  ) -> MealReaction? {
    let before = Dictionary(uniqueKeysWithValues: originals.map { ($0.id, $0) })
    let changedMeals = Set(items.filter { before[$0.id] != $0 }.map(\.meal))
    // Cancel, unchanged saves and deletion-only saves never celebrate eating less.
    guard !changedMeals.isEmpty else { return nil }
    let relevant = items.filter { changedMeals.contains($0.meal) }
    guard !relevant.isEmpty else { return nil }
    let nutrition = relevant.reduce(NutritionPlan(calories: 0, protein: 0, carbs: 0, fat: 0)) {
      sum, item in
      let n = item.nutrition
      return NutritionPlan(
        calories: sum.calories + n.calories, protein: sum.protein + n.protein,
        carbs: sum.carbs + n.carbs, fat: sum.fat + n.fat)
    }
    let facts = MealFacts(
      mealCalories: nutrition.calories, mealProtein: nutrition.protein,
      dayTotal: items.reduce(0) { $0 + $1.nutrition.calories }, target: target)
    let isToday = calendar.isDate(date, inSameDayAs: now)
    let lateHour = isToday && calendar.component(.hour, from: now) >= 19
    let isLate = changedMeals.contains(.dinner) || changedMeals.contains(.treat) || lateHour
    let state = classify(
      relevant: relevant, facts: facts, isLastMeal: changedMeals.contains(.dinner) || lateHour)
    let candidates = candidateKeys(
      state: state, voice: voice,
      tags: tags(
        relevant: relevant, all: items, facts: facts, isLateMeal: isLate,
        cravingDays: cravingDays, overDays: overDays, sex: sex),
      exists: exists)
    let fresh = candidates.filter { !recentKeys.contains($0) }
    let pool = fresh.isEmpty ? candidates : fresh
    let key = pool[((variant % pool.count) + pool.count) % pool.count]
    return MealReaction(
      state: state, messageKey: key, nutrition: nutrition, facts: facts,
      meal: changedMeals.count == 1 ? changedMeals.first : nil, date: date)
  }
}
