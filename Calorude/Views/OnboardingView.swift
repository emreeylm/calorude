import SwiftData
import SwiftUI

struct OnboardingView: View {
  @Environment(AppLocalization.self) private var l
  @Environment(\.modelContext) private var context
  @FocusState private var nameFocused: Bool
  @State private var vm = OnboardingViewModel()
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          HStack {
            Text(AppBrand.name(l)).font(.headline)
            Spacer()
            Text("0\(vm.step + 1) / 04").monospacedDigit().foregroundStyle(.secondary)
          }
          ProgressView(value: Double(vm.step + 1), total: 4).tint(Theme.interactive)
          Text(l.text("onboard.title.\(vm.step)")).font(
            .system(.largeTitle, design: .rounded, weight: .black))
          Text(l.text("onboard.subtitle.\(vm.step)")).foregroundStyle(.secondary)
          if vm.step == 0 {
            Panel {
              VStack(spacing: 20) {
                TextField(l.text("name"), text: $vm.name).textContentType(.nickname)
                  .autocorrectionDisabled().accessibilityIdentifier("onboarding.name").focused(
                    $nameFocused
                  ).submitLabel(.done).onSubmit { nameFocused = false }
                Stepper(l.text("age") + ": \(vm.age)", value: $vm.age, in: 18...80)
                Picker(l.text("sex"), selection: $vm.sex) {
                  ForEach(Sex.allCases, id: \.self) { Text(l.text("sex." + $0.rawValue)).tag($0) }
                }
                Toggle(l.text("eligibility"), isOn: $vm.eligible).accessibilityIdentifier(
                  "onboarding.eligibility")
              }
            }
          } else if vm.step == 1 {
            Panel {
              VStack(spacing: 22) {
                metric("height", value: $vm.height, range: 130...220, unit: "unit.cm")
                metric("weight", value: $vm.weight, range: 40...250, unit: "unit.kg")
                metric("targetWeight", value: $vm.target, range: 40...250, unit: "unit.kg")
              }
            }
          } else if vm.step == 2 {
            Panel {
              VStack(spacing: 24) {
                Picker(l.text("goal"), selection: $vm.goal) {
                  ForEach(Goal.allCases, id: \.self) { Text(l.text("goal." + $0.rawValue)).tag($0) }
                }
                Picker(l.text("activity"), selection: $vm.activity) {
                  ForEach(Activity.allCases, id: \.self) {
                    Text(l.text("activity." + $0.rawValue)).tag($0)
                  }
                }
                if vm.goal != .maintain {
                  Picker(l.text("weeklyChange"), selection: $vm.weekly) {
                    ForEach(vm.weeklyOptions, id: \.self) { amount in
                      Text(l.number(amount, digits: 1) + " " + l.text("kg.week")).tag(amount)
                    }
                  }
                }
              }
            }
            WeeklyRateNote(viewModel: vm)
            Text(l.text("plan.disclaimer")).font(.footnote).foregroundStyle(.secondary)
          } else {
            Panel {
              VStack(alignment: .leading, spacing: 24) {
                Text(l.text("dailyTarget")).font(.headline)
                Text(l.number(vm.plan.calories)).font(
                  .system(size: 64, weight: .black, design: .rounded)
                ).minimumScaleFactor(0.5)
                Text(l.text("unit.kcal")).foregroundStyle(.secondary)
                HStack {
                  MacroBar(
                    title: l.text("protein"), amount: 0, target: vm.plan.protein,
                    color: Theme.protein)
                  MacroBar(
                    title: l.text("carbs"), amount: 0, target: vm.plan.carbs, color: Theme.carbs)
                  MacroBar(title: l.text("fat"), amount: 0, target: vm.plan.fat, color: Theme.fat)
                }
              }
            }
            WeeklyRateNote(viewModel: vm)
            Text(l.text("plan.ready")).font(.title3.bold())
          }
          if vm.error {
            Text(l.text("validation.profile")).foregroundStyle(.red).accessibilityAddTraits(
              .isStaticText)
          }
          PrimaryButton(title: l.text(vm.step == 3 ? "start" : "continue")) { next() }
            .accessibilityIdentifier("onboarding.next")
          if vm.step > 0 {
            Button(l.text("back")) {
              vm.step -= 1
              vm.error = false
            }
          }
        }.padding(24)
      }.background(Color(.systemGroupedBackground))
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
    if vm.step == 0
      && (vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !vm.eligible)
    {
      vm.error = true
      return
    }
    if vm.step == 2 && !vm.valid {
      vm.error = true
      return
    }
    vm.error = false
    if vm.step < 3 {
      withAnimation { vm.step += 1 }
      return
    }
    let profile = vm.profile(language: l.language)
    context.insert(profile)
    context.insert(WeightEntry(weight: vm.weight))
    context.insert(AppPreferences(language: l.language))
    do { try context.save() } catch {
      context.rollback()
      vm.error = true
    }
  }
}
#Preview {
  OnboardingView().environment(AppLocalization(language: "tr")).preferredColorScheme(.dark)
    .modelContainer(for: UserProfile.self, inMemory: true)
}
