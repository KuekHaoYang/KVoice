import AVFoundation
import Foundation

@available(macOS 26, *)
public struct AppleSpeechSynthesizer: SpeechSynthesizing {
  public init() {}

  public func availableLanguageIdentifiers() async -> [String] {
    Array(Set(AVSpeechSynthesisVoice.speechVoices().map(\.language))).sorted()
  }

  public func synthesize(
    _ text: String,
    to outputURL: URL,
    languageIdentifier: String,
    replaceExisting: Bool
  ) async throws {
    let value = try TextProcessing.normalizedNonEmpty(text)
    guard outputURL.pathExtension.lowercased() == "wav" else {
      throw KVoiceError.unsupportedOutput("Speech output must be a .wav file: \(outputURL.path)")
    }
    guard let voice = AVSpeechSynthesisVoice(language: languageIdentifier) else {
      throw KVoiceError.unsupportedLanguage(languageIdentifier)
    }
    try FileValidation.validateOutput(outputURL, force: replaceExisting)

    let outputDirectory = outputURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: outputDirectory, withIntermediateDirectories: true)
    let temporaryURL = outputDirectory.appendingPathComponent(
      ".\(outputURL.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).wav")
    let utterance = AVSpeechUtterance(string: value)
    utterance.voice = voice
    let synthesizer = AVSpeechSynthesizer()
    let sink = AudioBufferSink(outputURL: temporaryURL, synthesizer: synthesizer)
    do {
      try await withCheckedThrowingContinuation { continuation in
        sink.install(continuation)
        synthesizer.write(utterance) { buffer in sink.consume(buffer) }
      }
      if FileManager.default.fileExists(atPath: outputURL.path) {
        guard replaceExisting else { throw KVoiceError.outputExists(outputURL) }
        _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: temporaryURL)
      } else {
        try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
      }
    } catch {
      try? FileManager.default.removeItem(at: temporaryURL)
      throw error
    }
  }
}

private final class AudioBufferSink: @unchecked Sendable {
  private let outputURL: URL
  private let lock = NSLock()
  private var synthesizer: AVSpeechSynthesizer?
  private var audioFile: AVAudioFile?
  private var continuation: CheckedContinuation<Void, Error>?
  private var finished = false

  init(outputURL: URL, synthesizer: AVSpeechSynthesizer) {
    self.outputURL = outputURL
    self.synthesizer = synthesizer
  }

  func install(_ continuation: CheckedContinuation<Void, Error>) {
    lock.lock()
    self.continuation = continuation
    lock.unlock()
  }

  func consume(_ buffer: AVAudioBuffer) {
    guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
      finish(
        .failure(KVoiceError.audioProcessing("Speech synthesizer returned a non-PCM audio buffer."))
      )
      return
    }
    if pcmBuffer.frameLength == 0 {
      lock.lock()
      let hasAudio = audioFile != nil
      lock.unlock()
      finish(
        hasAudio
          ? .success(())
          : .failure(KVoiceError.audioProcessing("Speech synthesizer returned no audio samples.")))
      return
    }

    lock.lock()
    guard !finished else {
      lock.unlock()
      return
    }
    do {
      if audioFile == nil {
        audioFile = try AVAudioFile(forWriting: outputURL, settings: pcmBuffer.format.settings)
      }
      try audioFile?.write(from: pcmBuffer)
      lock.unlock()
    } catch {
      lock.unlock()
      finish(.failure(error))
    }
  }

  private func finish(_ result: Result<Void, Error>) {
    lock.lock()
    guard !finished else {
      lock.unlock()
      return
    }
    finished = true
    let continuation = self.continuation
    self.continuation = nil
    synthesizer = nil
    audioFile = nil
    lock.unlock()
    switch result {
    case .success: continuation?.resume()
    case .failure(let error): continuation?.resume(throwing: error)
    }
  }
}
