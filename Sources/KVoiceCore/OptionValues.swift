import AVFoundation
import Foundation

struct OptionValues {
  private var values: [String: String] = [:]
  private var flags: Set<String> = []

  init(_ arguments: [String]) throws {
    var index = 0
    while index < arguments.count {
      let option = arguments[index]
      if [
        "--timestamps", "--no-optimize", "--force", "--sanitize-markdown", "--strip-markdown",
      ].contains(option) {
        guard !flags.contains(option) else {
          throw KVoiceError.invalidArguments("Repeated option: \(option)")
        }
        flags.insert(option)
        index += 1
      } else if option.hasPrefix("--") {
        guard index + 1 < arguments.count,
          option == "--text" || !arguments[index + 1].hasPrefix("--")
        else { throw KVoiceError.invalidArguments("Missing value for \(option)") }
        guard values[option] == nil else {
          throw KVoiceError.invalidArguments("Repeated option: \(option)")
        }
        values[option] = arguments[index + 1]
        index += 2
      } else {
        throw KVoiceError.invalidArguments("Unexpected argument: \(option)")
      }
    }
  }

  mutating func requiredPath(_ option: String) throws -> URL {
    guard let value = takeValue(option) else {
      throw KVoiceError.invalidArguments("Missing required option \(option)")
    }
    guard !value.isEmpty else { throw KVoiceError.invalidPath(value) }
    return FileValidation.resolvePath(value)
  }

  mutating func optionalPath(_ option: String) throws -> URL? {
    guard values[option] != nil else { return nil }
    return try requiredPath(option)
  }

  mutating func language() throws -> LanguageSelection {
    guard let value = takeValue("--language") else { return .automatic }
    return value.lowercased() == "auto" ? .automatic : .explicit(value)
  }

  mutating func nonEmptyValue(_ option: String) throws -> String? {
    guard let value = takeValue(option) else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw KVoiceError.invalidArguments("\(option) cannot be empty.")
    }
    return trimmed
  }

  mutating func rate() throws -> Float? {
    guard let value = takeValue("--rate") else { return nil }
    guard let rate = Float(value), rate.isFinite,
      rate >= AVSpeechUtteranceMinimumSpeechRate,
      rate <= AVSpeechUtteranceMaximumSpeechRate
    else { throw KVoiceError.invalidSpeechRate(value) }
    return rate
  }

  mutating func takeValue(_ option: String) -> String? { values.removeValue(forKey: option) }
  mutating func takeFlag(_ option: String) -> Bool { flags.remove(option) != nil }

  func requireEmpty() throws {
    guard values.isEmpty, flags.isEmpty else {
      let unknown = (Array(values.keys) + Array(flags)).sorted().joined(separator: ", ")
      throw KVoiceError.invalidArguments("Unknown or unsupported option(s): \(unknown)")
    }
  }
}
