import SwiftData
import SwiftUI

struct OnboardingView: View {
  @Environment(AppLocalization.self) private var l
  @Environment(\.modelContext) private var context
  @FocusState private var nameFocused: Bool
  @State private var vm = OnboardingViewModel()

  var body: some View {
    NavigationStack {
      if vm.step == .loading {
        CalculatingView { vm.advance() }
      } else {
        // New identity per step: no cross-fade ghosting and the scroll position starts at the top.
        ScrollView { content }.id(vm.step).background(Color(.systemGroupedBackground))
          .scrollDismissesKeyboard(.interactively)
      }
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 24) {
      header
      Text(l.text("ob.title." + vm.step.name))
        .font(.system(.largeTitle, design: .rounded, weight: .black))
        .accessibilityIdentifier(
          vm.step == .result ? "onboarding.result" : "onboarding.step." + vm.step.name)
      Text(l.text("ob.sub." + vm.step.name)).foregroundStyle(.secondary)
      stepBody
      if let key = vm.errorKey {
        Text(l.text(key)).foregroundStyle(.red).accessibilityIdentifier("onboarding.error")
      }
      PrimaryButton(title: l.text(primaryKey)) { next() }
        .accessibilityIdentifier("onboarding.next")
      if vm.step != .goal && vm.step != .result {
        Button(l.text("back")) { vm.goBack() }
          .accessibilityIdentifier("onboarding.back")
      }
    }.padding(24)
  }

