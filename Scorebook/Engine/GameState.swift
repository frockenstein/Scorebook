import Foundation

struct ReplayError: Error, LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct BatStats: Sendable {
    var pa = 0, ab = 0, r = 0, h = 0, rbi = 0, bb = 0, k = 0, hbp = 0
}

struct PitchStats: Sendable {
    var outs = 0, h = 0, r = 0, er = 0, bb = 0, k = 0, hbp = 0, pc = 0
    var inningsPitched: String { "\(outs / 3).\(outs % 3)" }
}

struct Player: Sendable {
    var info: PlayerInfo
    var kind: String
    var inning: Int
    var st = BatStats()
}

struct Pitcher: Sendable {
    var info: PlayerInfo
    var st = PitchStats()
}

/// One scorecard diamond: a single plate appearance and what became of the batter.
struct Cell: Sendable, Identifiable {
    var id: Int
    var slot: Int
    var pi: Int
    var inning: Int
    var res: PlayResult
    var main: String
    var sub: String
    var flip: Bool
    var reach = 0
    var out = 0
    var outAt = 0
    var outText = ""
    var scored = false
    var marks: [Int: String] = [:]
    var lob = false
    var pit = 0
    var pitches = ""
    var balls = 0
    var strikes = 0
    var rbi = 0
    /// What happened, in order: the at-bat itself, then each later advance or out.
    var story: [String] = []
}

struct LogEntry: Sendable, Identifiable {
    let id: Int
    let inning: Int
    let top: Bool
    let text: String
}

struct Notation: Sendable {
    var main: String
    var sub = ""
    var flip = false
}

enum Notate {
    static func display(_ res: PlayResult, _ fld: [Int]) -> Notation {
        let s = fld.map(String.init).joined(separator: "-")
        let last = fld.last.map(String.init) ?? ""
        switch res {
        case .single, .double, .triple, .homeRun: return Notation(main: res.rawValue)
        case .walk, .intentionalWalk, .hitByPitch, .catcherInterference: return Notation(main: res.rawValue)
        case .strikeout: return Notation(main: "K")
        case .strikeoutLooking: return Notation(main: "K", flip: true)
        case .strikeoutWildPitch: return Notation(main: "K", sub: "WP")
        case .strikeoutPassedBall: return Notation(main: "K", sub: "PB")
        case .strikeoutThrown: return Notation(main: "K", sub: s.isEmpty ? "2-3" : s)
        case .groundOut: return Notation(main: fld.count == 1 ? "\(fld[0])U" : (s.isEmpty ? "GO" : s))
        case .flyOut: return Notation(main: "F" + last)
        case .lineOut: return Notation(main: "L" + last)
        case .popOut: return Notation(main: "P" + last)
        case .sacFly: return Notation(main: "SF", sub: last)
        case .sacBunt: return Notation(main: "SH", sub: s)
        case .doublePlay: return Notation(main: s.isEmpty ? "DP" : s, sub: "DP")
        case .error: return Notation(main: "E" + (fld.first.map(String.init) ?? ""))
        case .fieldersChoice: return Notation(main: "FC", sub: s)
        }
    }

    static func count(_ pitches: String) -> (balls: Int, strikes: Int) {
        var b = 0, s = 0
        for c in pitches {
            switch c {
            case "B": b += 1
            case "C", "S": s += 1
            case "F": if s < 2 { s += 1 }
            default: break
            }
        }
        return (b, s)
    }
}

private struct PlayCtx {
    var isPA: Bool
    var bat = 0
    var res: PlayResult?
    var kind: AdvKind?
    var slot = 0
    var unearned = false
    var batIdx: Int?
    /// Short reason shown in a runner's story, e.g. "Tony's 1B" or "wild pitch".
    var cause = ""
}

private struct Resolution {
    var next: [Int?]
    var strand: [Int]
    var total: Int
    var scored: Int
}

private func bump(_ a: inout [Int], _ i: Int, _ n: Int) {
    while a.count <= i { a.append(0) }
    a[i] += n
}

/// Everything derived from replaying a game's event log.
struct GameState: Sendable {
    let innings: Int
    let names: Pair<String>

