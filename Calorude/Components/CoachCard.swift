import SwiftData
import SwiftUI

struct CoachCard: View {
  var profile: UserProfile
  var stats: DayStats
  var streak: Int
  var entries: [FoodEntry]
  @Environment(AppLocalization.self) private var l
  @Environment(StoreService.self) private var store
  @Query private var preferences: [AppPreferences]
  @Query private var weights: [WeightEntry]
  @State private var showShare = false
  var body: some View {
    let context = CoachContextBuilder.make(
      profile: profile, stats: stats, streak: streak, entries: entries, weights: weights)
    let message = RoastEngine.bundled.evaluate(
      context, intensity: profile.coachIntensity,
      personality: preferences.first?.personality ?? .standard, isPro: store.isPro,
      seed: (Calendar.current.ordinality(of: .day, in: .era, for: stats.day) ?? 0) + stats.count,
      dailyOnly: true)
    let comment =
      (store.isPro && preferences.first?.personality != .standard
        ? l.text("coach.intro." + (preferences.first?.personality.rawValue ?? "standard")) : "")
      + context.text(l.text(message.messageKey), l: l)
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "quote.bubble.fill")
        Text(l.text(message.titleKey)).font(.caption.weight(.heavy)).tracking(2).lineLimit(1)
          .minimumScaleFactor(0.7)
        Text(l.text("intensity." + profile.coachIntensity.available(isPro: store.isPro).rawValue))
          .font(.caption2.weight(.bold)).lineLimit(1).padding(.horizontal, 8).padding(.vertical, 3)
          .overlay(Capsule().stroke(Theme.ink.opacity(0.5), lineWidth: 1))
        Spacer()
      }.foregroundStyle(Theme.ink.opacity(0.7))
      Text(comment).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("coach.message")
      Text(
        l.number(stats.calories) + " / " + l.number(stats.target) + " " + l.text("unit.kcal")
          + " · " + l.text("protein") + " " + l.number(stats.protein) + " / "
          + l.number(stats.proteinTarget) + " " + l.text("unit.g")
      )
      .font(.caption).accessibilityIdentifier("coach.dailyTotals")
    }.padding(22).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Theme.ink)
      .background(Theme.accent, in: RoundedRectangle(cornerRadius: 24)).accessibilityElement(
        children: .combine
      ).accessibilityIdentifier("coach.card")
      // Outside the combined element so VoiceOver can reach it as its own control.
      .overlay(alignment: .topTrailing) {
        Button {
          showShare = true
        } label: {
          Image(systemName: "square.and.arrow.up").font(.body.weight(.semibold))
            .foregroundStyle(Theme.ink.opacity(0.7)).frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }.padding(8).accessibilityLabel(l.text("coach.shareStory"))
          .accessibilityIdentifier("coach.share")
      }
      .sheet(isPresented: $showShare) {
        ShareComposerView(profile: profile, date: stats.day, kind: .roast, roast: comment)
      }
  }
}
enum CoachContextBuilder {
  static func make(
    profile: UserProfile, stats: DayStats, streak: Int, entries: [FoodEntry],
    weights: [WeightEntry] = []
  ) -> RoastContext {
    let prior = entries.filter { $0.date < stats.day }.map(\.date).max()
    let gap =
      prior.map {
        Calendar.current.dateComponents(
          [.day], from: Calendar.current.startOfDay(for: $0), to: stats.day
        ).day ?? 0
      } ?? 0
    let week = ProgressService.week(
      ending: stats.day, entries: entries, target: profile.dailyCalorieTarget,
      proteinTarget: profile.proteinTarget)
    let today = entries.filter { Calendar.current.isDate($0.date, inSameDayAs: stats.day) }
    return RoastContext(
      calories: stats.calories, target: stats.target, protein: stats.protein,
      proteinTarget: stats.proteinTarget,
      hour: Calendar.current.isDateInToday(stats.day)
        ? Calendar.current.component(.hour, from: .now) : 23, goal: profile.goalType,
      streak: streak, weeklyAdherence: Double(week.successful) / 7,
      weightTrend: ProgressService.weightTrend(weights, ending: stats.day),
      loggedMeals: stats.count, daysSinceLastLog: gap,
      fastFood: today.contains { $0.category == "fastFood" },
      sweet: today.contains { $0.category == "sweet" })
  }
}
