import SwiftUI

/// Tap the fielders on a diamond instead of typing position numbers.
struct FieldPicker: View {
    @Binding var sequence: [Int]
    var height: CGFloat = 230

    private static let spots: [Int: CGPoint] = [
        7: CGPoint(x: 50, y: 66), 8: CGPoint(x: 130, y: 30), 9: CGPoint(x: 210, y: 66),
        5: CGPoint(x: 78, y: 134), 6: CGPoint(x: 100, y: 100), 4: CGPoint(x: 160, y: 100), 3: CGPoint(x: 186, y: 134),
        1: CGPoint(x: 130, y: 134), 2: CGPoint(x: 130, y: 182)
    ]
    private static let names = [1: "P", 2: "C", 3: "1B", 4: "2B", 5: "3B", 6: "SS", 7: "LF", 8: "CF", 9: "RF"]

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(sequence.isEmpty ? "Tap the fielders in order" : sequence.map(String.init).joined(separator: " – "))
                    .font(.system(size: sequence.isEmpty ? 14 : 26, weight: .semibold, design: .serif))
                    .foregroundStyle(sequence.isEmpty ? Theme.pencil : Theme.ink)
                Spacer()
                if !sequence.isEmpty {
                    Button("Clear") { sequence = [] }.font(.callout).foregroundStyle(Theme.accent)
                    Button { sequence.removeLast() } label: { Image(systemName: "delete.left") }.foregroundStyle(Theme.accent)
                }
            }
            .frame(minHeight: 34)
            GeometryReader { geo in
                let k = min(geo.size.width / 260, geo.size.height / 200)
                let ox = (geo.size.width - 260 * k) / 2
                ZStack(alignment: .topLeading) {
                    Group {
                        FieldWedge().fill(Color(red: 0.90, green: 0.94, blue: 0.87))
                        FieldWedge().stroke(Theme.grid, lineWidth: 1)
                        DiamondShape().path(in: CGRect(x: 72, y: 82, width: 116, height: 104))
                            .fill(Color(red: 0.91, green: 0.86, blue: 0.75))
                    }
                    .scaleEffect(k, anchor: .topLeading)
                    ForEach(Array(Self.spots.keys.sorted()), id: \.self) { n in
                        let p = Self.spots[n]!
                        let picked = sequence.contains(n)
                        Button { sequence.append(n) } label: {
                            VStack(spacing: 0) {
                                Text("\(n)").font(.system(size: 17, weight: .bold, design: .serif))
                                Text(Self.names[n]!).font(.system(size: 8))
                            }
                            .foregroundStyle(picked ? .white : Theme.ink)
                            .frame(width: 44, height: 44)
                            .background(picked ? Theme.ink : Theme.card, in: Circle())
                            .overlay(Circle().stroke(Theme.ink, lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)
                        .position(x: p.x * k + 0, y: p.y * k + 0)
                    }
                }
                .offset(x: ox)
            }
            .frame(height: height)
        }
    }
}

/// Outfield grass wedge, in a 260×200 box.
private struct FieldWedge: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 130, y: 190))
        p.addLine(to: CGPoint(x: 12, y: 82))
        p.addQuadCurve(to: CGPoint(x: 248, y: 82), control: CGPoint(x: 130, y: -50))
        p.closeSubpath()
        return p
    }
}
