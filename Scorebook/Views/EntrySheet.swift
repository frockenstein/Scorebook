import SwiftUI
import Observation

/// Drives scoring one at-bat: result → fielders (outs) → a question per ambiguous runner → record.
@MainActor
@Observable
final class EntryFlow {
    enum Step: Equatable {
        case results, more, fielders, ask(Int), askOut(Int), error(String)
    }

    var step: Step = .results
    var res: PlayResult?
    var fld: [Int] = []
    var pitches = ""
    var plans: [RunnerPlan] = []
    var outFld: [Int: [Int]] = [:]
    var outPick: [Int] = []
    private var queue: [Int] = []
    private let session: GameSession
    private let onDone: () -> Void

    init(session: GameSession, onDone: @escaping () -> Void) {
        self.session = session
        self.onDone = onDone
    }

    var state: GameState { session.state }
    var count: (balls: Int, strikes: Int) { Notate.count(pitches) }

    func pitch(_ c: Character) {
        pitches.append(c)
        let n = count
        if n.balls >= 4 { choose(.walk) }
        else if n.strikes >= 3 && (c == "C" || c == "S") { choose(c == "C" ? .strikeoutLooking : .strikeout) }
    }
    func undoPitch() { if !pitches.isEmpty { pitches.removeLast() } }

    func choose(_ r: PlayResult) {
        res = r
        fld = []
        r.needsFielders > 0 ? (step = .fielders) : plan()
    }

    func fieldersDone() { plan() }

    private func plan() {
        guard let res else { return }
        plans = Planner.plan(state, res)
        queue = plans.filter(\.ask).map(\.base)
        next()
    }

    private func next() {
        if let b = queue.first { step = .ask(b) } else { commit() }
    }

    func answer(base: Int, to: Int) {
        guard let i = plans.firstIndex(where: { $0.base == base }) else { return }
        plans[i].to = to
        if to == 0 { outPick = []; step = .askOut(base) } else { queue.removeFirst(); next() }
    }

    func outDone(base: Int) {
        outFld[base] = outPick
        queue.removeFirst()
        next()
    }

    func restartQuestions() {
        outFld = [:]
        plan()
    }

    private func commit() {
        guard let res else { return }
        let moves = plans.filter { $0.to != $0.base }.map { p -> RunnerMove in
            RunnerMove(from: p.base, to: p.to,
                       fld: p.to == 0 ? (outFld[p.base] ?? Planner.outFielders(res, fld)) : [])
        }
        let state = session.state
        let team = state.batting
        let ev = Event.pa(PlateAppearance(team: team, slot: state.nextSlot[team], res: res, fld: fld,
                                          pitches: pitches, bat: res.defaultBat, run: moves))
        do {
            try session.commit(ev)
            onDone()
        } catch {
            step = .error(error.localizedDescription)
        }
    }
}

struct EntrySheet: View {
    @State private var flow: EntryFlow
    let dismiss: () -> Void

    init(session: GameSession, dismiss: @escaping () -> Void) {
        _flow = State(initialValue: EntryFlow(session: session, onDone: dismiss))
        self.dismiss = dismiss
    }

