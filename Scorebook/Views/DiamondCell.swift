import SwiftUI

/// One scorecard diamond, drawn the way it would be penciled on paper.
struct DiamondCell: View {
    let cell: Cell
    var size: CGFloat = 62

    private static let corners: [CGPoint] = [
        CGPoint(x: 50, y: 90), CGPoint(x: 90, y: 50), CGPoint(x: 50, y: 10), CGPoint(x: 10, y: 50), CGPoint(x: 50, y: 90)
    ]
    private static let markPos: [Int: (CGPoint, UnitPoint)] = [
        1: (CGPoint(x: 98, y: 38), .trailing), 2: (CGPoint(x: 50, y: 6), .center),
        3: (CGPoint(x: 2, y: 38), .leading), 4: (CGPoint(x: 50, y: 97), .center)
    ]
    private static let outPos: [Int: (CGPoint, UnitPoint)] = [
        1: (CGPoint(x: 98, y: 62), .trailing), 2: (CGPoint(x: 50, y: 22), .center),
        3: (CGPoint(x: 2, y: 62), .leading), 4: (CGPoint(x: 50, y: 80), .center)
    ]

    var body: some View {
        Canvas { ctx, canvas in
            let k = min(canvas.width, canvas.height) / 100
            func P(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * k, y: p.y * k) }
            func text(_ s: String, _ size: CGFloat, weight: Font.Weight = .semibold, color: Color = Theme.ink,
                      at p: CGPoint, anchor: UnitPoint = .center, serif: Bool = true) {
                let t = Text(s).font(.system(size: size * k, weight: weight, design: serif ? .serif : .default)).foregroundStyle(color)
                ctx.draw(t, at: P(p), anchor: anchor)
            }

            // pitch count boxes
            for i in 0..<4 {
                let r = CGRect(x: (3 + CGFloat(i) * 6.4) * k, y: 3 * k, width: 5.2 * k, height: 5.2 * k)
                ctx.fill(Path(r), with: .color(i < cell.balls ? Theme.ink : .white))
                ctx.stroke(Path(r), with: .color(Theme.pencilLight), lineWidth: 0.8 * k)
            }
            for i in 0..<3 {
                let r = CGRect(x: (3 + CGFloat(i) * 6.4) * k, y: 10 * k, width: 5.2 * k, height: 5.2 * k)
                ctx.fill(Path(r), with: .color(i < cell.strikes ? Theme.ink : .white))
                ctx.stroke(Path(r), with: .color(Theme.pencilLight), lineWidth: 0.8 * k)
            }

            // diamond
            var dia = Path()
            dia.move(to: P(Self.corners[0]))
            for c in Self.corners.dropFirst().prefix(3) { dia.addLine(to: P(c)) }
            dia.closeSubpath()
            if cell.scored { ctx.fill(dia, with: .color(Theme.ink.opacity(0.18))) }
            ctx.stroke(dia, with: .color(cell.scored ? Theme.ink : Theme.pencilLight), lineWidth: 1.6 * k)

            // base path the runner has traveled
            for i in 0..<4 {
                let a = P(Self.corners[i]), b = P(Self.corners[i + 1])
                var seg = Path()
                if cell.reach > i {
                    seg.move(to: a); seg.addLine(to: b)
                    ctx.stroke(seg, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 4.5 * k, lineCap: .round))
                } else if cell.out > 0, cell.reach >= 1, cell.reach == i, cell.outAt == i + 1 {
                    let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    seg.move(to: a); seg.addLine(to: mid)
                    ctx.stroke(seg, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 4.5 * k, lineCap: .round))
                    var x = Path()
                    x.move(to: CGPoint(x: mid.x - 5 * k, y: mid.y - 5 * k)); x.addLine(to: CGPoint(x: mid.x + 5 * k, y: mid.y + 5 * k))
                    x.move(to: CGPoint(x: mid.x + 5 * k, y: mid.y - 5 * k)); x.addLine(to: CGPoint(x: mid.x - 5 * k, y: mid.y + 5 * k))
                    ctx.stroke(x, with: .color(Theme.accent), style: StrokeStyle(lineWidth: 3 * k, lineCap: .round))
                }
            }

            // the play
            let n = cell.main.count
            let fs: CGFloat = n <= 2 ? 24 : n <= 3 ? 20 : n <= 5 ? 15 : 11
            let my: CGFloat = cell.sub.isEmpty ? 50 : 44
            let mainColor = cell.res == .strikeout || cell.res == .strikeoutLooking ? Theme.accent : Theme.ink
            if cell.flip {
                var c2 = ctx
                c2.translateBy(x: 50 * k, y: my * k)
                c2.scaleBy(x: -1, y: 1)
                c2.draw(Text(cell.main).font(.system(size: fs * k, weight: .bold, design: .serif)).foregroundStyle(mainColor), at: .zero, anchor: .center)
            } else {
                text(cell.main, fs, weight: .bold, color: mainColor, at: CGPoint(x: 50, y: my))
            }
            if !cell.sub.isEmpty { text(cell.sub, 11, at: CGPoint(x: 50, y: my + 17)) }

            // base labels and the out text
            for (b, label) in cell.marks where !label.isEmpty {
                if let (p, a) = Self.markPos[b] { text(label, 9, color: Theme.pencil, at: p, anchor: a, serif: false) }
            }
            if cell.out > 0 {
                if !cell.outText.isEmpty, let (p, a) = Self.outPos[cell.outAt] {
                    text(cell.outText, 8.5, weight: .bold, color: Theme.accent, at: p, anchor: a, serif: false)
                }
                let circle = Path(ellipseIn: CGRect(x: 77 * k, y: 76 * k, width: 18 * k, height: 18 * k))
                ctx.stroke(circle, with: .color(Theme.accent), lineWidth: 1.8 * k)
                text(String(cell.out), 12, weight: .bold, color: Theme.accent, at: CGPoint(x: 86, y: 85))
            }
            if cell.lob {
                ctx.fill(Path(ellipseIn: CGRect(x: 11 * k, y: 83 * k, width: 5.5 * k, height: 5.5 * k)), with: .color(Theme.pencil))
            }
        }
        .frame(width: size, height: size)
    }
}

/// The dashed "write here" diamond for the next batter.
struct ActiveDiamond: View {
    var size: CGFloat = 62
    @State private var pulse = false

    var body: some View {
        ZStack {
            DiamondShape()
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.2, dash: [5, 4]))
                .padding(size * 0.1)
            Image(systemName: "plus")
                .font(.system(size: size * 0.3, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
        .frame(width: size, height: size)
        .opacity(pulse ? 0.4 : 1)
        .onAppear { withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

struct DiamondShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// Faint empty diamond for cells not yet played.
struct EmptyDiamond: View {
    var size: CGFloat = 62
    var body: some View {
        DiamondShape().stroke(Theme.pencilLight.opacity(0.5), lineWidth: 1.2).padding(size * 0.1).frame(width: size, height: size)
    }
}
