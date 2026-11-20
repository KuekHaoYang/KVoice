import Foundation

public enum KVoiceError: LocalizedError, Equatable {
  case invalidArguments(String)
  case invalidPath(String)
  case missingInput(URL)
  case unsupportedOutput(String)
  case outputExists(URL)
  case emptyText
  case unsupportedLanguage(String)
  case unsupportedVoice(String)
  case invalidSpeechRate(String)
  case invalidText(String)
  case noInputFiles(URL)
  case noLanguageAvailable
  case modelUnavailable(String)
  case invalidModelResponse(String)
  case audioProcessing(String)

  public var errorDescription: String? {
    switch self {
    case .invalidArguments(let message): return message
    case .invalidPath(let path): return "Invalid file path: \(path)"
    case .missingInput(let url): return "Input file does not exist or is not readable: \(url.path)"
    case .unsupportedOutput(let message): return message
    case .outputExists(let url):
      return "Output already exists: \(url.path)."
    case .emptyText: return "Input text is empty."
    case .unsupportedLanguage(let language):
      return
        "The requested language is not supported or its speech assets are unavailable: \(language)"
    case .unsupportedVoice(let name): return "No available speech voice matches '\(name)'."
    case .invalidSpeechRate(let value):
      return "Invalid speech rate '\(value)'. Use a decimal within Apple's supported rate range."
    case .invalidText(let message): return message
    case .noInputFiles(let url): return "No regular input files found in directory: \(url.path)"
    case .noLanguageAvailable:
      return "No supported speech language or voice is available on this Mac."
    case .modelUnavailable(let message): return "Apple Foundation Models is unavailable: \(message)"
    case .invalidModelResponse(let message):
      return "Apple Foundation Models returned an unusable response: \(message)"
    case .audioProcessing(let message): return "Audio processing failed: \(message)"
    }
  }
}
