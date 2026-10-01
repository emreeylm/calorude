import SwiftData
import SwiftUI

struct DashboardView: View {
  var profile: UserProfile
  @Environment(AppLocalization.self) private var l
  @Environment(\.modelContext) private var context
  @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var mealEditor: MealEditorRoute?
  @State private var pendingReaction: MealReaction?
  @State private var reaction: MealReaction?
  // The last few meal comments, so the same line does not come back right away.
  @AppStorage("coach.recentMealKeys") private var recentMealKeys = ""
  @State private var showShare = false
  @Environment(\.scenePhase) private var scenePhase
  @State private var selectedDate = Date.now
  @State private var today = Calendar.current.startOfDay(for: .now)
  @State private var error = false
  @State private var deleted: DeletedEntry?
  @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 235
  @ScaledMetric(relativeTo: .largeTitle) private var ringNumberSize: CGFloat = 54
  var stats: DayStats {
    ProgressService.day(
      selectedDate, entries: entries, target: profile.dailyCalorieTarget,
      proteinTarget: profile.proteinTarget)
  }
  var streak: Int {
    ProgressService.streak(
      days: ProgressService.allDays(
        entries: entries, target: profile.dailyCalorieTarget, proteinTarget: profile.proteinTarget)
    ).current
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
              Text(AppBrand.name(l)).font(.caption.weight(.heavy)).tracking(3).foregroundStyle(
                .secondary)
              Text(l.text("hello") + ", " + profile.name + ".").font(.largeTitle.bold())
            }
            Spacer()
            Label("\(streak)", systemImage: "flame.fill").font(.headline).foregroundStyle(
              Theme.interactive
            ).padding(12).background(Theme.interactive.opacity(0.10), in: Capsule()).accessibilityLabel(
              l.text("streak") + " \(streak)")
          }
          dayStrip
          Panel {
            VStack(spacing: 24) {
              HStack {
                Text(l.text("dailyProgress")).font(.caption.weight(.bold)).tracking(2)
                Spacer()
                Image(systemName: "bolt.fill").foregroundStyle(Theme.interactive)
              }
              ZStack {
                Circle().stroke(Theme.interactive.opacity(0.12), lineWidth: 17)
                Circle().trim(from: 0, to: min(stats.calories / max(stats.target, 1), 1)).stroke(
                  Theme.interactive, style: StrokeStyle(lineWidth: 17, lineCap: .round)
                ).rotationEffect(.degrees(-90))
                VStack(spacing: 8) {
                  Text(l.number(stats.calories)).font(
                    .system(size: ringNumberSize, weight: .black, design: .rounded)
                  ).minimumScaleFactor(0.5).lineLimit(1)
                  Text("/ " + l.number(stats.target) + " " + l.text("unit.kcal")).font(.subheadline)
                    .foregroundStyle(.secondary)
                  Text(
                    l.text(stats.calories > stats.target ? "over" : "remaining") + " · "
                      + l.number(abs(stats.target - stats.calories))
                  ).font(.caption.bold()).foregroundStyle(Theme.interactive)
                }
              }.frame(width: min(ringSize, 300), height: min(ringSize, 300)).padding(8)
                .accessibilityElement(children: .combine)
              HStack(alignment: .top, spacing: 12) {
                MacroBar(
                  title: l.text("protein"), amount: stats.protein, target: profile.proteinTarget,
                  color: Theme.protein)
                MacroBar(
                  title: l.text("carbs"), amount: stats.carbs, target: profile.carbTarget,
                  color: Theme.carbs)
                MacroBar(
                  title: l.text("fat"), amount: stats.fat, target: profile.fatTarget,
                  color: Theme.fat)
              }
            }
          }
          PrimaryButton(title: l.text("logFood"), icon: "plus") {
            mealEditor = MealEditorRoute(meal: .lunch)
          }
          .accessibilityIdentifier("dashboard.add")
          CoachCard(profile: profile, stats: stats)
          HStack {
            Text(l.text("yourMeals")).font(.title2.bold())
            Spacer()
            Button {
              showShare = true
            } label: {
              Image(systemName: "square.and.arrow.up")
            }.accessibilityLabel(l.text("share"))
          }
          if stats.count == 0 { EmptyCard() }
          ForEach(MealType.allCases, id: \.self) { meal in
            let rows = entries.filter {
              Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.mealType == meal
            }
            if !rows.isEmpty {
              Panel {
                VStack(alignment: .leading, spacing: 16) {
                  HStack {
                    Text(l.text("meal." + meal.rawValue)).font(.headline)
                    Spacer()
                    Button(l.text("mealEditor.edit"), systemImage: "pencil") {
                      mealEditor = MealEditorRoute(meal: meal)
                    }.accessibilityIdentifier("meal.edit." + meal.rawValue)
                  }
                  ForEach(rows) { entry in
                    HStack {
                      VStack(alignment: .leading, spacing: 5) {
                        Text(entry.name(l.language)).fontWeight(.medium)
                        if let key = entry.preparationTitleKey {
                          Text(l.text(key)).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(l.number(entry.amountInGrams) + " " + l.text("unit." + entry.unit))
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      }
                      Spacer()
                      Text(l.number(entry.calories)).font(.headline.monospacedDigit())
                      Button(role: .destructive) {
                        delete(entry)
                      } label: {
                        Image(systemName: "minus.circle").frame(width: 44, height: 44)
                      }.accessibilityLabel(l.text("delete") + " " + entry.name(l.language))
                    }
                  }
                }
              }
            }
          }
        }.padding(20)
      }.background(Color(.systemGroupedBackground)).toolbar(.hidden, for: .navigationBar)
        .hardBottomEdge()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: stats.calories)
        .sensoryFeedback(.success, trigger: stats.successful) { old, new in !old && new }
        .safeAreaInset(edge: .bottom) {
          if let deleted {
            HStack {
              Text(l.text("undo.deleted") + " · " + deleted.food.name(l.language)).lineLimit(1)
              Spacer()
              Button(l.text("undo")) { undoDelete(deleted) }.fontWeight(.bold)
                .accessibilityIdentifier("undo.button")
            }.padding(.horizontal, 20).padding(.vertical, 14)
              .background(.regularMaterial, in: Capsule()).padding(.horizontal, 20)
              .transition(.move(edge: .bottom).combined(with: .opacity))
              .accessibilityIdentifier("undo.banner")
          }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: deleted?.id)
        .task(id: deleted?.id) {
          guard deleted != nil else { return }
          try? await Task.sleep(for: .seconds(6))
          if !Task.isCancelled { deleted = nil }
        }
        .onChange(of: scenePhase) { _, phase in
          // Follow midnight: a day left open on "today" must not keep logging into yesterday.
          let now = Calendar.current.startOfDay(for: .now)
          guard phase == .active, now != today else { return }
          if Calendar.current.isDate(selectedDate, inSameDayAs: today) { selectedDate = .now }
          today = now
        }
        .sheet(
          item: $mealEditor,
          onDismiss: {
            reaction = pendingReaction
            pendingReaction = nil
          }
        ) { route in
          FoodLogView(
            profile: profile, date: selectedDate, initialMeal: route.meal,
            recentKeys: recentMealKeys.split(separator: ",").map(String.init)
          ) { result in
            pendingReaction = result
            if let result {
              remember(result.messageKey)
            }
          }
        }
        .sheet(item: $reaction) { MealReactionView(reaction: $0) }
        .sheet(isPresented: $showShare) { ShareComposerView(profile: profile, date: selectedDate) }
        .alert(l.text("error.save"), isPresented: $error) { Button(l.text("ok"), role: .cancel) {} }
    }
  }
}

