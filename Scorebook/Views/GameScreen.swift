import SwiftUI

enum ActiveSheet: Identifiable {
    case entry, runner, sub, stats, games, newGame
    case cell(TeamSide, Int)
    var id: String {
        switch self {
        case .cell(let s, let i): "cell-\(s.rawValue)-\(i)"
        default: "\(self)"
        }
    }
}

struct GameScreen: View {
    let session: GameSession
    let library: GameLibrary
    let onOpen: (Game) -> Void
    @State private var side: TeamSide = .away
    @State private var sheet: ActiveSheet?

    private var state: GameState { session.state }

    var body: some View {
        VStack(spacing: 0) {
            scoreStrip
            statusStrip
            TeamTabs(names: state.names, selection: $side)
                .padding(.horizontal, 10).padding(.vertical, 6)
            BookView(state: state, side: side, onTapActive: openEntry, onTapCell: { sheet = .cell(side, $0) })
            bottomBar
        }
        .background(Theme.paper)
        .sensoryFeedback(.impact(weight: .light), trigger: session.eventCount)
        .onChange(of: state.top) { _, top in side = top ? .away : .home }
        .onAppear { side = state.batting }
        .sheet(item: $sheet) { which in
            switch which {
            case .entry:
                EntrySheet(session: session) { sheet = nil }
            case .cell(let s, let i): CellDetailSheet(state: state, side: s, cellID: i) { sheet = nil }
            case .runner: RunnerSheet(session: session) { sheet = nil }
            case .sub: SubSheet(session: session) { sheet = nil }
            case .stats: StatsSheet(state: state) { sheet = nil }
            case .games:
                GamesSheet(library: library, onOpen: { g in sheet = nil; onOpen(g) }, onNew: { sheet = .newGame }) { sheet = nil }
            case .newGame:
                NewGameView(onStart: { g in library.save(g); sheet = nil; onOpen(g) }, onCancel: { sheet = nil })
            }
        }
    }

    private func openEntry() {
        guard !state.over else { return }
        sheet = .entry
    }

    // MARK: header

    private var scoreStrip: some View {
        HStack {
            Button { sheet = .games } label: { Image(systemName: "books.vertical") }
            Spacer()
            HStack(spacing: 14) {
                ForEach(TeamSide.allCases) { s in
                    VStack(spacing: 0) {
                        HStack(spacing: 4) {
                            HomeAwayBadge(side: s, onDark: true, size: 17)
                            Text(state.names[s]).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        }
                        Text("\(state.score(s))").font(.system(size: 26, weight: .bold, design: .serif))
                    }
                    .frame(minWidth: 70)
                }
            }
            Spacer()
            Button { sheet = .stats } label: { Image(systemName: "list.bullet.rectangle") }
        }
        .font(.title3)
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.green, ignoresSafeAreaEdges: [])
    }

    private var statusStrip: some View {
        Group {
            if state.over, let w = state.winner {
                Text("Final — \(state.names[w]) wins \(state.score(w))–\(state.score(w.other))")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .frame(maxWidth: .infinity).padding(10).background(Theme.card).foregroundStyle(Theme.green)
            } else {
                Button(action: openEntry) {
                    HStack(spacing: 10) {
                        MiniDiamond(bases: state.bases.map { $0 != nil })
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(state.halfLabel).font(.system(size: 15, weight: .bold, design: .serif))
                                HStack(spacing: 3) {
                                    ForEach(0..<3, id: \.self) { i in
                                        Circle().strokeBorder(Theme.accent, lineWidth: 1.5)
                                            .background(Circle().fill(i < state.outs ? Theme.accent : .clear))
                                            .frame(width: 10, height: 10)
                                    }
                                }
                            }
                            let t = state.batting
                            Text("At bat: #\(state.nextSlot[t] + 1) \(state.currentPlayer(t, state.nextSlot[t]).info.name)")
                                .font(.system(size: 13)).foregroundStyle(Theme.ink)
                            if let last = state.log.last {
                                Text(last.text).font(.system(size: 11)).foregroundStyle(Theme.pencil).lineLimit(1)
                            }
                        }
                        Spacer()
                        Text("Score").font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.accent, in: Capsule()).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.card)
                    .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button("Runner") { sheet = .runner }.buttonStyle(.paper)
                .disabled(!state.runnersOnBase || state.over).opacity(state.runnersOnBase && !state.over ? 1 : 0.4)
            Button("Sub") { sheet = .sub }.buttonStyle(.paper)
            Button("Undo") { session.undo() }.buttonStyle(.paper)
                .disabled(session.eventCount == 0).opacity(session.eventCount == 0 ? 0.4 : 1)
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 6)
        .background(Theme.paper)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

struct MiniDiamond: View {
    let bases: [Bool]
    var body: some View {
        ZStack {
            baseMark(bases[2]).offset(y: -13)
            baseMark(bases[3]).offset(x: -17)
            baseMark(bases[1]).offset(x: 17)
            baseMark(false, plate: true).offset(y: 13)
        }
        .frame(width: 52, height: 40)
    }
    private func baseMark(_ on: Bool, plate: Bool = false) -> some View {
        Rectangle()
            .fill(on ? Theme.accent : Theme.card)
            .overlay(Rectangle().stroke(plate ? Theme.pencilLight : Theme.pencil, lineWidth: 1.2))
            .frame(width: 11, height: 11)
            .rotationEffect(.degrees(45))
    }
}
