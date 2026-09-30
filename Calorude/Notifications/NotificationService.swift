import Foundation
import UserNotifications

@MainActor enum NotificationService {
  static let prefix = "coach."
  static func enable() async -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [
      .alert, .sound, .badge,
    ])) ?? false
  }
  static func disable() async {
    let center = UNUserNotificationCenter.current()
    let ids = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(prefix) }
      .map(\.identifier)
    center.removePendingNotificationRequests(withIdentifiers: ids)
  }
  static func eveningCategory(stats: DayStats, streak: Int, weekday: Int, isPro: Bool) -> String {
    guard isPro else { return "evening" }
    if stats.calories < stats.target * 0.5 { return "low" }
    if stats.protein < stats.proteinTarget * 0.6 { return "protein" }
    if [3, 7, 14, 30, 60, 100].contains(streak) { return "streak" }
    if weekday == 1 { return "weekly" }
    return "progress"
  }
  // Rebuilt on foreground, language, entitlement and log changes. No indefinitely repeating stale summaries.
  static func schedule(
    profile: UserProfile, entries: [FoodEntry], l: AppLocalization, isPro: Bool, now: Date = .now
  ) async throws {
    await disable()
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    guard
      settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    else { return }
    let calendar = Calendar.current
    let morning = calendar.nextDate(
      after: now, matching: DateComponents(hour: 9), matchingPolicy: .nextTime)!
    try await add(
      id: "morning", date: morning, body: l.text("notification.morning"), l: l, center: center)
    let delivered = await center.deliveredNotifications().filter {
      $0.request.identifier.hasPrefix(prefix) && calendar.isDate($0.date, inSameDayAs: now)
    }
    // Total cap of two, with a minimum one-hour separation and no late-night alerts.
    if delivered.count < 2,
      let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now),
      evening.timeIntervalSince(now) > 3600
    {
      let stats = ProgressService.day(
        now, entries: entries, target: profile.dailyCalorieTarget,
        proteinTarget: profile.proteinTarget)
      let streak = ProgressService.streak(
        days: ProgressService.allDays(
          entries: entries, target: profile.dailyCalorieTarget, proteinTarget: profile.proteinTarget
        )
      ).current
      let category = eveningCategory(
        stats: stats, streak: streak, weekday: calendar.component(.weekday, from: now), isPro: isPro
      )
      let body: String
      if isPro {
        var context = CoachContextBuilder.make(
          profile: profile, stats: stats, streak: streak, entries: entries)
        context.hour = 20
        let message = RoastEngine.bundled.evaluate(
          context, intensity: profile.coachIntensity, personality: .standard, isPro: true,
          seed: calendar.ordinality(of: .day, in: .era, for: now) ?? 0)
        body =
          l.text("notification.snapshot") + " "
          + (category == "weekly" ? l.text("weekly.build") : context.text(l.text(message.messageKey), l: l))
      } else {
        body = l.text("notification.evening")
      }
      try await add(id: category, date: evening, body: body, l: l, center: center)
    }
    center.setNotificationCategories(
      Set(
        ["morning", "low", "protein", "progress", "evening", "streak", "weekly"].map {
          UNNotificationCategory(identifier: prefix + $0, actions: [], intentIdentifiers: [])
        }))
  }
  private static func add(
    id: String, date: Date, body: String, l: AppLocalization, center: UNUserNotificationCenter
  ) async throws {
    try Task.checkCancellation()
    let content = UNMutableNotificationContent()
    content.title = AppBrand.name(l)
    content.body = body
    content.sound = .default
    content.categoryIdentifier = prefix + id
    let components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute], from: date)
    try await center.add(
      UNNotificationRequest(
        identifier: prefix + id, content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
  }
}
