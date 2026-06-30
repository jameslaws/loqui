// swift-tools-version: 5.10
import PackageDescription

// Loqui — standalone macOS menu-bar dictation utility.
//
// macOS 15 minimum. On macOS 26+ it uses the premium SpeechAnalyzer engine
// (gated by `if #available(macOS 26, *)` in VoiceTranscriber); on 15–25 it falls
// back to SFSpeechRecognizer. Fallback verified-by-code; test on a pre-26 Mac.
//
// Sparkle provides auto-update (checks an appcast feed; see release.sh for the
// nested-framework signing that notarization requires).
let package = Package(
    name: "loqui",
    platforms: [.macOS("15.0")],
    products: [
        .executable(name: "loqui", targets: ["loqui"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "loqui",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/loqui",
            // Resources/Info.plist is BOTH copied into the bundle AND embedded
            // in the executable's __TEXT,__info_plist Mach-O section (linker
            // flags below). The embedded section is what AppKit/SwiftUI reads at
            // launch to get CFBundleIdentifier — without it, the bundle id is
            // nil and AppKit refuses to register windows. Excluded from the
            // resource copy so SwiftPM doesn't process the same file twice.
            // No `resources:` — the only resource was an unused PNG, and an SPM
            // resource bundle bakes the absolute build path into the binary
            // (visible via `strings`). The real app icon is AppIcon.icns, copied
            // into the bundle by assemble-app.sh / release.sh. Info.plist is still
            // embedded via the linker section below.
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/loqui/Resources/Info.plist",
                    // Find embedded frameworks (Sparkle) at Contents/Frameworks.
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                ], .when(platforms: [.macOS])),
            ]
        ),
    ]
)
