import SwiftUI

struct ChessBoardView: View {
    let position: ChessPosition
    var selected: Int? = nil
    var targets: [Int] = []
    var highlights: [Int] = []
    var lastMove: ChessMove? = nil
    var orientation: ChessColor = .white
    var interactive = false
    var onTap: (Int) -> Void = { _ in }

    private var squares: [Int] {
        let white = (0..<64).map { index in (7 - index / 8) * 8 + index % 8 }
        return orientation == .white ? white : Array(white.reversed())
    }

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width / 8
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 8), spacing: 0) {
                ForEach(Array(squares.enumerated()), id: \.element) { index, square in
                    let piece = position.pieces[square]
                    let isLight = (square / 8 + square % 8) % 2 == 1
                    Button { onTap(square) } label: {
                        ZStack {
                            (isLight ? Palette.lightSquare : Palette.darkSquare)
                            if lastMove?.from == square || lastMove?.to == square {
                                Palette.lime.opacity(0.55)
                            }
                            if highlights.contains(square) { Palette.lime.opacity(0.7) }
                            if selected == square { Palette.lime.opacity(0.85) }
                            if let piece = piece {
                                // Keep chess symbols in the text font; the black pawn
                                // otherwise defaults to Apple's colored emoji glyph.
                                Text(piece.symbol + "\u{FE0E}")
                                    .font(.system(size: side * 0.77))
                                    .foregroundStyle(piece.color == .white ? Color.white : Palette.forest)
                                    .shadow(color: Palette.forest.opacity(piece.color == .white ? 0.65 : 0.15), radius: 0.8, y: 1)
                                    .offset(y: -side * 0.015)
                            }
                            if targets.contains(square) {
                                if piece == nil {
                                    Circle().fill(Palette.forest.opacity(0.3)).frame(width: side * 0.25)
                                } else {
                                    Circle().stroke(Palette.forest.opacity(0.5), lineWidth: 4).padding(2)
                                }
                            }
                            if index % 8 == 0 {
                                Text(String(square / 8 + 1)).font(.system(size: max(9, side * 0.19), weight: .bold, design: .rounded))
                                    .foregroundStyle(isLight ? Palette.forest : .white)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(3)
                            }
                            if index / 8 == 7 {
                                Text(String(UnicodeScalar(97 + square % 8)!)).font(.system(size: max(9, side * 0.19), weight: .bold, design: .rounded))
                                    .foregroundStyle(isLight ? Palette.forest : .white)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(3)
                            }
                        }.frame(width: side, height: side).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(!interactive)
                    .accessibilityLabel(accessibilityLabel(square, piece))
                    .accessibilityHint(interactive ? "Tap to select this square" : "Chess position")
                    .accessibilityAddTraits(selected == square ? .isSelected : [])
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.forest.opacity(0.08), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chess board, \(position.turn.title) to move")
    }

    private func accessibilityLabel(_ square: Int, _ piece: ChessPiece?) -> String {
        var label = ChessPosition.name(of: square)
        if let piece = piece { label += ", \(piece.color.title) \(piece.kind.title)" }
        else { label += ", empty" }
        if targets.contains(square) { label += ", legal destination" }
        if selected == square { label += ", selected" }
        return label
    }
}
