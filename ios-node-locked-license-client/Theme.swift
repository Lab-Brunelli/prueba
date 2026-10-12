import SwiftUI

enum Theme {
    static let bg = Color(hex: "#0A0A0B")
    static let card = Color(hex: "#16161A")
    static let cardStroke = Color(hex: "#26262B")
    static let pill = Color(hex: "#232327")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#8E8E93")
    static let safeGreen = Color(hex: "#2ECC71")
    static let danger = Color(hex: "#FF3B30")
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r, g, b: UInt64
        switch s.count {
        case 3:
            r = (int >> 8) * 17; g = ((int >> 4) & 0xF) * 17; b = (int & 0xF) * 17
        default:
            r = int >> 16; g = (int >> 8) & 0xFF; b = int & 0xFF
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: 1)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardStroke, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct Badge: View {
    let text: String
    var color: Color = Theme.safeGreen
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct IconBox: View {
    let system: String
    var body: some View {
        Image(systemName: system)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 36, height: 36)
            .background(Theme.pill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String = "cube"
    var badge: String? = "Seguro"
    @Binding var isOn: Bool
    var body: some View {
        Card {
            HStack(spacing: 12) {
                IconBox(system: icon)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    if let badge { Badge(text: badge) }
                }
                Spacer()
                Toggle("", isOn: $isOn).labelsHidden().tint(Theme.safeGreen)
            }
        }
    }
}