extension DashboardView {
  private var dayStrip: some View {
    HStack {
      Button {
        shiftDay(by: -1)
      } label: {
        Image(systemName: "chevron.left").frame(width: 44, height: 44)
      }.accessibilityLabel(l.text("day.previous")).accessibilityIdentifier("day.previous")
      Spacer()
      DatePicker(
        l.text("date"), selection: $selectedDate, in: ...Date.now, displayedComponents: .date
      ).labelsHidden()
      Spacer()
      Button {
        shiftDay(by: 1)
      } label: {
        Image(systemName: "chevron.right").frame(width: 44, height: 44)
      }.disabled(Calendar.current.isDateInToday(selectedDate))
        .accessibilityLabel(l.text("day.next")).accessibilityIdentifier("day.next")
    }
  }
  private func remember(_ key: String) {
    let kept = recentMealKeys.split(separator: ",").map(String.init).suffix(MealReactionEngine.recentLimit - 1)
    recentMealKeys = (kept + [key]).joined(separator: ",")
  }
  private func shiftDay(by days: Int) {
    let calendar = Calendar.current
    guard let moved = calendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
    selectedDate = calendar.isDateInToday(moved) || moved > .now ? .now : moved
  }
  private func delete(_ entry: FoodEntry) {
    let snapshot = try? MealDraftItem(entry: entry)
    let record = snapshot.map {
      DeletedEntry(
        id: $0.id, food: $0.food, grams: $0.grams, meal: $0.meal, date: entry.date,
        target: entry.calorieTargetSnapshot, proteinTarget: entry.proteinTargetSnapshot)
    }
    context.delete(entry)
    do {
      try context.save()
      deleted = record
    } catch {
      context.rollback()
      self.error = true
    }
  }
  private func undoDelete(_ item: DeletedEntry) {
    let entry = FoodEntry(
      food: item.food, grams: item.grams, meal: item.meal, date: item.date, target: item.target,
      proteinTarget: item.proteinTarget)
    entry.id = item.id
    context.insert(entry)
    do {
      try context.save()
      deleted = nil
    } catch {
      context.rollback()
      self.error = true
    }
  }
}

// Enough of a removed diary row to restore it exactly, including the targets it was logged under.
struct DeletedEntry: Identifiable {
  let id: UUID
  let food: Food
  let grams: Double
  let meal: MealType
  let date: Date
  let target: Double
  let proteinTarget: Double
}

struct MealEditorRoute: Identifiable {
  let id = UUID()
  let meal: MealType
}
