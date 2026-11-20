import Foundation

@testable import KVoiceCore

actor FakeLanguageModel: LanguageModeling {
  private let optimizedText: String
  private let detectedLanguage: String
  private let locationResult: ModelLocation
  private var detectionCandidates: [[String]] = []
  private var optimizations = 0
  private var locations = 0

  init(
    optimizedText: String = "optimized", detectedLanguage: String = "en-US",
    location: ModelLocation = ModelLocation(found: false)
  ) {
    self.optimizedText = optimizedText
    self.detectedLanguage = detectedLanguage
    self.locationResult = location
  }

  func optimize(_ text: String, purpose: OptimizationPurpose) async throws -> String {
    optimizations += 1
    return optimizedText
  }

  func detectLanguage(in text: String, candidates: [String]) async throws -> String {
    detectionCandidates.append(candidates)
    return detectedLanguage
  }

  func locate(_ sourceText: String, within referenceText: String) async throws -> ModelLocation {
    locations += 1
    return locationResult
  }

  func optimizationCount() -> Int { optimizations }
  func locationCount() -> Int { locations }
  func languageDetectionCandidates() -> [[String]] { detectionCandidates }
}

actor FakeTranscriber: SpeechRecognizing {
  private let result: TranscriptionResult
  private let supportedLanguages: [String]
  private let installedLanguages: [String]
  private var languages: [String] = []

  init(
    result: TranscriptionResult = TranscriptionResult(text: "", languageIdentifier: "en-US"),
    supportedLanguages: [String] = ["en-US", "ms-MY", "fr-FR"],
    installedLanguages: [String] = ["en-US", "ms-MY"]
  ) {
    self.result = result
    self.supportedLanguages = supportedLanguages
    self.installedLanguages = installedLanguages
  }

  func supportedLanguageIdentifiers() async throws -> [String] { supportedLanguages }
  func installedLanguageIdentifiers() async throws -> [String] { installedLanguages }
  func preferredLanguageIdentifier() async throws -> String { "en-US" }

  func transcribe(audioURL: URL, languageIdentifier: String, includeTimestamps: Bool) async throws
    -> TranscriptionResult
  {
    languages.append(languageIdentifier)
    return TranscriptionResult(
      text: result.text, languageIdentifier: languageIdentifier, segments: result.segments)
  }

  func requestedLanguages() -> [String] { languages }
}

actor FakeSynthesizer: SpeechSynthesizing {
  private let languages: [String]
  private let voices: [SpeechVoice]
  private var language: String?
  private var voiceIdentifier: String?
  private var rate: Float?
  private var speechText: String?

  init(languages: [String] = ["en-US"], voices: [SpeechVoice]? = nil) {
    self.languages = languages
    self.voices =
      voices
      ?? languages.map {
        SpeechVoice(identifier: $0, name: $0, languageIdentifier: $0, quality: "unknown")
      }
  }

  func availableLanguageIdentifiers() async -> [String] { languages }
  func availableVoices() async -> [SpeechVoice] { voices }

  func synthesize(
    _ text: String,
    to outputURL: URL,
    languageIdentifier: String,
    replaceExisting: Bool
  ) async throws {
    language = languageIdentifier
    try Data("audio:\(languageIdentifier):\(text)".utf8).write(to: outputURL)
  }

  func synthesize(
    _ text: String,
    to outputURL: URL,
    languageIdentifier: String,
    voiceIdentifier: String?,
    rate: Float?,
    replaceExisting: Bool
  ) async throws {
    language = languageIdentifier
    self.voiceIdentifier = voiceIdentifier
    self.rate = rate
    speechText = text
    try Data("audio:\(languageIdentifier):\(text)".utf8).write(to: outputURL)
  }

  func lastLanguage() -> String? { language }
  func lastVoiceIdentifier() -> String? { voiceIdentifier }
  func lastRate() -> Float? { rate }
  func lastSpeechText() -> String? { speechText }
}
