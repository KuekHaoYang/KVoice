import Foundation

struct SpeechOutputRunner: Sendable {
  private let languageModel: any LanguageModeling
  private let synthesizer: any SpeechSynthesizing
  private let standardInputReader: @Sendable () throws -> String

  init(
    languageModel: any LanguageModeling,
    synthesizer: any SpeechSynthesizing,
    standardInputReader: @escaping @Sendable () throws -> String
  ) {
    self.languageModel = languageModel
    self.synthesizer = synthesizer
    self.standardInputReader = standardInputReader
  }

  func run(
    input: TextInput,
    output: URL,
    language: LanguageSelection,
    optimize: Bool,
    force: Bool,
    voiceName: String?,
    rate: Float?,
    stripMarkdown: Bool
  ) async throws -> [URL] {
    if case .directory(let inputDirectory) = input {
      return try await runDirectory(
        inputDirectory, outputDirectory: output, language: language, optimize: optimize,
        force: force, voiceName: voiceName, rate: rate, stripMarkdown: stripMarkdown)
    }
    let source = try readText(input)
    if case .file(let inputFile) = input {
      try FileValidation.requireDistinct(output, from: [inputFile])
    }
    let target = try FileValidation.uniqueOutputURL(output, force: force)
    if case .file(let inputFile) = input {
      try FileValidation.requireDistinct(target, from: [inputFile])
    }
    try FileValidation.validateOutput(target, force: force)
    try await synthesize(
      source, to: target, language: language, optimize: optimize, voiceName: voiceName,
      rate: rate, stripMarkdown: stripMarkdown, replaceExisting: force)
    return [target]
  }

  private func runDirectory(
    _ inputDirectory: URL,
    outputDirectory: URL,
    language: LanguageSelection,
    optimize: Bool,
    force: Bool,
    voiceName: String?,
    rate: Float?,
    stripMarkdown: Bool
  ) async throws -> [URL] {
    let inputFiles = try regularFiles(in: inputDirectory, excluding: outputDirectory)
    guard !inputFiles.isEmpty else { throw KVoiceError.noInputFiles(inputDirectory) }
    try FileManager.default.createDirectory(
      at: outputDirectory, withIntermediateDirectories: true)
    var outputs: [URL] = []
    var claimedPaths: Set<String> = []
    for (inputFile, relativePath) in inputFiles {
      var pathComponents = relativePath.split(separator: "/").map(String.init)
      let inputName = pathComponents.removeLast()
      let outputName =
        URL(fileURLWithPath: inputName)
        .deletingPathExtension().lastPathComponent + ".wav"
      pathComponents.append(outputName)
      let desiredName = pathComponents.joined(separator: "/")
      let desiredOutput = outputDirectory.appendingPathComponent(desiredName)
      let requestedPath = desiredOutput.standardizedFileURL.path
      let alreadyClaimed = claimedPaths.contains(requestedPath)
      let mayReplaceRequestedPath = force && !alreadyClaimed
      var target = try FileValidation.uniqueOutputURL(
        desiredOutput, force: mayReplaceRequestedPath)
      while claimedPaths.contains(target.standardizedFileURL.path) {
        target = try FileValidation.uniqueOutputURL(target, force: false)
      }
      let replaceExisting =
        force && target.standardizedFileURL == desiredOutput.standardizedFileURL
        && FileManager.default.fileExists(atPath: target.path)
      claimedPaths.insert(target.standardizedFileURL.path)
      try FileValidation.validateOutput(target, force: force)
      try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      try await synthesize(
        try readText(.file(inputFile)), to: target, language: language, optimize: optimize,
        voiceName: voiceName, rate: rate, stripMarkdown: stripMarkdown,
        replaceExisting: replaceExisting)
      outputs.append(target)
    }
    return outputs
  }

