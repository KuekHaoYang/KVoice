import Foundation

public enum HelpText {
  public static let usage = """
    KVoice — macOS speech command-line application

    Usage:
      KVoice help --output <path.txt>
      KVoice version --output <path.txt>
      KVoice transcribe --input <audio-path> --output <path.txt> [options]
      KVoice speak (--input <text-path|-> | --text <text>) --output <path.wav> [options]
      KVoice speak --input <directory> --output <directory> [options]
      KVoice locate --reference <text-path> (--source-text <text-path> | --audio <audio-path>) --output <path.json> [options]
      KVoice list (languages|voices) --output <path.txt>

    Paths may be absolute or relative to the current working directory. Every command requires --output.
    """

  public static let full = """
    KVoice — complete command reference
    Version: 1.0.0
    Platform: macOS 26 or later

    PURPOSE
    KVoice is a Swift command-line tool for speech transcription, text optimization, and speech synthesis.
    It uses Apple's Speech, Foundation Models, and AVFoundation frameworks. Processing is local.

    PATH AND OUTPUT RULES
    - Every command requires --output, including help, version and list commands.
    - Absolute paths and paths relative to the current working directory are accepted.
    - An occupied output name is preserved; KVoice writes to "name copy.ext", then "name copy copy.ext".
    - --force explicitly replaces the requested output path.
    - KVoice creates missing output parent directories.
    - Successful commands print the actual generated artifact path(s) to standard output.
    - --no-optimize skips rewriting text. Automatic language selection still uses Foundation Models.
    - Apple Intelligence/Foundation Models must be available for optimization and automatic language selection.

    COMMAND: transcribe
    Transcribe an audio file using SpeechAnalyzer and SpeechTranscriber. Foundation Models correct the
    transcript by default.

    Required:
      --input <audio-path>       Read an audio file (WAV, AIFF, M4A and other AVAudioFile formats).
      --output <path.txt>        Write optimized transcript as UTF-8 text.

    Optional:
      --language <BCP-47|auto>   Choose locale (for example en-US, zh-CN, ms-MY). Default: auto.
      --timestamps               Write JSON with timed segments. Output path must end in .json.
      --no-optimize              Preserve the raw transcript and skip text correction.
      --force                    Replace the requested output path.

    Automatic audio language selection starts with the system-preferred installed locale, asks Foundation
    Models to classify the first transcript against installed locales, then repeats transcription if needed.
    This two-pass heuristic can misclassify short or noisy audio. Pass --language for a known locale.
    Timestamp ranges come from Apple's attributed audio time ranges; KVoice does not invent boundaries.

    COMMAND: speak
    Optimize text by default, then synthesize a WAV file with AVSpeechSynthesizer.

    Required input (exactly one):
      --input <text-path>        Read UTF-8 text from a file. Relative paths use the current directory.
      --input -                  Read UTF-8 text from standard input until EOF.
      --input <directory>        Convert each regular text file recursively to a WAV in the output directory.
      --text <text>              Use text passed as one shell argument.
    Required output:
      --output <path.wav>        Write one WAV file, or a directory when --input is a directory.

    Optional:
      --language <BCP-47|auto>   Select voice language. Default: auto via Foundation Models.
      --voice <name|identifier>  Select an installed voice by its displayed name (case-insensitive)
                                  or unique identifier.
                                  Use `list voices` to see names, locale, quality and identifier.
      --rate <0.0–1.0>           Set AVSpeechUtterance rate. Apple currently defines 0.0 as minimum,
                                  0.5 as default and 1.0 as maximum. If omitted, use the system default.
      --sanitize-markdown        Remove common Markdown formatting before synthesis. Link and image labels,
                                  inline code, and fenced code contents are retained as plain text.
      --strip-markdown           Alias for --sanitize-markdown.
      --no-optimize              Synthesize without Foundation Models text correction.
      --force                    Replace the requested output path.

    Voice names and identifiers come from AVSpeechSynthesisVoice.speechVoices(). Apple exposes voice name,
    unique identifier, BCP-47 language and quality. The `rate` property is a decimal bounded by
    AVSpeechUtteranceMinimumSpeechRate and AVSpeechUtteranceMaximumSpeechRate; KVoice validates against
    those Apple constants.

    For directory input, every regular file is read as UTF-8. Directory structure is preserved under the
    output directory and file extensions are changed to .wav. Existing destinations receive repeated
    " copy" suffixes. Directory conversion is recursive; subdirectories with no files are ignored.

    COMMAND: list
    Write installed speech resources to the required output file.
      KVoice list languages --output <path.txt>
        Lists installed/supported Speech locales and locales represented by installed synthesis voices.
      KVoice list voices --output <path.txt>
        Lists voice name, BCP-47 locale, quality and unique identifier, one tab-separated voice per line.

    COMMAND: locate
    Use Foundation Models to find source text within a reference. Audio is transcribed first, and the
    proposed excerpt is verified against the reference before KVoice writes its UTF-16 range.

    Required:
      --reference <text-path>           UTF-8 text to search.
      Exactly one source:
        --source-text <text-path>        UTF-8 source text to find.
        --audio <audio-path>             Transcribe audio, then locate its transcript.
      --output <path.json>               Write JSON with source text, language and match.

    Optional:
      --language <BCP-47|auto>           Applies only to --audio. Default: auto.
      --no-optimize                      Skip audio transcript correction; does not affect --source-text.
      --force                            Replace the requested output path.

    OTHER COMMANDS
      help / --help / -h                  Write this document; requires --output.
      version / --version                 Write the version; requires --output.

    EXAMPLES
      KVoice speak --input ./note.md --output ./note.wav --sanitize-markdown --voice Samantha --rate 0.57
      cat ./note.md | KVoice speak --input - --output ./note.wav --sanitize-markdown --language en-US
      KVoice speak --input ./notes --output ./audio --language en-GB --no-optimize
      KVoice list languages --output ./languages.txt
      KVoice list voices --output ./voices.txt
      KVoice transcribe --input ./interview.m4a --output ./interview.txt
      KVoice locate --reference ./lecture.txt --source-text ./quote.txt --output ./location.json

    EXIT BEHAVIOR
    Success returns exit code 0. Errors are written to standard error and return a nonzero code. Artifact
    contents are written to their selected output files; generated paths are written to standard output.
    """
}
