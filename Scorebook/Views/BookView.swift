import SwiftUI

/// The paper scorecard: pinned lineup column, a diamond per batter per inning, totals underneath.
struct BookView: View {
    let state: GameState
    let side: TeamSide
    let onTapActive: () -> Void
    var onTapCell: (Int) -> Void = { _ in }

    private let cellSize: CGFloat = 62
    private let nameWidth: CGFloat = 104
    private let headerHeight: CGFloat = 26
    private let footHeight: CGFloat = 26
    private let statWidth: CGFloat = 32

    private var lineupCount: Int { state.players[side].count }
    private var innings: Int { max(state.innings, state.inning) }
    private var activeSlot: Int? { !state.over && state.batting == side ? state.nextSlot[side] : nil }

    /// cells grouped by slot and inning
    private var grid: [Int: [Int: [Cell]]] {
        var g: [Int: [Int: [Cell]]] = [:]
        for c in state.cells[side] { g[c.slot, default: [:]][c.inning, default: []].append(c) }
        return g
    }

    /// Column width per inning grows when a batter bats around.
    private func columns(_ g: [Int: [Int: [Cell]]]) -> [Int] {
        (1...innings).map { inn in
            var m = 1
            for s in 0..<lineupCount {
                let n = (g[s]?[inn]?.count ?? 0) + (s == activeSlot && inn == state.inning ? 1 : 0)
                m = max(m, n)
            }
            return m
        }
    }

    var body: some View {
        let g = grid
        let cols = columns(g)
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    nameColumn
                    ScrollView(.horizontal, showsIndicators: false) {
                        gridBody(g, cols)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .background(Theme.card)
                .overlay(Rectangle().stroke(Theme.green, lineWidth: 2))
                .padding(.horizontal, 6)
                .padding(.bottom, 20)
            }
            .onChange(of: state.cells[side].count) { _, _ in scrollToActive(proxy) }
            .onChange(of: side) { _, _ in scrollToActive(proxy) }
            .onAppear { scrollToActive(proxy) }
        }
    }

    private func scrollToActive(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo("inning-\(min(state.inning, innings))", anchor: .center) }
        }
    }

    // MARK: pinned names

    private var nameColumn: some View {
        VStack(spacing: 0) {
            Text(state.names[side])
                .font(.system(size: 13, weight: .bold, design: .serif))
                .lineLimit(1)
                .frame(width: nameWidth, height: headerHeight, alignment: .leading)
                .padding(.leading, 6)
                .background(Theme.green)
                .foregroundStyle(.white)
            ForEach(0..<lineupCount, id: \.self) { slot in
                HStack(alignment: .top, spacing: 4) {
                    Text("\(slot + 1)")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: slot >= 9 ? 22 : 14)
                    VStack(alignment: .leading, spacing: 1) {
                        let pls = state.players[side][slot]
                        ForEach(Array(pls.enumerated()), id: \.offset) { i, p in
                            if i == 0 || i >= pls.count - 1 {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(p.info.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    Text("\(i > 0 ? p.kind + " · " : "")\(p.info.num.isEmpty ? "" : "#" + p.info.num + " ")\(p.info.pos)")
                                        .font(.system(size: 10)).foregroundStyle(Theme.pencil).lineLimit(1)
                                }
                                .opacity(i == 0 && pls.count > 1 ? 0.55 : 1)
                            }
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 6)
                .padding(.top, 4)
                .frame(width: nameWidth + 6, height: cellSize, alignment: .topLeading)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.grid).frame(height: 1) }
            }
            ForEach(["R", "H", "LOB"], id: \.self) { l in
                Text(l)
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .frame(width: nameWidth, height: footHeight, alignment: .leading)
                    .padding(.leading, 6)
                    .background(Theme.paper2)
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: nameWidth + 6)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.grid).frame(width: 1) }
    }

    // MARK: scrolling grid

    private func gridBody(_ g: [Int: [Int: [Cell]]], _ cols: [Int]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(1...innings, id: \.self) { inn in
                    let current = !state.over && state.batting == side && inn == state.inning
                    Text("\(inn)")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: cellSize * CGFloat(cols[inn - 1]), height: headerHeight)
                        .background(current ? Theme.accent : Theme.green)
                        .foregroundStyle(.white)
                        .id("inning-\(inn)")
                }
                ForEach(["AB", "R", "H", "RBI"], id: \.self) { h in
                    Text(h).font(.system(size: 11, weight: .semibold)).frame(width: statWidth, height: headerHeight)
                        .background(Theme.green).foregroundStyle(.white)
                }
            }
            ForEach(0..<lineupCount, id: \.self) { slot in
                HStack(spacing: 0) {
                    ForEach(1...innings, id: \.self) { inn in
                        let cells = g[slot]?[inn] ?? []
                        let isActive = slot == activeSlot && inn == state.inning
                        HStack(spacing: 0) {
                            ForEach(cells) { c in
                                DiamondCell(cell: c, size: cellSize)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTapCell(c.id) }
                            }
                            if isActive {
                                ActiveDiamond(size: cellSize).onTapGesture(perform: onTapActive)
                            } else if cells.isEmpty {
                                EmptyDiamond(size: cellSize)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(width: cellSize * CGFloat(cols[inn - 1]), height: cellSize, alignment: .leading)
                        .background(!state.over && state.batting == side && inn == state.inning ? Color.orange.opacity(0.07) : .clear)
                        .overlay(alignment: .trailing) { Rectangle().fill(Theme.grid).frame(width: 1) }
                        .contentShape(Rectangle())
                        .onTapGesture { if isActive { onTapActive() } }
                    }
                    let st = state.players[side][slot].reduce(into: BatStats()) { a, p in
                        a.ab += p.st.ab; a.r += p.st.r; a.h += p.st.h; a.rbi += p.st.rbi
                    }
                    statCell(st.ab); statCell(st.r); statCell(st.h); statCell(st.rbi)
                }
                .frame(height: cellSize)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.grid).frame(height: 1) }
            }
            footRow("R", state.runs[side])
            footRow("H", state.hits[side])
            footRow("LOB", state.lob[side])
        }
    }

    private func statCell(_ v: Int) -> some View {
        Text("\(v)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
            .frame(width: statWidth, height: cellSize)
    }

    private func footRow(_ label: String, _ values: [Int]) -> some View {
        HStack(spacing: 0) {
            ForEach(1...innings, id: \.self) { inn in
                let played = inn <= state.inning
                Text(inn <= values.count ? "\(values[inn - 1])" : (played ? "0" : ""))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: cellSize * CGFloat(columns(grid)[inn - 1]), height: footHeight)
                    .background(Theme.paper2)
            }
            let total = values.reduce(0, +)
            Text("\(total)").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.green)
                .frame(width: statWidth, height: footHeight).background(Theme.paper2)
            Spacer(minLength: 0).frame(width: statWidth * 3).background(Theme.paper2)
        }
    }
}
