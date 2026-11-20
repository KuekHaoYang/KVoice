import Foundation

public struct CommandRunner: Sendable {
  private let languageModel: any LanguageModeling
  private let transcriber: any SpeechRecognizing
  private let synthesizer: any SpeechSynthesizing
  private let standardInputReader: @Sendable () throws -> String

  public init(
    languageModel: any LanguageModeling, transcriber: any SpeechRecognizing,
    synthesizer: any SpeechSynthesizing,
    standardInputReader: @escaping @Sendable () throws -> String = {
      let data = FileHandle.standardInput.readDataToEndOfFile()
      guard let text = String(data: data, encoding: .utf8) else {
        throw KVoiceError.invalidText("Standard input must be valid UTF-8 text.")
      }
      return text
    }
  ) {
    self.languageModel = languageModel
    self.transcriber = transcriber
    self.synthesizer = synthesizer
    self.standardInputReader = standardInputReader
  }

  @discardableResult
  public func run(_ command: KVoiceCommand) async throws -> [URL] {
    switch command {
    case .help(let output, let force):
      return [try write(Data(HelpText.full.utf8), to: output, force: force)]
    case .version(let output, let force):
      return [try write(Data("KVoice 1.0.0\n".utf8), to: output, force: force)]
    case .transcribe(let input, let output, let language, let timestamps, let optimize, let force):
      return [
        try await transcribe(
          input: input, output: output, language: language, timestamps: timestamps,
          optimize: optimize, force: force)
      ]
    case .speak(let input, let output, let language, let optimize, let force):
      return try await runSpeech(
        input: input, output: output, language: language, optimize: optimize, force: force,
        voiceName: nil, rate: nil, stripMarkdown: false)
    case .speakConfigured(
      let input, let output, let language, let optimize, let force, let voiceName, let rate,
      let stripMarkdown):
      return try await runSpeech(
        input: input, output: output, language: language, optimize: optimize, force: force,
        voiceName: voiceName, rate: rate, stripMarkdown: stripMarkdown)
    case .locate(
      let reference, let sourceText, let audio, let output, let language, let optimize, let force):
      return [
        try await locate(
          reference: reference, sourceText: sourceText, audio: audio, output: output,
          language: language, optimize: optimize, force: force)
      ]
    case .listResources(let kind, let output, let force):
      return [try await listResources(kind: kind, output: output, force: force)]
    }
  }

  private func transcribe(
    input: URL,
    output: URL,
    language: LanguageSelection,
    timestamps: Bool,
    optimize: Bool,
    force: Bool
  ) async throws -> URL {
    try FileValidation.validateInput(input)
    try FileValidation.requireDistinct(output, from: [input])
    let destination = try FileValidation.uniqueOutputURL(output, force: force)
    try FileValidation.requireDistinct(destination, from: [input])
    try FileValidation.validateOutput(destination, force: force)
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
      return try write(TextProcessing.encodeJSON(document), to: destination, force: force)
    } else {
      return try write(Data((finalText + "\n").utf8), to: destination, force: force)
    }
  }

  private func runSpeech(
    input: TextInput, output: URL, language: LanguageSelection, optimize: Bool, force: Bool,
    voiceName: String?, rate: Float?, stripMarkdown: Bool
  ) async throws -> [URL] {
    if case .file(let url) = input { try FileValidation.validateInput(url) }
    if case .directory(let url) = input { try FileValidation.validateInputDirectory(url) }
    return try await SpeechOutputRunner(
      languageModel: languageModel, synthesizer: synthesizer,
      standardInputReader: standardInputReader
    ).run(
      input: input, output: output, language: language, optimize: optimize, force: force,
      voiceName: voiceName, rate: rate, stripMarkdown: stripMarkdown)
  }

  private func listResources(kind: ResourceList, output: URL, force: Bool) async throws -> URL {
    let contents: String
    switch kind {
    case .voices:
      let voices = await synthesizer.availableVoices()
      contents =
        voices.map {
          "\($0.name)\t\($0.languageIdentifier)\t\($0.quality)\t\($0.identifier)"
        }.joined(separator: "\n") + (voices.isEmpty ? "" : "\n")
    case .languages:
      let speech = try await transcriber.installedLanguageIdentifiers()
      let supportedSpeech = try await transcriber.supportedLanguageIdentifiers()
      let voices = await synthesizer.availableVoices()
      let synthesis = Array(Set(voices.map(\.languageIdentifier))).sorted()
      contents =
        "Speech recognition (installed):\n"
        + speech.map { "  \($0)" }.joined(separator: "\n")
        + "\n\nSpeech recognition (supported, may need download):\n"
        + supportedSpeech.map { "  \($0)" }.joined(separator: "\n")
        + "\n\nSpeech synthesis (installed voices):\n"
        + synthesis.map { "  \($0)" }.joined(separator: "\n") + "\n"
    }
    return try write(Data(contents.utf8), to: output, force: force)
  }

  private func locate(
    reference: URL,
    sourceText: URL?,
    audio: URL?,
    output: URL,
    language: LanguageSelection,
    optimize: Bool,
    force: Bool
  ) async throws -> URL {
    try FileValidation.validateInput(reference)
    try FileValidation.requireDistinct(
      output, from: [reference] + [sourceText, audio].compactMap { $0 })
    let destination = try FileValidation.uniqueOutputURL(output, force: force)
    try FileValidation.requireDistinct(
      destination, from: [reference] + [sourceText, audio].compactMap { $0 })
    try FileValidation.validateOutput(destination, force: force)
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
    return try write(TextProcessing.encodeJSON(document), to: destination, force: force)
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
    try LanguageResolver.resolve(requested, among: available)
  }

  private func localeKey(_ identifier: String) -> String {
    Locale(identifier: identifier).language.languageCode?.identifier.lowercased()
      ?? identifier.lowercased()
  }

  private func write(_ data: Data, to output: URL, force: Bool) throws -> URL {
    try OutputFileWriter.write(data, to: output, force: force)
  }
}
