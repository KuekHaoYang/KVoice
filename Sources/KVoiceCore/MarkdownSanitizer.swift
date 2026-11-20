import Foundation

public enum MarkdownSanitizer {
  public static func plainText(_ markdown: String) -> String {
    let lines = markdown.components(separatedBy: .newlines)
    var cleanedLines: [String] = []
    var fence: (character: Character, count: Int)?
    for line in lines {
      if let activeFence = fence {
        if closesFence(line, character: activeFence.character, minimumCount: activeFence.count) {
          fence = nil
        } else {
          cleanedLines.append(line)
        }
      } else if let opening = fenceOpening(line) {
        fence = opening
      } else if let clean = cleanLine(line) {
        cleanedLines.append(clean)
      }
    }
    let joined = cleanedLines.joined(separator: "\n")
    return
      joined
      .replacingOccurrences(of: "[ \t]+\n", with: "\n", options: .regularExpression)
      .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func cleanLine(_ source: String) -> String? {
    var line = source
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if matches(trimmed, pattern: "^(?:[-*_]\\s*){3,}$") { return nil }
    if matches(trimmed, pattern: "^=+\\s*$") { return nil }
    line = replacing(line, pattern: "^\\s{0,3}#{1,6}\\s+", with: "")
    line = replacing(line, pattern: "\\s+#+\\s*$", with: "")
    line = replacing(line, pattern: "^\\s{0,3}>+\\s?", with: "")
    line = replacing(line, pattern: "^\\s{0,3}\\[\\^([^\\]]+)\\]:\\s*", with: "")
    if matches(line, pattern: "^\\s{0,3}\\[(?!\\^)[^\\]]+\\]:\\s*\\S+.*$") { return nil }
    line = replacing(line, pattern: "^\\s{0,3}(?:[-+*]|\\d+[.)])\\s+", with: "")
    line = replacing(line, pattern: "^\\s{0,3}\\[[ xX]\\]\\s+", with: "")
    if matches(line.trimmingCharacters(in: .whitespaces), pattern: "^\\|?[\\s:|_-]+\\|?$"),
      line.contains("|")
    {
      return nil
    }
    line = replacing(line, pattern: "!\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1")
    line = replacing(line, pattern: "!\\[([^\\]]*)\\]\\[[^\\]]*\\]", with: "$1")
    line = replacing(line, pattern: "\\[([^\\]]+)\\]\\([^)]*\\)", with: "$1")
    line = replacing(line, pattern: "\\[([^\\]]+)\\]\\[[^\\]]*\\]", with: "$1")
    line = replacing(line, pattern: "\\[\\^([^\\]]+)\\]", with: "$1")
    line = replacing(line, pattern: "`{1,3}([^`]+)`{1,3}", with: "$1")
    line = replacing(line, pattern: "<(https?://[^>]+)>", with: "$1")
    line = replacing(line, pattern: "<(mailto:[^>]+)>", with: "$1")
    line = replacing(line, pattern: "<(/?)[A-Za-z][^>]*>", with: "")
    line = replacing(line, pattern: "\\*\\*(.+?)\\*\\*", with: "$1")
    line = replacing(line, pattern: "__(.+?)__", with: "$1")
    line = replacing(line, pattern: "~~(.+?)~~", with: "$1")
    line = replacing(line, pattern: "\\*([^*]+)\\*", with: "$1")
    line = replacing(line, pattern: "_([^_]+)_", with: "$1")
    line = replacing(line, pattern: "\\\\([\\\\`*_{}\\[\\]()#+.!|>~-])", with: "$1")
    line = line.replacingOccurrences(of: "|", with: " ")
    return
      line
      .replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)
  }

  private static func fenceOpening(_ line: String) -> (character: Character, count: Int)? {
    let leadingSpaces = line.prefix { $0 == " " }.count
    guard leadingSpaces <= 3 else { return nil }
    let candidate = line.dropFirst(leadingSpaces)
    guard let character = candidate.first, character == "`" || character == "~" else { return nil }
    let count = candidate.prefix { $0 == character }.count
    return count >= 3 ? (character, count) : nil
  }

  private static func closesFence(
    _ line: String, character: Character, minimumCount: Int
  ) -> Bool {
    let leadingSpaces = line.prefix { $0 == " " }.count
    guard leadingSpaces <= 3 else { return false }
    let candidate = line.dropFirst(leadingSpaces)
    guard candidate.first == character else { return false }
    let count = candidate.prefix { $0 == character }.count
    return count >= minimumCount && candidate.dropFirst(count).allSatisfy(\.isWhitespace)
  }

  private static func matches(_ value: String, pattern: String) -> Bool {
    value.range(of: pattern, options: .regularExpression) != nil
  }

  private static func replacing(_ value: String, pattern: String, with template: String) -> String {
    value.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
  }
}
