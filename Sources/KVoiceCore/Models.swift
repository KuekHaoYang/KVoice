import Foundation

public enum LanguageSelection: Equatable, Sendable {
  case automatic
  case explicit(String)
}

public enum TextInput: Equatable, Sendable {
  case file(URL)
  case inline(String)
}

public enum OptimizationPurpose: String, Sendable {
  case transcription
  case speech
}

public struct TimedSegment: Codable, Equatable, Sendable {
  public let text: String
  public let startSeconds: Double
  public let endSeconds: Double

  public init(text: String, startSeconds: Double, endSeconds: Double) {
    self.text = text
    self.startSeconds = startSeconds
    self.endSeconds = endSeconds
  }
}

public struct TranscriptionResult: Equatable, Sendable {
  public let text: String
  public let languageIdentifier: String
  public let segments: [TimedSegment]

  public init(text: String, languageIdentifier: String, segments: [TimedSegment] = []) {
    self.text = text
    self.languageIdentifier = languageIdentifier
    self.segments = segments
  }
}

public struct TranscriptionDocument: Codable, Equatable, Sendable {
  public let language: String
  public let transcript: String
  public let optimizedTranscript: String
  public let segments: [TimedSegment]

  public init(
    language: String, transcript: String, optimizedTranscript: String, segments: [TimedSegment]
  ) {
    self.language = language
    self.transcript = transcript
    self.optimizedTranscript = optimizedTranscript
    self.segments = segments
  }
}

public struct ModelLocation: Codable, Equatable, Sendable {
  public let found: Bool
  public let excerpt: String?
  public let startUTF16: Int?
  public let lengthUTF16: Int?

  public init(found: Bool, excerpt: String? = nil, startUTF16: Int? = nil, lengthUTF16: Int? = nil)
  {
    self.found = found
    self.excerpt = excerpt
    self.startUTF16 = startUTF16
    self.lengthUTF16 = lengthUTF16
  }
}

public struct LocateDocument: Codable, Equatable, Sendable {
  public let originalSourceText: String
  public let processedSourceText: String
  public let language: String?
  public let location: ModelLocation

  public init(
    originalSourceText: String, processedSourceText: String, language: String?,
    location: ModelLocation
  ) {
    self.originalSourceText = originalSourceText
    self.processedSourceText = processedSourceText
    self.language = language
    self.location = location
  }
}

public enum KVoiceCommand: Equatable, Sendable {
  case help(output: URL, force: Bool)
  case version(output: URL, force: Bool)
  case transcribe(
    input: URL, output: URL, language: LanguageSelection, timestamps: Bool, optimize: Bool,
    force: Bool)
  case speak(
    input: TextInput, output: URL, language: LanguageSelection, optimize: Bool, force: Bool)
  case locate(
    reference: URL, sourceText: URL?, audio: URL?, output: URL, language: LanguageSelection,
    optimize: Bool, force: Bool)
}
