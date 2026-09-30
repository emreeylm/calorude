import SwiftData
import SwiftUI

struct CustomFoodView: View {
  @Environment(AppLocalization.self) private var l
  @Environment(StoreService.self) private var store
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query private var custom: [CustomFood]
  @State private var name = ""
  @State private var amountUnit = "g"
  @State private var calories = 0.0
  @State private var protein = 0.0
  @State private var carbs = 0.0
  @State private var fat = 0.0
  @State private var error = false
  var valid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && calories.isFinite
      && (0...900).contains(calories)
      && [protein, carbs, fat].allSatisfy { $0.isFinite && (0...100).contains($0) }
      && protein + carbs + fat <= 100 && (store.isPro || custom.count < 10)
  }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker(l.text("food.measurement"), selection: $amountUnit) {
            Text(l.text("food.solid")).tag("g")
            Text(l.text("food.liquid")).tag("ml")
          }
        }
        Section(l.text(amountUnit == "ml" ? "per100ml" : "per100")) {
          TextField(l.text("name"), text: $name)
          field("calories", value: $calories)
          field("protein", value: $protein)
          field("carbs", value: $carbs)
          field("fat", value: $fat)
        }
        Section { Text(l.text("custom.limit")).font(.footnote) }
      }
      .navigationTitle(l.text("custom.create")).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(l.text("cancel")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(l.text("save")) {
            context.insert(
              CustomFood(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines), calories: calories,
                protein: protein, carbs: carbs, fat: fat, amountUnit: amountUnit))
            do {
              try context.save()
              dismiss()
            } catch {
              context.rollback()
              self.error = true
            }
          }.disabled(!valid)
        }
      }.alert(l.text("error.save"), isPresented: $error) { Button(l.text("ok"), role: .cancel) {} }
    }
  }
  func field(_ key: String, value: Binding<Double>) -> some View {
    HStack {
      Text(l.text(key))
      TextField(l.text(key), value: value, format: .number).multilineTextAlignment(.trailing)
        .keyboardType(.decimalPad)
    }
  }
}
