import Foundation

enum ChessColor: String, Codable, CaseIterable, Hashable, Sendable {
    case white = "w"
    case black = "b"

    var opposite: ChessColor { self == .white ? .black : .white }
    var title: String { self == .white ? "White" : "Black" }
}

enum PieceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case pawn = "p"
    case knight = "n"
    case bishop = "b"
    case rook = "r"
    case queen = "q"
    case king = "k"

    static let promotions: [PieceKind] = [.queen, .rook, .bishop, .knight]

    var title: String {
        switch self {
        case .pawn: return "pawn"
        case .knight: return "knight"
        case .bishop: return "bishop"
        case .rook: return "rook"
        case .queen: return "queen"
        case .king: return "king"
        }
    }
}

struct ChessPiece: Equatable, Hashable, Codable, Sendable {
    let color: ChessColor
    let kind: PieceKind

    var symbol: String {
        switch (color, kind) {
        case (.white, .king): return "♔"
        case (.white, .queen): return "♕"
        case (.white, .rook): return "♖"
        case (.white, .bishop): return "♗"
        case (.white, .knight): return "♘"
        case (.white, .pawn): return "♙"
        case (.black, .king): return "♚"
        case (.black, .queen): return "♛"
        case (.black, .rook): return "♜"
        case (.black, .bishop): return "♝"
        case (.black, .knight): return "♞"
        case (.black, .pawn): return "♟"
        }
    }

    var fenSymbol: String { color == .white ? kind.rawValue.uppercased() : kind.rawValue }
}

struct ChessMove: Equatable, Hashable, Codable, Sendable {
    let from: Int
    let to: Int
    let promotion: PieceKind?

    init(from: Int, to: Int, promotion: PieceKind? = nil) {
        self.from = from
        self.to = to
        self.promotion = promotion
    }

    var uci: String {
        ChessPosition.name(of: from) + ChessPosition.name(of: to) + (promotion?.rawValue ?? "")
    }
}

enum ChessPositionError: Error, LocalizedError, Equatable {
    case invalidFEN(String)

    var errorDescription: String? {
        switch self {
        case .invalidFEN(let reason): return "Invalid chess position: \(reason)"
        }
    }
}

/// A value-type chess position. Square indexes run from a1 = 0 to h8 = 63.
/// FEN parsing validates its six fields and both kings, rather than attempting
/// to prove that the position can be reached from the initial position.
struct ChessPosition: Equatable, Sendable {
    static let initialFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    static var initial: ChessPosition { try! ChessPosition(fen: initialFEN) }

    private(set) var pieces: [Int: ChessPiece]
    private(set) var turn: ChessColor
    private(set) var enPassantTarget: Int?
    private(set) var halfmoveClock: Int
    private(set) var fullmoveNumber: Int
    private var castlingRights: Set<Character>

