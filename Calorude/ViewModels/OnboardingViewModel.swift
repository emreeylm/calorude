import Foundation
import Observation

@MainActor @Observable final class OnboardingViewModel {
  var step = 0
  var name = ""
  var age = 28
  var sex = Sex.male
  var height = 175.0
  var weight = 80.0
  var target = 75.0
  var activity = Activity.light
  var goal = Goal.lose {
    didSet { if !weeklyOptions.contains(weekly) { weekly = 0.5 } }
  }
  var weekly = 0.5
  var weeklyOptions: [Double] { NutritionCalculator.weeklyOptions(for: goal) }
  var estimatedWeeklyChange: Double {
    NutritionCalculator.estimatedWeeklyChange(
      maintenance: NutritionCalculator.tdee(
        weight: weight, height: height, age: age, sex: sex, activity: activity),
      calories: plan.calories, goal: goal)
  }
  var isWeeklyChangeLimited: Bool { goal != .maintain && estimatedWeeklyChange + 0.025 < weekly }
  var eligible = false
  var error = false
  var valid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (18...80).contains(age)
      && (130...220).contains(height) && (40...250).contains(weight) && (40...250).contains(target)
      && eligible && (goal != .lose || (target < weight && target / pow(height / 100, 2) >= 18.5))
      && (goal != .gain || target > weight)
  }
  var plan: NutritionPlan {
    NutritionCalculator.plan(
      weight: weight, height: height, age: age, sex: sex, activity: activity, goal: goal,
      weekly: weekly)
  }
  func profile(language: String) -> UserProfile {
    UserProfile(
      name: name.trimmingCharacters(in: .whitespacesAndNewlines), age: age, sex: sex,
      height: height, weight: weight, target: goal == .maintain ? weight : target,
      activity: activity, goal: goal, weekly: goal == .maintain ? 0 : weekly, plan: plan,
      language: language)
  }
}
