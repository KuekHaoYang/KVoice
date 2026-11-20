import Foundation
import XCTest

@testable import KVoiceCore

final class CommandLineTests: XCTestCase {
  func testTranscribeAcceptsRelativePathsAndRequiresTimestampExtension() throws {
    XCTAssertEqual(
      try KVoiceCommandLine.parse([
        "transcribe", "--input", "relative.wav", "--output", "relative-result.txt",
      ]),
      .transcribe(
        input: FileValidation.resolvePath("relative.wav"),
        output: FileValidation.resolvePath("relative-result.txt"),
        language: .automatic, timestamps: false, optimize: true, force: false))
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "transcribe", "--input", "/tmp/in.wav", "--output", "/tmp/result.txt", "--timestamps",
      ]))
  }

  func testTranscribeDefaultsAndOptions() throws {
    let command = try KVoiceCommandLine.parse([
      "transcribe", "--input", "/tmp/in.wav", "--output", "/tmp/result.txt",
    ])
    XCTAssertEqual(
      command,
      .transcribe(
        input: URL(fileURLWithPath: "/tmp/in.wav"),
        output: URL(fileURLWithPath: "/tmp/result.txt"),
        language: .automatic,
        timestamps: false,
        optimize: true,
        force: false
      ))
    let json = try KVoiceCommandLine.parse([
      "transcribe", "--input", "/tmp/in.wav", "--output", "/tmp/result.json",
      "--timestamps", "--language", "ms-MY", "--no-optimize", "--force",
    ])
    XCTAssertEqual(
      json,
      .transcribe(
        input: URL(fileURLWithPath: "/tmp/in.wav"),
        output: URL(fileURLWithPath: "/tmp/result.json"),
        language: .explicit("ms-MY"),
        timestamps: true,
        optimize: false,
        force: true
      ))
  }

  func testSpeakRequiresExactlyOneInputAndWAVOutput() throws {
    XCTAssertThrowsError(try KVoiceCommandLine.parse(["speak", "--output", "/tmp/out.wav"]))
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "speak", "--input", "/tmp/a.txt", "--text", "text", "--output", "/tmp/out.wav",
      ]))
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "speak", "--text", "hello", "--output", "/tmp/out.mp3",
      ]))
    let command = try KVoiceCommandLine.parse([
      "speak", "--text", "hello", "--output", "/tmp/out.wav", "--language", "auto",
    ])
    XCTAssertEqual(
      command,
      .speak(
        input: .inline("hello"), output: URL(fileURLWithPath: "/tmp/out.wav"),
        language: .automatic, optimize: true, force: false
      ))
  }

  func testSpeakParsesVoiceRateMarkdownAndStandardInputOptions() throws {
    let output = FileValidation.resolvePath("relative.wav")
    XCTAssertEqual(
      try KVoiceCommandLine.parse([
        "speak", "--text", "# Hello", "--output", "relative.wav", "--voice", "Samantha",
        "--rate", "0.57", "--sanitize-markdown",
      ]),
      .speakConfigured(
        input: .inline("# Hello"), output: output, language: .automatic, optimize: true,
        force: false, voiceName: "Samantha", rate: 0.57, sanitizeMarkdown: true))

    XCTAssertEqual(
      try KVoiceCommandLine.parse(["speak", "--input", "-", "--output", "stdin.wav"]),
      .speakConfigured(
        input: .standardInput, output: FileValidation.resolvePath("stdin.wav"),
        language: .automatic, optimize: true, force: false, voiceName: nil, rate: nil,
        sanitizeMarkdown: false))
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "speak", "--text", "hello", "--output", "rate.wav", "--rate", "99",
      ]))
  }

  func testSpeakDirectoryInputUsesAnOutputDirectory() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let input = folder.appendingPathComponent("input", isDirectory: true)
    let output = folder.appendingPathComponent("output", isDirectory: true)
    try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }

    XCTAssertEqual(
      try KVoiceCommandLine.parse([
        "speak", "--input", input.path, "--output", output.path, "--no-optimize",
      ]),
      .speakConfigured(
        input: .directory(input), output: FileValidation.resolvePath(output.path),
        language: .automatic, optimize: false,
        force: false, voiceName: nil, rate: nil, sanitizeMarkdown: false))
  }

  func testListCommandsParseLanguagesAndVoices() throws {
    XCTAssertEqual(
      try KVoiceCommandLine.parse(["list", "languages", "--output", "languages.txt"]),
      .listResources(
        kind: .languages, output: FileValidation.resolvePath("languages.txt"), force: false))
    XCTAssertEqual(
      try KVoiceCommandLine.parse(["list", "voices", "--output", "voices.txt"]),
      .listResources(kind: .voices, output: FileValidation.resolvePath("voices.txt"), force: false))
  }

  func testLocateRequiresSingleSourceAndJSONOutput() throws {
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "locate", "--reference", "/tmp/ref.txt", "--output", "/tmp/out.json",
      ]))
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "locate", "--reference", "/tmp/ref.txt", "--audio", "/tmp/a.wav",
        "--source-text", "/tmp/s.txt", "--output", "/tmp/out.json",
      ]))
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "locate", "--reference", "/tmp/ref.txt", "--source-text", "/tmp/s.txt",
        "--language", "en-US", "--output", "/tmp/out.json",
      ]))
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "locate", "--reference", "/tmp/ref.txt", "--source-text", "/tmp/s.txt", "--output",
        "/tmp/out.txt",
      ]))
  }

  func testEveryCommandRequiresExplicitOutputAndRejectsUnknownOptions() throws {
    XCTAssertThrowsError(try KVoiceCommandLine.parse(["help"]))
    XCTAssertThrowsError(try KVoiceCommandLine.parse(["version"]))
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "transcribe", "--input", "/tmp/in.wav", "--output", "/tmp/out.txt", "--mystery", "yes",
      ]))
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "transcribe", "--input", "/tmp/in.wav", "--output", "/tmp/out.txt", "--force", "--force",
      ]))
  }

  func testHelpAndVersionAcceptRelativeOutputPaths() throws {
    XCTAssertEqual(
      try KVoiceCommandLine.parse(["help", "--output", "/tmp/help.txt"]),
      .help(output: URL(fileURLWithPath: "/tmp/help.txt"), force: false)
    )
    XCTAssertEqual(
      try KVoiceCommandLine.parse(["version", "--output", "/tmp/version.txt", "--force"]),
      .version(output: URL(fileURLWithPath: "/tmp/version.txt"), force: true)
    )
    XCTAssertEqual(
      try KVoiceCommandLine.parse(["help", "--output", "relative.txt"]),
      .help(output: FileValidation.resolvePath("relative.txt"), force: false))
  }
}
