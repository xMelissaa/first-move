import SwiftUI
import UIKit

enum Palette {
    static let cream = Color(hex: "F7F6EF")
    static let forest = Color(hex: "173F35")
    static let green = Color(hex: "2D6A50")
    static let mint = Color(hex: "DCEAD8")
    static let lime = Color(hex: "D9EB8F")
    static let ink = Color(hex: "1E3029")
    static let muted = Color(hex: "6B776E")
    static let orange = Color(hex: "D67B43")
    static let line = Color(hex: "DEE3D7")
    static let lightSquare = Color(hex: "ECEBDD")
    static let darkSquare = Color(hex: "83A58D")
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x173F35
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255, opacity: 1)
    }
}

struct PrimaryButton: View {
    var title: String
    var icon: String = "arrow.right"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).font(.system(.headline, design: .rounded))
                Spacer(minLength: 8)
                Image(systemName: icon).fontWeight(.semibold)
            }
            .padding(.horizontal, 22).padding(.vertical, 18)
            .foregroundStyle(.white).background(Palette.forest, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityHint(title)
    }
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.line.opacity(0.7), lineWidth: 1))
    }
}

struct SectionEyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased()).font(.system(.caption, design: .rounded).weight(.bold))
            .tracking(1.5).foregroundStyle(Palette.muted)
    }
}

struct StatPill: View {
    var symbol: String
    var value: String
    var tint: Color = Palette.forest
    var body: some View {
        Label(value, systemImage: symbol)
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(tint).padding(.horizontal, 12).padding(.vertical, 9)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
    }
}

struct RookCharacter: View {
    var size: CGFloat = 150
    var body: some View {
        ZStack {
            Circle().fill(Palette.lime).frame(width: size, height: size)
            Image(systemName: "sparkle").font(.system(size: size * 0.12))
                .foregroundStyle(Palette.green).offset(x: size * 0.35, y: -size * 0.32)
            RookShape().fill(Palette.forest).frame(width: size * 0.61, height: size * 0.69).offset(y: size * 0.02)
            HStack(spacing: size * 0.14) {
                Capsule().frame(width: size * 0.035, height: size * 0.07)
                Capsule().frame(width: size * 0.035, height: size * 0.07)
            }.foregroundStyle(Palette.cream).offset(y: size * 0.005)
            Path { p in
                p.move(to: CGPoint(x: size * 0.455, y: size * 0.565))
                p.addQuadCurve(to: CGPoint(x: size * 0.545, y: size * 0.565), control: CGPoint(x: size * 0.5, y: size * 0.61))
            }.stroke(Palette.cream, style: StrokeStyle(lineWidth: size * 0.018, lineCap: .round))
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct RookShape: Shape {
    func path(in r: CGRect) -> Path {
        let points: [CGPoint] = [
            .init(x: 0.08, y: 0.05), .init(x: 0.27, y: 0.05), .init(x: 0.27, y: 0.21),
            .init(x: 0.41, y: 0.21), .init(x: 0.41, y: 0.05), .init(x: 0.59, y: 0.05),
            .init(x: 0.59, y: 0.21), .init(x: 0.73, y: 0.21), .init(x: 0.73, y: 0.05),
            .init(x: 0.92, y: 0.05), .init(x: 0.92, y: 0.35), .init(x: 0.75, y: 0.45),
            .init(x: 0.69, y: 0.77), .init(x: 0.88, y: 0.86), .init(x: 0.93, y: 0.98),
            .init(x: 0.07, y: 0.98), .init(x: 0.12, y: 0.86), .init(x: 0.31, y: 0.77),
            .init(x: 0.25, y: 0.45), .init(x: 0.08, y: 0.35)
        ]
        var p = Path()
        for (i, point) in points.enumerated() {
            let q = CGPoint(x: r.minX + point.x * r.width, y: r.minY + point.y * r.height)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath(); return p
    }
}

enum Haptics {
    @MainActor static func success(enabled: Bool) {
        if enabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }
    @MainActor static func gentle(enabled: Bool) {
        if enabled { UISelectionFeedbackGenerator().selectionChanged() }
    }
}
