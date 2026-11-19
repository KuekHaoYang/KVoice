# KVoice

KVoice is a personal-use macOS command-line application for speech recognition, text-to-speech, Apple Foundation Models text correction, timestamped transcripts, and semantic text search. It is written in Swift and uses Apple's native frameworks directly.

## Platform and requirements

- macOS 26 or later; developed and verified on macOS 27.2.1 with Xcode 27.2 and Swift 6.4.2.
- Apple silicon and Apple Intelligence enabled for Foundation Models features.
- Speech language assets and text-to-speech voices may need to be downloaded or enabled in macOS.
- Xcode 27 is required for the documented Swift Package Manager commands. On this machine, the active Command Line Tools SwiftPM manifest linker is incompatible with its own PackageDescription symbols; use the Xcode toolchain commands below.
- No package dependencies, server, external HTTP requests, Python runtime, or app-side shell calls to `/usr/bin/fm`.

## Build and test

Run these from any directory. Use the absolute project path in place of `/Users/haoyangkuek/development/KVoice` if the checkout is elsewhere.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift build \
  --package-path /Users/haoyangkuek/development/KVoice \
  --scratch-path /Users/haoyangkuek/development/KVoice/.build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test \
  --package-path /Users/haoyangkuek/development/KVoice \
  --scratch-path /Users/haoyangkuek/development/KVoice/.build
```

Run KVoice through SwiftPM with `swift run --package-path <absolute-project-path> --scratch-path <absolute-build-path> KVoice ...`, or call the built executable. Every KVoice invocation below includes `--output`. Help and version also write a file so automation has a known output artifact.

## CLI reference

Generate the complete AI-oriented help document:

```sh
/Users/haoyangkuek/development/KVoice/.build/out/Products/Debug/KVoice help \
  --output /Users/haoyangkuek/Documents/KVoice-help.txt
```

The executable path may differ if another SwiftPM toolchain is used. The source of truth for flags, formats, defaults, and examples is [`HelpText.swift`](Sources/KVoiceCore/HelpText.swift).

### Speech to text

Transcribe an audio file. Apple Foundation Models optimization is on by default:

```sh
KVoice transcribe \
  --input /Users/haoyangkuek/Audio/interview.m4a \
  --output /Users/haoyangkuek/Audio/interview.txt
```

Select a language and disable optimization:

```sh
KVoice transcribe \
  --input /Users/haoyangkuek/Audio/meeting.wav \
  --output /Users/haoyangkuek/Audio/meeting.txt \
  --language ms-MY \
  --no-optimize
```

Write timestamped JSON. Speech time ranges are retained as supplied by `SpeechTranscriber`:

```sh
KVoice transcribe \
  --input /Users/haoyangkuek/Audio/lecture.m4a \
  --output /Users/haoyangkuek/Audio/lecture.json \
  --timestamps
```

The JSON document contains `language`, the raw `transcript`, `optimizedTranscript`, and `segments`. A segment has `text`, `startSeconds`, and `endSeconds`. Depending on what time ranges Apple assigns, a segment may cover one word or a larger text run; KVoice does not fabricate word-level boundaries.

#### Audio language selection limit

Apple's `SpeechTranscriber` initializer requires a locale before it can recognize an audio file. Foundation Models accepts text prompts, not raw audio. In automatic mode KVoice begins with the system-preferred installed Speech locale, asks Foundation Models to classify the resulting transcript against locally installed Speech locales, and runs a second pass if that language differs. This is a heuristic, not acoustic language detection before transcription. Very short, noisy, or mistranscribed audio can cause an incorrect choice. Pass `--language <BCP-47>` when the spoken language is known; an explicit supported locale may require a model asset download.

### Text to speech

Read UTF-8 text from a file, optimize it, detect its language with Foundation Models, then synthesize WAV:

```sh
KVoice speak \
  --input /Users/haoyangkuek/Documents/note.txt \
  --output /Users/haoyangkuek/Audio/note.wav
```

Or pass text directly as one shell argument:

```sh
KVoice speak \
  --text "Good morning. This is a KVoice speech test." \
  --output /Users/haoyangkuek/Audio/test.wav \
  --language en-GB
```

Use `--no-optimize` to synthesize source text unchanged. Automatic voice selection chooses from voices installed on the Mac. Explicit tags should use BCP-47, such as `en-US`, `zh-CN`, or `ms-MY`.

### Locate source text in a reference

Provide a UTF-8 reference document and exactly one source. The source can be a text file:

```sh
KVoice locate \
  --reference /Users/haoyangkuek/Documents/lecture.txt \
  --source-text /Users/haoyangkuek/Documents/quote.txt \
  --output /Users/haoyangkuek/Documents/quote-location.json
```

Or audio. KVoice transcribes first, optimizes the transcript by default, then uses Foundation Models to find a corresponding reference passage:

```sh
KVoice locate \
  --reference /Users/haoyangkuek/Documents/lecture.txt \
  --audio /Users/haoyangkuek/Audio/clip.m4a \
  --output /Users/haoyangkuek/Documents/clip-location.json \
  --language en-US
```

The JSON contains `originalSourceText`, `processedSourceText`, optional `language`, and `location`. A found location has a verbatim `excerpt`, a zero-based `startUTF16`, and `lengthUTF16`, compatible with `NSString` range coordinates. KVoice validates that the excerpt occurs in the reference before returning it. A semantic match can be missed or a weak match proposed by the on-device model; inspect the excerpt and offset for important work.

### Output behavior and options

- Input and output paths must be absolute.
- `transcribe` outputs `.txt`, or `.json` with `--timestamps`; `speak` outputs `.wav`; `locate` outputs `.json`.
- Every invocation requires `--output`; use `help --output /absolute/path.txt` to save help.
- Existing output files are protected. Use `--force` to replace them.
- `--no-optimize` disables text correction only. Automatic language selection still uses Foundation Models.
- `locate --source-text` searches the supplied text as-is; `--no-optimize` affects only audio transcripts.
- Results go only to the output file. Errors go to stderr and return a nonzero exit code.
- If Foundation Models is unavailable, default optimization and automatic language selection fail with an actionable error. Use `--no-optimize` with explicit `--language` to avoid Foundation Models for transcription or synthesis.

## Architecture

The package has three targets:

- `KVoiceCore`: argument parsing, domain models, file validation, orchestration, and framework adapters.
- `KVoiceCLI`: minimal async process entry point and stderr/exit-code handling.
- `KVoiceCoreTests`: deterministic tests using protocol fakes, plus opt-in native integration checks. Default tests do not call the system model or download Speech assets. Set `KVOICE_RUN_SYSTEM_TESTS=1` before `swift test` to opt in to tests that exercise the Foundation Model, installed voices, and Speech model assets.

Framework boundaries use `LanguageModeling`, `SpeechRecognizing`, and `SpeechSynthesizing`. The command runner owns operation order and output serialization. Native adapters contain Apple API interactions. `TextChunker` bounds ordinary prompts and preserves whitespace-bearing words where possible. Text matching uses model-proposed excerpts and deterministic UTF-16 range verification.

## Engineering standards

See [`ENGINEERING.md`](ENGINEERING.md) for architecture, complexity, style, error handling, privacy, and test requirements. In brief: one responsibility per type/file, no spaghetti control flow, no network or unrelated features, production Swift files capped at 250 lines, injected framework boundaries, and tests for each CLI contract and orchestration path.

Enforce the documented Swift file limits with `bash /Users/haoyangkuek/development/KVoice/scripts/check-swift-file-limits.sh`.
