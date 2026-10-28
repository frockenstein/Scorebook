import Foundation

enum TeamSide: String, Codable, CaseIterable, Sendable, Identifiable {
    case away, home
    var id: String { rawValue }
    var other: TeamSide { self == .away ? .home : .away }
    /// "A" or "H" for compact labels.
    var letter: String { self == .away ? "A" : "H" }
}

/// One value per team, indexed by side.
struct Pair<T: Sendable>: Sendable {
    var away: T
    var home: T
    subscript(side: TeamSide) -> T {
        get { side == .away ? away : home }
        set { if side == .away { away = newValue } else { home = newValue } }
    }
}
extension Pair: Codable where T: Codable {}

struct PlayerInfo: Codable, Hashable, Sendable {
    var name: String
    var num: String = ""
    var pos: String = ""
}

struct TeamSetup: Codable, Sendable {
    var name: String
    var lineup: [PlayerInfo]
    var pitcher: PlayerInfo
}

enum PlayResult: String, Codable, Sendable, CaseIterable {
    case single = "1B", double = "2B", triple = "3B", homeRun = "HR"
    case walk = "BB", intentionalWalk = "IBB", hitByPitch = "HBP"
    case strikeout = "K", strikeoutLooking = "KC", strikeoutWildPitch = "KWP", strikeoutPassedBall = "KPB", strikeoutThrown = "KT"
    case groundOut = "GO", flyOut = "FO", lineOut = "LO", popOut = "PO"
    case sacFly = "SF", sacBunt = "SH", doublePlay = "DP"
    case error = "E", fieldersChoice = "FC", catcherInterference = "CI"

    /// Base the batter ends on: 0 out, 1–3 bases, 4 scores.
    var defaultBat: Int {
        switch self {
        case .single, .walk, .intentionalWalk, .hitByPitch, .strikeoutWildPitch, .strikeoutPassedBall,
             .error, .fieldersChoice, .catcherInterference: 1
        case .double: 2
        case .triple: 3
        case .homeRun: 4
        default: 0
        }
    }
    /// Fielders that must be tapped for the notation.
    var needsFielders: Int {
        switch self {
        case .groundOut, .flyOut, .lineOut, .popOut, .sacFly, .sacBunt, .error, .fieldersChoice: 1
        case .doublePlay, .strikeoutThrown: 2
        default: 0
        }
    }
    var isHit: Bool { [.single, .double, .triple, .homeRun].contains(self) }
    var noAtBat: Bool { [.walk, .intentionalWalk, .hitByPitch, .sacFly, .sacBunt, .catcherInterference].contains(self) }
    var isStrikeout: Bool { [.strikeout, .strikeoutLooking, .strikeoutThrown, .strikeoutWildPitch, .strikeoutPassedBall].contains(self) }
    var noRBI: Bool { [.error, .doublePlay, .strikeoutWildPitch, .strikeoutPassedBall, .strikeoutThrown].contains(self) }

    var verb: String {
        switch self {
        case .single: "singles"
        case .double: "doubles"
        case .triple: "triples"
        case .homeRun: "homers"
        case .walk: "walks"
        case .intentionalWalk: "is intentionally walked"
        case .hitByPitch: "is hit by a pitch"
        case .strikeout: "strikes out swinging"
        case .strikeoutLooking: "strikes out looking"
        case .strikeoutWildPitch: "strikes out, reaches on a wild pitch"
        case .strikeoutPassedBall: "strikes out, reaches on a passed ball"
        case .strikeoutThrown: "strikes out (thrown out)"
        case .groundOut: "grounds out"
        case .flyOut: "flies out"
        case .lineOut: "lines out"
        case .popOut: "pops out"
        case .sacFly: "hits a sacrifice fly"
        case .sacBunt: "sacrifices"
        case .doublePlay: "grounds into a double play"
        case .error: "reaches on an error"
        case .fieldersChoice: "reaches on a fielder's choice"
        case .catcherInterference: "reaches on catcher's interference"
        }
    }
}

struct RunnerMove: Codable, Hashable, Sendable {
    var from: Int
    /// 0 = out, 1–3 = base, 4 = scores
    var to: Int
    var fld: [Int] = []
}

struct PlateAppearance: Codable, Sendable {
    var team: TeamSide
    var slot: Int
    var res: PlayResult
    var fld: [Int] = []
    var pitches: String = ""
    var bat: Int
    var run: [RunnerMove] = []
    var unearned: Bool = false
    var rbi: Int? = nil
}

enum AdvKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case stolenBase = "SB", caughtStealing = "CS", pickoff = "PO", wildPitch = "WP", passedBall = "PB"
    case balk = "BK", defensiveIndifference = "DI", otherAdvance = "OA", error = "E"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .stolenBase: "Stolen base"
        case .caughtStealing: "Caught stealing"
        case .pickoff: "Pickoff"
        case .wildPitch: "Wild pitch"
        case .passedBall: "Passed ball"
        case .balk: "Balk"
        case .defensiveIndifference: "Def. indifference"
        case .otherAdvance: "Other advance"
        case .error: "Error"
        }
    }
}

struct RunnerEvent: Codable, Sendable {
    var team: TeamSide
    var kind: AdvKind
    var run: [RunnerMove]
}

enum SubKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case pinchHitter = "PH", pinchRunner = "PR", defensive = "DEF"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pinchHitter: "Pinch hitter"
        case .pinchRunner: "Pinch runner"
        case .defensive: "Defensive"
        }
    }
}

struct Substitution: Codable, Sendable {
    var team: TeamSide
    var slot: Int
    var kind: SubKind
    var player: PlayerInfo
}

struct PitchingChange: Codable, Sendable {
    var team: TeamSide
    var player: PlayerInfo
}

enum Event: Codable, Sendable {
    case pa(PlateAppearance)
    case adv(RunnerEvent)
    case sub(Substitution)
    case pit(PitchingChange)
}

struct Game: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var created: Date = Date()
    var innings: Int = 9
    var away: TeamSetup
    var home: TeamSetup
    var events: [Event] = []

    func team(_ side: TeamSide) -> TeamSetup { side == .away ? away : home }

    static let defaultPositions = ["CF", "SS", "RF", "1B", "LF", "3B", "2B", "C", "P"]

    static func blankTeam(_ name: String, batters: Int = 9) -> TeamSetup {
        TeamSetup(
            name: name,
            lineup: (0..<batters).map { PlayerInfo(name: "", num: "", pos: $0 < defaultPositions.count ? defaultPositions[$0] : "EH") },
            pitcher: PlayerInfo(name: "", num: "", pos: "P")
        )
    }

    /// Fills in generic names for anything left blank.
    mutating func fillBlanks() {
        for side in TeamSide.allCases {
            var t = team(side)
            if t.name.trimmingCharacters(in: .whitespaces).isEmpty { t.name = side == .away ? "Away" : "Home" }
            for i in t.lineup.indices where t.lineup[i].name.trimmingCharacters(in: .whitespaces).isEmpty {
                t.lineup[i].name = "Batter \(i + 1)"
            }
            if t.pitcher.name.trimmingCharacters(in: .whitespaces).isEmpty { t.pitcher.name = "Starter" }
            if side == .away { away = t } else { home = t }
        }
    }
}