    init(fen: String) throws {
        let fields = fen.split(whereSeparator: { $0.isWhitespace })
        guard fields.count == 6 else {
            throw ChessPositionError.invalidFEN("FEN must contain six fields.")
        }
        let ranks = fields[0].split(separator: "/", omittingEmptySubsequences: false)
        guard ranks.count == 8 else {
            throw ChessPositionError.invalidFEN("The board must contain eight ranks.")
        }
        var board: [Int: ChessPiece] = [:]
        for (rankIndex, encodedRank) in ranks.enumerated() {
            var file = 0
            for character in encodedRank {
                if let empty = character.wholeNumberValue, (1...8).contains(empty), character.isASCII {
                    file += empty
                } else {
                    let text = String(character)
                    guard character.isASCII,
                          let kind = PieceKind(rawValue: text.lowercased()), file < 8 else {
                        throw ChessPositionError.invalidFEN("The board contains an invalid piece or rank.")
                    }
                    let color: ChessColor = text == text.uppercased() ? .white : .black
                    board[(7 - rankIndex) * 8 + file] = ChessPiece(color: color, kind: kind)
                    file += 1
                }
                guard file <= 8 else {
                    throw ChessPositionError.invalidFEN("A rank contains more than eight squares.")
                }
            }
            guard file == 8 else {
                throw ChessPositionError.invalidFEN("Each rank must describe eight squares.")
            }
        }
        for color in ChessColor.allCases {
            guard board.values.filter({ $0.color == color && $0.kind == .king }).count == 1 else {
                throw ChessPositionError.invalidFEN("Each side must have exactly one king.")
            }
        }
        guard let activeColor = ChessColor(rawValue: String(fields[1])) else {
            throw ChessPositionError.invalidFEN("The active color must be w or b.")
        }
        var rights: Set<Character> = []
        if fields[2] != "-" {
            for right in fields[2] {
                guard "KQkq".contains(right), rights.insert(right).inserted else {
                    throw ChessPositionError.invalidFEN("Castling rights must contain unique K, Q, k, or q letters.")
                }
            }
        }
        var epSquare: Int?
        if fields[3] != "-" {
            guard let square = Self.square(named: String(fields[3])),
                  square / 8 == (activeColor == .white ? 5 : 2), board[square] == nil else {
                throw ChessPositionError.invalidFEN("The en passant target must be an empty square on the appropriate third or sixth rank.")
            }
            epSquare = square
        }
        guard fields[4].allSatisfy({ $0.isASCII && $0.isNumber }),
              fields[5].allSatisfy({ $0.isASCII && $0.isNumber }),
              let halfmove = Int(fields[4]), halfmove >= 0,
              let fullmove = Int(fields[5]), fullmove >= 1 else {
            throw ChessPositionError.invalidFEN("Move counters must be nonnegative integers, with fullmove number at least one.")
        }
        pieces = board
        turn = activeColor
        enPassantTarget = epSquare
        halfmoveClock = halfmove
        fullmoveNumber = fullmove
        castlingRights = rights
    }

    static func square(named name: String) -> Int? {
        let bytes = Array(name.utf8)
        guard bytes.count == 2, (97...104).contains(bytes[0]), (49...56).contains(bytes[1]) else { return nil }
        return Int(bytes[1] - 49) * 8 + Int(bytes[0] - 97)
    }

    static func name(of square: Int) -> String {
        guard (0..<64).contains(square) else { return "?" }
        let file = UnicodeScalar(97 + square % 8)!
        return "\(Character(file))\(square / 8 + 1)"
    }

