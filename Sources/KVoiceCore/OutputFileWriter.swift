import Foundation

enum OutputFileWriter {
  static func write(_ data: Data, to requestedURL: URL, force: Bool) throws -> URL {
    try FileManager.default.createDirectory(
      at: requestedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if force {
      try FileValidation.validateOutput(requestedURL, force: true)
      try data.write(to: requestedURL, options: .atomic)
      return requestedURL
    }

    var destination = try FileValidation.uniqueOutputURL(requestedURL, force: false)
    while true {
      let temporaryURL = requestedURL.deletingLastPathComponent()
        .appendingPathComponent(".kvoice-\(UUID().uuidString).tmp")
      try data.write(to: temporaryURL, options: .atomic)
      do {
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
      } catch {
        try? FileManager.default.removeItem(at: temporaryURL)
        guard FileManager.default.fileExists(atPath: destination.path) else { throw error }
        destination = try FileValidation.uniqueOutputURL(destination, force: false)
      }
    }
  }
}
