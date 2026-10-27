import SwiftUI
import WidgetKit
import XCTest

@testable import Calorude

@MainActor final class WidgetTests: XCTestCase {
  let calendar = Calendar.current

  func content(_ calories: Double, target: Double = 2000, comment: String = "x") -> WidgetContent {
    WidgetContent(
      calories: calories, target: target, calorieText: "\(calories)", targetText: "/ \(target)",
      statusText: "s", comment: comment)
  }

  func testRingProgressIsClamped() {
    XCTAssertEqual(content(1000).progress, 0.5)
    XCTAssertEqual(content(3500).progress, 1, "an over-target day shows a full ring")
    XCTAssertEqual(content(0).progress, 0)
    XCTAssertEqual(content(500, target: 0).progress, 1, "a missing target never divides by zero")
  }

  func testSnapshotFlipsToTheEmptyDayAtMidnight() {
    let today = calendar.startOfDay(for: .now)
    let snapshot = WidgetSnapshot(
      day: today, today: content(1200, comment: "today"), nextDay: content(0, comment: "tomorrow"))
    let noon = calendar.date(byAdding: .hour, value: 12, to: today)!
    let nextMorning = calendar.date(byAdding: .hour, value: 30, to: today)!
    XCTAssertEqual(snapshot.content(at: noon).comment, "today")
    XCTAssertEqual(snapshot.content(at: nextMorning).comment, "tomorrow")
    // The app has not run for days: still the empty day, never stale numbers.
    XCTAssertEqual(snapshot.content(at: calendar.date(byAdding: .day, value: 4, to: today)!).calories, 0)
  }

  func testStoreRoundTripsThroughAnAppGroupSuite() throws {
    let name = "widget.test.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    XCTAssertNil(WidgetStore.load(defaults: defaults))
    let snapshot = WidgetSnapshot(
      day: calendar.startOfDay(for: .now), today: content(900), nextDay: content(0))
    WidgetStore.save(snapshot, defaults: defaults)
    XCTAssertEqual(WidgetStore.load(defaults: defaults), snapshot)
    defaults.set(Data("not json".utf8), forKey: WidgetStore.key)
    XCTAssertNil(WidgetStore.load(defaults: defaults), "a corrupt value falls back to the placeholder")
  }

  func testRenderedContentMatchesTheDashboard() throws {
    let l = AppLocalization(language: "en")
    let vm = OnboardingViewModel()
    vm.name = "Test"
    let profile = vm.profile(language: "en")
    let food = try XCTUnwrap(try FoodRepository().foods.first)
    let today = calendar.startOfDay(for: .now)
    let entry = FoodEntry(
      food: food, grams: 300, meal: .lunch, date: calendar.date(byAdding: .hour, value: 12, to: today)!,
      target: profile.dailyCalorieTarget, proteinTarget: profile.proteinTarget)
    let voice = CoachVoice(level: .normal, isPro: false)

    let rendered = WidgetSync.content(
      day: today, profile: profile, entries: [entry], voice: voice, l: l)
    let stats = ProgressService.day(
      today, entries: [entry], target: profile.dailyCalorieTarget, proteinTarget: profile.proteinTarget)
    XCTAssertEqual(rendered.calories, entry.calories, accuracy: 0.001)
    XCTAssertEqual(rendered.calorieText, l.number(stats.calories))
    XCTAssertEqual(rendered.comment, DayCoach.comment(stats: stats, voice: voice, l: l))
    XCTAssertFalse(rendered.comment.isEmpty)
    XCTAssertFalse(rendered.comment.contains("{"), "every placeholder is filled")

    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
    let empty = WidgetSync.content(
      day: tomorrow, profile: profile, entries: [entry], voice: voice, l: l)
    XCTAssertEqual(empty.calories, 0)
    XCTAssertEqual(empty.progress, 0)
    XCTAssertTrue(empty.statusText.hasPrefix(l.text("remaining")))
  }

  func testLockedStylesFallBackToNormalInTheWidget() {
    // The widget must not leak a Pro-only style to a free user.
    XCTAssertEqual(CoachVoice(level: .toxic, isPro: false).level, .normal)
    XCTAssertEqual(CoachVoice(level: .toxic, isPro: true).level, .toxic)
  }
}

extension WidgetTests {
  // Renders both widget sizes into SHOTS_DIR/widget (skipped when unset) for a visual check.
  func testRenderWidgetPreviews() throws {
    guard let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] else {
      throw XCTSkip("SHOTS_DIR not set")
    }
    try FileManager.default.createDirectory(atPath: dir + "/widget", withIntermediateDirectories: true)
    let samples: [(String, WidgetContent)] = [
      ("tr", .placeholder),
      (
        "over",
        WidgetContent(
          calories: 3584, target: 1935, calorieText: "3.584", targetText: "/ 1.935 kcal",
          statusText: "HEDEF ÜSTÜ · 1.649",
          comment: "Mutfak bugün tam kadro çalışmış. Mesai ücretini kim ödeyecek?")
      ),
    ]
    for (name, content) in samples {
      for (family, size) in [(WidgetFamily.systemSmall, CGSize(width: 158, height: 158)), (.systemMedium, CGSize(width: 338, height: 158))] {
        let view = CoachWidgetView(entry: CoachEntry(date: .now, content: content), forcedFamily: family)
          .padding(14)  // the system's own widget content margins
          .frame(width: size.width, height: size.height)
          .background(WidgetTheme.ink).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let data = try XCTUnwrap(renderer.uiImage?.pngData())
        try data.write(to: URL(fileURLWithPath: "\(dir)/widget/\(name)-\(family == .systemSmall ? "small" : "medium").png"))
      }
    }
  }
}
