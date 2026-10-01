import Foundation
import SwiftData

@MainActor enum TrackingCoordinator {
  static func rebuild(context: ModelContext, profile: UserProfile, entries: [FoodEntry]) throws {
    let days = ProgressService.allDays(
      entries: entries, target: profile.dailyCalorieTarget, proteinTarget: profile.proteinTarget)
    let existing = try context.fetch(FetchDescriptor<DailySummary>())
    let byDay = Dictionary(uniqueKeysWithValues: existing.map { ($0.day, $0) })
    let validDays = Set(days.map(\.day))
    for obsolete in existing where !validDays.contains(obsolete.day) { context.delete(obsolete) }
    for day in days {
      if let summary = byDay[day.day] {
        summary.calories = day.calories
        summary.protein = day.protein
        summary.target = day.target
      } else {
        context.insert(
          DailySummary(
            day: day.day, calories: day.calories, protein: day.protein, target: day.target))
      }
    }
    let calculated = ProgressService.streak(days: days)
    let state = try context.fetch(FetchDescriptor<StreakState>()).first ?? StreakState()
    if state.modelContext == nil { context.insert(state) }
    state.current = calculated.current
    state.best = calculated.best
    let unlocked = try context.fetch(FetchDescriptor<AchievementState>())
    for key in AchievementService.earned(days: days)
    where !unlocked.contains(where: { $0.key == key }) {
      context.insert(AchievementState(key))
    }
    try context.save()
  }
}
struct TrackingFingerprint: Equatable {
  var entries: [FoodEntryFingerprint]
  var language: String
  var notifications: Bool
  var intensity: CoachIntensity
  var pro: Bool
  var day: Date
}

// Portion edits retain entry IDs, so derived records must observe nutrition values as well.
struct FoodEntryFingerprint: Equatable {
  let id: UUID
  let date: Date
  let meal: MealType
  let grams: Double
  let calories: Double
  let protein: Double
  let carbs: Double
  let fat: Double
  init(_ entry: FoodEntry) {
    id = entry.id
    date = entry.date
    meal = entry.mealType
    grams = entry.amountInGrams
    calories = entry.calories
    protein = entry.protein
    carbs = entry.carbs
    fat = entry.fat
  }
}
