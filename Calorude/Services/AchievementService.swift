import Foundation

enum AchievementService {
  static func earned(days: [DayStats]) -> [String] {
    var keys: [String] = days.isEmpty ? [] : ["first"]
    let best = ProgressService.streak(days: days).best
    for milestone in [3, 7, 14, 30, 60, 100] where best >= milestone {
      keys.append("streak\(milestone)")
    }
    if days.contains(where: { $0.count > 0 && $0.protein >= $0.proteinTarget }) {
      keys.append("protein")
    }
    if days.contains(where: \.successful) { keys.append("bullseye") }
    let sorted = days.sorted { $0.day < $1.day }
    if zip(sorted, sorted.dropFirst()).contains(where: {
      Calendar.current.dateComponents([.day], from: $0.day, to: $1.day).day ?? 0 >= 3
    }) {
      keys.append("return")
    }
    return keys
  }
}
