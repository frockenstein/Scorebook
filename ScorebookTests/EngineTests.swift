import Foundation
import Testing
@testable import Scorebook

private func makeGame(innings: Int = 9) -> Game {
    var g = Game(innings: innings, away: Game.blankTeam("A"), home: Game.blankTeam("H"))
    g.fillBlanks()
    return g
}

/// Adds a plate appearance for whoever is up and returns the replayed state.
@discardableResult
private func pa(_ g: inout Game, _ res: PlayResult, fld: [Int] = [], bat: Int? = nil,
                run: [RunnerMove] = [], unearned: Bool = false) throws -> GameState {
    let s = try GameState(game: g)
    let team = s.batting
    g.events.append(.pa(PlateAppearance(team: team, slot: s.nextSlot[team], res: res, fld: fld,
                                        bat: bat ?? res.defaultBat, run: run, unearned: unearned)))
    return try GameState(game: g)
}

@Test func singleThenHomeRunScoresTwo() throws {
    var g = makeGame()
    try pa(&g, .single)
    let s = try pa(&g, .homeRun, run: [RunnerMove(from: 1, to: 4)])
    #expect(s.score(.away) == 2)
    #expect(s.players.away[1][0].st.rbi == 2)
    #expect(s.pitchers.home[0].st.er == 2)
}

@Test func threeOutsFlipHalfAndCountLOB() throws {
    var g = makeGame()
    try pa(&g, .single); try pa(&g, .strikeout); try pa(&g, .strikeout)
    let s = try pa(&g, .groundOut, fld: [6, 3])
    #expect(!s.top && s.inning == 1)
    #expect(s.lob.away[0] == 1)
    #expect(s.pitchers.home[0].st.outs == 3)
}

@Test func runDoesNotScoreOnBatterOutThirdOut() throws {
    var g = makeGame()
    try pa(&g, .strikeout); try pa(&g, .strikeout); try pa(&g, .double)
    let s = try pa(&g, .groundOut, fld: [6, 3], run: [RunnerMove(from: 2, to: 4)])
    #expect(s.score(.away) == 0)
    #expect(s.lob.away[0] == 1)
}

@Test func doublePlayNumbersOutsRunnerFirst() throws {
    var g = makeGame()
    try pa(&g, .single)
    let s = try pa(&g, .doublePlay, fld: [6, 4, 3], run: [RunnerMove(from: 1, to: 0, fld: [6, 4])])
    #expect(s.outs == 2)
    #expect(s.cells.away[0].out == 1 && s.cells.away[0].outText == "6-4")
    #expect(s.cells.away[1].out == 2 && s.cells.away[1].main == "6-4-3")
}

@Test func stolenBaseMovesRunnerAndLabelsBase() throws {
    var g = makeGame()
    try pa(&g, .walk)
    g.events.append(.adv(RunnerEvent(team: .away, kind: .stolenBase, run: [RunnerMove(from: 1, to: 2)])))
    let s = try GameState(game: g)
    #expect(s.bases[2] == 0)
    #expect(s.cells.away[0].marks[2] == "SB")
}

@Test func errorRunIsUnearned() throws {
    var g = makeGame()
    try pa(&g, .error, fld: [6])
    let s = try pa(&g, .homeRun, run: [RunnerMove(from: 1, to: 4)])
    #expect(s.pitchers.home[0].st.r == 2 && s.pitchers.home[0].st.er == 1)
    #expect(s.errors.home == 1)
}

@Test func walkOffEndsGame() throws {
    var g = makeGame(innings: 1)
    try pa(&g, .strikeout); try pa(&g, .strikeout); try pa(&g, .strikeout)
    let s = try pa(&g, .homeRun)
    #expect(s.over && s.winner == .home)
}

@Test func twoRunnersOnSameBaseRejected() throws {
    var g = makeGame()
    try pa(&g, .single)
    g.events.append(.pa(PlateAppearance(team: .away, slot: 1, res: .single, bat: 1)))
    #expect(throws: ReplayError.self) { try GameState(game: g) }
}

@Test func plannerForcesRunnerOnFirstButAsksAboutRunnerOnSecond() throws {
    var g = makeGame()
    let s1 = try pa(&g, .walk)
    #expect(Planner.plan(s1, .single).first { $0.base == 1 }?.ask == false)   // forced
    #expect(Planner.plan(s1, .single).first { $0.base == 1 }?.to == 2)
    g.events.append(.adv(RunnerEvent(team: .away, kind: .stolenBase, run: [RunnerMove(from: 1, to: 2)])))
    let s2 = try GameState(game: g)
    #expect(Planner.plan(s2, .single).first { $0.base == 2 }?.ask == true)    // not forced
    #expect(Planner.plan(s2, .homeRun).first { $0.base == 2 }?.to == 4)
}

@Test func gameRoundTripsThroughJSON() throws {
    var g = makeGame()
    try pa(&g, .single); try pa(&g, .doublePlay, fld: [6, 4, 3], run: [RunnerMove(from: 1, to: 0, fld: [6, 4])])
    let data = try JSONEncoder().encode(g)
    let back = try JSONDecoder().decode(Game.self, from: data)
    #expect(try GameState(game: back).outs == 2)
}

@Test func battingOrderOfElevenWrapsAround() throws {
    var g = Game(innings: 9, away: Game.blankTeam("A", batters: 11), home: Game.blankTeam("H", batters: 12))
    g.fillBlanks()
    #expect(g.away.lineup[10].pos == "EH")
    var s = try GameState(game: g)
    for _ in 0..<11 {                               // 11 walks: whole order, then #1 is up again
        let moves = Planner.plan(s, .walk).filter { $0.to != $0.base }.map { RunnerMove(from: $0.base, to: $0.to) }
        s = try pa(&g, .walk, run: moves)
    }
    #expect(s.nextSlot.away == 0)
    #expect(s.players.away.count == 11 && s.players.home.count == 12)
    #expect(s.score(.away) == 8)                    // first 3 walks load the bases; each of the other 8 forces one in
}

@Test func cellStoryTracksTheRunnersWholeTrip() throws {
    var g = makeGame()
    try pa(&g, .single)
    g.events.append(.adv(RunnerEvent(team: .away, kind: .stolenBase, run: [RunnerMove(from: 1, to: 2)])))
    let s = try pa(&g, .single, run: [RunnerMove(from: 2, to: 4)])
    #expect(s.cells.away[0].story == ["Batter 1 singles", "To 2nd — stolen base", "Scored — Batter 2's 1B"])
}
