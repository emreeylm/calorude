import Foundation

struct NutritionPlan: Equatable {
  var calories: Double
  var protein: Double
  var carbs: Double
  var fat: Double
}
enum NutritionCalculator {
  static func bmi(weight: Double, height: Double) -> Double {
    weight / pow(height / 100, 2)
  }
  // The pace is chosen for the user, never asked for. Loss stays near 0.5–0.75 % of body weight a
  // week (gentler under BMI 25); gains are slow so most of the extra weight is not fat.
  static func healthyWeeklyRate(weight: Double, height: Double, goal: Goal) -> Double {
    switch goal {
    case .maintain: return 0
    case .muscle: return 0.2
    case .gain: return 0.3
    case .lose:
      let overweight = bmi(weight: weight, height: height) >= 25
      return min(max(weight * (overweight ? 0.0075 : 0.005), 0.25), overweight ? 1.0 : 0.5)
    }
  }
  static func estimatedWeeklyChange(maintenance: Double, calories: Double, goal: Goal) -> Double {
    let delta = goal == .lose ? maintenance - calories : goal == .maintain ? 0 : calories - maintenance
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
    let delta: Double
    switch goal {
    case .lose: delta = -min(change, maintenance * 0.20)
    case .gain: delta = min(change, 350)
    case .muscle: delta = min(change, 300)
    case .maintain: delta = 0
    }
    let calories = max(sex == .male ? 1500 : 1200, maintenance + delta).rounded()
    let protein = min(weight * (goal == .muscle ? 2.0 : 1.6), calories * 0.30 / 4).rounded()
    let fat = (calories * 0.30 / 9).rounded()
    return NutritionPlan(
      calories: calories, protein: protein, carbs: (calories - protein * 4 - fat * 9) / 4, fat: fat)
  }
}
