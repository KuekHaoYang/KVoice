import Foundation
import XCTest

@testable import KVoiceCore

final class CommandRunnerTests: XCTestCase {
  func testTranscriptionOptimizesByDefaultAndWritesText() async throws {
    let folder = try makeFolder()
    let input = try makeFile(folder, name: "input.wav", text: "audio")
    let output = folder.appendingPathComponent("transcript.txt")
    let model = FakeLanguageModel(optimizedText: "Hello there.")
    let transcriber = FakeTranscriber(
      result: TranscriptionResult(text: "hello there", languageIdentifier: "en-US"))
    let runner = CommandRunner(
      languageModel: model, transcriber: transcriber, synthesizer: FakeSynthesizer())

    try await runner.run(
      .transcribe(
        input: input, output: output, language: .explicit("en-US"), timestamps: false,
        optimize: true, force: false))

    XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "Hello there.\n")
    let optimizationCount = await model.optimizationCount()
    XCTAssertEqual(optimizationCount, 1)
  }

  func testNoOptimizePreservesRawTranscription() async throws {
    let folder = try makeFolder()
    let input = try makeFile(folder, name: "input.wav", text: "audio")
    let output = folder.appendingPathComponent("transcript.txt")
    let model = FakeLanguageModel(optimizedText: "changed")
    let transcriber = FakeTranscriber(
      result: TranscriptionResult(text: "raw transcript", languageIdentifier: "en-US"))
    let runner = CommandRunner(
      languageModel: model, transcriber: transcriber, synthesizer: FakeSynthesizer())

    try await runner.run(
      .transcribe(
        input: input, output: output, language: .explicit("en-US"), timestamps: false,
        optimize: false, force: false))

    XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "raw transcript\n")
    let optimizationCount = await model.optimizationCount()
    XCTAssertEqual(optimizationCount, 0)
  }

  func testAutomaticTranscriptionUsesFoundationModelLanguageDetectionAndCanRepeat() async throws {
    let folder = try makeFolder()
    let input = try makeFile(folder, name: "input.wav", text: "audio")
    let output = folder.appendingPathComponent("transcript.txt")
    let model = FakeLanguageModel(optimizedText: "Halo.", detectedLanguage: "ms-MY")
    let transcriber = FakeTranscriber(
      result: TranscriptionResult(text: "halo", languageIdentifier: "en-US"),
      supportedLanguages: ["en-US", "ms-MY", "fr-FR"],
      installedLanguages: ["en-US", "ms-MY"])
    let runner = CommandRunner(
      languageModel: model, transcriber: transcriber, synthesizer: FakeSynthesizer())

    try await runner.run(
      .transcribe(
        input: input, output: output, language: .automatic, timestamps: false, optimize: false,
        force: false))

    let languages = await transcriber.requestedLanguages()
    XCTAssertEqual(languages, ["en-US", "ms-MY"])
    let candidates = await model.languageDetectionCandidates()
    XCTAssertEqual(candidates, [["en-US", "ms-MY"]])
    XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "halo\n")
  }

  func testTimestampOutputIncludesTimedSegmentsAndRawText() async throws {
    let folder = try makeFolder()
    let input = try makeFile(folder, name: "input.wav", text: "audio")
    let output = folder.appendingPathComponent("transcript.json")
    let segment = TimedSegment(text: "hello", startSeconds: 0.25, endSeconds: 0.8)
    let runner = CommandRunner(
      languageModel: FakeLanguageModel(optimizedText: "Hello."),
      transcriber: FakeTranscriber(
        result: TranscriptionResult(text: "hello", languageIdentifier: "en-US", segments: [segment])
      ),
      synthesizer: FakeSynthesizer()
    )

    try await runner.run(
      .transcribe(
        input: input, output: output, language: .explicit("en-US"), timestamps: true,
        optimize: true, force: false))

    let document = try JSONDecoder().decode(
      TranscriptionDocument.self, from: Data(contentsOf: output))
    XCTAssertEqual(document.transcript, "hello")
    XCTAssertEqual(document.optimizedTranscript, "Hello.")
    XCTAssertEqual(document.segments, [segment])
  }

  func testSpeakDetectsLanguageOptimizesAndSynthesizes() async throws {
    let folder = try makeFolder()
    let output = folder.appendingPathComponent("speech.wav")
    let model = FakeLanguageModel(optimizedText: "Hello.", detectedLanguage: "en-US")
    let synthesizer = FakeSynthesizer(languages: ["en-US", "ms-MY"])
    let runner = CommandRunner(
      languageModel: model, transcriber: FakeTranscriber(), synthesizer: synthesizer)

    try await runner.run(
      .speak(
        input: .inline("hello"), output: output, language: .automatic, optimize: true, force: false)
    )

    XCTAssertEqual(try Data(contentsOf: output), Data("audio:en-US:Hello.".utf8))
    let optimizationCount = await model.optimizationCount()
    let selectedLanguage = await synthesizer.lastLanguage()
    XCTAssertEqual(optimizationCount, 1)
    XCTAssertEqual(selectedLanguage, "en-US")
  }

  func testSpeakReadsTextFileAndSkipsOptimizationWhenRequested() async throws {
    let folder = try makeFolder()
    let input = try makeFile(folder, name: "text.txt", text: "Original text.")
    let output = folder.appendingPathComponent("speech.wav")
    let model = FakeLanguageModel()
    let synthesizer = FakeSynthesizer(languages: ["en-US"])
    let runner = CommandRunner(
      languageModel: model, transcriber: FakeTranscriber(), synthesizer: synthesizer)

    try await runner.run(
      .speak(
        input: .file(input), output: output, language: .explicit("en-US"), optimize: false,
        force: false))

    XCTAssertEqual(try Data(contentsOf: output), Data("audio:en-US:Original text.".utf8))
    let optimizationCount = await model.optimizationCount()
    XCTAssertEqual(optimizationCount, 0)
  }

  func testSpeakRejectsAnUnavailableExplicitLocaleInsteadOfChangingRegion() async throws {
    let folder = try makeFolder()
    let output = folder.appendingPathComponent("speech.wav")
    let runner = CommandRunner(
      languageModel: FakeLanguageModel(), transcriber: FakeTranscriber(),
      synthesizer: FakeSynthesizer(languages: ["en-US"]))

    do {
      try await runner.run(
        .speak(
          input: .inline("hello"), output: output, language: .explicit("en-GB"), optimize: false,
          force: false))
      XCTFail("Expected unavailable region to be rejected")
    } catch let error as KVoiceError {
      XCTAssertEqual(error, .unsupportedLanguage("en-GB"))
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
  }

  func testLocateTextSourceUsesOriginalTextWithoutOptimization() async throws {
    let folder = try makeFolder()
    let reference = try makeFile(folder, name: "reference.txt", text: "A phrase appears here.")
    let source = try makeFile(folder, name: "source.txt", text: "A phrase")
    let output = folder.appendingPathComponent("location.json")
    let match = ModelLocation(found: true, excerpt: "A phrase", startUTF16: 0, lengthUTF16: 8)
    let model = FakeLanguageModel(location: match)
    let runner = CommandRunner(
      languageModel: model, transcriber: FakeTranscriber(), synthesizer: FakeSynthesizer())

    try await runner.run(
      .locate(
        reference: reference, sourceText: source, audio: nil, output: output,
        language: .automatic, optimize: true, force: false))

    let document = try JSONDecoder().decode(LocateDocument.self, from: Data(contentsOf: output))
    XCTAssertEqual(document.originalSourceText, "A phrase")
    XCTAssertEqual(document.processedSourceText, "A phrase")
    XCTAssertNil(document.language)
    let optimizationCount = await model.optimizationCount()
    XCTAssertEqual(optimizationCount, 0)
  }

  func testLocateTranscribesOptimizesAndWritesVerifiedJSONShape() async throws {
    let folder = try makeFolder()
    let reference = try makeFile(folder, name: "reference.txt", text: "alpha hello there omega")
    let input = try makeFile(folder, name: "input.wav", text: "audio")
    let output = folder.appendingPathComponent("location.json")
    let location = ModelLocation(
      found: true, excerpt: "hello there", startUTF16: 6, lengthUTF16: 11)
    let model = FakeLanguageModel(optimizedText: "hello there", location: location)
    let transcriber = FakeTranscriber(
      result: TranscriptionResult(text: "hello there", languageIdentifier: "en-US"))
    let runner = CommandRunner(
      languageModel: model, transcriber: transcriber, synthesizer: FakeSynthesizer())

    try await runner.run(
      .locate(
        reference: reference, sourceText: nil, audio: input, output: output,
        language: .explicit("en-US"), optimize: true, force: false))

    let document = try JSONDecoder().decode(LocateDocument.self, from: Data(contentsOf: output))
    XCTAssertEqual(document.originalSourceText, "hello there")
    XCTAssertEqual(document.processedSourceText, "hello there")
    XCTAssertEqual(document.language, "en-US")
    XCTAssertEqual(document.location, location)
    let locationCount = await model.locationCount()
    XCTAssertEqual(locationCount, 1)
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
