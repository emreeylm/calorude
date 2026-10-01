import Foundation
import Observation

enum OnboardingStep: Int, CaseIterable {
  case goal, about, body, lifestyle, workouts, habits, safety, loading, result
  var name: String {
    switch self {
    case .goal: "goal"
    case .about: "about"
    case .body: "body"
    case .lifestyle: "lifestyle"
    case .workouts: "workouts"
    case .habits: "habits"
    case .safety: "safety"
    case .loading: "loading"
    case .result: "result"
    }
  }
}
enum DailyLife: Int, CaseIterable { case sitting, onFeet, physical }
enum WorkoutFrequency: Int, CaseIterable { case none, light, regular, intense }
enum EatingChallenge: String, CaseIterable {
  case sweets, nightSnacking, portions, eatingOut, irregular, lowAppetite, noIdea, notSure
  static func options(for goal: Goal) -> [EatingChallenge] {
    switch goal {
    case .lose: [.sweets, .nightSnacking, .portions, .eatingOut, .irregular, .notSure]
    case .muscle, .gain: [.lowAppetite, .irregular, .noIdea, .notSure]
    case .maintain: []
    }
  }
}
extension Activity {
  // Daily life sets the base and training adds to it; the nearest standard factor wins, which
  // keeps the estimate on the cautious side (a desk job plus 3–4 workouts is "lightly active").
  static func from(life: DailyLife, workouts: WorkoutFrequency) -> Activity {
    let factor = [1.2, 1.3, 1.4][life.rawValue] + [0, 0.1, 0.2, 0.3][workouts.rawValue]
    return allCases.min { abs($0.factor - factor) < abs($1.factor - factor) } ?? .light
  }
}

@MainActor @Observable final class OnboardingViewModel {
  var step = OnboardingStep.goal
  var name = ""
  var age = 28
  var sex = Sex.male
  var height = 175.0 {
    didSet { if !targetEdited { applyDefaultTarget() } }
  }
  var weight = 80.0 {
    didSet { if !targetEdited { applyDefaultTarget() } }
  }
  var target = 75.0 {
    didSet { if !applyingDefault { targetEdited = true } }
  }
  var goal = Goal.lose {
    didSet {
      if !targetEdited || validationKey(for: .body) != nil { applyDefaultTarget() }
      if !EatingChallenge.options(for: goal).contains(challenge) { challenge = .notSure }
    }
  }
  var lifestyle = DailyLife.onFeet { didSet { syncActivity() } }
  var workouts = WorkoutFrequency.light { didSet { syncActivity() } }
  var activity = Activity.light
  var challenge = EatingChallenge.notSure
  var eligible = false
  var errorKey: String?
  @ObservationIgnored private var targetEdited = false
  @ObservationIgnored private var applyingDefault = false

  private func syncActivity() { activity = .from(life: lifestyle, workouts: workouts) }

  // Until the user types a target of their own, it follows the goal and the current weight.
  private func applyDefaultTarget() {
    let raw: Double
    switch goal {
    case .lose:
      let floor = (18.5 * pow(height / 100, 2) * 2).rounded(.up) / 2
      raw = max(weight - 5, floor)
    case .muscle: raw = weight + 3
    case .gain: raw = weight + 4
    case .maintain: raw = weight
    }
    applyingDefault = true
    target = min(max(raw, 40), 250)
    applyingDefault = false
  }

  var effectiveTarget: Double { goal == .maintain ? weight : target }
  // Always automatic: the user picks a goal, the app picks a safe pace.
  var weekly: Double {
    NutritionCalculator.healthyWeeklyRate(weight: weight, height: height, goal: goal)
  }
  var maintenance: Double {
    NutritionCalculator.tdee(weight: weight, height: height, age: age, sex: sex, activity: activity)
  }
  var plan: NutritionPlan {
    NutritionCalculator.plan(
      weight: weight, height: height, age: age, sex: sex, activity: activity, goal: goal,
      weekly: weekly)
  }
  // The pace that survives the calorie floors and the 20 % deficit cap.
  var estimatedWeeklyChange: Double {
    NutritionCalculator.estimatedWeeklyChange(
      maintenance: maintenance, calories: plan.calories, goal: goal)
  }
  var weeksToGoal: Int? {
    guard goal != .maintain, estimatedWeeklyChange >= 0.05 else { return nil }
    return max(1, Int((abs(effectiveTarget - weight) / estimatedWeeklyChange).rounded(.up)))
  }
  var targetDate: Date? {
    weeksToGoal.flatMap { Calendar.current.date(byAdding: .weekOfYear, value: $0, to: .now) }
  }
  var tipKey: String { "ob.tip." + (goal == .maintain ? "maintain" : challenge.rawValue) }

  var infoSteps: [OnboardingStep] {
    [.goal, .about, .body, .lifestyle, .workouts, .habits, .safety].filter {
      !($0 == .habits && goal == .maintain)
    }
  }
  var progress: (position: Int, total: Int) {
    ((infoSteps.firstIndex(of: step) ?? infoSteps.count - 1) + 1, infoSteps.count)
  }

  func validationKey(for step: OnboardingStep) -> String? {
    switch step {
    case .about:
      if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "validation.name" }
      return (18...80).contains(age) ? nil : "validation.age"
    case .body:
      guard (130...220).contains(height), (40...250).contains(weight), (40...250).contains(target)
      else { return "validation.body" }
      let targetBMI = NutritionCalculator.bmi(weight: effectiveTarget, height: height)
      switch goal {
      case .lose:
        if target >= weight { return "validation.target.lose" }
        return targetBMI >= 18.5 ? nil : "validation.target.bmi"
      case .muscle, .gain:
        if target <= weight { return "validation.target.gain" }
        return targetBMI <= 30 ? nil : "validation.target.bmi.high"
      case .maintain: return nil
      }
    case .safety: return eligible ? nil : "validation.eligibility"
    default: return nil
    }
  }
  var valid: Bool {
    [OnboardingStep.about, .body, .safety].allSatisfy { validationKey(for: $0) == nil }
  }

  func advance() {
    if let key = validationKey(for: step) {
      errorKey = key
      return
    }
    errorKey = nil
    switch step {
    case .workouts: step = goal == .maintain ? .safety : .habits
    case .safety: step = .loading
    case .loading: step = .result
    case .result: break
    default: step = OnboardingStep(rawValue: step.rawValue + 1) ?? step
    }
  }
  func goBack() {
    errorKey = nil
    switch step {
    case .safety: step = goal == .maintain ? .workouts : .habits
    case .goal, .loading, .result: break
    default: step = OnboardingStep(rawValue: step.rawValue - 1) ?? step
    }
  }

  func profile(language: String) -> UserProfile {
    UserProfile(
      name: name.trimmingCharacters(in: .whitespacesAndNewlines), age: age, sex: sex,
      height: height, weight: weight, target: effectiveTarget, activity: activity, goal: goal,
      weekly: goal == .maintain ? 0 : weekly, plan: plan, language: language)
  }
}
