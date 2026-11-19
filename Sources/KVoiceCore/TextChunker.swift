import Foundation

public enum TextChunker {
  /// Splits at whitespace or punctuation where possible, then at Unicode character boundaries.
  public static func split(_ text: String, maximumCharacters: Int) -> [String] {
    guard maximumCharacters > 0, !text.isEmpty else { return text.isEmpty ? [] : [text] }
    let characters = Array(text)
    var chunks: [String] = []
    var start = 0

    while start < characters.count {
      let limit = min(start + maximumCharacters, characters.count)
      if limit == characters.count {
        chunks.append(String(characters[start..<limit]))
        break
      }

      let precedingBoundary = (start..<limit).reversed().first(where: { isBoundary(characters[$0]) }
      )
      let breakIndex: Int
      if let precedingBoundary {
        breakIndex = precedingBoundary + 1
      } else {
        breakIndex = limit
      }
      chunks.append(String(characters[start..<breakIndex]))
      start = breakIndex
    }
    return chunks
  }

  public static func windows(_ text: String, maximumCharacters: Int, overlap: Int) -> [(
    text: String, utf16Offset: Int
  )] {
    guard maximumCharacters > 0 else { return [] }
    let characters = Array(text)
    guard !characters.isEmpty else { return [] }
    let step = max(1, maximumCharacters - max(0, overlap))
    var windows: [(String, Int)] = []
    var characterOffset = 0

    while characterOffset < characters.count {
      let end = min(characterOffset + maximumCharacters, characters.count)
      let value = String(characters[characterOffset..<end])
      let prefix = String(characters[..<characterOffset])
      windows.append((value, (prefix as NSString).length))
      if end == characters.count { break }
      characterOffset += step
    }
    return windows
  }

  private static func isBoundary(_ character: Character) -> Bool {
    character.isWhitespace || ".!?。！？;；".contains(character)
  }
}
