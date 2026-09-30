import Charts
import SwiftData
import SwiftUI

struct ProgressScreen: View {
  var profile: UserProfile
  @Environment(AppLocalization.self) private var l
  @Environment(StoreService.self) private var store
  @Environment(\.modelContext) private var context
  @Query(sort: \FoodEntry.date) private var entries: [FoodEntry]
  @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
  @State private var range = 7
  @State private var weight = 80.0
  @State private var weightDate = Date.now
  @State private var showWeight = false
  @State private var showPaywall = false
  @State private var error = false
  var days: [DayStats] {
    ProgressService.allDays(
      entries: entries, target: profile.dailyCalorieTarget, proteinTarget: profile.proteinTarget)
  }
  var cutoff: Date {
    range == 0
      ? .distantPast
      : Calendar.current.date(
        byAdding: .day, value: -(range - 1), to: Calendar.current.startOfDay(for: .now))!
  }
  var recent: [DayStats] { days.filter { $0.day >= cutoff } }
  var week: WeeklyStats {
    ProgressService.week(
      ending: .now, entries: entries, target: profile.dailyCalorieTarget,
      proteinTarget: profile.proteinTarget)
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Text(l.text("progress.headline")).font(.largeTitle.bold())
          Picker(l.text("range"), selection: $range) {
            ForEach([7, 30, 90, 0], id: \.self) { Text(l.text("range.\($0)")).tag($0) }
          }.pickerStyle(.segmented).onChange(of: range) { _, value in
            if value != 7 && !store.isPro {
              range = 7
              showPaywall = true
            }
          }
          Panel {
            VStack(alignment: .leading, spacing: 18) {
              HStack {
                Text(l.text("weight")).font(.headline)
                Spacer()
                Button(l.text("add"), systemImage: "plus") {
                  weight = weights.last?.weight ?? profile.currentWeight
                  weightDate = .now
                  showWeight = true
                }
              }
              Text(
                l.number(weights.last?.weight ?? profile.currentWeight, digits: 1) + " "
                  + l.text("unit.kg")
              ).font(.largeTitle.bold())
              HStack {
                metric("starting", profile.startingWeight)
                Spacer()
                metric("targetWeight", profile.targetWeight)
                Spacer()
                metric(
                  "change", (weights.last?.weight ?? profile.currentWeight) - profile.startingWeight
                )
              }
              if weights.count > 1 {
                Chart(weights.filter { $0.date >= cutoff }) { entry in
                  LineMark(
                    x: .value(l.text("date"), entry.date), y: .value(l.text("weight"), entry.weight)
                  ).foregroundStyle(Theme.interactive)
                  PointMark(
                    x: .value(l.text("date"), entry.date), y: .value(l.text("weight"), entry.weight)
                  ).foregroundStyle(Theme.interactive)
                }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 190)
                  .accessibilityLabel(
                    l.text("chart.weight.summary") + " "
                      + l.number(
                        (weights.last?.weight ?? profile.currentWeight) - profile.startingWeight,
                        digits: 1) + " " + l.text("unit.kg"))
              } else {
                Text(l.text("chart.empty")).foregroundStyle(.secondary)
              }
              Text(l.text("weight.trend.note")).font(.caption).foregroundStyle(.secondary)
              if let average = ProgressService.averageWeight(
                weights,
                from: Calendar.current.date(
                  byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now))!, to: .now)
              {
                Text(
                  l.text("weeklyAverage") + ": " + l.number(average, digits: 1) + " "
                    + l.text("unit.kg")
                ).font(.subheadline.bold())
              }
            }
          }
          Panel {
            VStack(alignment: .leading, spacing: 18) {
              Text(l.text("calories")).font(.headline)
              if recent.isEmpty {
                VStack(spacing: 10) {
                  Image(systemName: "chart.bar.xaxis").font(.largeTitle).foregroundStyle(
                    Theme.interactive)
                  Text(l.text("chart.empty")).foregroundStyle(.secondary).multilineTextAlignment(
                    .center)
                }.frame(maxWidth: .infinity).padding(.vertical, 16)
              } else {
                Chart(recent) { day in
                  BarMark(
                    x: .value(l.text("date"), day.day, unit: .day),
                    y: .value(l.text("calories"), day.calories)
                  ).foregroundStyle(Theme.interactive)
                  LineMark(
                    x: .value(l.text("date"), day.day, unit: .day),
                    y: .value(l.text("dailyTarget"), day.target)
                  ).foregroundStyle(Theme.carbs).lineStyle(StrokeStyle(dash: [4, 4]))
                }.frame(height: 180).accessibilityLabel(
                  l.text("chart.calorie.summary") + " " + l.number(week.averageCalories))
                Text(l.text("chart.legend")).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
          let streak = ProgressService.streak(days: days)
          HStack {
            Panel {
              VStack(alignment: .leading) {
                Label(l.text("streak"), systemImage: "flame.fill")
                Text("\(streak.current)").font(.largeTitle.bold())
              }
            }
            Panel {
              VStack(alignment: .leading) {
                Text(l.text("bestStreak"))
                Text("\(streak.best)").font(.largeTitle.bold())
              }
            }
          }
          Panel {
            VStack(alignment: .leading, spacing: 18) {
              Text(l.text("thisWeek")).font(.caption.bold()).tracking(2)
              Text("\(week.successful) / 7").font(
                .system(size: 48, weight: .black, design: .rounded))
              Text(l.text("targetDays")).foregroundStyle(.secondary)
              if store.isPro {
                HStack {
                  VStack(alignment: .leading) {
                    Text(l.number(week.averageCalories)).font(.title.bold())
                    Text(l.text("avgCalories")).font(.caption)
                  }
                  Spacer()
                  VStack(alignment: .leading) {
                    Text(l.number(week.averageProtein)).font(.title.bold())
                    Text(l.text("avgProtein")).font(.caption)
                  }
                }
                Text(l.text("averages.logged") + " \(week.logged)/7").font(.caption)
                  .foregroundStyle(.secondary)
                if let trend = ProgressService.weightTrend(weights, ending: .now) {
                  Text(
                    l.text("weeklyWeightChange") + ": " + l.number(trend, digits: 1) + " "
                      + l.text("unit.kg"))
                } else {
                  Text(l.text("weight.noTrend")).font(.caption)
                }
                Text(
                  l.text("proteinAdherence")
                    + ": \(week.days.filter { $0.count > 0 && $0.protein >= $0.proteinTarget }.count)/7"
                )
                Text(l.text(week.successful >= 5 ? "weekly.good" : "weekly.build"))
                Chart(recent) { day in
                  BarMark(
                    x: .value(l.text("date"), day.day, unit: .day),
                    y: .value(l.text("protein"), day.protein)
                  ).foregroundStyle(Theme.protein)
                }.frame(height: 140).accessibilityLabel(
                  l.text("avgProtein") + " " + l.number(week.averageProtein))
              } else {
                Button {
                  showPaywall = true
                } label: {
                  HStack(spacing: 10) {
                    Text(l.text("pro.reports")).multilineTextAlignment(.leading)
                    Spacer()
                    Label("PRO", systemImage: "lock.fill").font(.caption2.weight(.heavy))
                      .padding(.horizontal, 8).padding(.vertical, 4)
                      .background(Theme.accent, in: Capsule()).foregroundStyle(Theme.ink)
                  }
                }.accessibilityIdentifier("progress.reports.pro")
              }
            }
          }
          AchievementGrid(days: days, entries: entries, isPro: store.isPro)
          if !weights.isEmpty {
            Panel {
              VStack(alignment: .leading, spacing: 14) {
                Text(l.text("weight.history")).font(.headline)
                ForEach(weights.suffix(store.isPro ? weights.count : 7).reversed()) { entry in
                  HStack {
                    Text(entry.date, format: .dateTime.day().month())
                    Spacer()
                    Text(l.number(entry.weight, digits: 1) + " " + l.text("unit.kg"))
                    Button(role: .destructive) {
                      context.delete(entry)
                      do { try context.save() } catch {
                        context.rollback()
                        self.error = true
                      }
                    } label: {
                      Image(systemName: "trash")
                    }.accessibilityLabel(l.text("delete"))
                  }
                }
              }
            }
          }
        }.padding(20)
      }.background(Color(.systemGroupedBackground)).toolbar(.hidden, for: .navigationBar)
        .hardBottomEdge()
        .sheet(isPresented: $showWeight) {
          NavigationStack {
            Form {
              TextField(l.text("weight"), value: $weight, format: .number).keyboardType(.decimalPad)
              DatePicker(
                l.text("date"), selection: $weightDate, in: ...Date.now, displayedComponents: .date)
              Button(l.text("save")) {
                context.insert(WeightEntry(weight: weight, date: weightDate))
                // Plan edits start from the most recent weigh-in, not the onboarding weight.
                if weightDate >= (weights.last?.date ?? .distantPast) {
                  profile.currentWeight = weight
                }
                do {
                  try context.save()
                  showWeight = false
                } catch {
                  context.rollback()
                  self.error = true
                }
              }.disabled(!weight.isFinite || !(40...250).contains(weight))
            }.navigationTitle(l.text("weight.add")).toolbar {
              Button(l.text("cancel")) { showWeight = false }
            }
          }.presentationDetents([.medium])
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert(l.text("error.save"), isPresented: $error) { Button(l.text("ok"), role: .cancel) {} }
    }
  }
  func metric(_ key: String, _ value: Double) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(l.text(key)).font(.caption).foregroundStyle(.secondary)
      Text(l.number(value, digits: 1)).font(.headline)
    }
  }
}
struct AchievementGrid: View {
  var days: [DayStats]
  var entries: [FoodEntry]
  var isPro: Bool
  @Environment(AppLocalization.self) private var l
  @Environment(\.modelContext) private var context
  @Query private var unlocked: [AchievementState]
  var earned: [String] { AchievementService.earned(days: days) }
  var body: some View {
    Panel {
      VStack(alignment: .leading, spacing: 16) {
        Text(l.text("achievements")).font(.title2.bold())
        ForEach(
          [
            "first", "streak3", "streak7", "protein", "bullseye", "return", "streak14", "streak30",
            "streak60", "streak100",
          ], id: \.self
        ) { key in
          HStack {
            Image(
              systemName: (isPro || ["first", "streak3", "streak7"].contains(key))
                && (earned.contains(key) || unlocked.contains(where: { $0.key == key }))
                ? "checkmark.seal.fill" : "lock.circle")
            Text(l.text("achievement." + key))
            Spacer()
            if !isPro && !["first", "streak3", "streak7"].contains(key) {
              Text(l.text("pro.badge")).font(.caption.bold())
            }
          }.foregroundStyle(earned.contains(key) ? .primary : .secondary)
        }
      }
    }.sensoryFeedback(.success, trigger: unlocked.count)
  }
}