    var inning = 1
    var top = true
    var outs = 0
    /// Cell index (in the batting team's `cells`) of the runner on each base; index 0 unused.
    var bases: [Int?] = [nil, nil, nil, nil]
    var over = false
    var winner: TeamSide?
    var nextSlot = Pair(away: 0, home: 0)
    var curPit = Pair(away: 0, home: 0)
    var players: Pair<[[Player]]>
    var pitchers: Pair<[Pitcher]>
    var cells = Pair<[Cell]>(away: [], home: [])
    var runs = Pair<[Int]>(away: [], home: [])
    var hits = Pair<[Int]>(away: [], home: [])
    var lob = Pair<[Int]>(away: [], home: [])
    var errors = Pair(away: 0, home: 0)
    var log: [LogEntry] = []

    var batting: TeamSide { top ? .away : .home }
    var fielding: TeamSide { top ? .home : .away }

    init(game: Game) throws {
        innings = game.innings
        names = Pair(away: game.away.name, home: game.home.name)
        func roster(_ t: TeamSetup) -> [[Player]] {
            t.lineup.map { [Player(info: $0, kind: "start", inning: 1)] }
        }
        players = Pair(away: roster(game.away), home: roster(game.home))
        pitchers = Pair(away: [Pitcher(info: game.away.pitcher)], home: [Pitcher(info: game.home.pitcher)])
        for ev in game.events {
            if over { throw ReplayError("The game is over") }
            try apply(ev)
        }
    }

    /// Total runs for a side.
    func score(_ side: TeamSide) -> Int { runs[side].reduce(0, +) }
    func hitTotal(_ side: TeamSide) -> Int { hits[side].reduce(0, +) }
    func lobTotal(_ side: TeamSide) -> Int { lob[side].reduce(0, +) }

    func currentPlayer(_ side: TeamSide, _ slot: Int) -> Player { players[side][slot].last! }
    func runnerName(_ base: Int) -> String {
        guard let idx = bases[base] else { return "" }
        let c = cells[batting][idx]
        return players[batting][c.slot][c.pi].info.name
    }
    var runnersOnBase: Bool { bases[1...3].contains { $0 != nil } }
    var halfLabel: String { (top ? "Top " : "Bottom ") + ordinal(inning) }

    // MARK: apply

    private mutating func note(_ text: String) {
        log.append(LogEntry(id: log.count, inning: inning, top: top, text: text))
    }

    mutating func apply(_ ev: Event) throws {
        switch ev {
        case .pa(let p): try applyPA(p)
        case .adv(let a): try applyAdv(a)
        case .sub(let s):
            guard players[s.team].indices.contains(s.slot) else { throw ReplayError("Bad lineup slot") }
            players[s.team][s.slot].append(Player(info: s.player, kind: s.kind.rawValue, inning: inning))
            note("\(s.kind.rawValue): \(s.player.name) in for slot \(s.slot + 1) (\(names[s.team]))")
        case .pit(let c):
            pitchers[c.team].append(Pitcher(info: c.player))
            curPit[c.team] = pitchers[c.team].count - 1
            note("Pitching change: \(c.player.name) (\(names[c.team]))")
        }
    }

