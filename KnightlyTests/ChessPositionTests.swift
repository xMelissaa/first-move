import XCTest
@testable import FirstMove

final class ChessPositionTests: XCTestCase {
    private func position(_ fen: String) throws -> ChessPosition { try ChessPosition(fen: fen) }

    private func move(_ uci: String, in position: ChessPosition, file: StaticString = #filePath, line: UInt = #line) throws -> ChessMove {
        try XCTUnwrap(position.legalMoves().first { $0.uci == uci }, "Expected legal move \(uci)", file: file, line: line)
    }

    private func perft(_ position: ChessPosition, depth: Int) -> Int {
        if depth == 0 { return 1 }
        return position.legalMoves().reduce(0) { $0 + perft(position.applying($1), depth: depth - 1) }
    }

    func testInitialFENRoundTripAndSquareCoordinates() throws {
        let board = try position(ChessPosition.initialFEN)
        XCTAssertEqual(board.fen, ChessPosition.initialFEN)
        XCTAssertEqual(board.pieces.count, 32)
        XCTAssertEqual(ChessPosition.square(named: "a1"), 0)
        XCTAssertEqual(ChessPosition.square(named: "h8"), 63)
        XCTAssertEqual(ChessPosition.name(of: 28), "e4")
        XCTAssertNil(ChessPosition.square(named: "a9"))
        XCTAssertNil(ChessPosition.square(named: "A1"))
    }

    func testInitialPerft() {
        XCTAssertEqual(perft(.initial, depth: 1), 20)
        XCTAssertEqual(perft(.initial, depth: 2), 400)
        XCTAssertEqual(perft(.initial, depth: 3), 8_902)
    }

