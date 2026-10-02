import XCTest

@testable import Calorude

@MainActor final class MealReactionTests: XCTestCase {
  let tr = AppLocalization(language: "tr")
  lazy var foods = (try? FoodRepository().foods) ?? []

  func food(_ id: String) throws -> Food { try XCTUnwrap(foods.first { $0.id == id }) }
  func items(_ values: [(String, Double)], meal: MealType = .lunch) throws -> [MealDraftItem] {
    try values.map { MealDraftItem(food: try food($0.0), grams: $0.1, meal: meal) }
  }
  func calories(_ items: [MealDraftItem]) -> Double { items.reduce(0) { $0 + $1.nutrition.calories } }
  // Grams of one food that add up to roughly the wanted calories.
  func grams(of id: String, calories wanted: Double) throws -> Double {
    wanted / (try food(id)).nutrition(grams: 100).calories * 100
  }
  func voice(_ level: CoachIntensity = .normal) -> CoachVoice {
    CoachVoice(level: level, isPro: true)
  }
  func react(
    _ meal: [MealDraftItem], others: [MealDraftItem] = [], target: Double, variant: Int = 0,
    voice: CoachVoice? = nil, recent: [String] = [], now: Date = .now
  ) throws -> MealReaction {
    try XCTUnwrap(
      MealReactionEngine.reaction(
        items: others + meal, originals: others, date: now, target: target, now: now,
        voice: voice ?? self.voice(), variant: variant, recentKeys: recent, exists: { self.tr.has($0) }))
  }

  func testBalanceIsJudgedSeparatelyFromFit() throws {
    XCTAssertTrue(MealReactionEngine.isBalanced(try items([("rice", 150), ("chicken", 200), ("yogurt", 100)])))
    XCTAssertFalse(MealReactionEngine.isBalanced(try items([("chips", 100), ("cola", 330)])))
    XCTAssertFalse(MealReactionEngine.isBalanced(try items([("chocolate", 50)])))
    XCTAssertTrue(MealReactionEngine.isBalanced(try items([("apple", 150)])))
  }

  // A 1,900 kcal target and a balanced meal worth about two thirds of it, with 0, ~600 and ~1,000
  // kcal already logged: the same meal must not get the same comment class every time.
  func testSameMealReadsDifferentlyAgainstTheDay() throws {
    let meal = try items([("rice", 300), ("chicken", 400), ("yogurt", 200)])
    let mealCalories = calories(meal)
    let target = mealCalories / 0.63
    func others(_ fraction: Double) throws -> [MealDraftItem] {
      try items([("bread", try grams(of: "bread", calories: target * fraction))], meal: .breakfast)
    }
    let empty = try react(meal, target: target, now: try noon())
    XCTAssertEqual(empty.state, .bigButFits)
    XCTAssertEqual(empty.facts.percent, 63)
    XCTAssertEqual(empty.facts.left, target - mealCalories, accuracy: 0.5)

    let tight = try react(meal, others: try others(0.32), target: target, now: try noon())
    XCTAssertEqual(tight.state, .balancedSqueezes)
    XCTAssertEqual(tight.facts.dayTotal, mealCalories + target * 0.32, accuracy: 1)
    XCTAssertEqual(tight.facts.over, 0)

    let over = try react(meal, others: try others(0.53), target: target, now: try noon())
    XCTAssertEqual(over.state, .balancedSqueezes)
    XCTAssertGreaterThan(over.facts.over, 0)
    XCTAssertNotEqual(tight.detail(tr), over.detail(tr))

    // An unbalanced meal over the same target is judged on its contents instead.
    let snacks = try items([("chips", 150), ("cola", 500)])
    let heavy = try react(
      snacks, others: try items([("bread", try grams(of: "bread", calories: 700))], meal: .breakfast),
      target: 1000, now: try noon())
    XCTAssertEqual(heavy.state, .unbalancedOver)
  }

  func testStateForEveryKindOfMeal() throws {
    XCTAssertEqual(try react(try items([("rice", 40)]), target: 2000).state, .incomplete)
    XCTAssertEqual(
      try react(try items([("rice", 150), ("chicken", 200), ("yogurt", 100)]), target: 3000).state,
      .goodFits)
    XCTAssertEqual(try react(try items([("chocolate", 80)]), target: 3000).state, .unbalancedWithin)
    // A big dinner that uses up the budget is the plan, not a squeeze.
    let dinner = try items([("rice", 300), ("chicken", 400), ("yogurt", 200)], meal: .dinner)
    XCTAssertNotEqual(
      try react(dinner, target: calories(dinner) * 1.05, now: try at(20)).state, .balancedSqueezes)
  }