    var fen: String {
        var encodedRanks: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var encoded = ""
            var empty = 0
            for file in 0..<8 {
                if let piece = pieces[rank * 8 + file] {
                    if empty > 0 { encoded += String(empty); empty = 0 }
                    encoded += piece.fenSymbol
                } else {
                    empty += 1
                }
            }
            if empty > 0 { encoded += String(empty) }
            encodedRanks.append(encoded)
        }
        let rights = String("KQkq".filter { castlingRights.contains($0) })
        let ep = enPassantTarget.map { Self.name(of: $0) } ?? "-"
        return "\(encodedRanks.joined(separator: "/")) \(turn.rawValue) \(rights.isEmpty ? "-" : rights) \(ep) \(halfmoveClock) \(fullmoveNumber)"
    }

    var isCheck: Bool { isKingInCheck(turn) }
    var isCheckmate: Bool { isCheck && legalMoves().isEmpty }
    var isStalemate: Bool { !isCheck && legalMoves().isEmpty }

    func legalMoves(from square: Int? = nil) -> [ChessMove] {
        pseudoLegalMoves(from: square).filter { move in
            var next = self
            next.applyUnchecked(move)
            return !next.isKingInCheck(turn)
        }
    }

    /// Apply a move returned by legalMoves(). Invalid moves are programmer errors.
    func applying(_ move: ChessMove) -> ChessPosition {
        precondition(legalMoves(from: move.from).contains(move), "The move must be legal in this position.")
        var next = self
        next.applyUnchecked(move)
        return next
    }

    private func isKingInCheck(_ color: ChessColor) -> Bool {
        guard let kingSquare = pieces.first(where: { $0.value.color == color && $0.value.kind == .king })?.key else {
            return true
        }
        return isSquareAttacked(kingSquare, by: color.opposite)
    }

    /// Attacks are geometric: a pinned piece still attacks squares for king safety.
    private func isSquareAttacked(_ square: Int, by color: ChessColor) -> Bool {
        let targetFile = square % 8
        let targetRank = square / 8
        for (source, piece) in pieces where piece.color == color {
            let dx = targetFile - source % 8
            let dy = targetRank - source / 8
            switch piece.kind {
            case .pawn:
                if abs(dx) == 1 && dy == (color == .white ? 1 : -1) { return true }
            case .knight:
                if (abs(dx) == 1 && abs(dy) == 2) || (abs(dx) == 2 && abs(dy) == 1) { return true }
            case .king:
                if max(abs(dx), abs(dy)) == 1 { return true }
            case .bishop, .rook, .queen:
                let diagonal = abs(dx) == abs(dy) && dx != 0
                let straight = (dx == 0) != (dy == 0)
                let canSlide = (piece.kind == .bishop && diagonal)
                    || (piece.kind == .rook && straight)
                    || (piece.kind == .queen && (diagonal || straight))
                if canSlide && isRayClear(from: source, to: square) { return true }
            }
        }
        return false
    }

    private func isRayClear(from: Int, to: Int) -> Bool {
        let dx = (to % 8 - from % 8).signum()
        let dy = (to / 8 - from / 8).signum()
        var file = from % 8 + dx
        var rank = from / 8 + dy
        while file != to % 8 || rank != to / 8 {
            if pieces[rank * 8 + file] != nil { return false }
            file += dx
            rank += dy
        }
        return true
    }

    private func pseudoLegalMoves(from requestedSquare: Int?) -> [ChessMove] {
        var moves: [ChessMove] = []
        let sources = requestedSquare.map { [$0] } ?? pieces.keys.sorted()
        for source in sources {
            guard (0..<64).contains(source), let piece = pieces[source], piece.color == turn else { continue }
            let file = source % 8
            let rank = source / 8

            func add(_ target: Int) {
                if piece.kind == .pawn && (target / 8 == 0 || target / 8 == 7) {
                    for kind in PieceKind.promotions {
                        moves.append(ChessMove(from: source, to: target, promotion: kind))
                    }
                } else {
                    moves.append(ChessMove(from: source, to: target))
                }
            }

            switch piece.kind {
            case .pawn:
                let direction = turn == .white ? 1 : -1
                let forwardRank = rank + direction
                guard (0..<8).contains(forwardRank) else { continue }
                let forward = forwardRank * 8 + file
                if pieces[forward] == nil {
                    add(forward)
                    let startRank = turn == .white ? 1 : 6
                    let doubleStep = (rank + 2 * direction) * 8 + file
                    if rank == startRank && pieces[doubleStep] == nil { add(doubleStep) }
                }
                for dx in [-1, 1] where (0..<8).contains(file + dx) {
                    let target = forwardRank * 8 + file + dx
                    if let captured = pieces[target], captured.color != turn, captured.kind != .king {
                        add(target)
                    } else if target == enPassantTarget, pieces[target] == nil,
                              pieces[rank * 8 + file + dx] == ChessPiece(color: turn.opposite, kind: .pawn) {
                        add(target)
                    }
                }
            case .knight, .king:
                let offsets: [(Int, Int)] = piece.kind == .knight
                    ? [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
                    : [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
                for (dx, dy) in offsets {
                    let targetFile = file + dx
                    let targetRank = rank + dy
                    guard (0..<8).contains(targetFile), (0..<8).contains(targetRank) else { continue }
                    let target = targetRank * 8 + targetFile
                    if let occupant = pieces[target], occupant.color == turn || occupant.kind == .king { continue }
                    add(target)
                }
                if piece.kind == .king { moves += castlingMoves(from: source) }
            case .bishop, .rook, .queen:
                var directions: [(Int, Int)] = []
                if piece.kind != .rook { directions += [(1, 1), (1, -1), (-1, 1), (-1, -1)] }
                if piece.kind != .bishop { directions += [(1, 0), (-1, 0), (0, 1), (0, -1)] }
                for (dx, dy) in directions {
                    var targetFile = file + dx
                    var targetRank = rank + dy
                    while (0..<8).contains(targetFile) && (0..<8).contains(targetRank) {
                        let target = targetRank * 8 + targetFile
                        if let occupant = pieces[target] {
                            if occupant.color != turn && occupant.kind != .king { add(target) }
                            break
                        }
                        add(target)
                        targetFile += dx
                        targetRank += dy
                    }
                }
            }
        }
        return moves
    }

    private func castlingMoves(from source: Int) -> [ChessMove] {
        let base = turn == .white ? 0 : 56
        guard source == base + 4, !isKingInCheck(turn) else { return [] }
        var moves: [ChessMove] = []
        let options: [(Character, Int, [Int], [Int], Int)] = [
            (turn == .white ? "K" : "k", 7, [5, 6], [5, 6], 6),
            (turn == .white ? "Q" : "q", 0, [1, 2, 3], [3, 2], 2)
        ]
        for (right, rookFile, emptyFiles, safeFiles, kingFile) in options {
            guard castlingRights.contains(right),
                  pieces[base + rookFile] == ChessPiece(color: turn, kind: .rook),
                  emptyFiles.allSatisfy({ pieces[base + $0] == nil }),
                  safeFiles.allSatisfy({ !isSquareAttacked(base + $0, by: turn.opposite) }) else { continue }
            moves.append(ChessMove(from: source, to: base + kingFile))
        }
        return moves
    }

    private mutating func applyUnchecked(_ move: ChessMove) {
        guard let piece = pieces[move.from] else { return }
        let captured = pieces[move.to]
        let isEnPassant = piece.kind == .pawn && move.to == enPassantTarget
            && captured == nil && move.from % 8 != move.to % 8

        pieces[move.from] = nil
        if isEnPassant { pieces[move.to + (piece.color == .white ? -8 : 8)] = nil }
        pieces[move.to] = ChessPiece(color: piece.color, kind: move.promotion ?? piece.kind)

        if piece.kind == .king {
            castlingRights.remove(piece.color == .white ? "K" : "k")
            castlingRights.remove(piece.color == .white ? "Q" : "q")
            if abs(move.to - move.from) == 2 {
                let base = piece.color == .white ? 0 : 56
                let rookFrom = move.to > move.from ? base + 7 : base
                let rookTo = move.to > move.from ? base + 5 : base + 3
                pieces[rookTo] = pieces[rookFrom]
                pieces[rookFrom] = nil
            }
        }
        if piece.kind == .rook { removeCastlingRight(forRookSquare: move.from) }
        if captured?.kind == .rook { removeCastlingRight(forRookSquare: move.to) }

        enPassantTarget = piece.kind == .pawn && abs(move.to - move.from) == 16 ? (move.to + move.from) / 2 : nil
        halfmoveClock = piece.kind == .pawn || captured != nil || isEnPassant ? 0 : min(halfmoveClock, Int.max - 1) + 1
        if turn == .black { fullmoveNumber = min(fullmoveNumber, Int.max - 1) + 1 }
        turn = turn.opposite
    }

    private mutating func removeCastlingRight(forRookSquare square: Int) {
        switch square {
        case 0: castlingRights.remove("Q")
        case 7: castlingRights.remove("K")
        case 56: castlingRights.remove("q")
        case 63: castlingRights.remove("k")
        default: break
        }
    }
}
