import SwiftData
import SwiftUI

enum CardKind: String, CaseIterable, Identifiable {
  case daily, weekly, roast, streak
  var id: String { rawValue }
}
enum CardTheme: String, CaseIterable { case dark, minimal, bold, brutalist }
struct ShareSnapshot {
  var calories: Double
  var target: Double
  var protein: Double
  var streak: Int
  var successfulDays: Int
  var averageCalories: Double
  var averageProtein: Double
  var roast: String
  var date: Date
  var weightChange: Double? = nil
}
struct ShareCardView: View {
  var snapshot: ShareSnapshot
  var kind: CardKind
  var theme: CardTheme
  var l: AppLocalization
  var light: Bool { theme == .minimal || theme == .bold || theme == .brutalist }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "bolt.fill")
        Text(AppBrand.name(l)).tracking(4)
        Spacer()
        Image(systemName: "arrow.up.right")
      }.font(.system(size: 15, weight: .black))
      Rectangle().frame(height: 2).opacity(0.3)
      Spacer(minLength: 0)
      Text(l.text("card." + kind.rawValue)).font(.system(size: 16, weight: .black)).tracking(4)
      if kind == .streak {
        Image(systemName: "flame.fill").font(.system(size: 60))
        Text("\(snapshot.streak)").font(.system(size: 90, weight: .black, design: .rounded))
        Text(l.text("streak.days")).font(.system(size: 24, weight: .black))
      } else if kind == .weekly {
        Text("\(snapshot.successfulDays) / 7").font(
          .system(size: 68, weight: .black, design: .rounded))
        Text(l.text("targetDays")).font(.system(size: 18, weight: .bold))
        HStack(alignment: .top) {
          stat(l.number(snapshot.averageCalories), "avgCalories")
          Spacer()
          stat(l.number(snapshot.averageProtein), "avgProtein")
        }
        HStack {
          if let change = snapshot.weightChange {
            stat(l.number(change, digits: 1) + " " + l.text("unit.kg"), "weeklyWeightChange")
          }
          Spacer()
          stat("\(snapshot.streak)", "streak.days")
        }
      } else {
        Text(l.number(snapshot.calories)).font(.system(size: 72, weight: .black, design: .rounded))
          .minimumScaleFactor(0.6).lineLimit(1)
        Text("/ " + l.number(snapshot.target) + " " + l.text("unit.kcal")).font(
          .system(size: 24, weight: .bold))
        if kind == .daily {
          HStack {
            stat(l.number(snapshot.protein) + " " + l.text("unit.g"), "protein")
            Spacer()
            stat("\(snapshot.streak)", "streak.days")
          }
        }
      }
      Rectangle().frame(height: 2).opacity(0.3)
      Text(snapshot.roast).font(.system(size: kind == .roast ? 30 : 22, weight: .bold)).lineLimit(8)
        .minimumScaleFactor(
          0.8)
      Spacer(minLength: 0)
      HStack {
        Text(AppBrand.name(l)).fontWeight(.black)
        Spacer()
        Text(snapshot.date, format: .dateTime.day().month().year())
      }.font(.system(size: 12))
    }.padding(30).frame(width: 360, height: 640).background(
      theme == .bold ? Theme.accent : light ? Color(red: 0.95, green: 0.94, blue: 0.89) : Theme.ink
    ).foregroundStyle(light ? Theme.ink : Theme.accent).overlay {
      if theme == .brutalist { Rectangle().strokeBorder(Theme.ink, lineWidth: 8).padding(12) }
    }.environment(\.locale, l.locale).environment(\.sizeCategory, .large)
  }
  func stat(_ value: String, _ key: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(value).font(.system(size: 28, weight: .black))
      Text(l.text(key)).font(.system(size: 10, weight: .bold)).textCase(.uppercase)
    }
  }
}
@MainActor enum ShareCardRenderer {
  static func render(snapshot: ShareSnapshot, kind: CardKind, theme: CardTheme, l: AppLocalization)
    throws -> URL
  {
    let renderer = ImageRenderer(
      content: ShareCardView(snapshot: snapshot, kind: kind, theme: theme, l: l))
    renderer.scale = 3
    renderer.isOpaque = true
    guard let data = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "story-\(UUID().uuidString).png")
    try data.write(to: url, options: .atomic)
    return url
  }
}
struct ShareService: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
struct ShareComposerView: View {
  var profile: UserProfile
  var date: Date
  // When set, cards quote this exact text (the coach comment the user is looking at).
  var roast: String?
  init(profile: UserProfile, date: Date, kind: CardKind = .daily, roast: String? = nil) {
    self.profile = profile
    self.date = date
    self.roast = roast
    _kind = State(initialValue: kind)
  }
  @Environment(AppLocalization.self) private var l
  @Environment(StoreService.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Query private var entries: [FoodEntry]
  @Query private var weights: [WeightEntry]
  @State private var kind = CardKind.daily
  @State private var theme = CardTheme.dark
  @State private var output: ShareOutput?
  @State private var showPaywall = false
  @State private var error = false
  var snapshot: ShareSnapshot {
    let day = ProgressService.day(
      date, entries: entries, target: profile.dailyCalorieTarget,
      proteinTarget: profile.proteinTarget)
    let days = ProgressService.allDays(
      entries: entries.filter {
        $0.date <= Calendar.current.date(
          byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))!
      }, target: profile.dailyCalorieTarget, proteinTarget: profile.proteinTarget)
    let streak = ProgressService.streak(days: days, today: date).current
    let week = ProgressService.week(
      ending: date, entries: entries, target: profile.dailyCalorieTarget,
      proteinTarget: profile.proteinTarget)
    let context = CoachContextBuilder.make(
      profile: profile, stats: day, streak: streak, entries: entries)
    let message = RoastEngine.bundled.evaluate(
      context,
      intensity: profile.coachIntensity, personality: .standard, isPro: store.isPro,
      seed: Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0)
    return ShareSnapshot(
      calories: day.calories, target: day.target, protein: day.protein, streak: streak,
      successfulDays: week.successful, averageCalories: week.averageCalories,
      averageProtein: week.averageProtein,
      roast: kind == .weekly
        ? l.text(week.successful >= 5 ? "weekly.good" : "weekly.build")
        : roast ?? context.text(l.text(message.messageKey), l: l), date: date,
      weightChange: ProgressService.weightTrend(weights, ending: date))
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 22) {
          Picker(l.text("card.type"), selection: $kind) {
            ForEach(CardKind.allCases) { Text(l.text("card." + $0.rawValue)).tag($0) }
          }.pickerStyle(.menu)
          ShareCardView(snapshot: snapshot, kind: kind, theme: theme, l: l).scaleEffect(0.85).frame(
            width: 306, height: 544
          ).clipped().accessibilityLabel(l.text("card.preview"))
          Picker(
            l.text("theme"),
            selection: Binding(
              get: { theme },
              set: { value in
                if value == .dark || store.isPro { theme = value } else { showPaywall = true }
              })
          ) {
            ForEach(CardTheme.allCases, id: \.self) { Text(l.text("theme." + $0.rawValue)).tag($0) }
          }
          PrimaryButton(title: l.text("share"), icon: "square.and.arrow.up") {
            do {
              output = ShareOutput(
                url: try ShareCardRenderer.render(
                  snapshot: snapshot, kind: kind, theme: store.isPro ? theme : .dark, l: l))
            } catch { self.error = true }
          }
          Text(l.text("share.note")).font(.caption).foregroundStyle(.secondary)
        }.padding(20)
      }.background(Color(.systemGroupedBackground)).navigationTitle(l.text("share.title")).toolbar {
        Button(l.text("done")) { dismiss() }
      }
    }
    .sheet(item: $output, onDismiss: { cleanup() }) { ShareService(url: $0.url) }
    .sheet(isPresented: $showPaywall) { PaywallView() }
    .alert(l.text("error.share"), isPresented: $error) { Button(l.text("ok"), role: .cancel) {} }
  }
  func cleanup() {
    let manager = FileManager.default
    if let files = try? manager.contentsOfDirectory(
      at: manager.temporaryDirectory, includingPropertiesForKeys: nil)
    {
      for url in files where url.lastPathComponent.hasPrefix("story-") {
        try? manager.removeItem(at: url)
      }
    }
  }
}
struct ShareOutput: Identifiable {
  let id = UUID()
  let url: URL
}
#Preview {
  ShareCardView(
    snapshot: ShareSnapshot(
      calories: 2387, target: 2400, protein: 158, streak: 8, successfulDays: 6,
      averageCalories: 2285, averageProtein: 148,
      roast: AppLocalization(language: "tr").text("plan.ready"), date: .now), kind: .daily,
    theme: .dark, l: AppLocalization(language: "tr"))
}