  func testEditedMealIsNotCountedTwice() throws {
    var lunch = try items([("rice", 150)])
    let original = lunch
    lunch[0].grams = 300
    let result = try XCTUnwrap(
      MealReactionEngine.reaction(
        items: lunch, originals: original, date: .now, target: 2000, voice: voice(),
        recentKeys: [], exists: { self.tr.has($0) }))
    XCTAssertEqual(result.facts.dayTotal, calories(lunch), accuracy: 0.01)
    XCTAssertEqual(result.facts.mealCalories, calories(lunch), accuracy: 0.01)
  }

  func testOnlyCommittedChangesGetAReaction() throws {
    let original = try items([("rice", 150)])
    XCTAssertNil(
      MealReactionEngine.reaction(
        items: original, originals: original, date: .now, target: 2000, voice: voice(),
        exists: { self.tr.has($0) }))
    XCTAssertNil(
      MealReactionEngine.reaction(
        items: [], originals: original, date: .now, target: 2000, voice: voice(),
        exists: { self.tr.has($0) }))
    var dinner = try items([("chicken", 200)])
    dinner[0].meal = .dinner
    let result = try react(dinner, others: original, target: 2000)
    XCTAssertEqual(result.meal, .dinner)
    XCTAssertEqual(result.nutrition.calories, 330, accuracy: 0.01)
    XCTAssertEqual(result.facts.dayTotal, 330 + calories(original), accuracy: 0.01)
  }

  func testContextLinesNeedDataThatSupportsThem() throws {
    let bro = voice(.savage)
    func keys(_ meal: [MealDraftItem], target: Double, others: [MealDraftItem] = []) throws -> [String] {
      let facts = MealFacts(
        mealCalories: calories(meal), mealProtein: meal.reduce(0) { $0 + $1.nutrition.protein },
        dayTotal: calories(meal + others), target: target)
      let state = MealReactionEngine.classify(
        relevant: meal, facts: facts, isLastMeal: false)
      let tags = MealReactionEngine.tags(
        relevant: meal, all: meal + others, facts: facts, isLateMeal: false)
      return MealReactionEngine.candidateKeys(
        state: state, voice: bro, tags: tags, exists: { self.tr.has($0) })
    }
    let riceChicken = try items([("rice", 400), ("chicken", 400), ("yogurt", 200)])
    XCTAssertTrue(
      try keys(riceChicken, target: calories(riceChicken) / 0.5).contains { $0.contains(".riceChicken.") })
    let apple = try items([("apple", 150), ("yogurt", 150)])
    XCTAssertFalse(try keys(apple, target: 2000).contains { $0.contains(".riceChicken.") })
    // "Third dessert" is only claimed when three sweets are in the day's log.
    let sweets = try items([("chocolate", 60)])
    XCTAssertFalse(try keys(sweets, target: 1500).contains { $0.contains(".thirdSweet.") })
    let threeSweets = try items([("chocolate", 60), ("chocolate", 60), ("chocolate", 60)])
    let withThree = MealReactionEngine.tags(
      relevant: sweets, all: threeSweets, facts: MealFacts(mealCalories: 330, mealProtein: 3, dayTotal: 990, target: 1500),
      isLateMeal: false)
    XCTAssertTrue(withThree.contains("thirdSweet"))
    // A sugary-drink line needs a sugary drink.
    let cola = MealReactionEngine.tags(
      relevant: try items([("cola", 330)]), all: try items([("cola", 330)]),
      facts: MealFacts(mealCalories: 140, mealProtein: 0, dayTotal: 140, target: 2000), isLateMeal: false)
    XCTAssertTrue(cola.contains("sugaryDrink"))
    XCTAssertFalse(withThree.contains("sugaryDrink"))
  }

  func testRepeatLinesNeedTheirData() throws {
    let meal = try items([("chocolate", 60)])
    let over = MealFacts(mealCalories: 330, mealProtein: 3, dayTotal: 2300, target: 2000)
    let within = MealFacts(mealCalories: 330, mealProtein: 3, dayTotal: 330, target: 2000)
    func tags(_ facts: MealFacts, treats: Int = 0, overs: Int = 0, late: Bool = false) -> Set<String> {
      MealReactionEngine.tags(
        relevant: meal, all: meal, facts: facts, isLateMeal: late, cravingDays: treats, overDays: overs)
    }
    XCTAssertFalse(tags(within, treats: 2).contains("repeatTreat"))
    XCTAssertTrue(tags(within, treats: 3).contains("repeatTreat"))
    // Repeated overshoot needs three days over target and today actually over.
    XCTAssertFalse(tags(over, overs: 2).contains("repeatOver"))
    XCTAssertFalse(tags(within, overs: 3).contains("repeatOver"))
    XCTAssertTrue(tags(over, overs: 3).contains("repeatOver"))
    func night(_ sex: Sex, late: Bool) -> Set<String> {
      MealReactionEngine.tags(
        relevant: meal, all: meal, facts: within, isLateMeal: late, sex: sex)
    }
    XCTAssertTrue(night(.male, late: true).contains("nightMale"))
    XCTAssertFalse(night(.male, late: true).contains("nightFemale"))
    XCTAssertTrue(night(.female, late: true).contains("nightFemale"))
    XCTAssertFalse(night(.female, late: false).contains("nightFemale"))
    XCTAssertTrue(tags(within, late: true).contains("evening"))
    XCTAssertFalse(tags(within).contains("evening"))
  }

