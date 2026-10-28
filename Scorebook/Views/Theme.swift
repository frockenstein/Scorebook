import SwiftUI

enum Theme {
    static let paper = Color(red: 0.969, green: 0.949, blue: 0.890)
    static let paper2 = Color(red: 0.937, green: 0.910, blue: 0.824)
    static let card = Color(red: 1.0, green: 0.992, blue: 0.965)
    static let grid = Color(red: 0.553, green: 0.702, blue: 0.612)
    static let line = Color(red: 0.812, green: 0.780, blue: 0.678)
    static let ink = Color(red: 0.110, green: 0.184, blue: 0.361)
    static let green = Color(red: 0.184, green: 0.365, blue: 0.275)
    static let accent = Color(red: 0.753, green: 0.271, blue: 0.169)
    static let pencil = Color(red: 0.42, green: 0.42, blue: 0.40)
    static let pencilLight = Color(red: 0.725, green: 0.694, blue: 0.604)
}

/// Big, forgiving tap target used across the entry sheets.
struct PaperButtonStyle: ButtonStyle {
    var prominent = false
    var danger = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .serif))
            .foregroundStyle(prominent ? .white : (danger ? Theme.accent : Theme.ink))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(prominent ? Theme.green : Theme.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(prominent ? Theme.green : Theme.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PaperButtonStyle {
    static var paper: PaperButtonStyle { PaperButtonStyle() }
    static var prominent: PaperButtonStyle { PaperButtonStyle(prominent: true) }
    static var danger: PaperButtonStyle { PaperButtonStyle(danger: true) }
}
