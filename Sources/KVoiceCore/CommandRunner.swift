import Foundation

public struct CommandRunner: Sendable {
  private let languageModel: any LanguageModeling
  private let transcriber: any SpeechRecognizing
  private let synthesizer: any SpeechSynthesizing

  public init(
    languageModel: any LanguageModeling, transcriber: any SpeechRecognizing,
    synthesizer: any SpeechSynthesizing
  ) {
    self.languageModel = languageModel
    self.transcriber = transcriber
    self.synthesizer = synthesizer
  }

  public func run(_ command: KVoiceCommand) async throws {
    switch command {
    case .help(let output, let force):
      try write(Data(HelpText.full.utf8), to: output, force: force)
    case .version(let output, let force):
      try write(Data("KVoice 1.0.0\n".utf8), to: output, force: force)
    case .transcribe(let input, let output, let language, let timestamps, let optimize, let force):
      try await transcribe(
        input: input, output: output, language: language, timestamps: timestamps,
        optimize: optimize, force: force)
    case .speak(let input, let output, let language, let optimize, let force):
      try await speak(
        input: input, output: output, language: language, optimize: optimize, force: force)
    case .locate(
      let reference, let sourceText, let audio, let output, let language, let optimize, let force):
      try await locate(
        reference: reference, sourceText: sourceText, audio: audio, output: output,
        language: language, optimize: optimize, force: force)
    }
  }

  private func transcribe(
    input: URL,
    output: URL,
    language: LanguageSelection,
    timestamps: Bool,
    optimize: Bool,
    force: Bool
  ) async throws {
    try FileValidation.validateInput(input)
    try FileValidation.requireDistinct(output, from: [input])
    try FileValidation.validateOutput(output, force: force)
    let result = try await transcribeAudio(input, language: language, timestamps: timestamps)
    let rawText = try TextProcessing.normalizedNonEmpty(result.text)
    let finalText =
      optimize
      ? try await languageModel.optimize(rawText, purpose: .transcription) : rawText
    _ = try TextProcessing.normalizedNonEmpty(finalText)

    if timestamps {
      let document = TranscriptionDocument(
        language: result.languageIdentifier,
        transcript: rawText,
        optimizedTranscript: finalText,
        segments: result.segments
      )
      try write(TextProcessing.encodeJSON(document), to: output, force: force)
    } else {
      try write(Data((finalText + "\n").utf8), to: output, force: force)
    }
  }

  private func speak(
    input: TextInput, output: URL, language: LanguageSelection, optimize: Bool, force: Bool
  ) async throws {
    try FileValidation.validateOutput(output, force: force)
    let rawText: String
    switch input {
    case .file(let url):
      try FileValidation.validateInput(url)
      try FileValidation.requireDistinct(output, from: [url])
      rawText = try String(contentsOf: url, encoding: .utf8)
    case .inline(let text): rawText = text
    }
    let text = try TextProcessing.normalizedNonEmpty(rawText)
    let speechText = optimize ? try await languageModel.optimize(text, purpose: .speech) : text
    _ = try TextProcessing.normalizedNonEmpty(speechText)
    let available = await synthesizer.availableLanguageIdentifiers()
    let languageIdentifier: String
    switch language {
    case .explicit(let requested):
      languageIdentifier = try resolveLanguage(requested, among: available)
    case .automatic:
      let detected = try await languageModel.detectLanguage(in: speechText, candidates: available)
      languageIdentifier = try resolveLanguage(detected, among: available)
    }
    try await synthesizer.synthesize(
      speechText, to: output, languageIdentifier: languageIdentifier, replaceExisting: force)
  }

  private func locate(
    reference: URL,
    sourceText: URL?,
    audio: URL?,
    output: URL,
    language: LanguageSelection,
    optimize: Bool,
    force: Bool
  ) async throws {
    try FileValidation.validateInput(reference)
    try FileValidation.requireDistinct(
      output, from: [reference] + [sourceText, audio].compactMap { $0 })
    try FileValidation.validateOutput(output, force: force)
    let referenceText = try TextProcessing.normalizedNonEmpty(
      String(contentsOf: reference, encoding: .utf8))
    let originalSource: String
    let resolvedLanguage: String?

    if let sourceText {
      try FileValidation.validateInput(sourceText)
      originalSource = try TextProcessing.normalizedNonEmpty(
        String(contentsOf: sourceText, encoding: .utf8))
      resolvedLanguage = nil
    } else if let audio {
      let result = try await transcribeAudio(audio, language: language, timestamps: false)
      originalSource = try TextProcessing.normalizedNonEmpty(result.text)
      resolvedLanguage = result.languageIdentifier
    } else {
      throw KVoiceError.invalidArguments("locate requires either source text or audio.")
    }

    let processed: String
    if optimize, audio != nil {
      processed = try await languageModel.optimize(originalSource, purpose: .transcription)
    } else {
      processed = originalSource
    }
    _ = try TextProcessing.normalizedNonEmpty(processed)
    let location = try await languageModel.locate(processed, within: referenceText)
    let document = LocateDocument(
      originalSourceText: originalSource,
      processedSourceText: processed,
      language: resolvedLanguage,
      location: location
    )
    try write(TextProcessing.encodeJSON(document), to: output, force: force)
  }

  private func transcribeAudio(_ input: URL, language: LanguageSelection, timestamps: Bool)
    async throws -> TranscriptionResult
  {
    let firstLanguage: String
    switch language {
    case .explicit(let requested):
      let supported = try await transcriber.supportedLanguageIdentifiers()
      firstLanguage = try resolveLanguage(requested, among: supported)
    case .automatic:
      firstLanguage = try await transcriber.preferredLanguageIdentifier()
    }
    let firstPass = try await transcriber.transcribe(
      audioURL: input, languageIdentifier: firstLanguage, includeTimestamps: timestamps)

    guard case .automatic = language else { return firstPass }
    guard !firstPass.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return firstPass
    }
    let candidates = try await transcriber.installedLanguageIdentifiers()
    let detected = try await languageModel.detectLanguage(
      in: firstPass.text, candidates: candidates)
    guard localeKey(detected) != localeKey(firstPass.languageIdentifier) else { return firstPass }
    return try await transcriber.transcribe(
      audioURL: input, languageIdentifier: detected, includeTimestamps: timestamps)
  }

  private func resolveLanguage(_ requested: String, among available: [String]) throws -> String {
    let normalized = TextProcessing.normalizedLanguageTag(requested)
    if let exact = available.first(where: {
      TextProcessing.normalizedLanguageTag($0).caseInsensitiveCompare(normalized) == .orderedSame
    }) {
      return exact
    }
    guard !normalized.contains("-") else {
      throw KVoiceError.unsupportedLanguage(requested)
    }
    let languageCode = Locale(identifier: normalized).language.languageCode?.identifier
    if let languageCode,
      let base = available.first(where: {
        Locale(identifier: $0).language.languageCode?.identifier.caseInsensitiveCompare(
          languageCode) == .orderedSame
      })
    {
      return base
    }
    throw KVoiceError.unsupportedLanguage(requested)
  }

  private func localeKey(_ identifier: String) -> String {
    Locale(identifier: identifier).language.languageCode?.identifier.lowercased()
      ?? identifier.lowercased()
  }

  private func write(_ data: Data, to output: URL, force: Bool) throws {
    try FileValidation.validateOutput(output, force: force)
    try FileManager.default.createDirectory(
      at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: output, options: .atomic)
  }
}
