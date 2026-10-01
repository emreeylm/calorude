import Foundation

// One coach; the level ("Koç Tarzı") sets how hard it hits. Only Normal is free.
struct CoachVoice: Equatable {
  var level: CoachIntensity
  init(level: CoachIntensity, isPro: Bool) { self.level = level.available(isPro: isPro) }
  var titleKey: String { "coach.title" }
}

enum DayState: String, CaseIterable { case empty, low, steady, perfect, over, veryHigh, protein }

struct RoastContext {
  var calories: Double
  var target: Double
  var protein: Double
  var proteinTarget: Double
  var hour: Int
  var loggedMeals: Int
  init(
    calories: Double, target: Double, protein: Double, proteinTarget: Double, hour: Int,
    loggedMeals: Int
  ) {
    self.calories = calories
    self.target = target
    self.protein = protein
    self.proteinTarget = proteinTarget
    self.hour = hour
    self.loggedMeals = loggedMeals
  }
  // Past days are judged as finished days, so the time-of-day rules do not apply to them.
  init(stats: DayStats, now: Date = .now, calendar: Calendar = .current) {
    self.init(
      calories: stats.calories, target: stats.target, protein: stats.protein,
      proteinTarget: stats.proteinTarget,
      hour: calendar.isDate(stats.day, inSameDayAs: now) ? calendar.component(.hour, from: now) : 23,
      loggedMeals: stats.count)
  }
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
    ]
    // A non-breaking space keeps a number and its unit on the same line.
    return values.reduce(template) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
      .replacingOccurrences(of: " kcal", with: "\u{00A0}kcal")
  }
}

// The dashboard comment judges the day's recorded total, never a single meal.
enum DayCoach {
  static let variants = 8

  static func state(for c: RoastContext) -> DayState {
    if c.loggedMeals == 0 { return .empty }
    let ratio = c.calories / max(c.target, 1)
    if c.hour >= 18 && ratio < 0.5 { return .low }
    if ratio > 1.4 { return .veryHigh }
    if ratio > 1.1 { return .over }
    if c.hour >= 18 && c.protein < c.proteinTarget * 0.6 { return .protein }
    if (0.9...1.1).contains(ratio) && c.protein >= c.proteinTarget * 0.9 { return .perfect }
    return .steady
  }

  // Derived only from the day, the diary size and the totals: redrawing the screen keeps the same
  // line, while a new entry (which changes the totals) rotates to the next one.
  static func variant(day: Date, context: RoastContext, calendar: Calendar = .current) -> Int {
    let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
    let mixed = ordinal &* 7 &+ context.loggedMeals &* 3 &+ Int(context.calories / 10)
    return ((mixed % variants) + variants) % variants
  }

  static func key(state: DayState, voice: CoachVoice, variant: Int) -> String {
    let index = ((variant % variants) + variants) % variants
    return
      "coach.day.\(state.rawValue).\(voice.level.key).\(index)"
  }
}
