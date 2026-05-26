import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
  case english = "en"
  case simplifiedChinese = "zh-Hans"

  var id: String {
    rawValue
  }

  var displayName: String {
    switch self {
    case .english:
      return "English"
    case .simplifiedChinese:
      return "简体中文"
    }
  }

  var localeIdentifier: String {
    switch self {
    case .english:
      return "en"
    case .simplifiedChinese:
      return "zh_Hans"
    }
  }
}

extension Notification.Name {
  static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}

enum L10n {
  private static let languageKey = "BRDiscSplitterLanguage"
  private static var selectedLanguage = defaultLanguage()

  static var language: AppLanguage {
    selectedLanguage
  }

  static func setLanguage(_ language: AppLanguage) {
    selectedLanguage = language
    UserDefaults.standard.set(language.rawValue, forKey: languageKey)
  }

  static func string(_ key: String) -> String {
    NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: key, comment: "")
  }

  static func format(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: string(key), locale: Locale(identifier: selectedLanguage.localeIdentifier), arguments: arguments)
  }

  private static var bundle: Bundle {
    guard let path = Bundle.main.path(forResource: selectedLanguage.rawValue, ofType: "lproj"),
      let bundle = Bundle(path: path)
    else {
      return .main
    }

    return bundle
  }

  private static func defaultLanguage() -> AppLanguage {
    if let saved = UserDefaults.standard.string(forKey: languageKey),
      let language = AppLanguage(rawValue: saved)
    {
      return language
    }

    let preferredLanguage = Locale.preferredLanguages.first ?? "en"
    return preferredLanguage.hasPrefix("zh") ? .simplifiedChinese : .english
  }
}