    private mutating func applyPA(_ ev: PlateAppearance) throws {
        let bt = batting, ft = fielding
        guard ev.team == bt else { throw ReplayError("The other team is batting") }
        guard ev.slot == nextSlot[bt] else { throw ReplayError("Wrong batter") }
        guard (0...4).contains(ev.bat) else { throw ReplayError("Choose where the batter ended up") }
        let pi = players[bt][ev.slot].count - 1
        let name = players[bt][ev.slot][pi].info.name
        let d = Notate.display(ev.res, ev.fld)
        let cnt = Notate.count(ev.pitches)
        let batIdx = cells[bt].count
        cells[bt].append(Cell(
            id: batIdx, slot: ev.slot, pi: pi, inning: inning, res: ev.res,
            main: d.main, sub: d.sub, flip: d.flip,
            reach: (1...3).contains(ev.bat) ? ev.bat : 0,
            pit: curPit[ft], pitches: ev.pitches, balls: cnt.balls, strikes: cnt.strikes,
            story: ["\(name) \(ev.res.verb)\(d.main == ev.res.rawValue && d.sub.isEmpty ? "" : " (\(d.main)\(d.sub.isEmpty ? "" : " " + d.sub))")"]
        ))
        let ctx = PlayCtx(isPA: true, bat: ev.bat, res: ev.res, slot: ev.slot, unearned: ev.unearned, batIdx: batIdx,
                          cause: "\(name)'s \(ev.res.rawValue)")
        let r = try resolve(ev.run, ctx)
        let cp = curPit[ft]
        pitchers[ft][cp].st.outs += r.total
        pitchers[ft][cp].st.pc += ev.pitches.count
        let rbi = ev.rbi ?? (ev.res.noRBI ? 0 : r.scored)
        cells[bt][batIdx].rbi = rbi
        players[bt][ev.slot][pi].st.rbi += rbi
        players[bt][ev.slot][pi].st.pa += 1
        if !ev.res.noAtBat { players[bt][ev.slot][pi].st.ab += 1 }
        if ev.res.isHit {
            players[bt][ev.slot][pi].st.h += 1
            pitchers[ft][cp].st.h += 1
            bump(&hits[bt], inning - 1, 1)
        }
        if ev.res == .walk || ev.res == .intentionalWalk { players[bt][ev.slot][pi].st.bb += 1; pitchers[ft][cp].st.bb += 1 }
        if ev.res == .hitByPitch { players[bt][ev.slot][pi].st.hbp += 1; pitchers[ft][cp].st.hbp += 1 }
        if ev.res.isStrikeout { players[bt][ev.slot][pi].st.k += 1; pitchers[ft][cp].st.k += 1 }
        if ev.res == .error { errors[ft] += 1 }
        nextSlot[bt] = (ev.slot + 1) % players[bt].count

        var text = "\(name) \(ev.res.verb)"
        if d.main != ev.res.rawValue || !d.sub.isEmpty { text += " [\(d.main)\(d.sub.isEmpty ? "" : " " + d.sub)]" }
        if r.scored > 0 { text += ", \(r.scored) run\(r.scored > 1 ? "s" : "") score\(r.scored > 1 ? "" : "s")" }
        if r.total - (ev.bat == 0 ? 1 : 0) > 0 { text += ", runner out" }
        note(text)
        finishPlay(r)
    }

    private mutating func applyAdv(_ ev: RunnerEvent) throws {
        let bt = batting, ft = fielding
        guard ev.team == bt else { throw ReplayError("The other team is batting") }
        guard ev.run.contains(where: { $0.to != $0.from }) else { throw ReplayError("Move at least one runner") }
        let r = try resolve(ev.run, PlayCtx(isPA: false, kind: ev.kind, cause: ev.kind.label.lowercased()))
        pitchers[ft][curPit[ft]].st.outs += r.total
        if ev.kind == .error { errors[ft] += 1 }
        let who = ev.run.filter { $0.to != $0.from }.map { runnerName($0.from) }.joined(separator: ", ")
        note("\(ev.kind.rawValue): \(who)\(r.scored > 0 ? " (\(r.scored) run\(r.scored > 1 ? "s" : ""))" : "")")
        finishPlay(r)
    }

    private static func place(_ next: inout [Int?], _ base: Int, _ idx: Int) throws {
        guard next[base] == nil else { throw ReplayError("Two runners on \(ordinal(base)) base") }
        next[base] = idx
    }

    private mutating func scoreRun(_ idx: Int, _ label: String, _ ctx: PlayCtx) {
        let bt = batting, ft = fielding
        cells[bt][idx].reach = 4
        cells[bt][idx].scored = true
        cells[bt][idx].marks[4] = label
        bump(&runs[bt], inning - 1, 1)
        let c = cells[bt][idx]
        let last = players[bt][c.slot].count - 1
        players[bt][c.slot][last].st.r += 1
        pitchers[ft][c.pit].st.r += 1
        if !(c.res == .error || ctx.unearned || ctx.kind == .error || ctx.kind == .passedBall) {
            pitchers[ft][c.pit].st.er += 1
        }
    }

