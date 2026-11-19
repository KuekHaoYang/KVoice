import Foundation
import XCTest

@testable import KVoiceCore

final class TextProcessingTests: XCTestCase {
  func testChunkerPreservesTextAndDoesNotBreakWords() {
    let source = "one two three four five six"
    let chunks = TextChunker.split(source, maximumCharacters: 10)
    XCTAssertEqual(chunks.joined(), source)
    XCTAssertTrue(chunks.allSatisfy { $0.count <= 10 })
    XCTAssertEqual(TextChunker.split("", maximumCharacters: 5), [])
  }

  func testChunkerHandlesOversizedWord() {
    let source = "supercalifragilistic word"
    let chunks = TextChunker.split(source, maximumCharacters: 4)
    XCTAssertEqual(chunks.joined(), source)
    XCTAssertTrue(chunks.allSatisfy { $0.count <= 4 })
    let cjk = "中文无空格文本"
    XCTAssertEqual(TextChunker.split(cjk, maximumCharacters: 3).joined(), cjk)
  }

  func testWindowOffsetsUseUTF16Coordinates() {
    let source = "a😀bcdef"
    let windows = TextChunker.windows(source, maximumCharacters: 4, overlap: 1)
    XCTAssertEqual(windows.map(\.utf16Offset), [0, 4])
    XCTAssertEqual(windows.map(\.text), ["a😀bc", "cdef"])
  }

  func testLanguageMatchAcceptsExactAndBaseLanguageTags() throws {
    let candidates = ["en-US", "zh-CN", "ms-MY"]
    XCTAssertEqual(try TextProcessing.languageMatch("zh-CN\n", candidates: candidates), "zh-CN")
    XCTAssertEqual(try TextProcessing.languageMatch("`en`", candidates: candidates), "en-US")
    XCTAssertEqual(try TextProcessing.languageMatch("en_US", candidates: candidates), "en-US")
    XCTAssertThrowsError(try TextProcessing.languageMatch("French", candidates: candidates))
    XCTAssertThrowsError(try TextProcessing.languageMatch("en-GB", candidates: candidates))
  }

  func testLocationUsesCaseAndAccentInsensitiveComparisonWithUTF16Offsets() {
    let reference = "Start 😀 café ends."
    let match = TextProcessing.location(of: "CAFE", in: reference)
    XCTAssertTrue(match.found)
    XCTAssertEqual(match.excerpt, "café")
    XCTAssertEqual(match.startUTF16, (reference as NSString).range(of: "café").location)
    XCTAssertEqual(match.lengthUTF16, 4)
    XCTAssertFalse(TextProcessing.location(of: "missing", in: reference).found)
  }

  func testEmptyTextIsRejected() {
    XCTAssertThrowsError(try TextProcessing.normalizedNonEmpty(" \n "))
    XCTAssertEqual(try TextProcessing.normalizedNonEmpty(" hello "), "hello")
  }
}
