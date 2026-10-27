import Foundation
import WidgetKit

// Renders today's ring and coach line (and the empty day after midnight) for the home screen widget.
@MainActor enum WidgetSync {
  static func content(
    day: Date, profile: UserProfile, entries: [FoodEntry], voice: CoachVoice, l: AppLocalization
  ) -> WidgetContent {
    let stats = ProgressService.day(
      day, entries: entries, target: profile.dailyCalorieTarget, proteinTarget: profile.proteinTarget)
    return WidgetContent(
      calories: stats.calories, target: stats.target, calorieText: l.number(stats.calories),
      targetText: "/ " + l.number(stats.target) + " " + l.text("unit.kcal"),
      statusText: l.text(stats.calories > stats.target ? "over" : "remaining") + " · "
        + l.number(abs(stats.target - stats.calories)),
      comment: DayCoach.comment(stats: stats, voice: voice, l: l))
  }

  static func update(
    profile: UserProfile, entries: [FoodEntry], l: AppLocalization, isPro: Bool,
    now: Date = .now, calendar: Calendar = .current
  ) {
    let voice = CoachVoice(level: profile.coachIntensity, isPro: isPro)
    let today = calendar.startOfDay(for: now)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
    func render(_ day: Date) -> WidgetContent {
      content(day: day, profile: profile, entries: entries, voice: voice, l: l)
    }
    let snapshot = WidgetSnapshot(day: today, today: render(today), nextDay: render(tomorrow))
    guard WidgetStore.load() != snapshot else { return }
    WidgetStore.save(snapshot)
    WidgetCenter.shared.reloadAllTimelines()
  }
}
