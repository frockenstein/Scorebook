import Foundation

/// What should happen to one runner on a play. `ask == true` means the app can't
/// know, so the user gets a one-line question with `to` pre-selected.
struct RunnerPlan: Sendable {
    var base: Int
    var to: Int
    var ask = false
}

enum Planner {
    /// Default runner outcomes for a result. Forced advances are decided here;
    /// only genuinely ambiguous runners are marked `ask`.
    static func plan(_ s: GameState, _ res: PlayResult) -> [RunnerPlan] {
        let b = s.bases
        let occ = [3, 2, 1].filter { b[$0] != nil }
        guard !occ.isEmpty else { return [] }
        let f1 = b[1] != nil
        let f2 = f1 && b[2] != nil
        let f3 = f2 && b[3] != nil
        func forced(_ k: Int) -> Bool { k == 1 ? f1 : k == 2 ? f2 : f3 }
        func up(_ k: Int, _ n: Int = 1) -> Int { min(4, k + n) }
        let lead = f3 ? 3 : f2 ? 2 : f1 ? 1 : 0

        var plans: [RunnerPlan] = occ.map { k in
            switch res {
            case .single:
                return forced(k) ? RunnerPlan(base: k, to: up(k)) : RunnerPlan(base: k, to: up(k), ask: true)
            case .double:
                return k == 1 ? RunnerPlan(base: k, to: 3, ask: true) : RunnerPlan(base: k, to: 4)
            case .triple, .homeRun:
                return RunnerPlan(base: k, to: 4)
            case .walk, .intentionalWalk, .hitByPitch, .strikeoutWildPitch, .strikeoutPassedBall, .catcherInterference:
                return RunnerPlan(base: k, to: forced(k) ? up(k) : k)
            case .error:
                return forced(k) ? RunnerPlan(base: k, to: up(k)) : RunnerPlan(base: k, to: up(k), ask: true)
            case .groundOut:
                return RunnerPlan(base: k, to: forced(k) ? up(k) : k, ask: true)
            case .flyOut:
                return k == 1 ? RunnerPlan(base: k, to: k) : RunnerPlan(base: k, to: k, ask: true)
            case .sacFly:
                return RunnerPlan(base: k, to: k == 3 ? 4 : k)
            case .sacBunt:
                return RunnerPlan(base: k, to: up(k))
            case .fieldersChoice:
                if lead == 0 { return RunnerPlan(base: k, to: k == occ[0] ? 0 : k, ask: k == occ[0]) }
                if k == lead { return RunnerPlan(base: k, to: 0) }
                return forced(k) ? RunnerPlan(base: k, to: up(k)) : RunnerPlan(base: k, to: k, ask: true)
            case .doublePlay:
                if f1 { return k == 1 ? RunnerPlan(base: k, to: 0) : RunnerPlan(base: k, to: forced(k) ? up(k) : k) }
                return RunnerPlan(base: k, to: k == occ[0] ? 0 : k, ask: k == occ[0])
            default: // strikeouts, line outs, pop outs
                return RunnerPlan(base: k, to: k)
            }
        }
        // Once the inning is over there's nothing left to ask.
        let fixedOuts = plans.filter { !$0.ask && $0.to == 0 }.count
        if s.outs + (res.defaultBat == 0 ? 1 : 0) + fixedOuts >= 3 {
            for i in plans.indices where plans[i].ask { plans[i].ask = false; plans[i].to = plans[i].base }
        }
        return plans
    }

    /// Default runner outcomes for a runner-only event.
    static func adv(_ s: GameState, _ kind: AdvKind) -> [Int: Int] {
        let b = s.bases
        var out: [Int: Int] = [:]
        for k in 1...3 where b[k] != nil { out[k] = k }
        switch kind {
        case .wildPitch, .passedBall, .balk, .otherAdvance:
            for k in out.keys { out[k] = min(4, k + 1) }
        case .stolenBase, .defensiveIndifference, .caughtStealing, .pickoff:
            var k = 0
            if b[1] != nil && b[2] == nil { k = 1 }
            else if b[2] != nil && b[3] == nil { k = 2 }
            else if b[3] != nil { k = 3 }
            else if b[1] != nil { k = 1 }
            if k > 0 { out[k] = (kind == .caughtStealing || kind == .pickoff) ? 0 : min(4, k + 1) }
        case .error:
            break
        }
        return out
    }

    /// Fielders to attach to a runner who is put out on a plate appearance.
    static func outFielders(_ res: PlayResult, _ fld: [Int]) -> [Int] {
        switch res {
        case .doublePlay: fld.count > 1 ? Array(fld.dropLast()) : fld
        case .fieldersChoice: fld
        default: []
        }
    }
}
