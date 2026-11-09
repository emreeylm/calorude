import Foundation
import UserNotifications

enum ReminderKind: String, CaseIterable {
  case breakfast, lunch, snack, dinner, night, emptyNoon, emptyEvening, water, streak, weekly
  // Water repeats four times a day, so it has more lines to keep the same one from echoing.
  var variants: Int { self == .water ? 6 : 3 }
}

struct PlannedReminder: Equatable {
  let id: String
  let date: Date
  let kind: ReminderKind
  let variant: Int
  // Streak days or on-target days this week; the %d in the message.
  var value = 0
}

@MainActor enum NotificationService {
  static let prefix = "coach."
  static let horizonDays = 3
  static let variantCount = 3
  // Five slots a day at most: three meals, an afternoon snack nudge and a late-night check.
  private static let breakfastSlot = (hour: 9, minute: 30)
  private static let noonSlot = (hour: 13, minute: 30)
  private static let snackSlot = (hour: 16, minute: 30)
  private static let eveningSlot = (hour: 20, minute: 0)
  // Four water nudges a day.
  private static let waterHours = [9, 13, 17, 21]
  private static let streakSlot = (hour: 19, minute: 0)
  private static let weeklySlot = (hour: 20, minute: 30)
  private static let nightSlot = (hour: 22, minute: 0)
  // A reminder due right after the user opens the app would only nag.
  private static let minimumLead: TimeInterval = 30 * 60

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

  // Today is planned from the real diary: a meal that is already logged sends nothing, and a day
  // with no entries at all gets the "nothing logged" messages at noon and in the evening. Later
  // days assume an empty diary; logging anything needs the app, which rebuilds this plan.
  static func plan(
    entries: [FoodEntry], now: Date, days: Int = horizonDays, waterDone: Bool = false,
    calendar: Calendar = .current
  ) -> [PlannedReminder] {
    let today = calendar.startOfDay(for: now)
    var reminders: [PlannedReminder] = []
    let dayStats = ProgressService.allDays(entries: entries, target: 0, proteinTarget: 0, calendar: calendar)
    let streak = ProgressService.streak(days: dayStats, today: now, calendar: calendar).current
    let todayDone = dayStats.contains { $0.day == today && $0.successful }
    for offset in 0..<days {
      guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
      let logged = offset == 0 ? entries.filter { calendar.isDate($0.date, inSameDayAs: day) } : []
      let meals = Set(logged.map(\.mealType))
      let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
      func append(_ kind: ReminderKind, _ slot: (hour: Int, minute: Int), value: Int) {
        guard
          let date = calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day),
          date.timeIntervalSince(now) > minimumLead
        else { return }
        reminders.append(
          PlannedReminder(
            id: "\(prefix)\(ordinal).\(kind.rawValue)", date: date, kind: kind,
            variant: ordinal % kind.variants, value: value))
      }
      let slots: [(slot: (hour: Int, minute: Int), kind: ReminderKind?)] = [
        (breakfastSlot, meals.contains(.breakfast) ? nil : .breakfast),
        (noonSlot, logged.isEmpty ? .emptyNoon : meals.contains(.lunch) ? nil : .lunch),
        (snackSlot, meals.contains(.snack) ? nil : .snack),
        (eveningSlot, logged.isEmpty ? .emptyEvening : meals.contains(.dinner) ? nil : .dinner),
        (nightSlot, .night),
      ]
      for (index, entry) in slots.enumerated() {
        guard let kind = entry.kind,
          let date = calendar.date(
            bySettingHour: entry.slot.hour, minute: entry.slot.minute, second: 0, of: day),
          date.timeIntervalSince(now) > minimumLead
        else { continue }
        reminders.append(
          PlannedReminder(
            id: "\(prefix)\(ordinal).\(kind.rawValue)", date: date, kind: kind,
            variant: (ordinal + index) % kind.variants))
      }
      // The streak is only at risk while today is still short of target.
      if offset == 0, streak >= 2, !todayDone {
        append(.streak, streakSlot, value: streak)
      }
      if calendar.component(.weekday, from: day) == 1 {  // Sunday
        let week = ProgressService.week(
          ending: day, entries: entries, target: 0, proteinTarget: 0, calendar: calendar)
        append(.weekly, weeklySlot, value: week.successful)
      }
      // Today's water goal is reached: no more nudges today.
      for hour in waterHours where !(offset == 0 && waterDone) {
        guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
          date.timeIntervalSince(now) > minimumLead
        else { continue }
        reminders.append(
          PlannedReminder(
            id: "\(prefix)\(ordinal).water.\(hour)", date: date, kind: .water,
            variant: (ordinal + hour) % ReminderKind.water.variants))
      }
    }
    return reminders.sorted { $0.date < $1.date }
  }

  static func messageKey(_ reminder: PlannedReminder, tier: CoachIntensity) -> String {
    "notif.\(reminder.kind.rawValue).\(tier.key).\(reminder.variant)"
  }

  // Rebuilt on foreground, language, mode, entitlement and diary changes.
  static func schedule(
    profile: UserProfile, entries: [FoodEntry], l: AppLocalization, isPro: Bool, waterDone: Bool = false,
    now: Date = .now
  ) async throws {
    await disable()
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    guard
      settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    else { return }
    // Only Normal is free; a lapsed subscription falls back to it.
    let tier = profile.coachIntensity.available(isPro: isPro)
    for reminder in plan(entries: entries, now: now, waterDone: waterDone) {
      let text = l.text(messageKey(reminder, tier: tier))
      // Only these two carry a %d; other lines may hold a literal percent sign.
      let body = [.streak, .weekly].contains(reminder.kind) ? String(format: text, reminder.value) : text
      try await add(reminder, body: body, l: l, center: center)
    }
  }
  private static func add(
    _ reminder: PlannedReminder, body: String, l: AppLocalization, center: UNUserNotificationCenter
  ) async throws {
    try Task.checkCancellation()
    let content = UNMutableNotificationContent()
    content.title = AppBrand.name(l)
    content.body = body
    content.sound = .default
    let components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute], from: reminder.date)
    try await center.add(
      UNNotificationRequest(
        identifier: reminder.id, content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
  }
}
