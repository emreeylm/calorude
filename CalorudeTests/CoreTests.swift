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
      if goal == .muscle {
        XCTAssertGreaterThan(p.calories, 2759)
        XCTAssertLessThanOrEqual(p.calories, 3059)
        XCTAssertEqual(p.protein, 160)
      }
      if goal == .maintain { XCTAssertEqual(p.calories, 2759) }
    }
    let extreme = NutritionCalculator.plan(
      weight: 45, height: 150, age: 70, sex: .female, activity: .sedentary, goal: .lose, weekly: 8)
    XCTAssertGreaterThanOrEqual(extreme.calories, 1200)
  }
  func testHealthyPaceIsChosenAutomatically() throws {
    let rate = { (weight: Double, goal: Goal) in
      NutritionCalculator.healthyWeeklyRate(weight: weight, height: 175, goal: goal)
    }
    XCTAssertEqual(rate(80, .lose), 0.6, accuracy: 0.001)  // BMI 26: 0.75 % of body weight
    XCTAssertEqual(rate(65, .lose), 0.325, accuracy: 0.001)  // normal BMI: gentler 0.5 %
    XCTAssertEqual(rate(200, .lose), 1.0)  // never above 1 kg a week
    XCTAssertEqual(rate(80, .maintain), 0)
    XCTAssertEqual(rate(80, .muscle), 0.2)
    XCTAssertEqual(rate(80, .gain), 0.3)
    let vm = OnboardingViewModel()
    XCTAssertEqual(vm.weekly, 0.6, accuracy: 0.001)
    XCTAssertEqual(vm.target, 75)
    // The 20 % deficit cap slows the real pace below the ideal one, and the timeline follows it.
    XCTAssertLessThan(vm.estimatedWeeklyChange, vm.weekly)
    let weeks = try XCTUnwrap(vm.weeksToGoal)
    XCTAssertTrue((5...20).contains(weeks))
    vm.goal = .maintain
    XCTAssertNil(vm.weeksToGoal)
    XCTAssertEqual(vm.estimatedWeeklyChange, 0)
    vm.goal = .muscle
    XCTAssertEqual(vm.target, 83)
    XCTAssertNotNil(vm.weeksToGoal)
    XCTAssertEqual(vm.plan.protein, 160)

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
      loggedMeals: meals)
  }
  func testDayStateUsesTotalsAndTimeOfDay() {
    XCTAssertEqual(DayCoach.state(for: context(calories: 0, hour: 10, meals: 0)), .empty)
    XCTAssertEqual(DayCoach.state(for: context(calories: 0, hour: 22, meals: 0)), .empty)
    XCTAssertEqual(DayCoach.state(for: context(calories: 700, hour: 10)), .steady)
    XCTAssertEqual(DayCoach.state(for: context(calories: 700, hour: 21)), .low)
    XCTAssertEqual(DayCoach.state(for: context(calories: 2900, hour: 14)), .over)
    XCTAssertEqual(DayCoach.state(for: context(calories: 2900, hour: 23)), .over)
    XCTAssertEqual(DayCoach.state(for: context(calories: 4000, hour: 23)), .veryHigh)
    XCTAssertEqual(DayCoach.state(for: context(calories: 2500, hour: 22)), .perfect)
    XCTAssertEqual(
      DayCoach.state(for: context(calories: 1800, hour: 20, protein: 40)), .protein)
    // Past days are finished days: the time-of-day rules never fire on them.
    let yesterday = DayStats(
      day: Calendar.current.date(byAdding: .day, value: -1, to: .now)!, calories: 700, protein: 90,
      carbs: 0, fat: 0, target: 2500, proteinTarget: 150, count: 2)
    XCTAssertEqual(RoastContext(stats: yesterday).hour, 23)
  }
  func testLevelIsGatedAndOldSettingsStillLoad() throws {
    XCTAssertEqual(CoachVoice(level: .toxic, isPro: false).level, .normal)
    XCTAssertEqual(CoachVoice(level: .toxic, isPro: true).level, .toxic)
    for intensity in CoachIntensity.allCases {
      XCTAssertEqual(intensity.available(isPro: true), intensity)
      XCTAssertEqual(intensity.available(isPro: false), .normal)
    }
    // Profiles saved before "Nükleer" became "Toksik" keep their stored value.
    XCTAssertEqual(CoachIntensity(rawValue: "nuclear"), .toxic)
    XCTAssertEqual(CoachIntensity.toxic.key, "toxic")
    let old = try JSONDecoder().decode([CoachIntensity].self, from: Data(#"["nuclear","savage"]"#.utf8))
    XCTAssertEqual(old, [.toxic, .savage])
    // Characters are gone, but stored preferences that mention one still decode.
    XCTAssertNotNil(try? JSONDecoder().decode(Personality.self, from: Data(#""sergeant""#.utf8)))
  }
  func testDayCommentIsStableUntilTheTotalsChange() {
    let day = Calendar.current.startOfDay(for: .now)
    let c = context(calories: 1500, hour: 15)
    XCTAssertEqual(
      DayCoach.variant(day: day, context: c), DayCoach.variant(day: day, context: c))
    var seen = Set<Int>()
    for step in 0..<10 {
      seen.insert(
        DayCoach.variant(day: day, context: context(calories: 1500 + Double(step) * 40, hour: 15)))
    }
    XCTAssertGreaterThan(seen.count, 1)
    XCTAssertTrue(seen.allSatisfy { (0..<DayCoach.variants).contains($0) })
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
    XCTAssertFalse(
      EntitlementRecord(
        productID: StoreProducts.yearly, verified: true, revoked: false, expiration: nil
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
  func testCoachLibraryIsCompleteInBothLanguages() {
    let day = RoastContext(
      calories: 3100, target: 2500, protein: 40, proteinTarget: 150, hour: 21, loggedMeals: 3)
    let facts = MealFacts(mealCalories: 646, mealProtein: 70, dayTotal: 1800, target: 1900)
    for language in ["tr", "en"] {
      let l = AppLocalization(language: language)
      XCTAssertNotEqual(AppBrand.name(l), "brand.name")
      XCTAssertNotEqual(l.text("coach.title"), "coach.title")
      do {
        for level in CoachIntensity.allCases {
          for state in DayState.allCases {
            for index in 0..<DayCoach.variants {
              let voice = CoachVoice(level: level, isPro: true)
              let key = DayCoach.key(state: state, voice: voice, variant: index)
              let text = day.text(l.text(key), l: l)
              XCTAssertNotEqual(text, key)
              XCTAssertFalse(text.contains("{") || text.contains("}"), key)
            }
          }
          for state in MealState.allCases {
            for index in 0..<MealReactionEngine.variants {
              let key = "coach.meal.\(state.rawValue).\(level.key).\(index)"
              let reaction = MealReaction(
                state: state, messageKey: key,
                nutrition: NutritionPlan(calories: 646, protein: 70, carbs: 47, fat: 18),
                facts: facts, meal: .lunch, date: .now)
              XCTAssertNotEqual(l.text(key), key)
              XCTAssertFalse(reaction.message(l).contains("{"), key)
            }
          }
        }
      }
    }
    XCTAssertEqual(DayState.allCases.count, 7)
    XCTAssertEqual(MealState.allCases.count, 6)
  }
  func testStoryTextFitsTheCard() {
    // The story card sets the quote at 30 pt in a 300 pt column and allows nine lines.
    let font = UIFont.systemFont(ofSize: 30, weight: .black)
    let rounded = font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 30) } ?? font
    let facts = MealFacts(mealCalories: 1292, mealProtein: 98, dayTotal: 2200, target: 1900)
    let day = RoastContext(
      calories: 3100, target: 2500, protein: 40, proteinTarget: 150, hour: 21, loggedMeals: 3)
    var longest: CGFloat = 0
    for language in ["tr", "en"] {
      let l = AppLocalization(language: language)
      do {
        for level in CoachIntensity.allCases {
          var texts: [String] = []
          for state in DayState.allCases {
            for index in 0..<DayCoach.variants {
              let key = "coach.day.\(state.rawValue).\(level.key).\(index)"
              texts.append(day.text(l.text(key), l: l))
            }
          }
          for state in MealState.allCases {
            for index in 0..<MealReactionEngine.variants {
              let key = "coach.meal.\(state.rawValue).\(level.key).\(index)"
              texts.append(
                MealReaction(
                  state: state, messageKey: key,
                  nutrition: NutritionPlan(calories: 1292, protein: 98, carbs: 0, fat: 0),
                  facts: facts, meal: .lunch, date: .now
                ).message(l))
            }
          }
          for text in texts {
            let height = (text as NSString).boundingRect(
              with: CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude),
              options: .usesLineFragmentOrigin, attributes: [.font: rounded], context: nil
            ).height
            let lines: CGFloat = height / rounded.lineHeight
            longest = max(longest, lines)
            XCTAssertLessThanOrEqual(lines.rounded(.up), 9, text)
          }
        }
      }
    }
    XCTAssertGreaterThan(longest, 1)
  }
  // Fixed local time so slot arithmetic does not depend on when the suite runs.
  func at(_ hour: Int, _ minute: Int = 0) throws -> Date {
    try XCTUnwrap(
      Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: hour, minute: minute)))
  }
  func entry(_ meal: MealType, hour: Int) throws -> FoodEntry {
    let food = try XCTUnwrap(FoodRepository.bundled?.foods.first)
    return FoodEntry(
      food: food, grams: 100, meal: meal, date: try at(hour), target: 2000, proteinTarget: 120)
  }
  func kinds(_ plan: [PlannedReminder], on day: Date) -> [ReminderKind] {
    plan.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.map(\.kind)
  }
  @MainActor func testReminderPlanForAnEmptyDay() throws {
    let plan = NotificationService.plan(entries: [], now: try at(8))
    XCTAssertEqual(plan.count, 9)
    XCTAssertEqual(kinds(plan, on: try at(8)), [.breakfast, .emptyNoon, .emptyEvening])
    XCTAssertEqual(Set(plan.map(\.id)).count, plan.count)
    XCTAssertEqual(plan.map(\.date), plan.map(\.date).sorted())
    // Variants rotate day to day so the same line never repeats on consecutive mornings.
    XCTAssertEqual(Set(plan.filter { $0.kind == .breakfast }.map(\.variant)).count, 3)
  }
  @MainActor func testLoggedMealsAreNotReminded() throws {
    let now = try at(8)
    XCTAssertEqual(
      kinds(NotificationService.plan(entries: [try entry(.breakfast, hour: 7)], now: now), on: now),
      [.lunch, .dinner])
    let all = try [entry(.breakfast, hour: 7), entry(.lunch, hour: 7), entry(.dinner, hour: 7)]
    let plan = NotificationService.plan(entries: all, now: now)
    XCTAssertEqual(kinds(plan, on: now), [])
    XCTAssertEqual(plan.count, 6)
  }
  @MainActor func testReminderDueSoonIsSkipped() throws {
    let now = try at(13, 20)
    XCTAssertEqual(
      kinds(NotificationService.plan(entries: [], now: now, days: 1), on: now), [.emptyEvening])
  }
  @MainActor func testEveryReminderMessageExistsForEveryTierAndLanguage() {
    for language in ["tr", "en"] {
      let l = AppLocalization(language: language)
      for kind in ReminderKind.allCases {
        for tier in CoachIntensity.allCases {
          for variant in 0..<NotificationService.variantCount {
            let key = NotificationService.messageKey(
              PlannedReminder(id: "x", date: .now, kind: kind, variant: variant), tier: tier)
            XCTAssertNotEqual(l.text(key), key)
            XCTAssertFalse(l.text(key).contains("{"), key)
          }
        }
      }
    }
    let free = CoachIntensity.toxic.available(isPro: false)
    XCTAssertTrue(
      NotificationService.messageKey(
        PlannedReminder(id: "x", date: .now, kind: .lunch, variant: 0), tier: free
      ).contains(".normal."))
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
  func testStepFlowAndPerStepValidation() {
    let vm = OnboardingViewModel()
    XCTAssertEqual(vm.step, .goal)
    vm.advance()
    XCTAssertEqual(vm.step, .about)
    vm.advance()
    XCTAssertEqual(vm.step, .about)
    XCTAssertEqual(vm.errorKey, "validation.name")
    vm.name = "Ece"
    vm.advance()
    XCTAssertEqual(vm.step, .body)
    vm.target = 90
    vm.advance()
    XCTAssertEqual(vm.step, .body)
    XCTAssertEqual(vm.errorKey, "validation.target.lose")
    vm.target = 75
    for expected in [OnboardingStep.lifestyle, .workouts, .habits, .safety] {
      vm.advance()
      XCTAssertEqual(vm.step, expected)
      XCTAssertNil(vm.errorKey)
    }
    vm.advance()
    XCTAssertEqual(vm.step, .safety)
    XCTAssertEqual(vm.errorKey, "validation.eligibility")
    vm.eligible = true
    vm.advance()
    XCTAssertEqual(vm.step, .loading)
    vm.advance()
    XCTAssertEqual(vm.step, .result)
    XCTAssertEqual(vm.progress.total, 7)

    let keep = OnboardingViewModel()
    keep.goal = .maintain
    keep.name = "Ece"
    XCTAssertEqual(keep.infoSteps.count, 6)
    for _ in 0..<4 { keep.advance() }
    XCTAssertEqual(keep.step, .workouts)
    keep.advance()
    XCTAssertEqual(keep.step, .safety)
    keep.goBack()
    XCTAssertEqual(keep.step, .workouts)
  }
  func testTargetFollowsGoalUntilTheUserTypesOne() {
    let vm = OnboardingViewModel()
    vm.goal = .gain
    XCTAssertEqual(vm.target, 84)
    vm.weight = 70
    XCTAssertEqual(vm.target, 74)
    vm.target = 78
    vm.weight = 72
    XCTAssertEqual(vm.target, 78)
    // A typed target that no longer fits the new goal is replaced.
    vm.goal = .lose
    XCTAssertEqual(vm.target, 67)
    let slim = OnboardingViewModel()
    slim.height = 150
    slim.weight = 45
    slim.target = 40
    XCTAssertEqual(slim.validationKey(for: .body), "validation.target.bmi")
  }
  func testActivityFromLifestyleAndWorkouts() {
    XCTAssertEqual(Activity.from(life: .sitting, workouts: .none), .sedentary)
    XCTAssertEqual(Activity.from(life: .sitting, workouts: .regular), .light)
    XCTAssertEqual(Activity.from(life: .onFeet, workouts: .regular), .moderate)
    XCTAssertEqual(Activity.from(life: .physical, workouts: .intense), .active)
    let vm = OnboardingViewModel()
    XCTAssertEqual(vm.activity, .light)
    vm.lifestyle = .sitting
    vm.workouts = .none
    XCTAssertEqual(vm.activity, .sedentary)
  }
  func testEveryOnboardingStringExistsInBothLanguages() {
    var keys = Set<String>()
    for step in OnboardingStep.allCases where step != .loading {
      keys.insert("ob.title." + step.name)
      keys.insert("ob.sub." + step.name)
    }
    for goal in Goal.allCases {
      keys.formUnion(["goal." + goal.rawValue, "ob.goal." + goal.rawValue])
      keys.insert("coach.weight." + goal.rawValue)
    }
    for life in DailyLife.allCases { keys.formUnion(["ob.life.\(life)", "ob.life.\(life).sub"]) }
    for frequency in WorkoutFrequency.allCases {
      keys.formUnion(["ob.workouts.\(frequency)", "ob.workouts.\(frequency).sub"])
    }
    for challenge in EatingChallenge.allCases {
      keys.formUnion(["ob.challenge." + challenge.rawValue, "ob.tip." + challenge.rawValue])
    }
    keys.insert("ob.tip.maintain")
    keys.formUnion(["ob.loading.title", "ob.loading.1", "ob.loading.2", "ob.loading.3", "ob.loading.4"])
    keys.formUnion(["ob.calculate", "ob.result.timeline", "ob.result.weeks", "ob.result.auto"])
    keys.formUnion(["validation.name", "validation.age", "validation.body", "validation.eligibility"])
    keys.formUnion(["validation.target.lose", "validation.target.gain", "validation.target.bmi", "validation.target.bmi.high"])
    for language in ["tr", "en"] {
      let l = AppLocalization(language: language)
      for key in keys { XCTAssertNotEqual(l.text(key), key, "\(language) \(key)") }
    }
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
