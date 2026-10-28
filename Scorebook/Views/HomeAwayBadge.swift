import SwiftUI

/// "A" or "H" in a solid circle, so it reads as a marker rather than part of the team name.
struct HomeAwayBadge: View {
    let side: TeamSide
    /// True when drawn on the dark green header: white circle, green letter.
    var onDark = false
    var size: CGFloat = 18

    var body: some View {
        Text(side.letter)
            .font(.system(size: size * 0.6, weight: .heavy, design: .rounded))
            .foregroundStyle(onDark ? Theme.green : .white)
            .frame(width: size, height: size)
            .background(onDark ? Color.white : Theme.green, in: Circle())
    }
}

/// Away / Home switcher styled like a segmented control, with the badge on each side.
struct TeamTabs: View {
    let names: Pair<String>
    @Binding var selection: TeamSide

    var body: some View {
        HStack(spacing: 3) {
            ForEach(TeamSide.allCases) { side in
                Button { selection = side } label: {
                    HStack(spacing: 7) {
                        HomeAwayBadge(side: side, size: 20)
                        Text(names[side]).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(selection == side ? Theme.card : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: selection == side ? .black.opacity(0.12) : .clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 11))
    }
}
