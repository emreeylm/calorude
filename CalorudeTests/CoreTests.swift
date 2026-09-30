import SwiftData
import UIKit
import XCTest

@testable import Calorude

@MainActor final class CoreTests: XCTestCase {
  func testBMRAndTDEE() {
    XCTAssertEqual(NutritionCalculator.bmr(weight: 80, height: 180, age: 30, sex: .male), 1780)
    XCTAssertEqual(NutritionCalculator.bmr(weight: 60, height: 165, age: 30, sex: .female), 1320.25)
    XCTAssertEqual(
      NutritionCalculator.tdee(weight: 80, height: 180, age: 30, sex: .male, activity: .moderate),
      2759)
  }
  func testTargetsAndMacros() {
    for goal in Goal.allCases {
      let p = NutritionCalculator.plan(
        weight: 80, height: 180, age: 30, sex: .male, activity: .moderate, goal: goal, weekly: 0.5)
      XCTAssertEqual(p.protein * 4 + p.carbs * 4 + p.fat * 9, p.calories, accuracy: 0.01)
      XCTAssertGreaterThan(p.carbs, 0)
      if goal == .lose {
        XCTAssertLessThan(p.calories, 2759)
        XCTAssertGreaterThanOrEqual(p.calories, 2759 * 0.8 - 1)
      }
      if goal == .gain {
        XCTAssertGreaterThan(p.calories, 2759)
        XCTAssertLessThanOrEqual(p.calories, 3109)
      }
      if goal == .maintain { XCTAssertEqual(p.calories, 2759) }
    }
    let extreme = NutritionCalculator.plan(
      weight: 45, height: 150, age: 70, sex: .female, activity: .sedentary, goal: .lose, weekly: 8)
    XCTAssertGreaterThanOrEqual(extreme.calories, 1200)
  }
  func testWeeklyLossChoicesAndLimits() {
    let vm = OnboardingViewModel()
    XCTAssertEqual(vm.weekly, 0.5)
    XCTAssertEqual(vm.weeklyOptions, [0.5, 1])
    vm.weekly = 1
    XCTAssertTrue(vm.isWeeklyChangeLimited)
    XCTAssertLessThan(vm.estimatedWeeklyChange, 1)
    vm.goal = .gain
    XCTAssertEqual(vm.weeklyOptions, [0.25, 0.5])
    XCTAssertEqual(vm.weekly, 0.5)
    vm.goal = .maintain
    XCTAssertEqual(vm.estimatedWeeklyChange, 0)
    XCTAssertFalse(vm.isWeeklyChangeLimited)

    let half = NutritionCalculator.plan(
      weight: 150, height: 195, age: 30, sex: .male, activity: .intense, goal: .lose, weekly: 0.5)
    let full = NutritionCalculator.plan(
      weight: 150, height: 195, age: 30, sex: .male, activity: .intense, goal: .lose, weekly: 1)
    let maintenance = NutritionCalculator.tdee(
      weight: 150, height: 195, age: 30, sex: .male, activity: .intense)
    XCTAssertLessThan(full.calories, half.calories)
    XCTAssertGreaterThanOrEqual(full.calories, maintenance * 0.8 - 1)
    let extreme = NutritionCalculator.plan(
      weight: 150, height: 195, age: 30, sex: .male, activity: .intense, goal: .lose, weekly: 8)
    XCTAssertEqual(extreme, full)
    XCTAssertEqual(full.protein * 4 + full.carbs * 4 + full.fat * 9, full.calories, accuracy: 0.01)
  }

