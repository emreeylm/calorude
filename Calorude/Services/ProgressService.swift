import Foundation

struct DayStats: Identifiable {
  var day: Date
  var calories: Double
  var protein: Double
  var carbs: Double
  var fat: Double
  var target: Double
  var proteinTarget: Double
  var count: Int
  var id: Date { day }
  var successful: Bool { count > 0 && target > 0 && abs(calories - target) <= target * 0.10 }
}
struct WeeklyStats {
  var days: [DayStats]
  var successful: Int { days.filter(\.successful).count }
  var logged: Int { days.filter { $0.count > 0 }.count }
  var averageCalories: Double {
    logged == 0 ? 0 : days.reduce(0) { $0 + $1.calories } / Double(logged)
  }
  var averageProtein: Double {
    logged == 0 ? 0 : days.reduce(0) { $0 + $1.protein } / Double(logged)
  }
}
enum ProgressService {
  static func day(
    _ date: Date, entries: [FoodEntry], target: Double, proteinTarget: Double,
    calendar: Calendar = .current
  ) -> DayStats {
    let rows = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }.sorted {
      $0.date < $1.date
    }
    return DayStats(
      day: calendar.startOfDay(for: date), calories: rows.reduce(0) { $0 + $1.calories },
      protein: rows.reduce(0) { $0 + $1.protein }, carbs: rows.reduce(0) { $0 + $1.carbs },
      fat: rows.reduce(0) { $0 + $1.fat }, target: rows.last?.calorieTargetSnapshot ?? target,
      proteinTarget: rows.last?.proteinTargetSnapshot ?? proteinTarget, count: rows.count)
  }
  static func week(
    ending: Date, entries: [FoodEntry], target: Double, proteinTarget: Double,
    calendar: Calendar = .current
  ) -> WeeklyStats {
    WeeklyStats(
      days: (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: ending) }
        .map {
          day(
            $0, entries: entries, target: target, proteinTarget: proteinTarget, calendar: calendar)
        })
  }
  static func streak(days: [DayStats], today: Date = .now, calendar: Calendar = .current) -> (
    current: Int, best: Int
  ) {
    let sorted = days.sorted { $0.day < $1.day }
    var best = 0
    var run = 0
    var previous: Date?
    for day in sorted {
      let adjacent =
        previous.map { calendar.dateComponents([.day], from: $0, to: day.day).day == 1 } ?? false
      run = day.successful ? (adjacent ? run + 1 : 1) : 0
      best = max(best, run)
      previous = day.day
    }
    let start = calendar.startOfDay(for: today)
    var cursor = start
    if !sorted.contains(where: { $0.day == start && $0.successful }) {
      cursor = calendar.date(byAdding: .day, value: -1, to: start)!
    }
    let successes = Set(sorted.filter(\.successful).map(\.day))
    var current = 0
    while successes.contains(cursor) {
      current += 1
      cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
    }
    return (current, best)
  }
  static func allDays(
    entries: [FoodEntry], target: Double, proteinTarget: Double, calendar: Calendar = .current
  ) -> [DayStats] {
    Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }.sorted { $0.key < $1.key }
      .map {
        day($0.key, entries: $0.value, target: target, proteinTarget: proteinTarget, calendar: calendar)
      }
  }
  static func weightTrend(_ weights: [WeightEntry], ending: Date, calendar: Calendar = .current)
    -> Double?
  {
    let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: ending))!
    let middle = calendar.date(byAdding: .day, value: -7, to: end)!
    let start = calendar.date(byAdding: .day, value: -7, to: middle)!
    guard let current = averageWeight(weights, from: middle, to: end),
      let previous = averageWeight(weights, from: start, to: middle)
    else { return nil }
    return current - previous
  }
  static func averageWeight(_ weights: [WeightEntry], from: Date, to: Date) -> Double? {
    let values = weights.filter { $0.date >= from && $0.date < to }.map(\.weight)
    return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
  }
}
