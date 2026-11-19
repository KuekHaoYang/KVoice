// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "KVoice",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "KVoice", targets: ["KVoiceCLI"]),
        .library(name: "KVoiceCore", targets: ["KVoiceCore"])
    ],
    targets: [
        .target(name: "KVoiceCore"),
        .executableTarget(name: "KVoiceCLI", dependencies: ["KVoiceCore"]),
        .testTarget(name: "KVoiceCoreTests", dependencies: ["KVoiceCore"])
    ],
    swiftLanguageModes: [.v6]
)
