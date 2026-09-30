import SwiftData
import XCTest

@testable import Calorude

@MainActor final class MealEditorTests: XCTestCase {
  private var containers: [ModelContainer] = []
  func fixture() throws -> (ModelContext, UserProfile, [Food]) {
    let container = try ModelContainer(
      for: UserProfile.self, FoodEntry.self, SavedMeal.self, SavedMealItem.self,
      DailySummary.self, StreakState.self, AchievementState.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    containers.append(container)
    let context = container.mainContext
    let vm = OnboardingViewModel()
    vm.name = "Test"
    let profile = vm.profile(language: "tr")
    context.insert(profile)
    try context.save()
    return (context, profile, try FoodRepository().foods)
  }
  func testDrinkUnitsSurviveSaveEditAndLegacyDecode() throws {
    let (context, profile, foods) = try fixture()
    let cola = try XCTUnwrap(foods.first { $0.id == "cola" })
    let ayran = try XCTUnwrap(foods.first { $0.id == "ayran" })
    XCTAssertEqual(cola.unit, "ml")
    XCTAssertEqual(ayran.unit, "ml")
    XCTAssertEqual(foods.first { $0.id == "yogurt" }?.unit, "g")
    XCTAssertEqual(cola.nutrition(grams: 330).calories, 138.6, accuracy: 0.001)
    for food in [cola, ayran] {
      var object = try XCTUnwrap(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(food)) as? [String: Any])
      object.removeValue(forKey: "amountUnit")
      let legacy = try JSONDecoder().decode(
        Food.self, from: JSONSerialization.data(withJSONObject: object))
      XCTAssertEqual(legacy.unit, "ml")
    }
    let draft = MealEditorViewModel(meal: .lunch)
    try draft.load(entries: [])
    draft.add(food: cola, grams: 330)
    try MealRepository.commit(
      items: draft.items, originals: [], date: .now, profile: profile, context: context)
    let entry = try XCTUnwrap(context.fetch(FetchDescriptor<FoodEntry>()).first)
    XCTAssertEqual(entry.unit, "ml")
    entry.amountUnit = nil  // Pre-update diary entry: preserve totals and infer legacy drink unit.
    try context.save()
    let edit = MealEditorViewModel(meal: .lunch)
    try edit.load(entries: [entry])
    XCTAssertEqual(edit.currentItems.first?.food.unit, "ml")
    edit.update(id: entry.id, grams: 200)
    try MealRepository.commit(
      items: edit.items, originals: edit.originals, date: .now, profile: profile, context: context
    )
    XCTAssertEqual(entry.calories, 84, accuracy: 0.001)
    XCTAssertEqual(entry.unit, "ml")
    let custom = CustomFood(
      name: "Test drink", calories: 40, protein: 2, carbs: 5, fat: 1, amountUnit: "ml")
    let saved = try SavedMealItem(food: custom.food, grams: 250)
    XCTAssertEqual(saved.food?.unit, "ml")
    XCTAssertEqual(saved.food?.nutrition(grams: saved.grams).calories, 100)
    XCTAssertEqual(foods.count, 108)
    XCTAssertEqual(foods.filter { $0.unit == "g" }.count, 88)
    XCTAssertEqual(foods.filter { $0.unit == "ml" }.count, 20)
    for id in ["turkey", "tuna", "wholebread", "oats", "blacktea", "greentea", "proteinmilk"] {
      XCTAssertTrue(foods.contains { $0.id == id })
    }
  }
  func testPreparationChangesRecalculateAndPersistWithoutChangingTargets() throws {
    let (context, profile, foods) = try fixture()
    let chicken = try XCTUnwrap(foods.first { $0.id == "chicken" })
    XCTAssertFalse(chicken.localizedNameTR.contains("pişmiş"))
    XCTAssertEqual(chicken.prepared("raw").nutrition(grams: 100).calories, 120, accuracy: 0.01)
    let draft = MealEditorViewModel(meal: .lunch)
    try draft.load(entries: [])
    draft.add(food: chicken.prepared("raw"), grams: 200)
    try MealRepository.commit(
      items: draft.items, originals: [], date: .now, profile: profile, context: context)
    let entry = try XCTUnwrap(context.fetch(FetchDescriptor<FoodEntry>()).first)
    XCTAssertEqual(entry.calories, 240, accuracy: 0.01)
    let target = entry.calorieTargetSnapshot
    let edit = MealEditorViewModel(meal: .lunch)
    try edit.load(entries: [entry])
    let food = try XCTUnwrap(edit.items.first?.food)
    XCTAssertEqual(food.selectedPreparation, "raw")
    edit.update(id: entry.id, grams: 200, food: food.prepared("cooked"))
    try MealRepository.commit(
      items: edit.items, originals: edit.originals, date: .now, profile: profile, context: context)
    XCTAssertEqual(entry.calories, 330, accuracy: 0.01)
    XCTAssertEqual(entry.calorieTargetSnapshot, target)
    let reloaded = try MealDraftItem(entry: entry)
    XCTAssertEqual(reloaded.food.selectedPreparation, "cooked")
    let saved = try SavedMealItem(food: reloaded.food, grams: 200)
    XCTAssertEqual(saved.food?.selectedPreparation, "cooked")
    XCTAssertEqual(foods.first { $0.id == "egg" }?.portions?.first?.amount, 50)
    XCTAssertEqual(foods.first { $0.id == "bread" }?.portions?.first?.amount, 30)
    XCTAssertEqual(foods.first { $0.id == "ayran" }?.portions?.first?.amount, 200)
    XCTAssertTrue(chicken.prepared("raw").availablePortions.isEmpty)
  }
  func testBatchAdditionThenPortionEditAndRemoval() throws {
    let (context, profile, foods) = try fixture()
    let rice = try XCTUnwrap(foods.first { $0.id == "rice" })
    let chicken = try XCTUnwrap(foods.first { $0.id == "chicken" })
    let yogurt = try XCTUnwrap(foods.first { $0.id == "yogurt" })
    let date = Date.now
    let draft = MealEditorViewModel(meal: .lunch)
    try draft.load(entries: [])
    draft.add(food: rice, grams: 150)
    draft.add(food: chicken, grams: 200)
    draft.add(food: yogurt, grams: 100)
    XCTAssertEqual(draft.currentItems.count, 3)
    XCTAssertEqual(draft.total.calories, 646, accuracy: 0.001)
    XCTAssertEqual(
      try context.fetchCount(FetchDescriptor<FoodEntry>()), 0, "Drafts must not leak into the diary"
    )
    try MealRepository.commit(
      items: draft.items, originals: draft.originals, date: date, profile: profile, context: context
    )
    var rows = try context.fetch(FetchDescriptor<FoodEntry>())
    XCTAssertEqual(rows.count, 3)
    let riceEntry = try XCTUnwrap(rows.first { $0.foodID == "rice" })
    let originalID = riceEntry.id
    let originalDate = riceEntry.date
    let originalTarget = riceEntry.calorieTargetSnapshot
    let before = FoodEntryFingerprint(riceEntry)
    // Changing the profile must not rewrite the target of an existing logged meal.
    profile.dailyCalorieTarget = 3000
    let edit = MealEditorViewModel(meal: .lunch)
    try edit.load(entries: rows)
    edit.update(id: originalID, grams: 200)
    edit.remove(id: try XCTUnwrap(rows.first { $0.foodID == "chicken" }).id)
    try MealRepository.commit(
      items: edit.items, originals: edit.originals, date: date, profile: profile, context: context)
    rows = try context.fetch(FetchDescriptor<FoodEntry>())
    XCTAssertEqual(rows.count, 2)
    XCTAssertEqual(riceEntry.id, originalID)
    XCTAssertEqual(riceEntry.date, originalDate)
    XCTAssertEqual(riceEntry.calorieTargetSnapshot, originalTarget)
    XCTAssertEqual(riceEntry.calories, 340, accuracy: 0.001)
    XCTAssertEqual(riceEntry.protein, 6, accuracy: 0.001)
    XCTAssertNotEqual(before, FoodEntryFingerprint(riceEntry))
    try TrackingCoordinator.rebuild(context: context, profile: profile, entries: rows)
    let summary = try XCTUnwrap(context.fetch(FetchDescriptor<DailySummary>()).first)
    XCTAssertEqual(summary.calories, 401, accuracy: 0.001)
    XCTAssertEqual(summary.protein, 9.5, accuracy: 0.001)
  }
  func testCancelAndInvalidBatchLeaveDiaryUnchanged() throws {
    let (context, profile, foods) = try fixture()
    let food = try XCTUnwrap(foods.first)
    try FoodRepository.log(
      food: food, grams: 100, meal: .lunch, date: .now, profile: profile, context: context)
    let rows = try context.fetch(FetchDescriptor<FoodEntry>())
    let entry = try XCTUnwrap(rows.first)
    let draft = MealEditorViewModel()
    try draft.load(entries: rows)
    draft.update(id: entry.id, grams: 200)
    XCTAssertEqual(entry.amountInGrams, 100, "Cancel needs no database rollback")
    draft.add(food: food, grams: .nan)
    XCTAssertFalse(draft.canSave)
    XCTAssertThrowsError(
      try MealRepository.commit(
        items: draft.items, originals: draft.originals, date: .now, profile: profile,
        context: context))
    XCTAssertEqual(entry.amountInGrams, 100)
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntry>()), 1)
  }
  func testSwitchingMealsPreservesDraftsAndSavedMealIsNotLoggedEarly() throws {
    let (context, _, foods) = try fixture()
    let food = try XCTUnwrap(foods.first)
    let draft = MealEditorViewModel()
    try draft.load(entries: [])
    draft.add(food: food, grams: 150)
    draft.meal = .dinner
    XCTAssertTrue(draft.currentItems.isEmpty)
    let saved = SavedMeal(
      name: "Test",
      items: [try SavedMealItem(food: food, grams: 50), try SavedMealItem(food: food, grams: 100)])
    try draft.add(savedMeal: saved)
    XCTAssertEqual(draft.currentItems.count, 2)
    draft.meal = .lunch
    XCTAssertEqual(draft.currentItems.count, 1)
    XCTAssertEqual(draft.items.count, 3)
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntry>()), 0)
  }
  func testDeleteEntireMealKeepsOtherDatesAndMeals() throws {
    let (context, profile, foods) = try fixture()
    let food = try XCTUnwrap(foods.first)
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!
    for (date, meal) in [(Date.now, MealType.lunch), (Date.now, .dinner), (yesterday, .lunch)] {
      try FoodRepository.log(
        food: food, grams: 100, meal: meal, date: date, profile: profile, context: context)
    }
    let today = try context.fetch(FetchDescriptor<FoodEntry>()).filter {
      Calendar.current.isDateInToday($0.date)
    }
    let draft = MealEditorViewModel()
    try draft.load(entries: today)
    for item in draft.currentItems { draft.remove(id: item.id) }
    XCTAssertTrue(draft.canSave)
    try MealRepository.commit(
      items: draft.items, originals: draft.originals, date: .now, profile: profile, context: context
    )
    let rows = try context.fetch(FetchDescriptor<FoodEntry>())
    XCTAssertEqual(rows.count, 2)
    XCTAssertTrue(rows.contains { $0.mealType == .dinner })
    XCTAssertTrue(rows.contains { Calendar.current.isDate($0.date, inSameDayAs: yesterday) })
  }
  func testConcurrentChangesAreNotOverwritten() throws {
    let (context, profile, foods) = try fixture()
    try FoodRepository.log(
      food: try XCTUnwrap(foods.first), grams: 100, meal: .lunch, date: .now, profile: profile,
      context: context)
    let rows = try context.fetch(FetchDescriptor<FoodEntry>())
    let draft = MealEditorViewModel()
    try draft.load(entries: rows)
    let entry = try XCTUnwrap(rows.first)
    entry.calories = 42
    try context.save()
    draft.remove(id: entry.id)
    XCTAssertThrowsError(
      try MealRepository.commit(
        items: draft.items, originals: draft.originals, date: .now, profile: profile,
        context: context))
    XCTAssertEqual(entry.calories, 42)
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntry>()), 1)
  }
}
