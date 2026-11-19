import Foundation
import XCTest

@testable import KVoiceCore

final class CommandLineTests: XCTestCase {
  func testTranscribeRequiresAbsolutePathsAndTimestampExtension() throws {
    XCTAssertThrowsError(
      try KVoiceCommandLine.parse([
        "transcribe", "--input", "relative.wav", "--output", "/tmp/result.txt",
      ]))
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

  func testHelpAndVersionRequireAbsoluteOutputPaths() throws {
    XCTAssertEqual(
      try KVoiceCommandLine.parse(["help", "--output", "/tmp/help.txt"]),
      .help(output: URL(fileURLWithPath: "/tmp/help.txt"), force: false)
    )
    XCTAssertEqual(
      try KVoiceCommandLine.parse(["version", "--output", "/tmp/version.txt", "--force"]),
      .version(output: URL(fileURLWithPath: "/tmp/version.txt"), force: true)
    )
    XCTAssertThrowsError(try KVoiceCommandLine.parse(["help", "--output", "relative.txt"]))
  }
}
