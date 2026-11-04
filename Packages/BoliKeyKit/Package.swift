// swift-tools-version:5.10
import PackageDescription

let engineTargets: [(name: String, deps: [String])] = [
    ("HinglishEngine", ["LanguageCore"]),
    ("LanguageDetectionEngine", ["LanguageCore"]),
    ("TransliterationEngine", ["LanguageCore"]),
    ("StorageEngine", []),
    ("PersonalizationEngine", ["LanguageCore", "StorageEngine"]),
    ("CorrectionEngine", ["LanguageCore", "HinglishEngine", "LanguageDetectionEngine", "PersonalizationEngine"]),
    ("PredictionEngine", ["LanguageCore", "HinglishEngine", "LanguageDetectionEngine", "PersonalizationEngine"]),
    ("AIWritingEngine", ["LanguageCore", "HinglishEngine"]),
    ("KeyboardInputEngine", []),
    ("PrivacyManager", ["StorageEngine", "PersonalizationEngine"]),
]

let package = Package(
    name: "BoliKeyKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BoliKeyKit", targets: ["BoliKeyKit"]),
        .library(name: "KeyboardUI", targets: ["KeyboardUI"]),
    ],
    targets: [
        .target(name: "LanguageCore", resources: [.copy("Resources")]),
    ]
    + engineTargets.map { .target(name: $0.name, dependencies: $0.deps.map { .byName(name: $0) }) }
    + [
        .target(name: "BoliKeyKit", dependencies: engineTargets.map { .byName(name: $0.name) } + ["LanguageCore"]),
        .target(name: "KeyboardUI", dependencies: ["BoliKeyKit"]),
        .testTarget(name: "BoliKeyKitTests", dependencies: ["BoliKeyKit"]),
    ]
)
