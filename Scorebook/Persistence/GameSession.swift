import Foundation
import Observation

/// The open game: its event log plus the state replayed from it.
@MainActor
@Observable
final class GameSession {
    private(set) var game: Game
    private(set) var state: GameState
    private let library: GameLibrary

    init(game: Game, library: GameLibrary) throws {
        self.game = game
        self.library = library
        self.state = try GameState(game: game)
    }

    var eventCount: Int { game.events.count }

    /// Returns an error message if the event isn't legal right now.
    func check(_ event: Event) -> String? {
        var g = game
        g.events.append(event)
        do { _ = try GameState(game: g); return nil } catch { return error.localizedDescription }
    }

    func commit(_ event: Event) throws {
        var g = game
        g.events.append(event)
        state = try GameState(game: g)
        game = g
        library.save(g)
    }

    func undo() {
        guard !game.events.isEmpty else { return }
        var g = game
        g.events.removeLast()
        guard let s = try? GameState(game: g) else { return }
        game = g
        state = s
        library.save(g)
    }
}