  private var primaryKey: String {
    switch vm.step {
    case .result: "start"
    case .safety: "ob.calculate"
    default: "continue"
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(AppBrand.name(l)).font(.headline)
        Spacer()
        if vm.step != .result {
          Text(verbatim: "\(vm.progress.position) / \(vm.progress.total)").monospacedDigit()
            .foregroundStyle(.secondary)
        }
      }
      if vm.step != .result {
        ProgressView(value: Double(vm.progress.position), total: Double(vm.progress.total))
          .tint(Theme.interactive)
      }
    }
  }

  @ViewBuilder private var stepBody: some View {
    switch vm.step {
    case .goal: goalStep
    case .about: aboutStep
    case .body: bodyStep
    case .lifestyle: lifestyleStep
    case .workouts: workoutsStep
    case .habits: habitsStep
    case .safety: safetyStep
    case .loading: EmptyView()
    case .result: resultStep
    }
  }

  private var goalStep: some View {
    VStack(spacing: 12) {
      ForEach(Goal.allCases, id: \.self) { goal in
        ChoiceCard(
          icon: goalIcon(goal), title: l.text("goal." + goal.rawValue),
          subtitle: l.text("ob.goal." + goal.rawValue), selected: vm.goal == goal
        ) { vm.goal = goal }
          .accessibilityIdentifier("onboarding.goal." + goal.rawValue)
      }
    }
  }

  private var aboutStep: some View {
    Panel {
      VStack(spacing: 20) {
        TextField(l.text("name"), text: $vm.name).textContentType(.nickname)
          .autocorrectionDisabled().accessibilityIdentifier("onboarding.name")
          .focused($nameFocused).submitLabel(.done).onSubmit { nameFocused = false }
        Stepper(l.text("age") + ": \(vm.age)", value: $vm.age, in: 18...80)
        Picker(l.text("sex"), selection: $vm.sex) {
          ForEach(Sex.allCases, id: \.self) { Text(l.text("sex." + $0.rawValue)).tag($0) }
        }
      }
    }
  }

  private var bodyStep: some View {
    Panel {
      VStack(spacing: 22) {
        metric("height", value: $vm.height, range: 130...220, unit: "unit.cm")
        metric("weight", value: $vm.weight, range: 40...250, unit: "unit.kg")
        if vm.goal != .maintain {
          metric("targetWeight", value: $vm.target, range: 40...250, unit: "unit.kg")
        }
      }
    }
  }

  private var lifestyleStep: some View {
    VStack(spacing: 12) {
      ForEach(DailyLife.allCases, id: \.self) { life in
        ChoiceCard(
          icon: ["desktopcomputer", "figure.walk", "hammer.fill"][life.rawValue],
          title: l.text("ob.life.\(life)"), subtitle: l.text("ob.life.\(life).sub"),
          selected: vm.lifestyle == life
        ) { vm.lifestyle = life }
          .accessibilityIdentifier("onboarding.lifestyle.\(life)")
      }
    }
  }

  private var workoutsStep: some View {
    VStack(spacing: 12) {
      ForEach(WorkoutFrequency.allCases, id: \.self) { frequency in
        ChoiceCard(
          icon: ["moon.zzz.fill", "figure.walk", "figure.run", "flame.fill"][frequency.rawValue],
          title: l.text("ob.workouts.\(frequency)"), subtitle: l.text("ob.workouts.\(frequency).sub"),
          selected: vm.workouts == frequency
        ) { vm.workouts = frequency }
          .accessibilityIdentifier("onboarding.workouts.\(frequency)")
      }
    }
  }

  private var habitsStep: some View {
    VStack(spacing: 12) {
      ForEach(EatingChallenge.options(for: vm.goal), id: \.self) { challenge in
        ChoiceCard(
          icon: challengeIcon(challenge), title: l.text("ob.challenge." + challenge.rawValue),
          subtitle: nil, selected: vm.challenge == challenge
        ) { vm.challenge = challenge }
          .accessibilityIdentifier("onboarding.challenge." + challenge.rawValue)
      }
    }
  }

  private var safetyStep: some View {
    Panel {
      VStack(alignment: .leading, spacing: 16) {
        Toggle(l.text("eligibility"), isOn: $vm.eligible)
          .accessibilityIdentifier("onboarding.eligibility")
        Text(l.text("plan.disclaimer")).font(.footnote).foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder private var resultStep: some View {
    Panel {
      VStack(alignment: .leading, spacing: 24) {
        Text(l.text("dailyTarget")).font(.headline)
        Text(l.number(vm.plan.calories)).font(.system(size: 64, weight: .black, design: .rounded))
          .minimumScaleFactor(0.5)
        Text(l.text("unit.kcal")).foregroundStyle(.secondary)
        HStack {
          MacroBar(
            title: l.text("protein"), amount: 0, target: vm.plan.protein, color: Theme.protein)
          MacroBar(title: l.text("carbs"), amount: 0, target: vm.plan.carbs, color: Theme.carbs)
          MacroBar(title: l.text("fat"), amount: 0, target: vm.plan.fat, color: Theme.fat)
        }
      }
    }
    WeeklyRateNote(viewModel: vm)
    Panel {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "lightbulb.fill").foregroundStyle(Theme.interactive)
        Text(l.text(vm.tipKey)).fixedSize(horizontal: false, vertical: true)
      }
    }
    Text(l.text("plan.disclaimer")).font(.footnote).foregroundStyle(.secondary)
  }

  private func goalIcon(_ goal: Goal) -> String {
    switch goal {
    case .lose: "arrow.down.circle.fill"
    case .muscle: "dumbbell.fill"
    case .gain: "arrow.up.circle.fill"
    case .maintain: "equal.circle.fill"
    }
  }
  private func challengeIcon(_ challenge: EatingChallenge) -> String {
    switch challenge {
    case .sweets: "birthday.cake.fill"
    case .nightSnacking: "moon.stars.fill"
    case .portions: "fork.knife"
    case .eatingOut: "takeoutbag.and.cup.and.straw.fill"
    case .irregular: "clock.fill"
    case .lowAppetite: "leaf.fill"
    case .noIdea, .notSure: "questionmark.circle.fill"
    }
  }

  private func metric(
    _ key: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String
  ) -> some View {
    VStack(alignment: .leading) {
      HStack {
        Text(l.text(key))
        Spacer()
        Text(l.number(value.wrappedValue, digits: 1) + " " + l.text(unit)).fontWeight(.bold)
      }
      HStack(spacing: 4) {
        stepButton("minus", key: key, value: value, range: range, delta: -0.5)
        Slider(value: value, in: range, step: 0.5).tint(Theme.interactive)
        stepButton("plus", key: key, value: value, range: range, delta: 0.5)
      }
    }
  }
  // A slider alone is too coarse for 0.5-step values across a 90-unit range.
  private func stepButton(
    _ icon: String, key: String, value: Binding<Double>, range: ClosedRange<Double>, delta: Double
  ) -> some View {
    Button {
      value.wrappedValue = min(max(value.wrappedValue + delta, range.lowerBound), range.upperBound)
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      Image(systemName: icon + ".circle.fill").font(.title2).frame(width: 44, height: 44)
    }.buttonStyle(.plain).foregroundStyle(Theme.interactive)
      .accessibilityLabel(l.text(key) + (delta > 0 ? " +" : " −") + "0,5")
  }

  private func next() {
    nameFocused = false
    if vm.step == .result {
      finish()
      return
    }
    vm.advance()
  }
  private func finish() {
    context.insert(vm.profile(language: l.language))
    context.insert(WeightEntry(weight: vm.weight))
    context.insert(AppPreferences(language: l.language))
    do { try context.save() } catch {
      context.rollback()
      vm.errorKey = "error.save"
    }
  }
}

