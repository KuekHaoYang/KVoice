import Foundation

public enum HelpText {
  public static let usage = """
    KVoice — native macOS speech CLI

    Usage:
      KVoice help --output <absolute-path.txt>
      KVoice version --output <absolute-path.txt>
      KVoice transcribe --input <absolute-audio-path> --output <absolute-path.txt> [options]
      KVoice speak (--input <absolute-text-path> | --text <text>) --output <absolute-path.wav> [options]
      KVoice locate --reference <absolute-text-path> (--source-text <absolute-text-path> | --audio <absolute-audio-path>) --output <absolute-path.json> [options]

    All file paths must be absolute. Every invocation, including help/version, requires --output.
    """

  public static let full = """
    KVoice — AI-readable command reference
    Version: 1.0.0
    Platform: macOS 26 or later

    PURPOSE
    KVoice is a personal-use Swift command-line tool. It uses Apple's Speech framework for transcription,
    Apple Foundation Models for text optimization, and AVFoundation for speech synthesis. It has no
    network client, server, Python runtime, microphone recorder, or third-party dependency.

    GLOBAL PATH AND OUTPUT RULES
    - Every command writes an artifact and requires --output, including help and version.
    - Every input and output file path must be absolute (begin with /).
    - Existing outputs cause an error. Add --force to replace an output.
    - KVoice creates missing output parent directories.
    - --no-optimize skips rewriting text. Automatic language detection still uses Foundation Models.
    - Apple Intelligence/Foundation Models must be available for automatic language selection and optimization.
    - Speech recognition is on device. macOS may download a missing Speech model asset for the requested locale.

    COMMAND: transcribe
    Purpose: Transcribe an audio file using SpeechAnalyzer and SpeechTranscriber. By default, run Apple
    Foundation Models over the transcript to correct recognition errors and punctuation.

    Required:
      --input <absolute-audio-path>   Read audio from a file (WAV, AIFF, M4A and other AVAudioFile formats).
      --output <absolute-path.txt>     Write optimized transcript as UTF-8 text.

    Optional:
      --language <BCP-47|auto>         Choose locale (for example en-US, zh-CN, ms-MY). Default: auto.
      --timestamps                     Write JSON instead of text. Each timed segment contains its text,
                                       startSeconds and endSeconds from Speech attributed time ranges.
                                       Output path must end in .json.
      --no-optimize                    Preserve the raw transcript and skip text correction.
      --force                          Replace an existing output file.

    Automatic audio language selection: SpeechTranscriber needs a locale before it can decode audio.
    KVoice first uses the system-preferred installed speech locale, asks Foundation Models to classify
    the first transcript against locally installed locales, and repeats transcription if it differs.
    An explicit supported language may require downloading its speech asset. This is a two-pass
    heuristic; noisy or very short audio can be classified incorrectly. Pass --language for a known locale.
    Timestamps come from Apple's attributed audio time ranges. KVoice reports each range as provided and
    does not invent boundaries when the system groups multiple words into one range.

    COMMAND: speak
    Purpose: Optimize text with Apple Foundation Models by default, then synthesize an audio file using
    AVSpeechSynthesizer and AVSpeechUtterance.

    Required input (exactly one):
      --input <absolute-text-path>     Read UTF-8 text from a file.
      --text <text>                    Use direct text passed as one shell argument.
    Required output:
      --output <absolute-path.wav>     Write a WAV audio file.

    Optional:
      --language <BCP-47|auto>         Select AVSpeech voice language. Default: auto via Foundation Models.
      --no-optimize                    Synthesize the original text without correction.
      --force                          Replace an existing output file.

    Automatic language selection chooses from voices installed on the current Mac. Install a system
    voice for a language in macOS settings if no matching voice exists.

    COMMAND: locate
    Purpose: Use Apple Foundation Models to find an audio/text source within a reference text. Audio is
    transcribed first. The model returns a verbatim excerpt; KVoice verifies the excerpt against the
    reference and writes a zero-based UTF-16 offset and length, suitable for Foundation NSString ranges.

    Required:
      --reference <absolute-text-path>     UTF-8 text to search in.
      Exactly one source:
        --source-text <absolute-path>      UTF-8 source text to find.
        --audio <absolute-audio-path>      Transcribe this audio, then locate its transcript.
      --output <absolute-path.json>        Write JSON with original/processed source, language and match.

    Optional:
      --language <BCP-47|auto>             Applies only to --audio. Default: auto.
      --no-optimize                        Skip correction of an audio transcript before matching. It does not affect a --source-text input.
      --force                              Replace an existing output file.

    OPTIONS
      --output <absolute-path>             Required for every command.
      --force                               Allow replacement of an existing output file.
      help / --help / -h                    As the first argument, writes this help text; still requires --output.
      version / --version                   As the first argument, writes the version; still requires --output.

    EXAMPLES
      KVoice transcribe --input /Users/me/Audio/interview.m4a --output /Users/me/Audio/interview.txt
      KVoice transcribe --input /Users/me/Audio/interview.wav --output /Users/me/Audio/interview.json --timestamps
      KVoice transcribe --input /Users/me/Audio/meeting.m4a --output /Users/me/Audio/meeting-ms.txt --language ms-MY --no-optimize
      KVoice speak --input /Users/me/Documents/note.txt --output /Users/me/Audio/note.wav
      KVoice speak --text "Good morning." --output /Users/me/Audio/greeting.wav --language en-GB
      KVoice locate --reference /Users/me/Documents/lecture.txt --audio /Users/me/Audio/clip.m4a --output /Users/me/Audio/location.json
      KVoice locate --reference /Users/me/Documents/lecture.txt --source-text /Users/me/Documents/quote.txt --output /Users/me/Documents/location.json
      KVoice help --output /Users/me/Documents/kvoice-help.txt

    EXIT BEHAVIOR
    Success returns exit code 0. Errors are written to standard error and return a nonzero code. Results
    are written only to the explicit --output path; the app does not print converted content to stdout.
    """
}
