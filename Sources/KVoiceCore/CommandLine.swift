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
    case "list": return try parseList(Array(arguments.dropFirst()))
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
    let inputValue = options.takeValue("--input")
    let inline = options.takeValue("--text")
    guard (inputValue != nil) != (inline != nil) else {
      throw KVoiceError.invalidArguments(
        "speak requires exactly one of --input <text-path|-> or --text <text>.")
    }
    let input = try parseTextInput(inputValue, inline: inline)
    let output = try options.requiredPath("--output")
    let language = try options.language()
    let optimize = !options.takeFlag("--no-optimize")
    let voiceName = try options.nonEmptyValue("--voice")
    let rate = try options.rate()
    let sanitizeMarkdown = options.takeFlag("--sanitize-markdown")
    let stripMarkdownAlias = options.takeFlag("--strip-markdown")
    guard !(sanitizeMarkdown && stripMarkdownAlias) else {
      throw KVoiceError.invalidArguments(
        "Choose either --sanitize-markdown or its alias --strip-markdown, not both.")
    }
    let stripMarkdown = sanitizeMarkdown || stripMarkdownAlias
    let force = options.takeFlag("--force")
    try options.requireEmpty()
    if case .directory(let inputDirectory) = input {
      try FileValidation.validateOutputDirectory(output)
      try FileValidation.requireDirectoryDistinct(output, from: inputDirectory)
    } else {
      try validateOutput(output, extension: "wav")
    }
    if voiceName == nil, rate == nil, !stripMarkdown {
      switch input {
      case .file, .inline:
        return .speak(
          input: input, output: output, language: language, optimize: optimize, force: force)
      case .directory, .standardInput: break
      }
    }
    return .speakConfigured(
      input: input, output: output, language: language, optimize: optimize, force: force,
      voiceName: voiceName, rate: rate, sanitizeMarkdown: stripMarkdown)
  }

  private static func parseTextInput(_ path: String?, inline: String?) throws -> TextInput {
    guard let path else { return .inline(inline ?? "") }
    guard !path.isEmpty else { throw KVoiceError.invalidPath(path) }
    if path == "-" { return .standardInput }
    let url = FileValidation.resolvePath(path)
    if FileValidation.isDirectory(url) {
      try FileValidation.validateInputDirectory(url)
      return .directory(url)
    }
    try FileValidation.validateInput(url)
    return .file(url)
  }

  private static func parseLocate(_ arguments: [String]) throws -> KVoiceCommand {
    var options = try OptionValues(arguments)
    let reference = try options.requiredPath("--reference")
    try FileValidation.validateInput(reference)
    let sourceText = try options.optionalPath("--source-text")
    let audio = try options.optionalPath("--audio")
    guard (sourceText != nil) != (audio != nil) else {
      throw KVoiceError.invalidArguments(
        "locate requires exactly one of --source-text <path> or --audio <path>.")
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

  private static func parseList(_ arguments: [String]) throws -> KVoiceCommand {
    guard let name = arguments.first else {
      throw KVoiceError.invalidArguments("list requires one of: languages, voices.")
    }
    let kind: ResourceList
    switch name {
    case "languages": kind = .languages
    case "voices": kind = .voices
    default: throw KVoiceError.invalidArguments("Unknown resource list '\(name)'.")
    }
    var options = try OptionValues(Array(arguments.dropFirst()))
    let output = try options.requiredPath("--output")
    let force = options.takeFlag("--force")
    try options.requireEmpty()
    try FileValidation.validateOutput(output, force: force)
    return .listResources(kind: kind, output: output, force: force)
  }

  private static func validateOutput(_ url: URL, extension expected: String) throws {
    guard url.pathExtension.lowercased() == expected else {
      throw KVoiceError.unsupportedOutput("Output must use the .\(expected) extension: \(url.path)")
    }
    try FileValidation.validateOutput(url, force: false)
  }
}
