import SwiftUI

struct PortionSelection: Identifiable, Hashable {
  let id = UUID()
  let food: Food
  let grams: Double
  var entryID: UUID? = nil
}

struct PortionEditorView: View {
  let selection: PortionSelection
  var onSave: (Food, Double) -> Void
  @Environment(AppLocalization.self) private var l
  @Environment(\.dismiss) private var dismiss
  @State private var food: Food
  @State private var amount: Double
  @State private var portionID = "amount"
  @FocusState private var amountFocused: Bool

  init(selection: PortionSelection, onSave: @escaping (Food, Double) -> Void) {
    self.selection = selection
    self.onSave = onSave
    _food = State(initialValue: selection.food)
    _amount = State(initialValue: selection.grams)
  }
  private var selectedPortion: FoodPortion? { food.availablePortions.first { $0.id == portionID } }
  private var grams: Double { amount * (selectedPortion?.amount ?? 1) }
  private var valid: Bool { grams.isFinite && (1...3000).contains(grams) }
  private var portionBinding: Binding<String> {
    Binding(
      get: { portionID },
      set: { newID in
        let current = grams
        portionID = newID
        amount = current / (selectedPortion?.amount ?? 1)
      })
  }
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        Panel {
          VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
              FoodThumbnail(food: food, size: 64)
              Text(food.name(l.language)).font(.title2.bold())
            }
            if let variants = food.preparations, !variants.isEmpty {
              Picker(
                l.text("food.preparation"),
                selection: Binding(
                  get: { food.selectedPreparation ?? variants[0].id },
                  set: {
                    let weight = grams
                    food = food.prepared($0)
                    portionID = "amount"
                    amount = weight
                  }
                )
              ) {
                ForEach(variants) { variant in Text(l.text(variant.titleKey)).tag(variant.id) }
              }.accessibilityIdentifier("portion.preparation")
              Text(l.text("food.preparationNote")).font(.caption).foregroundStyle(.secondary)
            }
            if !food.availablePortions.isEmpty {
              Picker(l.text("food.measurement"), selection: portionBinding) {
                Text(l.text(food.unitKey)).tag("amount")
                ForEach(food.availablePortions) { portion in
                  Text(l.text(portion.titleKey)).tag(portion.id)
                }
              }.accessibilityIdentifier("portion.unit")
            }
            HStack {
              Text(
                l.text(
                  selectedPortion == nil
                    ? (food.unit == "ml" ? "milliliters" : "grams") : "portion.count"))
              TextField(l.text("portion.count"), value: $amount, format: .number)
                .font(.title2.bold())
                .padding(12)
                .background(
                  Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
                )
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($amountFocused)
                .contentShape(Rectangle()).onTapGesture { amountFocused = true }
                .accessibilityIdentifier("portion.grams")
            }
            if let portion = selectedPortion {
              Text(
                "1 " + l.text(portion.titleKey) + " ≈ " + l.number(portion.amount) + " "
                  + l.text(food.unitKey)
                  + " · " + l.number(grams) + " " + l.text(food.unitKey)
              )
              .font(.caption).foregroundStyle(.secondary)
              Text(l.text("portion.estimate")).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
              ForEach(
                food.unit == "ml" ? [100.0, 200, 250, 330] : [50.0, 100, 150, 200], id: \.self
              ) {
                value in
                Button(l.number(value) + " " + l.text(food.unitKey)) {
                  amountFocused = false
                  portionID = "amount"
                  amount = value
                }.font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
                  .buttonStyle(.bordered).accessibilityIdentifier("portion.\(Int(value))")
              }
            }
            if valid {
              Text(l.number(food.nutrition(grams: grams).calories) + " " + l.text("unit.kcal"))
                .accessibilityIdentifier("portion.calories")
            } else {
              Text(l.text(food.unit == "ml" ? "mealEditor.invalidML" : "mealEditor.invalidGrams"))
                .foregroundStyle(.red)
            }
          }
        }
        PrimaryButton(
          title: l.text(selection.entryID == nil ? "mealEditor.addItem" : "mealEditor.updateItem"),
          icon: "checkmark"
        ) {
          onSave(food, grams)
          dismiss()
        }.disabled(!valid).opacity(valid ? 1 : 0.45).accessibilityIdentifier("portion.confirm")
      }.padding(20)
    }.background(Color(.systemGroupedBackground)).navigationTitle(l.text("portion"))
      .scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button(l.text("done")) { amountFocused = false }
            .accessibilityIdentifier("portion.keyboardDone")
        }
      }
  }
}
