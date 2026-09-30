import SwiftUI

@MainActor @Observable final class AppLocalization {
  var language: String {
    didSet {
      UserDefaults.standard.set(language, forKey: "language")
      bundle = Self.bundle(for: language)
    }
  }
  @ObservationIgnored private var bundle: Bundle?
  init(language: String? = nil) {
    let resolved =
      language ?? UserDefaults.standard.string(forKey: "language")
      ?? (Locale.preferredLanguages.first?.hasPrefix("tr") == true ? "tr" : "en")
    self.language = resolved
    bundle = Self.bundle(for: resolved)
  }
  private static func bundle(for language: String) -> Bundle? {
    Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
  }
  var locale: Locale { Locale(identifier: language) }
  func text(_ key: String) -> String {
    bundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
  }
  func number(_ value: Double, digits: Int = 0) -> String {
    value.formatted(.number.locale(locale).precision(.fractionLength(digits)))
  }
}
@MainActor enum AppBrand {
  static func name(_ l: AppLocalization) -> String { l.text("brand.name") }
  static func pro(_ l: AppLocalization) -> String { l.text("brand.pro") }
}
