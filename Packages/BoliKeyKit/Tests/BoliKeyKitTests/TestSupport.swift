import Foundation
@testable import BoliKeyKit

func makeEngine(settings: KeyboardSettings = KeyboardSettings()) -> BoliKeyEngine {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent("bolikey-tests-\(UUID().uuidString)")
    let store = SharedStore(sharedDirectory: base.appendingPathComponent("shared"), privateDirectory: base.appendingPathComponent("private"))
    return BoliKeyEngine(store: store, settings: settings)
}
