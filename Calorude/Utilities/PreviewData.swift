#if DEBUG
  import SwiftData
  import SwiftUI

  @MainActor enum PreviewData {
    static func container() -> ModelContainer {
      let schema = Schema(versionedSchema: CalorudeSchemaV1.self)
      do {
        let container = try ModelContainer(
          for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let profile = UserProfile(
          name: "Emre", age: 28, sex: .male, height: 180, weight: 80, target: 75,
          activity: .moderate, goal: .lose, weekly: 0.25,
          plan: NutritionPlan(calories: 2400, protein: 160, carbs: 260, fat: 80), language: "tr")
        container.mainContext.insert(profile)
        container.mainContext.insert(AppPreferences(language: "tr"))
        if let foods = try? FoodRepository().foods,
          let chicken = foods.first(where: { $0.id == "chicken" })
        {
          container.mainContext.insert(
            FoodEntry(food: chicken, grams: 200, meal: .lunch, target: 2400, proteinTarget: 160))
        }
        try container.mainContext.save()
        return container
      } catch { preconditionFailure("Preview fixture failed: \(error)") }
    }
  }
  #Preview("Türkçe · Dark") {
    RootView().modelContainer(PreviewData.container()).environment(AppLocalization(language: "tr"))
      .environment(StoreService()).tint(Theme.interactive)
  }
  #Preview("English · Accessible") {
    RootView().modelContainer(PreviewData.container()).environment(AppLocalization(language: "en"))
      .environment(StoreService()).dynamicTypeSize(.accessibility1).tint(Theme.interactive)
  }
#endif
