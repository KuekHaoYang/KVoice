import Foundation
import XCTest

@testable import KVoiceCore

final class SpeechOutputFeatureTests: XCTestCase {
  func testSanitizesMarkdownSelectsNamedVoiceAndAppliesRate() async throws {
    let folder = try makeFolder()
    let output = folder.appendingPathComponent("speech.wav")
    let voice = SpeechVoice(
      identifier: "com.apple.voice.samantha", name: "Samantha", languageIdentifier: "en-US",
      quality: "premium")
    let synthesizer = FakeSynthesizer(languages: ["en-US"], voices: [voice])
    let runner = CommandRunner(
      languageModel: FakeLanguageModel(), transcriber: FakeTranscriber(), synthesizer: synthesizer)

    try await runner.run(
      .speakConfigured(
        input: .inline("# Hello **there**"), output: output, language: .automatic,
        optimize: false, force: false, voiceName: "samantha", rate: 0.57,
        sanitizeMarkdown: true))

    let selectedLanguage = await synthesizer.lastLanguage()
    let selectedVoice = await synthesizer.lastVoiceIdentifier()
    let selectedRate = await synthesizer.lastRate()
    let speechText = await synthesizer.lastSpeechText()
    XCTAssertEqual(selectedLanguage, "en-US")
    XCTAssertEqual(selectedVoice, voice.identifier)
    XCTAssertEqual(selectedRate, 0.57)
    XCTAssertEqual(speechText, "Hello there")
    XCTAssertEqual(try Data(contentsOf: output), Data("audio:en-US:Hello there".utf8))
  }

  func testReadsInjectedStandardInput() async throws {
    let folder = try makeFolder()
    let output = folder.appendingPathComponent("speech.wav")
    let synthesizer = FakeSynthesizer(languages: ["en-US"])
    let runner = CommandRunner(
      languageModel: FakeLanguageModel(), transcriber: FakeTranscriber(), synthesizer: synthesizer,
      standardInputReader: { "Piped text." })

    try await runner.run(
      .speakConfigured(
        input: .standardInput, output: output, language: .explicit("en-US"), optimize: false,
        force: false, voiceName: nil, rate: nil, sanitizeMarkdown: false))

    let speechText = await synthesizer.lastSpeechText()
    XCTAssertEqual(speechText, "Piped text.")
  }

  func testRecursivelyConvertsDirectoryFilesAndPreservesStructure() async throws {
    let folder = try makeFolder()
    let input = folder.appendingPathComponent("notes", isDirectory: true)
    let output = folder.appendingPathComponent("audio", isDirectory: true)
    try FileManager.default.createDirectory(
      at: input.appendingPathComponent("nested", isDirectory: true),
      withIntermediateDirectories: true)
    try Data("root".utf8).write(to: input.appendingPathComponent("root.txt"))
    try Data("child".utf8).write(to: input.appendingPathComponent("nested/child.md"))
    let runner = CommandRunner(
      languageModel: FakeLanguageModel(), transcriber: FakeTranscriber(),
      synthesizer: FakeSynthesizer(languages: ["en-US"]))

    let generated = try await runner.run(
      .speakConfigured(
        input: .directory(input), output: output, language: .explicit("en-US"), optimize: false,
        force: false, voiceName: nil, rate: nil, sanitizeMarkdown: false))

    XCTAssertEqual(
      Set(generated.map(\.path)),
      Set([
        output.appendingPathComponent("root.wav").path,
        output.appendingPathComponent("nested/child.wav").path,
      ]))
    XCTAssertEqual(
      try Data(contentsOf: output.appendingPathComponent("root.wav")),
      Data("audio:en-US:root".utf8))
    XCTAssertEqual(
      try Data(contentsOf: output.appendingPathComponent("nested/child.wav")),
      Data("audio:en-US:child".utf8))
  }

  func testListsVoiceAndLanguageResources() async throws {
    let folder = try makeFolder()
    let voicesOutput = folder.appendingPathComponent("voices.txt")
    let languagesOutput = folder.appendingPathComponent("languages.txt")
    let voice = SpeechVoice(
      identifier: "voice.samantha", name: "Samantha", languageIdentifier: "en-US",
      quality: "premium")
    let runner = CommandRunner(
      languageModel: FakeLanguageModel(), transcriber: FakeTranscriber(),
      synthesizer: FakeSynthesizer(languages: ["en-US"], voices: [voice]))

    try await runner.run(.listResources(kind: .voices, output: voicesOutput, force: false))
    try await runner.run(.listResources(kind: .languages, output: languagesOutput, force: false))

    XCTAssertEqual(
      try String(contentsOf: voicesOutput, encoding: .utf8),
      "Samantha\ten-US\tpremium\tvoice.samantha\n")
    let languages = try String(contentsOf: languagesOutput, encoding: .utf8)
    XCTAssertTrue(languages.contains("Speech recognition (installed):\n  en-US\n  ms-MY"))
    XCTAssertTrue(languages.contains("Speech recognition (supported, may need download):"))
    XCTAssertTrue(languages.contains("Speech synthesis (installed voices):\n  en-US"))
  }

  private func makeFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
  }
}
