import SwiftData
import SwiftUI

struct EditPlanView: View {
  let profile: UserProfile
  @Environment(AppLocalization.self) private var l
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var vm: OnboardingViewModel
  @State private var error = false
  init(profile: UserProfile) {
    self.profile = profile
    let vm = OnboardingViewModel()
    vm.name = profile.name
    vm.age = profile.age
    vm.sex = profile.sex
    vm.height = profile.height
    vm.weight = profile.currentWeight
    // Goal first: changing it resets a target that does not fit, so the saved target goes last.
    vm.goal = profile.goalType
    vm.target = profile.targetWeight
    vm.activity = profile.activityLevel
    vm.eligible = true
    _vm = State(initialValue: vm)
  }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Stepper(l.text("age") + ": \(vm.age)", value: $vm.age, in: 18...80)
          number("height", $vm.height)
          number("weight", $vm.weight)
          number("targetWeight", $vm.target)
          Picker(l.text("sex"), selection: $vm.sex) {
            ForEach(Sex.allCases, id: \.self) { Text(l.text("sex." + $0.rawValue)).tag($0) }
          }
          Picker(l.text("goal"), selection: $vm.goal) {
            ForEach(Goal.allCases, id: \.self) { Text(l.text("goal." + $0.rawValue)).tag($0) }
          }
          Picker(l.text("activity"), selection: $vm.activity) {
            ForEach(Activity.allCases, id: \.self) {
              Text(l.text("activity." + $0.rawValue)).tag($0)
            }
          }
        }
        Section {
          if vm.valid {
            LabeledContent(
              l.text("dailyTarget"), value: l.number(vm.plan.calories) + " " + l.text("unit.kcal"))
          } else {
            Text(l.text(vm.validationKey(for: .body) ?? "validation.profile"))
              .foregroundStyle(.red)
          }
          if vm.valid { WeeklyRateNote(viewModel: vm) }
          Text(l.text("editPlan.note")).font(.footnote)
          Text(l.text("plan.disclaimer")).font(.footnote)
        }
      }.navigationTitle(l.text("editPlan"))
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(l.text("cancel")) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(l.text("save")) { save() }.disabled(!vm.valid)
          }
        }
        .alert(l.text("error.save"), isPresented: $error) { Button(l.text("ok"), role: .cancel) {} }
    }
  }
  func number(_ key: String, _ value: Binding<Double>) -> some View {
    HStack {
      Text(l.text(key))
      TextField(l.text(key), value: value, format: .number).keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
    }
  }
  func save() {
    profile.age = vm.age
    profile.sex = vm.sex
    profile.height = vm.height
    profile.currentWeight = vm.weight
    profile.targetWeight = vm.effectiveTarget
    profile.goalType = vm.goal
    profile.activityLevel = vm.activity
    profile.weeklyGoal = vm.goal == .maintain ? 0 : vm.weekly
    profile.dailyCalorieTarget = vm.plan.calories
    profile.proteinTarget = vm.plan.protein
    profile.carbTarget = vm.plan.carbs
    profile.fatTarget = vm.plan.fat
    do {
      try context.save()
      dismiss()
    } catch {
      context.rollback()
      self.error = true
    }
  }
}
