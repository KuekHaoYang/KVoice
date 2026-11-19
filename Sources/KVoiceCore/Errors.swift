import Foundation

public enum KVoiceError: LocalizedError, Equatable {
  case invalidArguments(String)
  case invalidPath(String)
  case missingInput(URL)
  case unsupportedOutput(String)
  case outputExists(URL)
  case emptyText
  case unsupportedLanguage(String)
  case noLanguageAvailable
  case modelUnavailable(String)
  case invalidModelResponse(String)
  case audioProcessing(String)

  public var errorDescription: String? {
    switch self {
    case .invalidArguments(let message): return message
    case .invalidPath(let path): return "Paths must be absolute. Invalid path: \(path)"
    case .missingInput(let url): return "Input file does not exist or is not readable: \(url.path)"
    case .unsupportedOutput(let message): return message
    case .outputExists(let url):
      return "Output already exists: \(url.path). Choose another path or pass --force."
    case .emptyText: return "Input text is empty."
    case .unsupportedLanguage(let language):
      return
        "The requested language is not supported or its speech assets are unavailable: \(language)"
    case .noLanguageAvailable:
      return "No supported speech language or voice is available on this Mac."
    case .modelUnavailable(let message): return "Apple Foundation Models is unavailable: \(message)"
    case .invalidModelResponse(let message):
      return "Apple Foundation Models returned an unusable response: \(message)"
    case .audioProcessing(let message): return "Audio processing failed: \(message)"
    }
  }
}
