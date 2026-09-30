import Foundation

struct NutritionPlan: Equatable {
  var calories: Double
  var protein: Double
  var carbs: Double
  var fat: Double
}
enum NutritionCalculator {
  static func weeklyOptions(for goal: Goal) -> [Double] {
    goal == .lose ? [0.5, 1.0] : [0.25, 0.5]
  }
  static func estimatedWeeklyChange(maintenance: Double, calories: Double, goal: Goal) -> Double {
    let delta = goal == .lose ? maintenance - calories : goal == .gain ? calories - maintenance : 0
    return max(0, delta) * 7 / 7700
  }
  static func bmr(weight: Double, height: Double, age: Int, sex: Sex) -> Double {
    10 * weight + 6.25 * height - 5 * Double(age) + (sex == .male ? 5 : -161)
  }
  static func tdee(weight: Double, height: Double, age: Int, sex: Sex, activity: Activity) -> Double
  {
    bmr(weight: weight, height: height, age: age, sex: sex) * activity.factor
  }
  // Conservative product limits, not a medical prescription. No compensatory restriction.
  static func plan(
    weight: Double, height: Double, age: Int, sex: Sex, activity: Activity, goal: Goal,
    weekly: Double
  ) -> NutritionPlan {
    let maintenance = tdee(weight: weight, height: height, age: age, sex: sex, activity: activity)
    let change = min(max(weekly, 0), goal == .lose ? 1.0 : 0.5) * 7700 / 7
    let delta =
      goal == .lose ? -min(change, maintenance * 0.20) : goal == .gain ? min(change, 350) : 0
    let calories = max(sex == .male ? 1500 : 1200, maintenance + delta).rounded()
    let protein = min(weight * 1.6, calories * 0.30 / 4).rounded()
    let fat = (calories * 0.30 / 9).rounded()
    return NutritionPlan(
      calories: calories, protein: protein, carbs: (calories - protein * 4 - fat * 9) / 4, fat: fat)
  }
}