    func testKiwipetePerftExercisesCastlingAndPins() throws {
        let board = try position("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
        XCTAssertEqual(perft(board, depth: 1), 48)
        XCTAssertEqual(perft(board, depth: 2), 2_039)
        XCTAssertEqual(perft(board, depth: 3), 97_862)
    }

    func testEndgamePerftExercisesEnPassantAndChecks() throws {
        let board = try position("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
        XCTAssertEqual(perft(board, depth: 1), 14)
        XCTAssertEqual(perft(board, depth: 2), 191)
        XCTAssertEqual(perft(board, depth: 3), 2_812)
    }

    func testCastlingMovesRookAndClearsRights() throws {
        let board = try position("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
        XCTAssertTrue(board.legalMoves().contains { $0.uci == "e1c1" })
        let next = board.applying(try move("e1g1", in: board))
        XCTAssertEqual(next.pieces[6], ChessPiece(color: .white, kind: .king))
        XCTAssertEqual(next.pieces[5], ChessPiece(color: .white, kind: .rook))
        XCTAssertNil(next.pieces[7])
        XCTAssertEqual(next.fen, "r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1")
    }

    func testCannotCastleThroughCheckOrWithoutRook() throws {
        let attacked = try position("4kr2/8/8/8/8/8/8/R3K2R w KQ - 0 1")
        XCTAssertFalse(attacked.legalMoves().contains { $0.uci == "e1g1" })
        XCTAssertTrue(attacked.legalMoves().contains { $0.uci == "e1c1" })
        let missingRook = try position("4k3/8/8/8/8/8/8/4K3 w KQ - 0 1")
        XCTAssertFalse(missingRook.legalMoves().contains { abs($0.to - $0.from) == 2 })
    }

    func testRookCaptureRemovesCastlingRight() throws {
        let board = try position("r3k2r/Q7/8/8/8/8/8/4K3 w kq - 0 1")
        let next = board.applying(try move("a7a8", in: board))
        XCTAssertEqual(next.fen, "Q3k2r/8/8/8/8/8/8/4K3 b k - 0 1")
    }

    func testRookReturningHomeDoesNotRestoreCastlingRight() throws {
        var board = try position("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
        for uci in ["h1h2", "e8d8", "h2h1", "d8e8"] {
            board = board.applying(try move(uci, in: board))
        }
        XCTAssertFalse(board.legalMoves().contains { $0.uci == "e1g1" })
        XCTAssertEqual(board.fen, "4k3/8/8/8/8/8/8/4K2R w - - 4 3")
    }

    func testBlackQueensideCastlingAndFullmoveCounter() throws {
        let board = try position("r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 12 8")
        let next = board.applying(try move("e8c8", in: board))
        XCTAssertEqual(next.fen, "2kr3r/8/8/8/8/8/8/R3K2R w KQ - 13 9")
    }

    func testEnPassantRemovesCapturedPawn() throws {
        let board = try position("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2")
        let next = board.applying(try move("e5d6", in: board))
        XCTAssertEqual(next.fen, "4k3/8/3P4/8/8/8/8/4K3 b - - 0 2")
    }

    func testEnPassantCannotExposeOwnKing() throws {
        let board = try position("7k/8/8/r4pPK/8/8/8/8 w - f6 0 1")
        XCTAssertFalse(board.legalMoves().contains { $0.uci == "g5f6" })
    }

    func testBlackEnPassant() throws {
        let board = try position("4k3/8/8/8/3Pp3/8/8/4K3 b - d3 0 2")
        let next = board.applying(try move("e4d3", in: board))
        XCTAssertEqual(next.fen, "4k3/8/8/8/8/3p4/8/4K3 w - - 0 3")
    }

    func testEnPassantExpiresAfterOneMove() throws {
        var board = ChessPosition.initial
        board = board.applying(try move("e2e4", in: board))
        XCTAssertEqual(board.enPassantTarget, ChessPosition.square(named: "e3"))
        board = board.applying(try move("g8f6", in: board))
        XCTAssertNil(board.enPassantTarget)
    }

    func testFourPromotionsAndUnderpromotion() throws {
        let board = try position("7k/P7/8/8/8/8/8/7K w - - 0 1")
        let promotions = board.legalMoves(from: 48)
        XCTAssertEqual(Set(promotions.map(\.uci)), Set(["a7a8q", "a7a8r", "a7a8b", "a7a8n"]))
        let next = board.applying(try move("a7a8n", in: board))
        XCTAssertEqual(next.pieces[56], ChessPiece(color: .white, kind: .knight))
        XCTAssertEqual(next.halfmoveClock, 0)
    }

    func testBlackPromotionCaptureHasFourChoices() throws {
        let board = try position("7k/8/8/8/8/8/1p6/R6K b - - 0 1")
        let captures = board.legalMoves(from: 9).filter { $0.to == 0 }
        XCTAssertEqual(Set(captures.map(\.uci)), Set(["b2a1q", "b2a1r", "b2a1b", "b2a1n"]))
        let next = board.applying(try move("b2a1q", in: board))
        XCTAssertEqual(next.pieces[0], ChessPiece(color: .black, kind: .queen))
        XCTAssertTrue(next.isCheck)
    }

    func testPinnedRookMayMoveAlongPinButNotAway() throws {
        let board = try position("4r1k1/8/8/8/8/8/4R3/4K3 w - - 0 1")
        let moves = Set(board.legalMoves(from: 12).map(\.uci))
        XCTAssertFalse(moves.contains("e2d2"))
        XCTAssertTrue(moves.contains("e2e8"))
    }

    func testKingCannotCaptureDefendedPiece() throws {
        let board = try position("7k/8/8/8/8/4r3/4r3/4K3 w - - 0 1")
        XCTAssertTrue(board.isCheck)
        XCTAssertFalse(board.legalMoves().contains { $0.uci == "e1e2" })
    }

    func testFoolsMateAndStalemate() throws {
        var board = ChessPosition.initial
        for uci in ["f2f3", "e7e5", "g2g4", "d8h4"] {
            board = board.applying(try move(uci, in: board))
        }
        XCTAssertTrue(board.isCheck)
        XCTAssertTrue(board.isCheckmate)
        XCTAssertFalse(board.isStalemate)
        let stalemate = try position("7k/5K2/6Q1/8/8/8/8/8 b - - 0 1")
        XCTAssertTrue(stalemate.isStalemate)
        XCTAssertFalse(stalemate.isCheck)
        XCTAssertFalse(stalemate.isCheckmate)
    }

    func testCountersAndDoublePawnTarget() throws {
        var board = ChessPosition.initial
        board = board.applying(try move("g1f3", in: board))
        XCTAssertEqual(board.halfmoveClock, 1)
        XCTAssertEqual(board.fullmoveNumber, 1)
        board = board.applying(try move("g8f6", in: board))
        XCTAssertEqual(board.halfmoveClock, 2)
        XCTAssertEqual(board.fullmoveNumber, 2)
        board = board.applying(try move("e2e4", in: board))
        XCTAssertEqual(board.halfmoveClock, 0)
        XCTAssertTrue(board.fen.contains(" b KQkq e3 0 2"))
    }

    func testInvalidFENsAreRejected() {
        let invalid = [
            "8/8/8/8/8/8/8/8 w - - 0 1", // No kings.
            "7k/8/8/8/8/8/8/7K x - - 0 1", // Unknown turn.
            "7k/8/8/8/8/8/8/7K w KK - 0 1", // Duplicate castling right.
            "7k/8/8/8/8/8/8/7K w - e3 0 1", // Wrong en passant rank for White.
            "7k/8/8/8/8/8/8/7K w - - -1 1", // Negative halfmove.
            "7k/8/8/8/8/8/8/7K w - - 0 0", // Invalid fullmove.
            "9/8/8/8/8/8/8/7K w - - 0 1", // Invalid rank.
            "7k/8/8/8/8/8/8/7K w - - 0" // Missing field.
        ]
        for fen in invalid { XCTAssertThrowsError(try position(fen), fen) }
    }
}
