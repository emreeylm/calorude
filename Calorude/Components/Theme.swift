import SwiftUI

enum Theme {
  static let accent = Color(red: 0.78, green: 0.96, blue: 0.28)
  static let interactive = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.78, green: 0.96, blue: 0.28, alpha: 1)
        : UIColor(red: 0.24, green: 0.38, blue: 0.03, alpha: 1)
    })
  static let ink = Color(red: 0.07, green: 0.09, blue: 0.07)
  static let protein = Color(red: 0.54, green: 0.72, blue: 1)
  static let carbs = Color(red: 1, green: 0.72, blue: 0.40)
  static let fat = Color(red: 0.80, green: 0.61, blue: 1)
}
extension View {
  // The floating iOS 26 tab bar otherwise lets scrolled text show through and clip under it.
  @ViewBuilder func hardBottomEdge() -> some View {
    if #available(iOS 26, *) {
      scrollEdgeEffectStyle(.hard, for: .bottom)
    } else {
      self
    }
  }
}
struct Panel<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(
      Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26))
  }
}
struct PrimaryButton: View {
  var title: String
  var icon: String = "arrow.right"
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        Text(title).fontWeight(.bold)
        Spacer()
        Image(systemName: icon)
      }.padding(18).foregroundStyle(Theme.ink).background(
        Theme.accent, in: RoundedRectangle(cornerRadius: 18))
    }.buttonStyle(.plain)
  }
}
struct MacroBar: View {
  var title: String
  var amount: Double
  var target: Double
  var color: Color
  @Environment(AppLocalization.self) private var l
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(l.number(amount)).font(.title3.bold())
        + Text(" / " + l.number(target) + " " + l.text("unit.g")).font(.caption).foregroundColor(
          .secondary)
      ProgressView(value: min(max(amount / max(target, 1), 0), 1)).tint(color)
    }.accessibilityElement(children: .combine)
  }
}
struct EmptyCard: View {
  @Environment(AppLocalization.self) private var l
  var body: some View {
    Panel {
      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: "fork.knife").font(.title).foregroundStyle(Theme.interactive)
        Text(l.text("empty.title")).font(.headline)
        Text(l.text("empty.body")).foregroundStyle(.secondary)
      }
    }
  }
}

/// Bundled representative food photography; custom foods use a neutral symbol.
struct FoodThumbnail: View {
  let food: Food
  var size: CGFloat = 48
  var body: some View {
    Group {
      if let photo = UIImage(named: "food-" + food.id) {
        Image(uiImage: photo).resizable().scaledToFill()
      } else {
        Image(systemName: food.unit == "ml" ? "cup.and.saucer.fill" : "fork.knife")
          .font(.system(size: size * 0.4)).foregroundStyle(Theme.interactive)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Theme.interactive.opacity(0.08))
      }
    }.frame(width: size, height: size)
      .clipShape(RoundedRectangle(cornerRadius: size * 0.23))
      .accessibilityHidden(true)
  }
}
