import Testing
@testable import Thock

struct PipeCommandTests {

    @Test func tokenizesABareCommand() {
        #expect(PipeListenerService.tokenize("set-enabled true") == ["set-enabled", "true"])
    }

    @Test func tokenizesSetSoundpackWithAUUID() {
        let command = "set-soundpack 550E8400-E29B-41D4-A716-446655440000"
        #expect(PipeListenerService.tokenize(command) == [
            "set-soundpack",
            "550E8400-E29B-41D4-A716-446655440000"
        ])
    }

    /// thock-cli always writes both tokens quoted, so quotes must be stripped.
    @Test func stripsSurroundingQuotes() {
        #expect(PipeListenerService.tokenize("\"set-soundpack\" \"abc-123\"") == [
            "set-soundpack",
            "abc-123"
        ])
    }

    @Test func keepsQuotedValuesWithSpacesAsOneToken() {
        #expect(PipeListenerService.tokenize("\"set-soundpack\" \"My Pack Name\"") == [
            "set-soundpack",
            "My Pack Name"
        ])
    }

    @Test func ignoresRepeatedAndSurroundingWhitespace() {
        #expect(PipeListenerService.tokenize("   set-enabled    true   ") == ["set-enabled", "true"])
    }

    @Test func returnsEmptyArrayForBlankInput() {
        #expect(PipeListenerService.tokenize("").isEmpty)
        #expect(PipeListenerService.tokenize("   ").isEmpty)
    }

    @Test func preservesExtraArgumentsInOrder() {
        #expect(PipeListenerService.tokenize("cmd one two three") == ["cmd", "one", "two", "three"])
    }

    /// An unterminated quote still yields a token rather than dropping the argument.
    @Test func handlesUnterminatedQuote() {
        let tokens = PipeListenerService.tokenize("\"set-enabled true")
        #expect(tokens.isEmpty == false)
        #expect(tokens.first == "\"set-enabled")
    }
}