  func testFoodScaling() throws {
    let food = try XCTUnwrap(try FoodRepository().foods.first { $0.id == "chicken" })
    XCTAssertEqual(food.nutrition(grams: 150).calories, 247.5)
    XCTAssertEqual(food.nutrition(grams: 150).protein, 46.5)
    XCTAssertEqual(food.nutrition(grams: 0).calories, 0)
  }
  func day(_ offset: Int, calories: Double = 2000) -> DayStats {
    DayStats(
      day: Calendar.current.startOfDay(
        for: Calendar.current.date(byAdding: .day, value: offset, to: .now)!), calories: calories,
      protein: 130, carbs: 200, fat: 60, target: 2000, proteinTarget: 130,
      count: calories == 0 ? 0 : 1)
  }
  func testStreakToleranceAndBreaks() {
    XCTAssertTrue(day(0, calories: 1800).successful)
    XCTAssertTrue(day(0, calories: 2200).successful)
    XCTAssertFalse(day(0, calories: 1799).successful)
    XCTAssertEqual(ProgressService.streak(days: [day(-3), day(-2), day(-1)]).current, 3)
    XCTAssertEqual(ProgressService.streak(days: [day(-4), day(-3), day(-1), day(0)]).best, 2)
    XCTAssertEqual(ProgressService.streak(days: [day(-3), day(-2)]).current, 0)
    XCTAssertEqual(ProgressService.streak(days: [day(-1), day(0, calories: 0)]).current, 1)
  }
  func testWeeklyStatisticsExcludeUnloggedAverages() {
    let stats = WeeklyStats(days: [day(-2), day(-1, calories: 1800), day(0, calories: 0)])
    XCTAssertEqual(stats.logged, 2)
    XCTAssertEqual(stats.successful, 2)
    XCTAssertEqual(stats.averageCalories, 1900)
    XCTAssertEqual(WeeklyStats(days: []).averageProtein, 0)
  }
  func context(calories: Double, hour: Int, meals: Int = 2, protein: Double = 140) -> RoastContext {
    RoastContext(
      calories: calories, target: 2500, protein: protein, proteinTarget: 150, hour: hour,
      goal: .lose, streak: 0, weeklyAdherence: 0, weightTrend: nil, loggedMeals: meals,
      daysSinceLastLog: 0)
  }
  func testDailyCoachUsesTotalsInsteadOfMealTypeOrHistory() {
    var c = context(calories: 1800, hour: 20, protein: 40)
    c.fastFood = true
    c.sweet = true
    c.streak = 7
    c.weeklyAdherence = 1
    c.daysSinceLastLog = 5
    c.weightTrend = 2
    XCTAssertEqual(RoastEngine.dailyRule(for: c), "protein")
    c.protein = 150
    c.calories = 2500
    XCTAssertEqual(RoastEngine.dailyRule(for: c), "perfect")
    c.calories = 3000
    XCTAssertEqual(RoastEngine.dailyRule(for: c), "high")
    c.calories = 700
    XCTAssertEqual(RoastEngine.dailyRule(for: c), "low")
    c.hour = 10
    XCTAssertEqual(RoastEngine.dailyRule(for: c), "steady")
    c.loggedMeals = 0
    c.hour = 22
    XCTAssertEqual(RoastEngine.dailyRule(for: c), "empty")
    let message = RoastEngine().evaluate(
      c, intensity: .normal, personality: .standard, isPro: false, seed: 0, dailyOnly: true)
    XCTAssertEqual(message.rule, "empty")
  }
  func testTimeAwareRoasts() {
    XCTAssertEqual(RoastEngine.rule(for: context(calories: 700, hour: 10)), "steady")
    XCTAssertEqual(RoastEngine.rule(for: context(calories: 700, hour: 21)), "low")
    XCTAssertEqual(RoastEngine.rule(for: context(calories: 2900, hour: 14)), "earlyHigh")
    XCTAssertEqual(RoastEngine.rule(for: context(calories: 2900, hour: 23)), "high")
    XCTAssertEqual(RoastEngine.rule(for: context(calories: 4000, hour: 23)), "veryHigh")
    XCTAssertEqual(RoastEngine.rule(for: context(calories: 2500, hour: 22)), "perfect")
    XCTAssertEqual(RoastEngine.rule(for: context(calories: 1800, hour: 20, protein: 40)), "protein")
    XCTAssertEqual(RoastEngine.rule(for: context(calories: 0, hour: 10, meals: 0)), "empty")
    XCTAssertEqual(RoastEngine.rule(for: context(calories: 0, hour: 22, meals: 0)), "low")
  }
  func testEntitlements() {
    let future = Date.now.addingTimeInterval(1000)
    let past = Date.now.addingTimeInterval(-1000)
    XCTAssertTrue(
      EntitlementRecord(
        productID: StoreProducts.yearly, verified: true, revoked: false, expiration: future
      ).grantsAccess(at: .now))
    XCTAssertFalse(
      EntitlementRecord(
        productID: StoreProducts.monthly, verified: true, revoked: false, expiration: past
      ).grantsAccess(at: .now))
    XCTAssertTrue(
      EntitlementRecord(
        productID: StoreProducts.lifetime, verified: true, revoked: false, expiration: nil
      ).grantsAccess(at: .now))
    XCTAssertFalse(
      EntitlementRecord(
        productID: StoreProducts.lifetime, verified: false, revoked: false, expiration: nil
      ).grantsAccess(at: .now))
    XCTAssertFalse(
      EntitlementRecord(
        productID: StoreProducts.lifetime, verified: true, revoked: true, expiration: nil
      ).grantsAccess(at: .now))
    XCTAssertFalse(
      EntitlementRecord(productID: "unknown", verified: true, revoked: false, expiration: future)
        .grantsAccess(at: .now))
  }
  func testEveryCatalogFoodHasBundledPhoto() throws {
    for food in try FoodRepository().foods {
      let image = try XCTUnwrap(UIImage(named: "food-" + food.id), food.id)
      let pixels = try XCTUnwrap(image.cgImage, food.id)
      XCTAssertEqual(pixels.width, 256, food.id)
      XCTAssertEqual(pixels.height, 256, food.id)
    }
  }
  func testLibraryAndLocalization() throws {
    let engine = RoastEngine()
    XCTAssertGreaterThanOrEqual(engine.messages.count, 100)
    XCTAssertEqual(Set(engine.messages.map(\.id)).count, engine.messages.count)
    for language in ["tr", "en"] {
      let l = AppLocalization(language: language)
      XCTAssertNotEqual(AppBrand.name(l), "brand.name")
      for message in engine.messages {
        XCTAssertNotEqual(l.text(message.messageKey), message.messageKey)
        XCTAssertNotEqual(l.text(message.titleKey), message.titleKey)
      }
    }
    for message in engine.messages {
      let selected = engine.evaluate(
        context(calories: 700, hour: 21), intensity: message.intensity, personality: .savage,
        isPro: false, seed: -4)
      XCTAssertFalse(selected.pro)
      XCTAssertEqual(selected.rule, "low")
    }
  }
  func testEveryMessageQuotesRealNumbersAndLeavesNoPlaceholder() {
    var c = context(calories: 3100, hour: 21)
    c.streak = 7
    c.daysSinceLastLog = 4
    c.weeklyAdherence = 5.0 / 7
    c.weightTrend = -0.6
    for language in ["tr", "en"] {
      let l = AppLocalization(language: language)
      for message in RoastEngine.bundled.messages {
        let text = c.text(l.text(message.messageKey), l: l)
        XCTAssertFalse(text.contains("{") || text.contains("}"), message.id)
      }
      let over = c.text("{over}|{kcal}|{proteinLeft}|{weekDays}|{trend}", l: l)
      XCTAssertEqual(
        over, [l.number(600), l.number(3100), l.number(10), "5", l.number(0.6, digits: 1)].joined(separator: "|"))
    }
  }
  func testOnlyNormalIsFreeAndOtherTiersAreProGated() {
    let messages = RoastEngine.bundled.messages
    XCTAssertEqual(CoachIntensity.allCases.count, 5)
    for rule in Set(messages.map(\.rule)) {
      XCTAssertGreaterThanOrEqual(
        messages.filter { $0.rule == rule && $0.intensity == .normal && !$0.pro }.count, 3, rule)
      for intensity in CoachIntensity.allCases where intensity != .normal {
        XCTAssertTrue(
          messages.contains { $0.rule == rule && $0.intensity == intensity }, "\(rule) \(intensity)")
      }
    }
    XCTAssertTrue(messages.filter { $0.intensity != .normal }.allSatisfy(\.pro))
    XCTAssertTrue(messages.filter { $0.intensity == .normal }.allSatisfy { !$0.pro })
    for intensity in CoachIntensity.allCases {
      XCTAssertEqual(intensity.available(isPro: true), intensity)
      XCTAssertEqual(intensity.available(isPro: false), .normal)
    }
    let c = context(calories: 3100, hour: 21)
    for intensity in CoachIntensity.allCases {
      let free = RoastEngine.bundled.evaluate(
        c, intensity: intensity, personality: .standard, isPro: false, seed: 0)
      XCTAssertEqual(free.intensity, .normal)
      XCTAssertFalse(free.pro)
      let pro = RoastEngine.bundled.evaluate(
        c, intensity: intensity, personality: .standard, isPro: true, seed: 0)
      XCTAssertEqual(pro.intensity, intensity)
    }
  }
  func testOnboardingValidation() {
    let vm = OnboardingViewModel()
    XCTAssertFalse(vm.valid)
    vm.name = "Test"
    vm.eligible = true
    XCTAssertTrue(vm.valid)
    vm.target = 35
    XCTAssertFalse(vm.valid)
    vm.target = 90
    XCTAssertFalse(vm.valid)
    vm.goal = .gain
    XCTAssertTrue(vm.valid)
    vm.eligible = false
    XCTAssertFalse(vm.valid)
  }
  @MainActor func testPersistenceAndSavedMealCascade() throws {
    let schema = Schema([
      UserProfile.self, FoodEntry.self, CustomFood.self, FavoriteFood.self, SavedMeal.self,
      SavedMealItem.self, WeightEntry.self,
    ])
    let container = try ModelContainer(
      for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    let vm = OnboardingViewModel()
    vm.name = "Test"
    let profile = vm.profile(language: "tr")
    context.insert(profile)
    let food = try XCTUnwrap(try FoodRepository().foods.first)
    try FoodRepository.log(
      food: food, grams: 100, meal: .breakfast, date: .now, profile: profile, context: context)
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntry>()), 1)
    XCTAssertThrowsError(
      try FoodRepository.log(
        food: food, grams: .nan, meal: .breakfast, date: .now, profile: profile, context: context))
    let saved = SavedMeal(name: "Test", items: [try SavedMealItem(food: food, grams: 100)])
    context.insert(saved)
    try context.save()
    context.delete(saved)
    try context.save()
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavedMealItem>()), 0)
  }
  @MainActor func testStoryDimensionsForEveryLanguageAndTemplate() throws {
    for language in ["tr", "en"] {
      let l = AppLocalization(language: language)
      for kind in CardKind.allCases {
        let url = try ShareCardRenderer.render(
          snapshot: ShareSnapshot(
            calories: 2387, target: 2400, protein: 158, streak: 8, successfulDays: 6,
            averageCalories: 2285, averageProtein: 148, roast: l.text("roast.perfect.0"), date: .now
          ), kind: kind, theme: .dark, l: l)
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
        XCTAssertEqual(image.width, 1080)
        XCTAssertEqual(image.height, 1920)
        let attachment = XCTAttachment(contentsOfFile: url)
        attachment.name = "\(language)-\(kind.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
        try FileManager.default.removeItem(at: url)
      }
    }
  }
}