    /// Moves runners (and the batter, for a PA). Returns the new base layout.
    private mutating func resolve(_ moves: [RunnerMove], _ ctx: PlayCtx) throws -> Resolution {
        let bt = batting
        var mv: [Int: RunnerMove] = [:]
        for m in moves {
            guard (1...3).contains(m.from), bases[m.from] != nil else { throw ReplayError("There is no runner on base \(m.from)") }
            guard mv[m.from] == nil else { throw ReplayError("A runner was moved twice") }
            guard (0...4).contains(m.to) else { throw ReplayError("Bad destination") }
            mv[m.from] = m
        }
        let runnerOuts = [3, 2, 1].filter { mv[$0]?.to == 0 }
        let batOut = ctx.isPA && ctx.bat == 0
        let total = runnerOuts.count + (batOut ? 1 : 0)
        guard outs + total <= 3 else { throw ReplayError("That would be more than three outs") }
        // No run counts if the third out is the batter or a force play.
        var drop = false
        if ctx.isPA, total > 0, outs + total == 3,
           batOut || ctx.res == .fieldersChoice || ctx.res == .doublePlay { drop = true }

        var next: [Int?] = [nil, nil, nil, nil]
        var strand: [Int] = []
        var scored = 0
        let label = ctx.isPA ? String(ctx.slot + 1) : (ctx.kind?.rawValue ?? "")

        for b in runnerOuts {
            let idx = bases[b]!
            outs += 1
            cells[bt][idx].out = outs
            cells[bt][idx].outAt = ctx.kind == .pickoff ? b : b + 1
            let f = mv[b]!.fld.map(String.init).joined(separator: "-")
            cells[bt][idx].outText = ctx.isPA
                ? (f.isEmpty ? "OUT" : f)
                : ((ctx.kind?.rawValue ?? "") + (f.isEmpty ? "" : " " + f))
            let spot = cells[bt][idx].outAt == 4 ? "home" : ordinal(cells[bt][idx].outAt)
            cells[bt][idx].story.append("Out at \(spot) — \(ctx.cause)\(f.isEmpty ? "" : " (\(f))")")
        }
        if batOut, let bi = ctx.batIdx {
            outs += 1
            cells[bt][bi].out = outs
        }
        for b in [3, 2, 1] {
            guard let idx = bases[b] else { continue }
            let to = mv[b]?.to ?? b
            if to == 0 { continue }
            if to < b { throw ReplayError("Runners cannot move backward") }
            if to == 4 {
                if drop { strand.append(idx) } else {
                    scoreRun(idx, label, ctx); scored += 1
                    cells[bt][idx].story.append("Scored — \(ctx.cause)")
                }
            } else if to == b {
                try Self.place(&next, b, idx)
            } else {
                cells[bt][idx].reach = to
                cells[bt][idx].marks[to] = label
                cells[bt][idx].story.append("To \(ordinal(to)) — \(ctx.cause)")
                try Self.place(&next, to, idx)
            }
        }
        if ctx.isPA, let bi = ctx.batIdx {
            if ctx.bat == 4 { scoreRun(bi, "", ctx); scored += 1; cells[bt][bi].story.append("Scored on the home run") }
            else if ctx.bat >= 1 { try Self.place(&next, ctx.bat, bi) }
        }
        return Resolution(next: next, strand: strand, total: total, scored: scored)
    }

    private mutating func finishPlay(_ r: Resolution) {
        let bt = batting
        bases = r.next
        if outs >= 3 {
            let left = r.strand + r.next.compactMap { $0 }
            bump(&lob[bt], inning - 1, left.count)
            for i in left { cells[bt][i].lob = true; cells[bt][i].story.append("Left on base") }
            let a = score(.away), h = score(.home)
            if top {
                if inning >= innings && h > a { over = true; winner = .home; return }
                top = false
            } else {
                if inning >= innings && a != h { over = true; winner = a > h ? .away : .home; return }
                top = true
                inning += 1
            }
            outs = 0
            bases = [nil, nil, nil, nil]
        } else if !top && inning >= innings && score(.home) > score(.away) {
            over = true
            winner = .home // walk-off
        }
    }
}

func ordinal(_ n: Int) -> String {
    let suffix: String
    switch (n % 100, n % 10) {
    case (11...13, _): suffix = "th"
    case (_, 1): suffix = "st"
    case (_, 2): suffix = "nd"
    case (_, 3): suffix = "rd"
    default: suffix = "th"
    }
    return "\(n)\(suffix)"
}
