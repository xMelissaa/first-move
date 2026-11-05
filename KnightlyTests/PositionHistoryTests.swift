import XCTest
@testable import FirstMove

final class PositionHistoryTests: XCTestCase {
    func testUncapturableEnPassantDoesNotChangeRepetitionIdentity() throws {
        var position = ChessPosition.initial
        var keys: [String] = []
        for uci in ["e2e4", "g8f6", "g1f3", "f6g8", "f3g1", "g8f6", "g1f3", "f6g8", "f3g1"] {
            let move = try XCTUnwrap(position.legalMoves().first { $0.uci == uci })
            position = position.applying(move); keys.append(position.repetitionKey)
        }
        XCTAssertEqual(keys.filter { $0 == position.repetitionKey }.count, 3)
    }
    func testCapturableEnPassantChangesRepetitionIdentity() throws {
        let capture = try ChessPosition(fen: "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
        let noCapture = try ChessPosition(fen: "4k3/8/8/3pP3/8/8/8/4K3 w - - 0 1")
        XCTAssertNotEqual(capture.repetitionKey, noCapture.repetitionKey)
    }
}
