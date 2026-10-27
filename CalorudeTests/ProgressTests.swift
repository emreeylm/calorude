import SwiftData
import XCTest

@testable import Calorude

@MainActor final class ProgressTests: XCTestCase {
  let calendar = Calendar.current

  func date(_ offset: Int) -> Date {
    calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: .now)!)
  }
  func stats(_ offset: Int, calories: Double = 2000, protein: Double = 130, target: Double = 2000)
    -> DayStats
  {
    DayStats(
      day: date(offset), calories: calories, protein: protein, carbs: 200, fat: 60, target: target,
      proteinTarget: 130, count: calories == 0 ? 0 : 1)
  }
  func entry(_ food: Food, offset: Int, hour: Int = 12, target: Double = 2000) -> FoodEntry {
    let when = calendar.date(byAdding: .hour, value: hour, to: date(offset))!
    return FoodEntry(
      food: food, grams: 100, meal: .lunch, date: when, target: target, proteinTarget: 130)
  }

  func testSuccessWindowIsTenPercentEitherSide() {
    XCTAssertTrue(stats(0, calories: 1800).successful)
    XCTAssertTrue(stats(0, calories: 2200).successful)
    XCTAssertFalse(stats(0, calories: 1799).successful)
    XCTAssertFalse(stats(0, calories: 2201).successful)
    XCTAssertFalse(stats(0, calories: 2000, target: 0).successful)
  }

  func testDayUsesTheLatestEntrysTargetSnapshotAndSumsTheDay() throws {
    let food = try XCTUnwrap(try FoodRepository().foods.first)
    let morning = entry(food, offset: 0, hour: 8, target: 1800)
    let evening = entry(food, offset: 0, hour: 20, target: 2100)
    let yesterday = entry(food, offset: -1)
    let day = ProgressService.day(
      date(0), entries: [evening, yesterday, morning], target: 1500, proteinTarget: 99)
    XCTAssertEqual(day.count, 2)
    XCTAssertEqual(day.calories, morning.calories + evening.calories, accuracy: 0.001)
    // Editing the plan later must not rewrite the past: the last entry's snapshot wins.
    XCTAssertEqual(day.target, 2100)
    XCTAssertEqual(day.proteinTarget, 130)
    let empty = ProgressService.day(date(5), entries: [morning], target: 1500, proteinTarget: 99)
    XCTAssertEqual(empty.count, 0)
    XCTAssertEqual(empty.target, 1500)
  }

  func testWeekCoversSevenDaysEndingToday() throws {
    let food = try XCTUnwrap(try FoodRepository().foods.first)
    let week = ProgressService.week(
      ending: date(0), entries: [entry(food, offset: -6), entry(food, offset: -7)], target: 2000,
      proteinTarget: 130)
    XCTAssertEqual(week.days.count, 7)
    XCTAssertEqual(week.days.first?.day, date(-6))
    XCTAssertEqual(week.days.last?.day, date(0))
    XCTAssertEqual(week.logged, 1, "the entry 7 days back is outside the window")
  }

  func testAllDaysGroupsEntriesChronologically() throws {
    let food = try XCTUnwrap(try FoodRepository().foods.first)
    let days = ProgressService.allDays(
      entries: [entry(food, offset: 0), entry(food, offset: -3), entry(food, offset: -3, hour: 18)],
      target: 2000, proteinTarget: 130)
    XCTAssertEqual(days.map(\.day), [date(-3), date(0)])
    XCTAssertEqual(days.map(\.count), [2, 1])
  }

  func testOngoingStreakSurvivesAnUnfinishedToday() {
    XCTAssertEqual(ProgressService.streak(days: [stats(-2), stats(-1)]).current, 2)
    XCTAssertEqual(
      ProgressService.streak(days: [stats(-2), stats(-1), stats(0, calories: 300)]).current, 2)
    XCTAssertEqual(ProgressService.streak(days: [stats(-3), stats(-1)]).best, 1)
  }

  func testAchievementsStartEmptyAndUnlockFirstAndStreakMilestones() {
    XCTAssertEqual(AchievementService.earned(days: []), [])
    let one = AchievementService.earned(days: [stats(0)])
    XCTAssertTrue(one.contains("first"))
    XCTAssertFalse(one.contains("streak3"))
    let week = AchievementService.earned(days: (-6...0).map { stats($0) })
    XCTAssertTrue(week.contains("streak3") && week.contains("streak7"))
    XCTAssertFalse(week.contains("streak14"))
  }

  func testProteinAndBullseyeAchievementsNeedRealLogs() {
    let missed = AchievementService.earned(days: [stats(0, calories: 3500, protein: 50)])
    XCTAssertFalse(missed.contains("protein"))
    XCTAssertFalse(missed.contains("bullseye"))
    let hit = AchievementService.earned(days: [stats(0, calories: 2000, protein: 140)])
    XCTAssertTrue(hit.contains("protein") && hit.contains("bullseye"))
    // An unlogged day never counts, even though 0 >= 0 would satisfy the protein check.
    XCTAssertFalse(
      AchievementService.earned(days: [stats(0, calories: 0, protein: 0)]).contains("protein"))
  }

  func testReturnAchievementNeedsAGapOfThreeDays() {
    XCTAssertFalse(AchievementService.earned(days: [stats(-3), stats(-2)]).contains("return"))
    XCTAssertTrue(AchievementService.earned(days: [stats(-5), stats(-2)]).contains("return"))
  }

  func testWeightTrendComparesTwoSevenDayAverages() {
    let now = date(0)
    func weight(_ value: Double, _ offset: Int) -> WeightEntry {
      WeightEntry(weight: value, date: calendar.date(byAdding: .hour, value: 9, to: date(offset))!)
    }
    let weights = [weight(82, -10), weight(80, -9), weight(79, -2), weight(77, -1), weight(78, 0)]
    XCTAssertEqual(try XCTUnwrap(ProgressService.weightTrend(weights, ending: now)), -3, accuracy: 0.001)
    XCTAssertNil(ProgressService.weightTrend([weight(80, -1)], ending: now), "needs both weeks")
    XCTAssertNil(ProgressService.averageWeight([], from: date(-7), to: date(1)))
  }
}
