import Foundation

public enum FileValidation {
  public static func resolvePath(_ value: String) -> URL {
    if value.hasPrefix("/") { return URL(fileURLWithPath: value).standardizedFileURL }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
      .appendingPathComponent(value).standardizedFileURL
  }

  public static func isDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }

  public static func validateInput(_ url: URL) throws {
    guard url.isFileURL, url.path.hasPrefix("/") else { throw KVoiceError.invalidPath(url.path) }
    guard FileManager.default.fileExists(atPath: url.path), !isDirectory(url),
      FileManager.default.isReadableFile(atPath: url.path)
    else { throw KVoiceError.missingInput(url) }
  }

  public static func validateInputDirectory(_ url: URL) throws {
    guard url.isFileURL, url.path.hasPrefix("/"), isDirectory(url),
      FileManager.default.isReadableFile(atPath: url.path)
    else { throw KVoiceError.missingInput(url) }
  }

  public static func validateOutput(_ url: URL, force: Bool) throws {
    guard url.isFileURL, url.path.hasPrefix("/") else { throw KVoiceError.invalidPath(url.path) }
    if FileManager.default.fileExists(atPath: url.path), isDirectory(url) {
      throw KVoiceError.unsupportedOutput("Output must be a file, not a directory: \(url.path)")
    }
  }

  public static func validateOutputDirectory(_ url: URL) throws {
    guard url.isFileURL, url.path.hasPrefix("/") else { throw KVoiceError.invalidPath(url.path) }
    if FileManager.default.fileExists(atPath: url.path), !isDirectory(url) {
      throw KVoiceError.unsupportedOutput(
        "Directory conversion output must be a directory: \(url.path)")
    }
  }

  public static func uniqueOutputURL(_ url: URL, force: Bool) throws -> URL {
    guard !force, FileManager.default.fileExists(atPath: url.path) else { return url }
    guard !isDirectory(url) else {
      throw KVoiceError.unsupportedOutput("Output must be a file, not a directory: \(url.path)")
    }
    let name = url.deletingPathExtension().lastPathComponent
    let fileExtension = url.pathExtension
    var copyCount = 1
    while true {
      let suffix = Array(repeating: "copy", count: copyCount).joined(separator: " ")
      let candidateName =
        fileExtension.isEmpty
        ? "\(name) \(suffix)" : "\(name) \(suffix).\(fileExtension)"
      let candidate = url.deletingLastPathComponent().appendingPathComponent(candidateName)
      if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
      copyCount += 1
    }
  }

  public static func requireDistinct(_ output: URL, from inputs: [URL]) throws {
    let resolvedOutput = output.standardizedFileURL.resolvingSymlinksInPath()
    guard
      !inputs.contains(where: {
        $0.standardizedFileURL.resolvingSymlinksInPath() == resolvedOutput
      })
    else {
      throw KVoiceError.invalidArguments(
        "The output path must differ from every input path: \(output.path)")
    }
  }

  public static func requireDirectoryDistinct(_ output: URL, from input: URL) throws {
    let inputPath = input.standardizedFileURL.resolvingSymlinksInPath().path
    let outputPath = output.standardizedFileURL.resolvingSymlinksInPath().path
    guard inputPath != outputPath else {
      throw KVoiceError.invalidArguments("Input and output directories must differ.")
    }
  }
}
