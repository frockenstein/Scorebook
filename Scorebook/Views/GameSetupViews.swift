import SwiftUI
import UniformTypeIdentifiers

struct NewGameView: View {
    let onStart: (Game) -> Void
    var onCancel: (() -> Void)?
    @State private var game = Game(away: Game.blankTeam(""), home: Game.blankTeam(""))

    var body: some View {
        NavigationStack {
            Form {
                Picker("Innings", selection: $game.innings) {
                    ForEach([9, 7, 6, 5, 3], id: \.self) { Text("\($0)").tag($0) }
                }
                teamSection("Away", \.away)
                teamSection("Home", \.home)
            }
            .navigationTitle("New game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onCancel { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Play ball") {
                        var g = game
                        g.fillBlanks()
                        g.created = Date()
                        onStart(g)
                    }.fontWeight(.semibold)
                }
            }
        }
    }

    private func teamSection(_ title: String, _ kp: WritableKeyPath<Game, TeamSetup>) -> some View {
        Section(title) {
            TextField("\(title) team name", text: Binding(get: { game[keyPath: kp].name }, set: { game[keyPath: kp].name = $0 }))
            Stepper("Batting order: \(game[keyPath: kp].lineup.count)", onIncrement: {
                if game[keyPath: kp].lineup.count < 25 { game[keyPath: kp].lineup.append(PlayerInfo(name: "", num: "", pos: "EH")) }
            }, onDecrement: {
                if game[keyPath: kp].lineup.count > 4 { game[keyPath: kp].lineup.removeLast() }
            })
            ForEach(Array(game[keyPath: kp].lineup.indices), id: \.self) { i in
                HStack(spacing: 8) {
                    Text("\(i + 1)").foregroundStyle(Theme.green).fontWeight(.bold).frame(width: 16)
                    TextField("#", text: Binding(get: { game[keyPath: kp].lineup[i].num }, set: { game[keyPath: kp].lineup[i].num = $0 }))
                        .keyboardType(.numberPad).frame(width: 40)
                    TextField("Batter \(i + 1)", text: Binding(get: { game[keyPath: kp].lineup[i].name }, set: { game[keyPath: kp].lineup[i].name = $0 }))
                    Picker("", selection: Binding(get: { game[keyPath: kp].lineup[i].pos }, set: { game[keyPath: kp].lineup[i].pos = $0 })) {
                        ForEach(["P", "C", "1B", "2B", "3B", "SS", "LF", "CF", "RF", "DH", "EH"], id: \.self) { Text($0).tag($0) }
                    }.labelsHidden()
                }
            }
            HStack(spacing: 8) {
                Text("P").foregroundStyle(Theme.green).fontWeight(.bold).frame(width: 16)
                TextField("#", text: Binding(get: { game[keyPath: kp].pitcher.num }, set: { game[keyPath: kp].pitcher.num = $0 }))
                    .keyboardType(.numberPad).frame(width: 40)
                TextField("Starting pitcher", text: Binding(get: { game[keyPath: kp].pitcher.name }, set: { game[keyPath: kp].pitcher.name = $0 }))
            }
        }
    }
}

struct GamesSheet: View {
    let library: GameLibrary
    let onOpen: (Game) -> Void
    let onNew: () -> Void
    let dismiss: () -> Void
    @State private var importing = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(library.games) { g in
                    Button { onOpen(g) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(g.away.name) at \(g.home.name)").font(.system(size: 16, weight: .semibold, design: .serif))
                                Text(summary(g)).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if g.id == library.currentID { Image(systemName: "checkmark").foregroundStyle(Theme.green) }
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    .swipeActions {
                        Button(role: .destructive) { library.delete(g.id) } label: { Label("Delete", systemImage: "trash") }
                        if let url = library.exportURL(for: g) {
                            ShareLink(item: url) { Label("Export", systemImage: "square.and.arrow.up") }.tint(Theme.green)
                        }
                    }
                }
            }
            .overlay { if library.games.isEmpty { ContentUnavailableView("No games yet", systemImage: "baseball") } }
            .navigationTitle("Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done", action: dismiss) }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }
                    Button("New game", action: onNew).fontWeight(.semibold)
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result, let g = library.importGame(from: url) { onOpen(g) }
            }
        }
    }

    private func summary(_ g: Game) -> String {
        guard let s = try? GameState(game: g) else { return "Unreadable" }
        let score = "\(s.score(.away))–\(s.score(.home))"
        let when = g.created.formatted(date: .abbreviated, time: .omitted)
        return "\(when) · \(score) · \(s.over ? "Final" : s.halfLabel)"
    }
}
