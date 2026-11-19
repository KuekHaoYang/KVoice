import Darwin
import Foundation
import KVoiceCore

@main
struct KVoiceCLI {
  static func main() async {
    do {
      let command = try KVoiceCommandLine.parse(Array(CommandLine.arguments.dropFirst()))
      if #available(macOS 26, *) {
        let runner = CommandRunner(
          languageModel: AppleFoundationModel(),
          transcriber: AppleSpeechTranscriber(),
          synthesizer: AppleSpeechSynthesizer()
        )
        try await runner.run(command)
      } else {
        throw KVoiceError.modelUnavailable("KVoice requires macOS 26 or later.")
      }
    } catch {
      FileHandle.standardError.write(Data("KVoice: \(error.localizedDescription)\n".utf8))
      exit(EXIT_FAILURE)
    }
  }
}
