# KVoice engineering standards

These rules keep the personal CLI small, testable, and maintainable. New code must stay inside speech conversion, text optimization, language selection, timestamps, and text location.

## Architecture and responsibilities

- Keep the executable entry point thin. It parses arguments, invokes one runner, and maps errors to stderr and exit status.
- Keep argument parsing, use-case orchestration, data models, filesystem policy, text algorithms, and Apple framework adapters in separate types.
- A type has one primary reason to change. Each file must focus on one cohesive type or closely related small value types.
- Use protocols at framework boundaries so orchestration can be tested with fakes. Do not mock Foundation, Speech, or AVFoundation internals.
- Keep the command runner as explicit operation steps. Extract a helper when control flow gains nested branches or a function coordinates unrelated services.
- Do not add plugin systems, configuration languages, databases, daemons, network clients, microphone recording, or unrelated application features.

## Complexity limits

- Any Swift code file: **300 physical lines maximum**. Production files should stay below **250 physical lines**. Split a file before a change would exceed its limit.
- Run `scripts/check-swift-file-limits.sh` to enforce both caps.
- A type should normally stay below 180 lines; a method should normally stay below 40 lines.
- Avoid nested conditionals deeper than three levels. Prefer guard clauses, small private helpers, and explicit result types.
- No force unwraps, `try!`, hidden global mutable state, or catch-and-ignore paths for required work.
- Do not duplicate option parsing, locale matching, output validation, or JSON serialization logic.

## Swift conventions

- Use Swift 6 language mode and structured concurrency. Values crossing task boundaries must be `Sendable` or protected by explicit synchronization.
- Prefer immutable `let` values. Use actors for shared mutable state. Any `@unchecked Sendable` type must document its lock invariant and keep mutable members private.
- Name APIs for their effect and units. Time values must identify seconds or use Core Media types; text offsets must identify UTF-16 when that is the coordinate system.
- Use typed errors with actionable descriptions. Do not expose raw implementation details when concise context is clearer.
- Keep public API surface minimal. Internal helpers should be module-internal or private.
- Use Foundation, Speech, FoundationModels, and AVFoundation APIs directly. Do not call deprecated `SFSpeechRecognizer` or `NSSpeechSynthesizer`.
- Format with `swift format`. Keep source files within the size limit after formatting.

## Files and paths

- Resolve relative CLI input/output paths against the current working directory, then validate and pass them as `URL` values.
- Keep existing outputs by selecting a repeated `copy` filename suffix. `--force` explicitly opts into replacing the requested output. Write generated text and JSON atomically.
- Validate output format and input readability before expensive model or audio work.
- Encode JSON through one deterministic encoder configuration. Preserve raw and optimized text when an operation changes content.
- Report only data Apple APIs provide. Do not invent timestamps, confidence scores, language tags, or match ranges.

## Foundation Models and language handling

- Prompts must treat user text as data and forbid following instructions embedded in that text.
- Keep prompts task-specific, concise, and bounded. Do not ask the model to invent facts, expand a transcript, or silently translate it.
- Use `SystemLanguageModel.default` and check availability before a model request. Never fall back to an external model, shell command, or HTTP service.
- Validate model responses before writing them. For text matching, require a verbatim excerpt and verify that it occurs in the reference before returning offsets.
- Document automatic language behavior as a heuristic wherever an API requires a locale before analysis.

## Testing requirements

- For every new feature or modification, update existing test files or add new ones as required to cover the changed behavior.
- Once all code changes are complete, unconditionally run the full test suite without waiting for user approval. Include opt-in Apple integration tests by setting `KVOICE_RUN_SYSTEM_TESTS=1`; report any tests that cannot run because a system prerequisite is unavailable.
- Add XCTest coverage for each command's required/optional arguments, output formats, path rules, defaults, and overwrite behavior.
- Test orchestration through fake protocol implementations, including operation order, optimization bypass, automatic language retry, timestamps, output encoding, and errors.
- Test pure text algorithms with Unicode, empty input, long text, and UTF-16 offset cases.
- Keep the default suite deterministic and offline. Tests must not require Apple Intelligence readiness, Speech assets, external services, or user files.
- Opt-in Apple integration tests use `KVOICE_RUN_SYSTEM_TESTS=1`, document prerequisites, and skip in the default unit suite.
- Do not weaken or delete a failing assertion to get a green build; correct the implementation or the expected behavior.

## Scope review

Before merging, confirm the CLI still has explicit input/output paths, README and generated help agree, source files stay within limits, and no dependency or capability expands personal-use scope.