  private func synthesize(
    _ source: String,
    to output: URL,
    language: LanguageSelection,
    optimize: Bool,
    voiceName: String?,
    rate: Float?,
    stripMarkdown: Bool,
    replaceExisting: Bool
  ) async throws {
    let sourceText = stripMarkdown ? MarkdownSanitizer.plainText(source) : source
    let text = try TextProcessing.normalizedNonEmpty(sourceText)
    let optimized = optimize ? try await languageModel.optimize(text, purpose: .speech) : text
    let speechText = stripMarkdown ? MarkdownSanitizer.plainText(optimized) : optimized
    _ = try TextProcessing.normalizedNonEmpty(speechText)
    let voices = await synthesizer.availableVoices()
    guard !voices.isEmpty else { throw KVoiceError.noLanguageAvailable }
    let voice = try selectedVoice(named: voiceName, language: language, among: voices)
    let languageIdentifier = try await selectedLanguage(
      for: voice, selection: language, text: speechText, voices: voices)
    try await synthesizer.synthesize(
      speechText, to: output, languageIdentifier: languageIdentifier,
      voiceIdentifier: voice?.identifier, rate: rate, replaceExisting: replaceExisting)
  }

  private func selectedVoice(
    named name: String?, language: LanguageSelection, among voices: [SpeechVoice]
  ) throws -> SpeechVoice? {
    guard let name else { return nil }
    let named = voices.filter {
      $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame || $0.identifier == name
    }
    guard !named.isEmpty else { throw KVoiceError.unsupportedVoice(name) }
    let matches: [SpeechVoice]
    if case .explicit(let requested) = language {
      let resolvedLanguage = try LanguageResolver.resolve(
        requested, among: named.map(\.languageIdentifier))
      matches = named.filter {
        $0.languageIdentifier.caseInsensitiveCompare(resolvedLanguage) == .orderedSame
      }
    } else {
      matches = named
    }
    guard matches.count == 1, let selected = matches.first else {
      if matches.count > 1 {
        throw KVoiceError.invalidArguments(
          "Voice '\(name)' is ambiguous. Add --language to select its locale, or use its identifier."
        )
      }
      throw KVoiceError.unsupportedVoice(name)
    }
    return selected
  }

  private func selectedLanguage(
    for voice: SpeechVoice?, selection: LanguageSelection, text: String, voices: [SpeechVoice]
  ) async throws -> String {
    if let voice {
      if case .explicit(let requested) = selection {
        let resolved = try LanguageResolver.resolve(requested, among: [voice.languageIdentifier])
        guard resolved.caseInsensitiveCompare(voice.languageIdentifier) == .orderedSame else {
          throw KVoiceError.invalidArguments(
            "--voice '\(voice.name)' uses \(voice.languageIdentifier), which conflicts with --language \(requested)."
          )
        }
      }
      return voice.languageIdentifier
    }
    let languages = Array(Set(voices.map(\.languageIdentifier))).sorted()
    switch selection {
    case .explicit(let requested): return try LanguageResolver.resolve(requested, among: languages)
    case .automatic:
      return try LanguageResolver.resolve(
        await languageModel.detectLanguage(in: text, candidates: languages), among: languages)
    }
  }

  private func readText(_ input: TextInput) throws -> String {
    switch input {
    case .file(let url): return try String(contentsOf: url, encoding: .utf8)
    case .standardInput: return try standardInputReader()
    case .inline(let text): return text
    case .directory:
      throw KVoiceError.invalidArguments("Directory input requires batch processing.")
    }
  }

  private func regularFiles(in directory: URL, excluding outputDirectory: URL) throws -> [(
    URL, String
  )] {
    guard
      let enumerator = FileManager.default.enumerator(
        at: directory, includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsPackageDescendants])
    else { return [] }
    var files: [(URL, String)] = []
    let directoryPath = directory.standardizedFileURL.resolvingSymlinksInPath().path
    let directoryPrefix = directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/"
    let outputPath = outputDirectory.standardizedFileURL.resolvingSymlinksInPath().path
    let outputPrefix = outputPath.hasSuffix("/") ? outputPath : outputPath + "/"
    let outputIsInsideInput = outputPath.hasPrefix(directoryPrefix)
    for case let file as URL in enumerator {
      let filePath = file.standardizedFileURL.resolvingSymlinksInPath().path
      if filePath == outputPath {
        enumerator.skipDescendants()
        continue
      }
      if outputIsInsideInput && filePath.hasPrefix(outputPrefix) { continue }
      guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
        continue
      }
      guard filePath.hasPrefix(directoryPrefix) else { continue }
      let relativePath = String(filePath.dropFirst(directoryPrefix.count))
      files.append((file, relativePath))
    }
    return files.sorted {
      $0.1.localizedStandardCompare($1.1) == .orderedAscending
    }
  }
}
