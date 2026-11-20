# KVoice engineering standards

These standards define the architecture, scope, and maintenance requirements for KVoice. New code must support speech conversion, text optimization, language selection, timestamps, or text location.

## Architecture and responsibilities

- Keep the executable entry point thin: parse arguments, invoke one runner, and map errors to standard error and an exit status.
- Separate argument parsing, use-case orchestration, data models, filesystem policy, text algorithms, and Apple framework adapters.
- Give each type one primary reason to change. Each file should contain one cohesive type or a small set of closely related value types.
- Use protocols at framework boundaries so orchestration can be tested with fakes. Do not mock Foundation, Speech, or AVFoundation internals.
- Keep command execution as explicit operation steps. Extract helpers when control flow becomes deeply nested or a function coordinates unrelated services.
- Do not add plugin systems, configuration languages, databases, daemons, network clients, microphone recording, or unrelated application features.

## Complexity limits

- Swift code files must not exceed **300 physical lines**. Production files should not exceed **250 physical lines**. Split a file before a change would exceed its limit.
- Run `scripts/check-swift-file-limits.sh` to enforce these limits.
- A type should normally remain below 180 lines and a method below 40 lines.
- Avoid conditionals nested more than three levels. Prefer guard clauses, small private helpers, and explicit result types.
- Do not use force unwraps, `try!`, hidden global mutable state, or catch-and-ignore paths for required work.
- Do not duplicate option parsing, locale matching, output validation, or JSON serialization logic.

## Swift conventions

- Use Swift 6 language mode and structured concurrency. Values crossing task boundaries must be `Sendable` or protected by explicit synchronization.
- Prefer immutable `let` values. Use actors for shared mutable state. Any `@unchecked Sendable` type must document its lock invariant and keep mutable members private.
- Name APIs for their effect and units. Time values must identify seconds or use Core Media types; text offsets must identify UTF-16 when that is the coordinate system.
- Use typed errors with actionable descriptions. Avoid exposing raw implementation details when concise context is clearer.
- Keep the public API surface minimal. Internal helpers should be module-internal or private.
- Use Foundation, Speech, FoundationModels, and AVFoundation APIs directly. Do not call deprecated `SFSpeechRecognizer` or `NSSpeechSynthesizer` APIs.
- Format with `swift format`. Keep source files within the size limits after formatting.

## Files and paths

- Resolve relative CLI input and output paths against the current working directory, then validate and pass them as `URL` values.
- Preserve existing outputs by selecting a repeated `copy` filename suffix. `--force` explicitly opts into replacing the requested output. Write generated text and JSON atomically.
- Validate output format and input readability before expensive model or audio work.
- Encode JSON through one deterministic encoder configuration. Preserve raw and optimized text when an operation changes content.
- Report only data supplied by Apple APIs. Do not invent timestamps, confidence scores, language tags, or match ranges.

## Foundation Models and language handling

- Treat user-provided text as data in prompts and instruct the model not to follow instructions embedded in it.
- Keep prompts task-specific, concise, and bounded. Do not ask the model to invent facts, expand a transcript, or silently translate it.
- Use `SystemLanguageModel.default` and check availability before a model request. Do not fall back to an external model, shell command, or HTTP service.
- Validate model responses before writing them. For text matching, require a verbatim excerpt and verify that it occurs in the reference before returning offsets.
- Document automatic language behavior as a heuristic wherever an API requires a locale before analysis.

## Testing requirements

- For every new feature or behaviour change, update or add tests that cover the changed behaviour.
- Run the full test suite after code changes. Opt-in Apple integration tests use `KVOICE_RUN_SYSTEM_TESTS=1`; report when a system prerequisite prevents them from running.
- Add XCTest coverage for each command's required and optional arguments, output formats, path rules, defaults, and overwrite behaviour.
- Test orchestration through fake protocol implementations, including operation order, optimization bypass, automatic language retry, timestamps, output encoding, and errors.
- Test pure text algorithms with Unicode, empty input, long text, and UTF-16 offset cases.
- Keep the default suite deterministic and offline. Tests must not require Apple Intelligence readiness, Speech assets, external services, or user files.
- Opt-in Apple integration tests use `KVOICE_RUN_SYSTEM_TESTS=1`, document prerequisites, and skip in the default unit suite.
- Do not weaken or delete a failing assertion to obtain a passing build; correct the implementation or expected behaviour.

## Scope review

Before merging, confirm that the CLI still uses explicit input and output paths, the README agrees with generated help, source files stay within their limits, and no dependency or capability expands the project's documented scope.
