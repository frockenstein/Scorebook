import SwiftUI

// MARK: runner events (steals, wild pitches, pickoffs …)

struct RunnerSheet: View {
    let session: GameSession
    let dismiss: () -> Void
    @State private var kind: AdvKind = .stolenBase
    @State private var moves: [Int: Int] = [:]
    @State private var outFld: [Int] = []
    @State private var error: String?

    private var state: GameState { session.state }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("What happened").font(.caption).foregroundStyle(Theme.pencil)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(AdvKind.allCases) { k in
                            Button { kind = k; moves = Planner.adv(state, k); outFld = [] } label: {
                                VStack(spacing: 1) { Text(k.rawValue); Text(k.label).font(.system(size: 9, weight: .regular)).lineLimit(1) }
                            }
                            .buttonStyle(k == kind ? .prominent : .paper)
                        }
                    }
                    Text("Runners").font(.caption).foregroundStyle(Theme.pencil)
                    ForEach([3, 2, 1], id: \.self) { b in
                        if state.bases[b] != nil { runnerRow(b) }
                    }
                    if moves.values.contains(0) {
                        Text("Who made the play? (optional)").font(.caption).foregroundStyle(Theme.pencil)
                        FieldPicker(sequence: $outFld, height: 200)
                    }
                    if let error {
                        Text(error).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 0.99, green: 0.91, blue: 0.89), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Color(red: 0.54, green: 0.16, blue: 0.08))
                    }
                    Button("Record") { record() }.buttonStyle(.prominent)
                }
                .padding(14)
            }
            .background(Theme.paper)
            .navigationTitle("Runner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss) } }
        }
        .onAppear { moves = Planner.adv(state, kind) }
    }

    private func runnerRow(_ b: Int) -> some View {
        let cur = moves[b] ?? b
        var opts: [(Int, String)] = [(b, "Holds")]
        if b < 3 { for t in (b + 1)...3 { opts.append((t, ordinal(t))) } }
        opts.append((4, "Scores")); opts.append((0, "Out"))
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(ordinal(b)) — \(state.runnerName(b))").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
            HStack(spacing: 6) {
                ForEach(opts, id: \.0) { to, label in
                    Button(label) { moves[b] = to }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(cur == to ? (to == 0 ? Theme.accent : Theme.green) : Theme.card, in: Capsule())
                        .overlay(Capsule().stroke(Theme.line))
                        .foregroundStyle(cur == to ? .white : Theme.ink)
                }
            }
        }
    }

    private func record() {
        let run = moves.filter { $0.key != $0.value }.sorted { $0.key > $1.key }
            .map { RunnerMove(from: $0.key, to: $0.value, fld: $0.value == 0 ? outFld : []) }
        let ev = Event.adv(RunnerEvent(team: state.batting, kind: kind, run: run))
        do { try session.commit(ev); dismiss() } catch { self.error = error.localizedDescription }
    }
}

// MARK: substitutions

struct SubSheet: View {
    let session: GameSession
    let dismiss: () -> Void
    @State private var pitching = false
    @State private var team: TeamSide
    @State private var slot: Int
    @State private var kind: SubKind = .pinchHitter
    @State private var name = ""
    @State private var num = ""
    @State private var pos = ""
    @State private var error: String?

    init(session: GameSession, dismiss: @escaping () -> Void) {
        self.session = session
        self.dismiss = dismiss
        _team = State(initialValue: session.state.batting)
        _slot = State(initialValue: session.state.nextSlot[session.state.batting])
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $pitching) {
                    Text("Batter / fielder").tag(false)
                    Text("Pitching change").tag(true)
                }.pickerStyle(.segmented)
                Picker("Team", selection: $team) {
                    ForEach(TeamSide.allCases) { Text(session.state.names[$0]).tag($0) }
                }.pickerStyle(.segmented)
                if !pitching {
                    Picker("Replaces", selection: $slot) {
                        ForEach(0..<session.state.players[team].count, id: \.self) { i in
                            let p = session.state.currentPlayer(team, i)
                            Text("\(i + 1). \(p.info.name) \(p.info.pos)").tag(i)
                        }
                    }
                    Picker("Kind", selection: $kind) {
                        ForEach(SubKind.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("New player") {
                    TextField("Name", text: $name)
                    TextField("Number", text: $num).keyboardType(.numberPad)
                    if !pitching {
                        Picker("Position", selection: $pos) {
                            ForEach(["", "P", "C", "1B", "2B", "3B", "SS", "LF", "CF", "RF", "DH", "EH"], id: \.self) { Text($0.isEmpty ? "—" : $0).tag($0) }
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(Theme.accent) }
            }
            .navigationTitle("Substitution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss) }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { record() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
        }
    }

    private func record() {
        let p = PlayerInfo(name: name.trimmingCharacters(in: .whitespaces), num: num, pos: pitching ? "P" : pos)
        let ev: Event = pitching
            ? .pit(PitchingChange(team: team, player: p))
            : .sub(Substitution(team: team, slot: slot, kind: kind, player: p))
        do { try session.commit(ev); dismiss() } catch { self.error = error.localizedDescription }
    }
}

// MARK: stats and play-by-play

struct StatsSheet: View {
    let state: GameState
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(TeamSide.allCases) { side in
                    Section("\(state.names[side]) pitching") {
                        HStack { Text("").frame(maxWidth: .infinity, alignment: .leading); cols(["IP", "H", "R", "ER", "BB", "K", "P"], bold: true) }
                        ForEach(Array(state.pitchers[side].enumerated()), id: \.offset) { _, p in
                            HStack {
                                Text(p.info.name + (p.info.num.isEmpty ? "" : " #" + p.info.num)).frame(maxWidth: .infinity, alignment: .leading)
                                cols([p.st.inningsPitched, "\(p.st.h)", "\(p.st.r)", "\(p.st.er)", "\(p.st.bb)", "\(p.st.k)", p.st.pc == 0 ? "–" : "\(p.st.pc)"])
                            }
                        }
                    }
                    .font(.system(size: 13))
                }
                Section("Play by play") {
                    ForEach(state.log.reversed()) { e in
                        Text("\(e.top ? "▲" : "▼")\(e.inning)  \(e.text)").font(.system(size: 13))
                    }
                }
            }
            .navigationTitle("Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: dismiss) } }
        }
    }

    private func cols(_ v: [String], bold: Bool = false) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(v.enumerated()), id: \.offset) { _, s in
                Text(s).frame(width: 30).fontWeight(bold ? .semibold : .regular).foregroundStyle(bold ? Theme.pencil : .primary)
            }
        }.monospacedDigit()
    }
}
