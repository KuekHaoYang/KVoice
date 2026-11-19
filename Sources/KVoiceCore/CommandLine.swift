import Foundation

public enum KVoiceCommandLine {
  public static func parse(_ arguments: [String]) throws -> KVoiceCommand {
    guard let first = arguments.first else {
      throw KVoiceError.invalidArguments("Missing command.\n\n\(HelpText.usage)")
    }
    if first == "--help" || first == "-h" || first == "help" {
      let (output, force) = try parseOutputOnly(Array(arguments.dropFirst()))
      return .help(output: output, force: force)
    }
    if first == "--version" || first == "version" {
      let (output, force) = try parseOutputOnly(Array(arguments.dropFirst()))
      return .version(output: output, force: force)
    }

    switch first {
    case "transcribe": return try parseTranscribe(Array(arguments.dropFirst()))
    case "speak": return try parseSpeak(Array(arguments.dropFirst()))
    case "locate": return try parseLocate(Array(arguments.dropFirst()))
    default: throw KVoiceError.invalidArguments("Unknown command '\(first)'.\n\n\(HelpText.usage)")
    }
  }

  private static func parseOutputOnly(_ arguments: [String]) throws -> (URL, Bool) {
    var options = try OptionValues(arguments)
    let output = try options.requiredPath("--output")
    let force = options.takeFlag("--force")
    try options.requireEmpty()
    try FileValidation.validateOutput(output, force: force)
    return (output, force)
  }

  private static func parseTranscribe(_ arguments: [String]) throws -> KVoiceCommand {
    var options = try OptionValues(arguments)
    let input = try options.requiredPath("--input")
    let output = try options.requiredPath("--output")
    let language = try options.language()
    let timestamps = options.takeFlag("--timestamps")
    let optimize = !options.takeFlag("--no-optimize")
    let force = options.takeFlag("--force")
    try options.requireEmpty()
    try validateOutput(output, extension: timestamps ? "json" : "txt")
    return .transcribe(
      input: input, output: output, language: language, timestamps: timestamps, optimize: optimize,
      force: force)
  }

  private static func parseSpeak(_ arguments: [String]) throws -> KVoiceCommand {
    var options = try OptionValues(arguments)
    let inputPath = try options.optionalPath("--input")
    let inline = options.takeValue("--text")
    guard (inputPath != nil) != (inline != nil) else {
      throw KVoiceError.invalidArguments(
        "speak requires exactly one of --input <absolute-text-path> or --text <text>.")
    }
    if let inputPath { try FileValidation.validateInput(inputPath) }
    let input: TextInput = inputPath.map(TextInput.file) ?? .inline(inline ?? "")
    let output = try options.requiredPath("--output")
    let language = try options.language()
    let optimize = !options.takeFlag("--no-optimize")
    let force = options.takeFlag("--force")
    try options.requireEmpty()
    try validateOutput(output, extension: "wav")
    return .speak(
      input: input, output: output, language: language, optimize: optimize, force: force)
  }

  private static func parseLocate(_ arguments: [String]) throws -> KVoiceCommand {
    var options = try OptionValues(arguments)
    let reference = try options.requiredPath("--reference")
    try FileValidation.validateInput(reference)
    let sourceText = try options.optionalPath("--source-text")
    let audio = try options.optionalPath("--audio")
    guard (sourceText != nil) != (audio != nil) else {
      throw KVoiceError.invalidArguments(
        "locate requires exactly one of --source-text <absolute-path> or --audio <absolute-audio-path>."
      )
    }
    if let sourceText { try FileValidation.validateInput(sourceText) }
    let output = try options.requiredPath("--output")
    let language = try options.language()
    if sourceText != nil, case .explicit = language {
      throw KVoiceError.invalidArguments(
        "--language applies only when --audio is used with locate.")
    }
    let optimize = !options.takeFlag("--no-optimize")
    let force = options.takeFlag("--force")
    try options.requireEmpty()
    try validateOutput(output, extension: "json")
    return .locate(
      reference: reference, sourceText: sourceText, audio: audio, output: output,
      language: language, optimize: optimize, force: force)
  }

  private static func validateOutput(_ url: URL, extension expected: String) throws {
    guard url.pathExtension.lowercased() == expected else {
      throw KVoiceError.unsupportedOutput("Output must use the .\(expected) extension: \(url.path)")
    }
  }
}

private struct OptionValues {
  private var values: [String: String] = [:]
  private var flags: Set<String> = []

  init(_ arguments: [String]) throws {
    var index = 0
    while index < arguments.count {
      let option = arguments[index]
      if ["--timestamps", "--no-optimize", "--force"].contains(option) {
        guard !flags.contains(option) else {
          throw KVoiceError.invalidArguments("Repeated option: \(option)")
        }
        flags.insert(option)
        index += 1
      } else if option.hasPrefix("--") {
        guard index + 1 < arguments.count,
          option == "--text" || !arguments[index + 1].hasPrefix("--")
        else {
          throw KVoiceError.invalidArguments("Missing value for \(option)")
        }
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
    let url = URL(fileURLWithPath: value)
    guard value.hasPrefix("/"), url.isFileURL else { throw KVoiceError.invalidPath(value) }
    return url.standardizedFileURL
  }

  mutating func optionalPath(_ option: String) throws -> URL? {
    guard values[option] != nil else { return nil }
    return try requiredPath(option)
  }

  mutating func language() throws -> LanguageSelection {
    guard let value = takeValue("--language") else { return .automatic }
    return value.lowercased() == "auto" ? .automatic : .explicit(value)
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

public enum FileValidation {
  public static func validateInput(_ url: URL) throws {
    guard url.isFileURL, url.path.hasPrefix("/") else { throw KVoiceError.invalidPath(url.path) }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
      !isDirectory.boolValue,
      FileManager.default.isReadableFile(atPath: url.path)
    else { throw KVoiceError.missingInput(url) }
  }

  public static func validateOutput(_ url: URL, force: Bool) throws {
    guard url.isFileURL, url.path.hasPrefix("/") else { throw KVoiceError.invalidPath(url.path) }
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
      guard !isDirectory.boolValue else {
        throw KVoiceError.unsupportedOutput("Output must be a file, not a directory: \(url.path)")
      }
      if !force { throw KVoiceError.outputExists(url) }
    }
  }

  public static func requireDistinct(_ output: URL, from inputs: [URL]) throws {
    let resolvedOutput = output.standardizedFileURL.resolvingSymlinksInPath()
    guard
      !inputs.contains(where: { $0.standardizedFileURL.resolvingSymlinksInPath() == resolvedOutput }
      )
    else {
      throw KVoiceError.invalidArguments(
        "The output path must differ from every input path: \(output.path)")
    }
  }
}
