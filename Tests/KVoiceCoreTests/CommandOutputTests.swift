import Foundation
import XCTest

@testable import KVoiceCore

final class CommandOutputTests: XCTestCase {
  func testOutputOverwriteRequiresForce() async throws {
    let folder = try makeFolder()
    let input = try makeFile(folder, name: "input.wav", text: "audio")
    let output = try makeFile(folder, name: "transcript.txt", text: "keep me")
    let runner = makeRunner()

    do {
      try await runner.run(
        .transcribe(
          input: input, output: output, language: .explicit("en-US"), timestamps: false,
          optimize: false, force: false))
      XCTFail("Expected existing output to be rejected")
    } catch let error as KVoiceError {
      XCTAssertEqual(error, .outputExists(output))
    }
    XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "keep me")
  }

  func testOutputCannotReplaceAnInputEvenWithForce() async throws {
    let folder = try makeFolder()
    let input = try makeFile(folder, name: "input.wav", text: "audio")

    do {
      try await makeRunner().run(
        .transcribe(
          input: input, output: input, language: .explicit("en-US"), timestamps: false,
          optimize: false, force: true))
      XCTFail("Expected input/output collision to be rejected")
    } catch let error as KVoiceError {
      XCTAssertEqual(
        error, .invalidArguments("The output path must differ from every input path: \(input.path)")
      )
    }
    XCTAssertEqual(try String(contentsOf: input, encoding: .utf8), "audio")
  }

  func testHelpAndVersionAreWrittenToRequestedFiles() async throws {
    let folder = try makeFolder()
    let help = folder.appendingPathComponent("help.txt")
    let version = folder.appendingPathComponent("version.txt")
    let runner = makeRunner()

    try await runner.run(.help(output: help, force: false))
    try await runner.run(.version(output: version, force: false))

    XCTAssertTrue(try String(contentsOf: help, encoding: .utf8).contains("COMMAND: transcribe"))
    XCTAssertEqual(try String(contentsOf: version, encoding: .utf8), "KVoice 1.0.0\n")
  }

  func testForceDoesNotAllowReplacingAnOutputDirectory() async throws {
    let folder = try makeFolder()
    let input = try makeFile(folder, name: "input.wav", text: "audio")
    let output = folder.appendingPathComponent("output.txt")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
    let marker = try makeFile(output, name: "keep.txt", text: "preserve")

    do {
      try await makeRunner().run(
        .transcribe(
          input: input, output: output, language: .explicit("en-US"), timestamps: false,
          optimize: false, force: true))
      XCTFail("Expected output directory to be rejected")
    } catch let error as KVoiceError {
      XCTAssertEqual(
        error, .unsupportedOutput("Output must be a file, not a directory: \(output.path)")
      )
    }
    XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "preserve")
  }

  private func makeRunner() -> CommandRunner {
    CommandRunner(
      languageModel: FakeLanguageModel(),
      transcriber: FakeTranscriber(
        result: TranscriptionResult(text: "new", languageIdentifier: "en-US")),
      synthesizer: FakeSynthesizer())
  }

  private func makeFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
  }

  private func makeFile(_ folder: URL, name: String, text: String) throws -> URL {
    let url = folder.appendingPathComponent(name)
    try Data(text.utf8).write(to: url)
    return url
  }
}
