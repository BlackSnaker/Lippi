import Foundation
import Testing
@testable import Lippi

struct BonsaiConfigurationTests {
    @Test("Uses the pinned PrismML model artifact")
    func usesPinnedArtifact() {
        let model = BonsaiModelDescriptor.recommended

        #expect(model.displayName == "Bonsai 4B 1-bit")
        #expect(model.byteCount == 572_270_624)
        #expect(model.downloadURL.host == "huggingface.co")
        #expect(model.downloadURL.path.contains(model.revision))
        #expect(model.downloadURL.lastPathComponent == model.fileName)
        #expect(model.sha256.count == 64)
    }

    @Test("Migrates the former Mac provider to on-device Bonsai")
    func migratesFromOllama() {
        let defaults = UserDefaults.standard
        let legacyKey = "ollama.provider.enabled"
        let previousLegacy = defaults.object(forKey: legacyKey)
        let previousEnabled = defaults.object(forKey: BonsaiConfiguration.enabledKey)
        let previousMigration = defaults.object(forKey: BonsaiConfiguration.migrationKey)

        defer {
            restore(previousLegacy, key: legacyKey, defaults: defaults)
            restore(previousEnabled, key: BonsaiConfiguration.enabledKey, defaults: defaults)
            restore(previousMigration, key: BonsaiConfiguration.migrationKey, defaults: defaults)
        }

        defaults.set(true, forKey: legacyKey)
        defaults.removeObject(forKey: BonsaiConfiguration.enabledKey)
        defaults.removeObject(forKey: BonsaiConfiguration.migrationKey)

        let configuration = BonsaiConfiguration.stored
        #expect(configuration.isEnabled)
        #expect(!defaults.bool(forKey: legacyKey))
        #expect(defaults.bool(forKey: BonsaiConfiguration.migrationKey))
    }

    private func restore(_ value: Any?, key: String, defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
