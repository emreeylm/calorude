import Foundation
import UserNotifications

enum ReminderKind: String, CaseIterable {
  case breakfast, lunch, dinner, emptyNoon, emptyEvening
}

struct PlannedReminder: Equatable {
  let id: String
  let date: Date
  let kind: ReminderKind
  let variant: Int
}

@MainActor enum NotificationService {
  static let prefix = "coach."
  static let horizonDays = 3
  static let variantCount = 3
  // Meal-time slots; daytime only, so a day never holds more than three reminders.
  private static let breakfastSlot = (hour: 9, minute: 30)
  private static let noonSlot = (hour: 13, minute: 30)
  private static let eveningSlot = (hour: 20, minute: 0)
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
    entries: [FoodEntry], now: Date, days: Int = horizonDays, calendar: Calendar = .current
  ) -> [PlannedReminder] {
    let today = calendar.startOfDay(for: now)
    var reminders: [PlannedReminder] = []
    for offset in 0..<days {
      guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
      let logged = offset == 0 ? entries.filter { calendar.isDate($0.date, inSameDayAs: day) } : []
      let meals = Set(logged.map(\.mealType))
      let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
      let slots: [(slot: (hour: Int, minute: Int), kind: ReminderKind?)] = [
        (breakfastSlot, meals.contains(.breakfast) ? nil : .breakfast),
        (noonSlot, logged.isEmpty ? .emptyNoon : meals.contains(.lunch) ? nil : .lunch),
        (eveningSlot, logged.isEmpty ? .emptyEvening : meals.contains(.dinner) ? nil : .dinner),
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
            variant: (ordinal + index) % variantCount))
      }
    }
    return reminders
  }

  static func messageKey(_ reminder: PlannedReminder, tier: CoachIntensity) -> String {
    "notif.\(reminder.kind.rawValue).\(tier.rawValue).\(reminder.variant)"
  }

  // Rebuilt on foreground, language, mode, entitlement and diary changes.
  static func schedule(
    profile: UserProfile, entries: [FoodEntry], l: AppLocalization, isPro: Bool, now: Date = .now
  ) async throws {
    await disable()
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    guard
      settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    else { return }
    // Only Normal is free; a lapsed subscription falls back to it.
    let tier = profile.coachIntensity.available(isPro: isPro)
    for reminder in plan(entries: entries, now: now) {
      try await add(reminder, body: l.text(messageKey(reminder, tier: tier)), l: l, center: center)
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
