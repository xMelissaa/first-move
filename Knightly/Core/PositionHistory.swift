import Foundation

extension ChessPosition {
    /// For repetition, an en-passant target matters only if a legal capture exists.
    /// Counters do not affect the identity of a position.
    var repetitionKey: String {
        var fields = fen.split(separator: " ").prefix(4).map(String.init)
        if let target = enPassantTarget {
            let canCapture = legalMoves().contains {
                $0.to == target && pieces[$0.from]?.kind == .pawn && $0.from % 8 != $0.to % 8
            }
            if !canCapture { fields[3] = "-" }
        }
        return fields.joined(separator: " ")
    }
}
