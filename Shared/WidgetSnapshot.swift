import Foundation

// What the widget draws. The app renders every string (language, coach style and number format
// follow the in-app settings), so the widget extension stays free of SwiftData and the coach rules.
struct WidgetContent: Codable, Equatable {
  var calories: Double
  var target: Double
  var calorieText: String
  var targetText: String
  var statusText: String
  var comment: String
  var progress: Double { min(max(calories / max(target, 1), 0), 1) }
}

struct WidgetSnapshot: Codable, Equatable {
  // Start of the day `today` was rendered for.
  var day: Date
  var today: WidgetContent
  // The empty-day view the widget switches to at midnight until the app runs again.
  var nextDay: WidgetContent

  func content(at date: Date, calendar: Calendar = .current) -> WidgetContent {
    calendar.isDate(date, inSameDayAs: day) ? today : nextDay
  }
}

enum WidgetStore {
  static let group = "group.com.yemeboluum.app"
  static let key = "widget.snapshot"

  static func save(_ snapshot: WidgetSnapshot, defaults: UserDefaults? = UserDefaults(suiteName: group)) {
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    defaults?.set(data, forKey: key)
  }

  static func load(defaults: UserDefaults? = UserDefaults(suiteName: group)) -> WidgetSnapshot? {
    defaults?.data(forKey: key).flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }
  }
}
