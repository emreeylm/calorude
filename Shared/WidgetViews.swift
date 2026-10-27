import SwiftUI
import WidgetKit

// Mirrors Theme in the app target (the extension does not link the app's UI code).
enum WidgetTheme {
  static let lime = Color(red: 0.78, green: 0.96, blue: 0.28)
  static let ink = Color(red: 0.07, green: 0.09, blue: 0.07)
}

struct CoachEntry: TimelineEntry {
  let date: Date
  let content: WidgetContent
}

extension WidgetContent {
  // Shown in the gallery and before the app has ever written a snapshot.
  static var placeholder: WidgetContent {
    let turkish = Locale.current.language.languageCode?.identifier == "tr"
    return WidgetContent(
      calories: 1002, target: 1935, calorieText: turkish ? "1.002" : "1,002",
      targetText: turkish ? "/ 1.935 kcal" : "/ 1,935 kcal",
      statusText: turkish ? "KALAN · 933" : "LEFT · 933",
      comment: turkish
        ? "Yeterince iyi gidiyorsun. Beni ikna edecek kadar değil ama."
        : "You're doing fine. Not enough to convince me, though.")
  }
}

struct Ring: View {
  let content: WidgetContent
  var lineWidth: CGFloat
  var numberSize: CGFloat

  var body: some View {
    ZStack {
      Circle().stroke(WidgetTheme.lime.opacity(0.14), lineWidth: lineWidth)
      Circle().trim(from: 0, to: content.progress)
        .stroke(WidgetTheme.lime, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90)).widgetAccentable()
      VStack(spacing: 1) {
        Text(content.calorieText)
          .font(.system(size: numberSize, weight: .black, design: .rounded)).foregroundStyle(.white)
          .minimumScaleFactor(0.5).lineLimit(1)
        Text(content.targetText).font(.system(size: max(numberSize * 0.3, 8), weight: .medium))
          .foregroundStyle(.white.opacity(0.6)).minimumScaleFactor(0.6).lineLimit(1)
      }.padding(lineWidth + 2)
    }
  }
}

struct CoachBubble: View {
  let comment: String
  var size: CGFloat

  var body: some View {
    Text(comment).font(.system(size: size, weight: .semibold)).foregroundStyle(WidgetTheme.ink)
      .minimumScaleFactor(0.7).multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(10)
      .background(WidgetTheme.lime, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

struct CoachWidgetView: View {
  let entry: CoachEntry
  // Only set by previews and tests; WidgetKit's environment value is read-only.
  var forcedFamily: WidgetFamily?
  @Environment(\.widgetFamily) private var environmentFamily
  private var family: WidgetFamily { forcedFamily ?? environmentFamily }

  var body: some View {
    Group {
      if family == .systemSmall {
        VStack(spacing: 8) {
          Ring(content: entry.content, lineWidth: 7, numberSize: 21).frame(width: 72, height: 72)
          CoachBubble(comment: entry.content.comment, size: 11)
        }
      } else {
        HStack(spacing: 14) {
          Ring(content: entry.content, lineWidth: 11, numberSize: 30).frame(width: 118, height: 118)
          CoachBubble(comment: entry.content.comment, size: 15)
        }
      }
    }.containerBackground(WidgetTheme.ink, for: .widget)
  }
}