struct ChoiceCard: View {
  var icon: String
  var title: String
  var subtitle: String?
  var selected: Bool
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: icon).font(.title2).frame(width: 36)
          .foregroundStyle(selected ? Theme.interactive : Color.secondary)
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.headline)
          if let subtitle {
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
          }
        }.multilineTextAlignment(.leading)
        Spacer()
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(selected ? Theme.interactive : Color.secondary)
      }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(
          Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 18).stroke(
            selected ? Theme.interactive : Color.clear, lineWidth: 2)
        ).contentShape(RoundedRectangle(cornerRadius: 18))
    }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
  }
}

// The plan is instant to compute; the pause is a deliberate "we're working on it" moment.
private struct CalculatingView: View {
  var onFinished: () -> Void
  @Environment(AppLocalization.self) private var l
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var stage = 0
  @State private var progress = 0.0
  private let stageKeys = ["ob.loading.1", "ob.loading.2", "ob.loading.3", "ob.loading.4"]
  // Four stages of 1.1 s keep the whole wait under five seconds.
  private var stageSeconds: Double {
    #if DEBUG
      ProcessInfo.processInfo.arguments.contains("--uitesting") ? 0.15 : 1.1
    #else
      1.1
    #endif
  }

  var body: some View {
    VStack(spacing: 28) {
      Spacer()
      ZStack {
        Circle().stroke(Theme.interactive.opacity(0.15), lineWidth: 14)
        Circle().trim(from: 0, to: progress)
          .stroke(Theme.interactive, style: StrokeStyle(lineWidth: 14, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Image(systemName: "bolt.fill").font(.system(size: 44)).foregroundStyle(Theme.interactive)
      }.frame(width: 150, height: 150).accessibilityHidden(true)
      Text(l.text("ob.loading.title"))
        .font(.system(.title2, design: .rounded, weight: .black)).multilineTextAlignment(.center)
        .accessibilityIdentifier("onboarding.loading")
      Text(l.text(stageKeys[stage])).font(.subheadline).foregroundStyle(.secondary)
        .multilineTextAlignment(.center).frame(minHeight: 40, alignment: .top)
      Spacer()
    }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemGroupedBackground))
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: stage)
      .task {
        for index in stageKeys.indices {
          stage = index
          withAnimation(reduceMotion ? nil : .linear(duration: stageSeconds)) {
            progress = Double(index + 1) / Double(stageKeys.count)
          }
          try? await Task.sleep(for: .seconds(stageSeconds))
          if Task.isCancelled { return }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFinished()
      }
  }
}

#Preview {
  OnboardingView().environment(AppLocalization(language: "tr")).preferredColorScheme(.dark)
    .modelContainer(for: UserProfile.self, inMemory: true)
}
