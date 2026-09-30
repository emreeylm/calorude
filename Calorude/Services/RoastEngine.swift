import Foundation

enum RoastSeverity: String, Codable { case positive, neutral, warning, roast, celebration }
enum RoastCategory: String, Codable {
  case calories, protein, weight, streak, meal, weekly, general, fastFood, sweet, returningUser
}
struct RoastMessage: Codable, Identifiable {
  var id: String
  var titleKey: String
  var messageKey: String
  var severity: RoastSeverity
  var category: RoastCategory
  var rule: String
  var intensity: CoachIntensity
  var pro: Bool
}
struct RoastContext {
  var calories: Double
  var target: Double
  var protein: Double
  var proteinTarget: Double
  var hour: Int
  var goal: Goal
  var streak: Int
  var weeklyAdherence: Double
  var weightTrend: Double?
  var loggedMeals: Int
  var daysSinceLastLog: Int
  var fastFood: Bool = false
  var sweet: Bool = false
}
extension RoastContext {
  // Messages quote the day's real numbers through {token} placeholders. Units always follow a
  // token in the catalog so Turkish suffixes never attach to a number.
  @MainActor func text(_ template: String, l: AppLocalization) -> String {
    let values: [String: String] = [
      "kcal": l.number(calories), "target": l.number(target),
      "over": l.number(max(0, calories - target)), "left": l.number(max(0, target - calories)),
      "protein": l.number(protein), "proteinTarget": l.number(proteinTarget),
      "proteinLeft": l.number(max(0, proteinTarget - protein)),
      "streak": l.number(Double(streak)), "days": l.number(Double(daysSinceLastLog)),
      "weekDays": l.number((weeklyAdherence * 7).rounded()),
      "trend": l.number(abs(weightTrend ?? 0), digits: 1),
    ]
    return values.reduce(template) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
  }
}
struct RoastEngine {
  // Decoded once; views re-evaluate on every render.
  static let bundled = RoastEngine()
  var messages: [RoastMessage]
  init(bundle: Bundle = .main) {
    if let url = bundle.url(forResource: "roasts", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let decoded = try? JSONDecoder().decode([RoastMessage].self, from: data)
    {
      messages = decoded
    } else {
      messages = []
    }
  }
  init(messages: [RoastMessage]) { self.messages = messages }
  // Dashboard comments depend only on the selected day's totals and time of day.
  static func dailyRule(for c: RoastContext) -> String {
    if c.loggedMeals == 0 { return "empty" }
    let ratio = c.calories / max(c.target, 1)
    if c.hour >= 18 && ratio < 0.5 { return "low" }
    if ratio > 1.4 { return "veryHigh" }
    if ratio > 1.1 { return c.hour < 18 ? "earlyHigh" : "high" }
    if c.hour >= 18 && c.protein < c.proteinTarget * 0.6 { return "protein" }
    if (0.9...1.1).contains(ratio) && c.protein >= c.proteinTarget * 0.9 { return "perfect" }
    return "steady"
  }
  static func rule(for c: RoastContext) -> String {
    let ratio = c.calories / max(c.target, 1)
    if c.hour >= 18 && ratio < 0.5 { return "low" }
    if ratio > 1.4 { return "veryHigh" }
    if ratio > 1.1 && c.hour < 18 { return "earlyHigh" }
    if ratio > 1.1 { return "high" }
    if c.daysSinceLastLog >= 3 && c.loggedMeals > 0 { return "return" }
    if c.loggedMeals == 0 { return "empty" }
    if c.hour >= 18 && c.protein < c.proteinTarget * 0.6 { return "protein" }
    if c.streak >= 3 && [3, 7, 14, 30, 60, 100].contains(c.streak) { return "streak" }
    if (0.9...1.1).contains(ratio) && c.protein >= c.proteinTarget * 0.9 { return "perfect" }
    if c.weeklyAdherence >= 0.7 { return "week" }
    if c.fastFood { return "fast" }
    if c.sweet { return "sweet" }
    if let trend = c.weightTrend, abs(trend) > 0.2 { return "weight" }
    return "steady"
  }
  func evaluate(
    _ context: RoastContext, intensity: CoachIntensity, personality: Personality, isPro: Bool,
    seed: Int, dailyOnly: Bool = false
  ) -> RoastMessage {
    let rule = dailyOnly ? Self.dailyRule(for: context) : Self.rule(for: context)
    let allowed = messages.filter { $0.rule == rule && (isPro || !$0.pro) }
    let tier = intensity.available(isPro: isPro)
    let matched = allowed.filter { $0.intensity == tier }
    let pool = matched.isEmpty ? allowed : matched
    let offset = Personality.allCases.firstIndex(of: isPro ? personality : .standard) ?? 0
    var selected =
      pool.isEmpty
      ? RoastMessage(
        id: "fallback", titleKey: "coach.title", messageKey: "coach.fallback", severity: .neutral,
        category: .general, rule: "steady", intensity: .normal, pro: false)
      : pool[((seed % pool.count) + pool.count + offset) % pool.count]
    selected.titleKey =
      rule == "weight"
      ? "coach.weight." + context.goal.rawValue
      : "coach.personality." + (isPro ? personality.rawValue : "standard")
    return selected
  }
}