  func testSafetyNoteOnlyForOverAndIncomplete() throws {
    func reaction(_ state: MealState, over: Double) -> MealReaction {
      MealReaction(
        state: state, messageKey: "x", nutrition: NutritionPlan(calories: 0, protein: 0, carbs: 0, fat: 0),
        facts: MealFacts(mealCalories: 500, mealProtein: 20, dayTotal: 2000 + over, target: 2000),
        meal: .lunch, date: .now)
    }
    XCTAssertTrue(reaction(.unbalancedOver, over: 0).showsSafetyNote)
    XCTAssertTrue(reaction(.incomplete, over: 0).showsSafetyNote)
    XCTAssertTrue(reaction(.balancedSqueezes, over: 100).showsSafetyNote)
    XCTAssertFalse(reaction(.goodFits, over: 0).showsSafetyNote)
    XCTAssertFalse(reaction(.unbalancedWithin, over: 0).showsSafetyNote)
  }

  func testRecentLinesDoNotComeBack() throws {
    let meal = try items([("chips", 100), ("cola", 330)])
    var recent: [String] = []
    var previous: String?
    for variant in 0..<60 {
      let result = try react(meal, target: 2000, variant: variant * 7, recent: recent)
      XCTAssertNotEqual(result.messageKey, previous)
      XCTAssertFalse(recent.contains(result.messageKey), result.messageKey)
      previous = result.messageKey
      recent = (recent + [result.messageKey]).suffix(4)
    }
  }

  func testEveryStateRendersAsAStoryInBothLanguages() throws {
    for language in ["tr", "en"] {
      let l = AppLocalization(language: language)
      for state in MealState.allCases {
        let facts = MealFacts(mealCalories: 646, mealProtein: 70, dayTotal: 2150, target: 1900)
        let result = MealReaction(
          state: state, messageKey: "coach.meal.\(state.rawValue).toxic.0",
          nutrition: NutritionPlan(calories: 646, protein: 70, carbs: 47, fat: 18), facts: facts,
          meal: .lunch, date: .now)
        XCTAssertFalse(result.detail(l).contains("{"))
        let url = try MealReactionRenderer.render(result, l: l)
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
        XCTAssertEqual(image.width, 1080)
        XCTAssertEqual(image.height, 1920)
        let attachment = XCTAttachment(contentsOfFile: url)
        attachment.name = "reaction-\(language)-\(state.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
        try FileManager.default.removeItem(at: url)
      }
    }
  }

  // Renders the story card of each hard style into SHOTS_DIR/<lang>/levels (skipped when unset).
  func testRenderHardStyleStoryCards() throws {
    guard let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] else {
      throw XCTSkip("SHOTS_DIR not set")
    }
    let cases: [(MealState, Double, Double)] = [
      (.unbalancedOver, 2210, 760), (.balancedSqueezes, 1890, 980),
    ]
    for language in ["tr", "en"] {
      let l = AppLocalization(language: language)
      let folder = "\(dir)/\(language)/levels"
      try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
      for level in ["savage", "unhinged", "toxic"] {
        for (state, total, meal) in cases {
          let reaction = MealReaction(
            state: state, messageKey: "coach.meal.\(state.rawValue).\(level).0",
            nutrition: NutritionPlan(calories: meal, protein: 24, carbs: 80, fat: 40),
            facts: MealFacts(mealCalories: meal, mealProtein: 24, dayTotal: total, target: 1935),
            meal: .dinner, date: .now)
          let url = try MealReactionRenderer.render(reaction, l: l)
          let target = URL(fileURLWithPath: "\(folder)/\(level)-\(state.rawValue).png")
          try? FileManager.default.removeItem(at: target)
          try FileManager.default.copyItem(at: url, to: target)
        }
      }
    }
  }

  func at(_ hour: Int) throws -> Date {
    try XCTUnwrap(
      Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: hour)))
  }
  func noon() throws -> Date { try at(12) }
}
