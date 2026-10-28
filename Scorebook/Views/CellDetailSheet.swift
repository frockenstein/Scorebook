import SwiftUI

/// A zoomed-in diamond with the fine print of one plate appearance.
struct CellDetailSheet: View {
    let state: GameState
    let side: TeamSide
    let cellID: Int
    let dismiss: () -> Void

    private var cell: Cell? { state.cells[side].first { $0.id == cellID } }

    var body: some View {
        if let cell {
            let player = state.players[side][cell.slot][cell.pi]
            let pitcher = state.pitchers[side.other][cell.pit].info
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("#\(cell.slot + 1) \(player.info.name)")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                        Text("Inning \(cell.inning) vs \(pitcher.name)").font(.footnote).opacity(0.85)
                    }
                    Spacer()
                    Button(action: dismiss) { Image(systemName: "xmark").font(.title3) }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Theme.green)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        DiamondCell(cell: cell, size: 260)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(cell.story.enumerated()), id: \.offset) { i, line in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("\(i + 1)").font(.system(size: 12, weight: .bold, design: .serif))
                                        .foregroundStyle(.white).frame(width: 20, height: 20)
                                        .background(i == 0 ? Theme.ink : Theme.pencil, in: Circle())
                                    Text(line).font(.system(size: 16)).foregroundStyle(Theme.ink)
                                }
                            }
                            if cell.rbi > 0 { stat("RBI", "\(cell.rbi)") }
                        }

                        if !cell.pitches.isEmpty { pitchRow(cell) }
                    }
                    .padding(16)
                }
            }
            .background(Theme.paper)
            .presentationDetents([.fraction(0.75), .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func stat(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(Theme.pencil); Text(v).fontWeight(.semibold).foregroundStyle(Theme.ink) }
            .font(.system(size: 15))
    }

    private func pitchRow(_ cell: Cell) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pitches (\(cell.pitches.count)) · count \(cell.balls)–\(cell.strikes)")
                .font(.caption).foregroundStyle(Theme.pencil)
            HStack(spacing: 6) {
                ForEach(Array(cell.pitches.enumerated()), id: \.offset) { _, c in
                    VStack(spacing: 1) {
                        Text(String(c)).font(.system(size: 15, weight: .bold, design: .serif))
                        Text(Self.names[c] ?? "").font(.system(size: 8))
                    }
                    .foregroundStyle(c == "B" ? Theme.green : Theme.accent)
                    .frame(width: 42, height: 40)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                }
            }
        }
    }

    private static let names: [Character: String] = ["B": "ball", "C": "called", "S": "swing", "F": "foul"]
}
