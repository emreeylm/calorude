import SwiftUI

struct MealReactionView: View {
  let reaction: MealReaction
  @Environment(AppLocalization.self) private var l
  @Environment(\.dismiss) private var dismiss
  @State private var output: ShareOutput?
  @State private var exportedURL: URL?
  @State private var error = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Label(l.text("reaction.saved"), systemImage: "checkmark.circle.fill")
            .font(.subheadline.bold()).foregroundStyle(Theme.interactive)
          Text(l.text("reaction.title." + reaction.verdict.rawValue))
            .font(.largeTitle.bold())
          Text(reaction.message(l)).font(.title2.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(
              "reaction.message")
          Text(l.text("reaction.action." + reaction.verdict.rawValue))
            .foregroundStyle(.secondary)
          HStack {
            Label(
              l.number(reaction.nutrition.calories) + " " + l.text("unit.kcal"),
              systemImage: "fork.knife")
            Spacer()
            Text(
              l.number(reaction.nutrition.protein) + " " + l.text("unit.g") + " "
                + l.text("protein"))
          }.font(.subheadline.bold())
          PrimaryButton(title: l.text("reaction.share"), icon: "square.and.arrow.up") {
            do {
              let url = try MealReactionRenderer.render(reaction, l: l)
              exportedURL = url
              output = ShareOutput(url: url)
            } catch { self.error = true }
          }.accessibilityIdentifier("reaction.share")
          Text(l.text("share.note")).font(.caption).foregroundStyle(.secondary)
        }.padding(24)
      }.background(Color(.systemGroupedBackground))
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(l.text("done")) { dismiss() }.accessibilityIdentifier("reaction.close")
          }
        }
    }
    .sheet(item: $output, onDismiss: cleanup) { ShareService(url: $0.url) }
    .alert(l.text("error.share"), isPresented: $error) { Button(l.text("ok"), role: .cancel) {} }
    .onDisappear { if output == nil { cleanup() } }
  }
  private func cleanup() {
    if let exportedURL { try? FileManager.default.removeItem(at: exportedURL) }
    exportedURL = nil
  }
}

struct MealReactionStoryView: View {
  let reaction: MealReaction
  let l: AppLocalization
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Image(systemName: "bolt.fill")
        Text(AppBrand.name(l)).tracking(2)
        Spacer()
        Image(systemName: "arrow.up.right")
      }.font(.system(size: 14, weight: .black))
      Rectangle().frame(height: 2).opacity(0.4)
      Spacer(minLength: 0)
      Text(l.text("reaction.title." + reaction.verdict.rawValue))
        .font(.system(size: 14, weight: .black)).textCase(.uppercase)
      Text(reaction.message(l)).font(.system(size: 30, weight: .black, design: .rounded))
        .lineLimit(9).minimumScaleFactor(0.75)
      Text(l.text("reaction.action." + reaction.verdict.rawValue))
        .font(.system(size: 15, weight: .medium)).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      Rectangle().frame(height: 2).opacity(0.4)
      Text(reaction.meal.map { l.text("meal." + $0.rawValue) } ?? l.text("reaction.meals"))
        .font(.system(size: 14, weight: .bold))
      HStack(alignment: .firstTextBaseline) {
        Text(l.number(reaction.nutrition.calories)).font(.system(size: 44, weight: .black))
        Text(l.text("unit.kcal")).font(.system(size: 14, weight: .bold))
        Spacer()
        Text(l.number(reaction.nutrition.protein) + " " + l.text("unit.g"))
          .font(.system(size: 24, weight: .black))
      }
      HStack {
        Text(reaction.date, format: .dateTime.day().month().year())
        Spacer()
        Text(l.text("protein"))
      }.font(.system(size: 12))
    }.padding(30).frame(width: 360, height: 640)
      .foregroundStyle(reaction.verdict == .snackHeavy ? Theme.accent : Theme.ink)
      .background(reaction.verdict == .snackHeavy ? Theme.ink : Theme.accent)
      .environment(\.locale, l.locale).environment(\.sizeCategory, .large)
  }
}

@MainActor enum MealReactionRenderer {
  static func render(_ reaction: MealReaction, l: AppLocalization) throws -> URL {
    let renderer = ImageRenderer(content: MealReactionStoryView(reaction: reaction, l: l))
    renderer.scale = 3
    renderer.isOpaque = true
    guard let data = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "meal-reaction-\(UUID().uuidString).png")
    try data.write(to: url, options: .atomic)
    return url
  }
}