    private var state: GameState { flow.state }
    private var batter: Player { state.currentPlayer(state.batting, state.nextSlot[state.batting]) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch flow.step {
                    case .results: results
                    case .more: more
                    case .fielders: fielders
                    case .ask(let b): ask(b)
                    case .askOut(let b): askOut(b)
                    case .error(let m): errorView(m)
                    }
                }
                .padding(14)
            }
        }
        .background(Theme.paper)
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("#\(state.nextSlot[state.batting] + 1) \(batter.info.name)")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                Text("\(state.halfLabel) · \(state.outs) out")
                    .font(.footnote).opacity(0.85)
            }
            Spacer()
            if flow.step != .results {
                Button("Back") { flow.step = .results; flow.res = nil }.foregroundStyle(.white.opacity(0.9))
            }
            Button { dismiss() } label: { Image(systemName: "xmark").font(.title3) }
                .padding(.leading, 12)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Theme.green)
    }

    // MARK: results

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            countStrip
            grid([.single, .double, .triple, .homeRun, .walk, .strikeout], subs: ["Single", "Double", "Triple", "Home run", "Walk", "Strikeout"])
            HStack(spacing: 8) {
                Button { flow.choose(.groundOut) } label: { stack("Ground", "out") }.buttonStyle(.danger)
                Button { flow.choose(.flyOut) } label: { stack("Fly", "out") }.buttonStyle(.danger)
                Button { flow.step = .more } label: { stack("More…", "E, FC, DP, SF") }.buttonStyle(.paper)
            }
        }
    }

    private func stack(_ a: String, _ b: String) -> some View {
        VStack(spacing: 1) { Text(a); Text(b).font(.system(size: 10, weight: .regular)).opacity(0.7) }
    }

    private func grid(_ rs: [PlayResult], subs: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(rs.enumerated()), id: \.offset) { i, r in
                Button { flow.choose(r) } label: { stack(r.rawValue, subs[i]) }
                    .buttonStyle(r.isStrikeout ? .danger : .paper)
            }
        }
    }

    private var countStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Count (optional)").font(.caption).foregroundStyle(Theme.pencil)
                Spacer()
                Text("\(flow.count.balls)–\(flow.count.strikes)")
                    .font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(Theme.ink)
                if !flow.pitches.isEmpty { Button("Undo") { flow.undoPitch() }.font(.caption).foregroundStyle(Theme.accent) }
            }
            HStack(spacing: 8) {
                small("Ball") { flow.pitch("B") }
                small("Called K") { flow.pitch("C") }
                small("Swing K") { flow.pitch("S") }
                small("Foul") { flow.pitch("F") }
            }
        }
    }

    private func small(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(t, action: action)
            .font(.system(size: 13, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line))
            .foregroundStyle(Theme.ink)
    }

    // MARK: more

    private var more: some View {
        VStack(alignment: .leading, spacing: 10) {
            group("Reach base", [(.error, "Error"), (.fieldersChoice, "Fielder's choice"), (.hitByPitch, "Hit by pitch"),
                                 (.intentionalWalk, "Int. walk"), (.catcherInterference, "Catcher int.")])
            group("Outs", [(.doublePlay, "Double play"), (.sacFly, "Sac fly"), (.sacBunt, "Sac bunt"),
                           (.lineOut, "Line out"), (.popOut, "Pop out")])
            group("Strikeouts", [(.strikeoutLooking, "Looking"), (.strikeoutWildPitch, "K + wild pitch"),
                                 (.strikeoutPassedBall, "K + passed ball"), (.strikeoutThrown, "K + thrown out")])
        }
    }

    private func group(_ title: String, _ items: [(PlayResult, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Theme.pencil)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(items, id: \.0) { r, label in
                    Button { flow.choose(r) } label: { stack(r.rawValue, label) }.buttonStyle(.paper)
                }
            }
        }
    }

    // MARK: fielders

    private var fielders: some View {
        let need = flow.res?.needsFielders ?? 1
        let title = flow.res.map { $0.verb.prefix(1).uppercased() + $0.verb.dropFirst() } ?? ""
        return VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(Theme.ink)
            FieldPicker(sequence: $flow.fld, height: 290)
            Button(flow.fld.count >= need ? "Record" : (need > 1 ? "Tap at least \(need) fielders" : "Tap a fielder")) {
                flow.fieldersDone()
            }
            .buttonStyle(.prominent)
            .disabled(flow.fld.count < need)
            .opacity(flow.fld.count < need ? 0.4 : 1)
        }
    }

    // MARK: runner questions

    private func ask(_ base: Int) -> some View {
        let plan = flow.plans.first { $0.base == base }!
        let opts = destinations(from: base)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Runner on \(ordinal(base))").font(.caption).foregroundStyle(Theme.pencil)
            Text(state.runnerName(base)).font(.system(size: 24, weight: .semibold, design: .serif)).foregroundStyle(Theme.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(opts, id: \.to) { o in
                    Button(o.label) { flow.answer(base: base, to: o.to) }
                        .buttonStyle(o.to == plan.to ? .prominent : (o.to == 0 ? .danger : .paper))
                }
            }
        }
    }

    private func destinations(from b: Int) -> [(to: Int, label: String)] {
        var o: [(Int, String)] = []
        for t in (b + 1)...4 { o.append((t, t == 4 ? "Scores" : "To \(ordinal(t))")) }
        o.insert((b, "Holds at \(ordinal(b))"), at: 0)
        o.append((0, "Out"))
        return o.map { (to: $0.0, label: $0.1) }
    }

    private func askOut(_ base: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(state.runnerName(base)) is out").font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(Theme.ink)
            Text("Who made the play? (optional)").font(.caption).foregroundStyle(Theme.pencil)
            FieldPicker(sequence: $flow.outPick, height: 260)
            Button("Done") { flow.outDone(base: base) }.buttonStyle(.prominent)
        }
    }

    private func errorView(_ m: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(m).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.99, green: 0.91, blue: 0.89), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Color(red: 0.54, green: 0.16, blue: 0.08))
            Button("Answer again") { flow.restartQuestions() }.buttonStyle(.prominent)
            Button("Start over") { flow.step = .results; flow.res = nil }.buttonStyle(.paper)
        }
    }
}
