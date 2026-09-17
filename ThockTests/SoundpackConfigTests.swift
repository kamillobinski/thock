import Testing
import Foundation
@testable import Thock

struct SoundpackConfigTests {

    private func decode(_ json: String) throws -> SoundpackConfig {
        try JSONDecoder().decode(SoundpackConfig.self, from: Data(json.utf8))
    }

    @Test func decodesAFullyPopulatedConfig() throws {
        let config = try decode("""
        {
          "id": "3F2504E0-4F89-41D3-9A0C-0305E82C3301",
          "metadata": {
            "name": "Topre",
            "brand": "Realforce",
            "author": "kamil",
            "category": "keyboard",
            "supportsKeyUp": true
          },
          "license": { "type": "MIT", "url": "https://example.com/license" },
          "sounds": {
            "a": { "down": ["a-down-1.wav", "a-down-2.wav"], "up": ["a-up.wav"] }
          }
        }
        """)

        #expect(config.id == UUID(uuidString: "3F2504E0-4F89-41D3-9A0C-0305E82C3301"))
        #expect(config.metadata.name == "Topre")
        #expect(config.metadata.brand == "Realforce")
        #expect(config.metadata.author == "kamil")
        #expect(config.metadata.category == "keyboard")
        #expect(config.metadata.supportsKeyUp == true)
        #expect(config.license.type == "MIT")
        #expect(config.sounds["a"]?.down == ["a-down-1.wav", "a-down-2.wav"])
        #expect(config.sounds["a"]?.up == ["a-up.wav"])
    }

    /// Older soundpacks omit `category`; it must fall back to "keyboard".
    @Test func categoryDefaultsToKeyboardWhenOmitted() throws {
        let config = try decode("""
        {
          "id": "3F2504E0-4F89-41D3-9A0C-0305E82C3302",
          "metadata": { "name": "Legacy", "brand": "b", "author": "a" },
          "license": { "type": "MIT", "url": "https://example.com" },
          "sounds": {}
        }
        """)

        #expect(config.metadata.category == "keyboard")
    }

    /// Older soundpacks omit `supportsKeyUp`; it must default to false.
    @Test func supportsKeyUpDefaultsToFalseWhenOmitted() throws {
        let config = try decode("""
        {
          "id": "3F2504E0-4F89-41D3-9A0C-0305E82C3303",
          "metadata": { "name": "Legacy", "brand": "b", "author": "a" },
          "license": { "type": "MIT", "url": "https://example.com" },
          "sounds": {}
        }
        """)

        #expect(config.metadata.supportsKeyUp == false)
    }

    @Test func decodesAnEmptySoundsMap() throws {
        let config = try decode("""
        {
          "id": "3F2504E0-4F89-41D3-9A0C-0305E82C3304",
          "metadata": { "name": "Empty", "brand": "b", "author": "a" },
          "license": { "type": "MIT", "url": "https://example.com" },
          "sounds": {}
        }
        """)

        #expect(config.sounds.isEmpty)
    }

    @Test func missingRequiredMetadataFieldThrows() {
        #expect(throws: (any Error).self) {
            try decode("""
            {
              "id": "3F2504E0-4F89-41D3-9A0C-0305E82C3305",
              "metadata": { "brand": "b", "author": "a" },
              "license": { "type": "MIT", "url": "https://example.com" },
              "sounds": {}
            }
            """)
        }
    }

    @Test func missingLicenseThrows() {
        #expect(throws: (any Error).self) {
            try decode("""
            {
              "id": "3F2504E0-4F89-41D3-9A0C-0305E82C3306",
              "metadata": { "name": "n", "brand": "b", "author": "a" },
              "sounds": {}
            }
            """)
        }
    }
}
