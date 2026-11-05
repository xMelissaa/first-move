import XCTest
@testable import FirstMove

final class TrainingBotTests: XCTestCase {
    func testPracticePartnerFindsAnImmediateMate() throws {
        let position = try ChessPosition(fen: "7k/8/5KQ1/8/8/8/8/8 w - - 0 1")
        let move = try XCTUnwrap(TrainingBot.choose(in: position))
        XCTAssertTrue(position.legalMoves().contains(move))
        XCTAssertTrue(position.applying(move).isCheckmate)
    }

    func testPracticePartnerDoesNotMoveAfterTheGameEnds() throws {
        let mate = try ChessPosition(fen: "7k/6Q1/5K2/8/8/8/8/8 b - - 0 1")
        let stalemate = try ChessPosition(fen: "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
        XCTAssertNil(TrainingBot.choose(in: mate))
        XCTAssertNil(TrainingBot.choose(in: stalemate))
    }
}
