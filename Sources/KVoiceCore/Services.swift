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
  func synthesize(
    _ text: String,
    to outputURL: URL,
    languageIdentifier: String,
    replaceExisting: Bool
  ) async throws
}
