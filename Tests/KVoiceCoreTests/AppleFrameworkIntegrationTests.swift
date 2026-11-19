import AVFoundation
import Foundation
import FoundationModels
import Speech
import XCTest

@testable import KVoiceCore

@available(macOS 26, *)
final class AppleFrameworkIntegrationTests: XCTestCase {
  func testFoundationModelCorrectionLanguageSelectionAndLocate() async throws {
    try skipUnlessEnabled()
    guard case .available = SystemLanguageModel.default.availability else {
      throw XCTSkip("Apple Foundation Models is unavailable on this Mac.")
    }
    let model = AppleFoundationModel()
    let optimized = try await model.optimize("hello from kvoice", purpose: .speech)
    let language = try await model.detectLanguage(in: optimized, candidates: ["en-US"])
    let location = try await model.locate(
      "hello from KVoice", within: "Welcome. Hello from KVoice today.")

    XCTAssertFalse(optimized.isEmpty)
    XCTAssertEqual(language, "en-US")
    XCTAssertTrue(location.found)
    XCTAssertNotNil(location.excerpt)
    let range = ("Welcome. Hello from KVoice today." as NSString)
      .range(of: location.excerpt ?? "")
    XCTAssertNotEqual(range.location, NSNotFound)
  }

  func testSpeechSynthesisAndSpeechAnalyzerRoundTrip() async throws {
    try skipUnlessEnabled()
    guard SpeechTranscriber.isAvailable else {
      throw XCTSkip("SpeechTranscriber is unavailable on this Mac.")
    }
    let installedLocales = await SpeechTranscriber.installedLocales
    guard
      let speechLocale = installedLocales.first(where: {
        $0.language.languageCode?.identifier == "en"
      })
    else {
      throw XCTSkip("Install an English SpeechTranscriber asset to run this integration check.")
    }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let audio = folder.appendingPathComponent("roundtrip.wav")
    let synthesizer = AppleSpeechSynthesizer()
    let voiceLanguage = await synthesizer.availableLanguageIdentifiers().first(where: {
      $0.hasPrefix("en")
    })
    guard let voiceLanguage else { throw XCTSkip("No English AVSpeech voice is installed.") }

    try await synthesizer.synthesize(
      "KVoice native speech integration test.", to: audio, languageIdentifier: voiceLanguage,
      replaceExisting: false)
    let result = try await AppleSpeechTranscriber().transcribe(
      audioURL: audio, languageIdentifier: speechLocale.identifier, includeTimestamps: true)

    XCTAssertGreaterThan(try Data(contentsOf: audio).count, 44)
    XCTAssertFalse(result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    XCTAssertEqual(
      result.languageIdentifier,
      TextProcessing.normalizedLanguageTag(speechLocale.identifier))
    XCTAssertFalse(result.segments.isEmpty)
    XCTAssertTrue(result.segments.allSatisfy { $0.startSeconds <= $0.endSeconds })
  }

  private func skipUnlessEnabled() throws {
    guard ProcessInfo.processInfo.environment["KVOICE_RUN_SYSTEM_TESTS"] == "1" else {
      throw XCTSkip("Set KVOICE_RUN_SYSTEM_TESTS=1 to run tests that load Apple system models.")
    }
  }
}
