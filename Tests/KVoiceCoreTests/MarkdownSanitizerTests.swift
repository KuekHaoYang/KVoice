import XCTest

@testable import KVoiceCore

final class MarkdownSanitizerTests: XCTestCase {
  func testRemovesCommonMarkdownSyntaxAndKeepsCodeContents() {
    let markdown = """
      # Heading
      **bold** and *italic*
      - list item
      > quoted text
      [link label](https://example.com) and ![image label](image.png)
      `inline code`
      ```swift
      let answer = 42
      ```
      """

    XCTAssertEqual(
      MarkdownSanitizer.plainText(markdown),
      "Heading\nbold and italic\nlist item\nquoted text\nlink label and image label\ninline code\nlet answer = 42"
    )
  }

  func testRemovesTaskMarkersAndTableSeparators() {
    let markdown = """
      - [x] complete
      | name | value |
      | --- | --- |
      | alpha | beta |
      """

    XCTAssertEqual(
      MarkdownSanitizer.plainText(markdown).components(separatedBy: .newlines),
      ["complete", "name value", "alpha beta"])
  }
}
