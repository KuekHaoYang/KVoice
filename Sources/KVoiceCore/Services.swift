import Foundation

public protocol LanguageModeling: Sendable {
  func optimize(_ text: String, purpose: OptimizationPurpose) async throws -> String
  func detectLanguage(in text: String, candidates: [String]) async throws -> String
  func locate(_ sourceText: String, within referenceText: String) async throws -> ModelLocation
}

public protocol SpeechRecognizing: Sendable {
  func supportedLanguageIdentifiers() async throws -> [String]
  func installedLanguageIdentifiers() async throws -> [String]
  func preferredLanguageIdentifier() async throws -> String
  func transcribe(audioURL: URL, languageIdentifier: String, includeTimestamps: Bool) async throws
    -> TranscriptionResult
}

public protocol SpeechSynthesizing: Sendable {
  func availableLanguageIdentifiers() async -> [String]
  func availableVoices() async -> [SpeechVoice]
  func synthesize(
    _ text: String,
    to outputURL: URL,
    languageIdentifier: String,
    replaceExisting: Bool
  ) async throws
  func synthesize(
    _ text: String,
    to outputURL: URL,
    languageIdentifier: String,
    voiceIdentifier: String?,
    rate: Float?,
    replaceExisting: Bool
  ) async throws
}

extension SpeechSynthesizing {
  public func availableVoices() async -> [SpeechVoice] {
    let languages = await availableLanguageIdentifiers()
    return languages.map {
      SpeechVoice(identifier: $0, name: $0, languageIdentifier: $0, quality: "unknown")
    }
  }

  public func synthesize(
    _ text: String,
    to outputURL: URL,
    languageIdentifier: String,
    voiceIdentifier: String?,
    rate: Float?,
    replaceExisting: Bool
  ) async throws {
    try await synthesize(
      text, to: outputURL, languageIdentifier: languageIdentifier,
      replaceExisting: replaceExisting)
  }
}
