import Foundation
import SwiftData

@MainActor enum MealRepository {
  // Commit all additions, edits and removals together. Never mutate the diary while browsing.
  static func commit(
    items: [MealDraftItem], originals: [MealDraftItem], date: Date,
    profile: UserProfile, context: ModelContext
  ) throws {
    guard items.allSatisfy(\.isValid), Set(items.map(\.id)).count == items.count else {
      throw CocoaError(.validationNumberTooLarge)
    }
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: date)
    let end = calendar.date(byAdding: .day, value: 1, to: start)!
    let rows = try context.fetch(
      FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.date >= start && $0.date < end }))
    let existing = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
    let originalByID = Dictionary(uniqueKeysWithValues: originals.map { ($0.id, $0) })
    // Reject stale edits rather than overwriting a diary change made elsewhere.
    for original in originals {
      guard let row = existing[original.id], try MealDraftItem(entry: row) == original else {
        throw CocoaError(.persistentStoreSaveConflicts)
      }
    }
    for item in items where originalByID[item.id] == nil && existing[item.id] != nil {
      throw CocoaError(.persistentStoreSaveConflicts)
    }
    let historicalTarget = rows.sorted { $0.date < $1.date }.last
    let target = historicalTarget?.calorieTargetSnapshot ?? profile.dailyCalorieTarget
    let proteinTarget = historicalTarget?.proteinTargetSnapshot ?? profile.proteinTarget
    let retained = Set(items.map(\.id))
    do {
      for original in originals where !retained.contains(original.id) {
        if let row = existing[original.id] { context.delete(row) }
      }
      for item in items {
        if let original = originalByID[item.id], let row = existing[item.id] {
          guard item != original else { continue }
          if item.food != original.food {
            // Preparation changes select another per-100 nutrient profile, not a weight conversion.
            let nutrition = item.nutrition
            row.calories = nutrition.calories
            row.protein = nutrition.protein
            row.carbs = nutrition.carbs
            row.fat = nutrition.fat
          } else {
            let ratio = item.grams / row.amountInGrams
            row.calories *= ratio
            row.protein *= ratio
            row.carbs *= ratio
            row.fat *= ratio
          }
          row.foodSnapshot = try JSONEncoder().encode(item.food)
          row.amountInGrams = item.grams
          row.mealType = item.meal
        } else {
          let entry = FoodEntry(
            food: item.food, grams: item.grams, meal: item.meal, date: date,
            target: target, proteinTarget: proteinTarget)
          entry.id = item.id
          context.insert(entry)
        }
      }
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }
}
