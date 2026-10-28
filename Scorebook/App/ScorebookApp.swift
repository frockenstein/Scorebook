import SwiftUI

@main
struct ScorebookApp: App {
    @State private var library = GameLibrary()

    var body: some Scene {
        WindowGroup {
            RootView(library: library)
                .preferredColorScheme(.light)
                .tint(Theme.green)
        }
    }
}

struct RootView: View {
    let library: GameLibrary
    @State private var session: GameSession?

    var body: some View {
        Group {
            if let session {
                GameScreen(session: session, library: library, onOpen: open)
                    .id(session.game.id)
            } else {
                NewGameView(onStart: { g in library.save(g); open(g) })
            }
        }
        .onAppear {
            guard session == nil, let g = library.current ?? library.games.first else { return }
            open(g)
        }
    }

    private func open(_ game: Game) {
        guard let s = try? GameSession(game: game, library: library) else { return }
        library.currentID = game.id
        session = s
    }
}
