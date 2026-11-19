import AVFoundation
import Foundation
import Speech

@available(macOS 26, *)
public struct AppleSpeechTranscriber: SpeechRecognizing {
  public init() {}

  public func supportedLanguageIdentifiers() async throws -> [String] {
    try requireSpeechAvailability()
    return uniqueIdentifiers(await SpeechTranscriber.supportedLocales)
  }

  public func installedLanguageIdentifiers() async throws -> [String] {
    try requireSpeechAvailability()
    return uniqueIdentifiers(await SpeechTranscriber.installedLocales)
  }

  public func preferredLanguageIdentifier() async throws -> String {
    try requireSpeechAvailability()
    let preferred = Locale.current
    let installed = (await SpeechTranscriber.installedLocales).sorted {
      TextProcessing.normalizedLanguageTag($0.identifier)
        < TextProcessing.normalizedLanguageTag($1.identifier)
    }
    guard !installed.isEmpty else {
      throw KVoiceError.noLanguageAvailable
    }
    let preferredTag = TextProcessing.normalizedLanguageTag(preferred.identifier)
    if let exact = installed.first(where: {
      TextProcessing.normalizedLanguageTag($0.identifier).caseInsensitiveCompare(preferredTag)
        == .orderedSame
    }) {
      return TextProcessing.normalizedLanguageTag(exact.identifier)
    }
    let preferredLanguage = preferred.language.languageCode?.identifier
    if let sameLanguage = installed.first(where: {
      Locale(identifier: $0.identifier).language.languageCode?.identifier == preferredLanguage
    }) {
      return TextProcessing.normalizedLanguageTag(sameLanguage.identifier)
    }
    return TextProcessing.normalizedLanguageTag(installed[0].identifier)
  }

  public func transcribe(audioURL: URL, languageIdentifier: String, includeTimestamps: Bool)
    async throws -> TranscriptionResult
  {
    try FileValidation.validateInput(audioURL)
    try requireSpeechAvailability()

    let normalizedIdentifier = TextProcessing.normalizedLanguageTag(languageIdentifier)
    let supportedLocales = await SpeechTranscriber.supportedLocales
    let exactLocale = supportedLocales.first(where: {
      TextProcessing.normalizedLanguageTag($0.identifier).caseInsensitiveCompare(
        normalizedIdentifier) == .orderedSame
    })
    let resolvedLocale: Locale?
    if let exactLocale {
      resolvedLocale = exactLocale
    } else {
      resolvedLocale = await SpeechTranscriber.supportedLocale(
        equivalentTo: Locale(identifier: normalizedIdentifier))
    }
    guard let locale = resolvedLocale else {
      throw KVoiceError.unsupportedLanguage(languageIdentifier)
    }
    let attributes: Set<SpeechTranscriber.ResultAttributeOption> =
      includeTimestamps ? [.audioTimeRange] : []
    let preset: SpeechTranscriber.Preset =
      includeTimestamps ? .timeIndexedTranscriptionWithAlternatives : .transcription
    let transcriber = SpeechTranscriber(
      locale: locale,
      transcriptionOptions: preset.transcriptionOptions,
      reportingOptions: preset.reportingOptions,
      attributeOptions: preset.attributeOptions.union(attributes)
    )

    if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
      try await request.downloadAndInstall()
    }

    let analyzer = SpeechAnalyzer(modules: [transcriber])
    let collector = Task {
      try await Self.collectResults(from: transcriber, includeTimestamps: includeTimestamps)
    }
    do {
      let audioFile = try AVAudioFile(forReading: audioURL)
      if let endTime = try await analyzer.analyzeSequence(from: audioFile) {
        try await analyzer.finalizeAndFinish(through: endTime)
      } else {
        await analyzer.cancelAndFinishNow()
      }
      let collected = try await collector.value
      return TranscriptionResult(
        text: collected.text,
        languageIdentifier: TextProcessing.normalizedLanguageTag(locale.identifier),
        segments: collected.segments)
    } catch {
      await analyzer.cancelAndFinishNow()
      collector.cancel()
      throw error
    }
  }

  private static func collectResults(
    from transcriber: SpeechTranscriber,
    includeTimestamps: Bool
  ) async throws -> (text: String, segments: [TimedSegment]) {
    var transcript = ""
    var segments: [TimedSegment] = []

    for try await result in transcriber.results where result.isFinal {
      transcript += String(result.text.characters)
      guard includeTimestamps else { continue }
      for run in result.text.runs {
        guard let timeRange = run.audioTimeRange else { continue }
        let text = String(result.text[run.range].characters).trimmingCharacters(
          in: .whitespacesAndNewlines)
        guard !text.isEmpty else { continue }
        let start = timeRange.start.seconds
        let end = CMTimeRangeGetEnd(timeRange).seconds
        guard start.isFinite, end.isFinite, end >= start else { continue }
        segments.append(TimedSegment(text: text, startSeconds: start, endSeconds: end))
      }
    }
    return (transcript, segments)
  }

  private func requireSpeechAvailability() throws {
    guard SpeechTranscriber.isAvailable else {
      throw KVoiceError.audioProcessing("SpeechTranscriber is unavailable on this Mac.")
    }
  }

  private func uniqueIdentifiers(_ locales: [Locale]) -> [String] {
    Array(Set(locales.map { TextProcessing.normalizedLanguageTag($0.identifier) })).sorted()
  }
}
