import Foundation

public enum TextProcessing {
  public static func normalizedLanguageTag(_ identifier: String) -> String {
    identifier.replacingOccurrences(of: "_", with: "-")
  }

  public static func normalizedNonEmpty(_ text: String) throws -> String {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { throw KVoiceError.emptyText }
    return value
  }

  public static func languageMatch(_ response: String, candidates: [String]) throws -> String {
    let raw =
      response
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "`", with: "")
      .components(separatedBy: .newlines).first ?? ""
    let normalized = normalizedLanguageTag(raw)
    if let exact = candidates.first(where: {
      normalizedLanguageTag($0).caseInsensitiveCompare(normalized) == .orderedSame
    }
    ) {
      return exact
    }
    guard !normalized.contains("-") else {
      throw KVoiceError.invalidModelResponse(
        "Expected one of the available language tags; received '\(normalized)'.")
    }
    let languageCode = Locale(identifier: normalized).language.languageCode?.identifier
    if let languageCode,
      let match = candidates.first(where: {
        Locale(identifier: $0).language.languageCode?.identifier.caseInsensitiveCompare(
          languageCode) == .orderedSame
      })
    {
      return match
    }
    throw KVoiceError.invalidModelResponse(
      "Expected one of the available language tags; received '\(normalized)'.")
  }

  public static func location(of excerpt: String, in reference: String) -> ModelLocation {
    let nsReference = reference as NSString
    let range = nsReference.range(of: excerpt, options: [.caseInsensitive, .diacriticInsensitive])
    guard range.location != NSNotFound, range.length > 0 else { return ModelLocation(found: false) }
    let matched = nsReference.substring(with: range)
    return ModelLocation(
      found: true, excerpt: matched, startUTF16: range.location, lengthUTF16: range.length)
  }

  public static func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }
}
