import Foundation

enum LanguageResolver {
  static func resolve(_ requested: String, among available: [String]) throws -> String {
    let normalized = TextProcessing.normalizedLanguageTag(requested)
    if let exact = available.first(where: {
      TextProcessing.normalizedLanguageTag($0).caseInsensitiveCompare(normalized) == .orderedSame
    }) {
      return exact
    }
    guard !normalized.contains("-") else { throw KVoiceError.unsupportedLanguage(requested) }
    let languageCode = Locale(identifier: normalized).language.languageCode?.identifier
    if let languageCode,
      let base = available.first(where: {
        Locale(identifier: $0).language.languageCode?.identifier.caseInsensitiveCompare(
          languageCode) == .orderedSame
      })
    {
      return base
    }
    throw KVoiceError.unsupportedLanguage(requested)
  }
}
