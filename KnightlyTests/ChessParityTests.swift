import Foundation
import XCTest
@testable import FirstMove

/// These expectations come from chess.js 1.4.0, not from ChessPosition.
/// Run these hosted tests on an iOS Simulator or an iPhone before release.
final class ChessParityTests: XCTestCase {
    private struct FixtureDocument: Decodable {
        let schemaVersion: Int
        let oracle: String
        let positions: [PositionFixture]
    }

    private struct PositionFixture: Decodable {
        let id: String
        let fen: String
        let legalMoves: [String]
        let isCheck: Bool
        let isCheckmate: Bool
        let isStalemate: Bool
        let transitions: [TransitionFixture]
    }

    private struct TransitionFixture: Decodable {
        let uci: String
        let fen: String
        let isCheck: Bool
        let isCheckmate: Bool
        let isStalemate: Bool
    }

    private func fixtures() throws -> FixtureDocument {
        let bundle = Bundle(for: ChessParityTests.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "chess-parity", withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "chess-parity", withExtension: "json"),
            "Add KnightlyTests/Fixtures/chess-parity.json to the test target’s resources."
        )
        return try JSONDecoder().decode(FixtureDocument.self, from: Data(contentsOf: url))
    }

    /// Chess.js emits '-' when an en-passant target has no legal capture.
    /// Keeping that harmless target in native FEN is also valid. Compare the
    /// board, turn, rights, and both move counters, then check actionable EP.
    private func fenWithoutEnPassant(_ fen: String) -> String {
        var fields = fen.split(separator: " ").map(String.init)
        if fields.count == 6 { fields[3] = "-" }
        return fields.joined(separator: " ")
    }

    func testNativeLegalMoveSetsMatchIndependentOracle() throws {
        let document = try fixtures()
        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertEqual(document.oracle, "chess.js@1.4.0")
        XCTAssertGreaterThanOrEqual(document.positions.count, 100)

        for fixture in document.positions {
            let position = try ChessPosition(fen: fixture.fen)
            XCTAssertEqual(
                position.legalMoves().map(\.uci).sorted(),
                fixture.legalMoves.sorted(),
                "Legal moves differ for \(fixture.id): \(fixture.fen)"
            )
            XCTAssertEqual(position.isCheck, fixture.isCheck, fixture.id)
            XCTAssertEqual(position.isCheckmate, fixture.isCheckmate, fixture.id)
            XCTAssertEqual(position.isStalemate, fixture.isStalemate, fixture.id)
        }
    }

    func testNativeResultStatesMatchIndependentOracle() throws {
        let document = try fixtures()
        var checkedTransitions = 0

        for fixture in document.positions {
            let position = try ChessPosition(fen: fixture.fen)
            let legal = position.legalMoves()
            for transition in fixture.transitions {
                let context = "\(fixture.id), move \(transition.uci)"
                let move = try XCTUnwrap(legal.first { $0.uci == transition.uci }, context)
                let next = position.applying(move)
                XCTAssertEqual(fenWithoutEnPassant(next.fen), fenWithoutEnPassant(transition.fen), context)
                let expectedFields = transition.fen.split(separator: " ")
                if expectedFields.count == 6, expectedFields[3] != "-" {
                    XCTAssertEqual(
                        next.enPassantTarget.map { ChessPosition.name(of: $0) },
                        String(expectedFields[3]),
                        "Missing actionable en-passant target: \(context)"
                    )
                }
                XCTAssertEqual(next.isCheck, transition.isCheck, context)
                XCTAssertEqual(next.isCheckmate, transition.isCheckmate, context)
                XCTAssertEqual(next.isStalemate, transition.isStalemate, context)
                checkedTransitions += 1
            }
        }
        XCTAssertGreaterThanOrEqual(checkedTransitions, 300)
    }

    func testBundledCoursePositionsAndAcceptedMovesAreLegal() throws {
        // These are hosted app tests: Bundle.main must contain the real course,
        // so this also catches a missing or incorrectly named app resource.
        let catalog = CourseCatalog()
        XCTAssertNil(catalog.errorMessage)
        XCTAssertGreaterThanOrEqual(catalog.units.count, 8)
        XCTAssertGreaterThanOrEqual(catalog.lessons.count, 32)
        var diagramCount = 0
        var acceptedMoveCount = 0

        for lesson in catalog.lessons {
            for (index, step) in lesson.steps.enumerated() {
                let context = "\(lesson.id), step \(index + 1)"
                if let fen = step.fen {
                    let position = try ChessPosition(fen: fen)
                    diagramCount += 1
                    if step.type == "move" {
                        let answers = try XCTUnwrap(step.accept, context)
                        XCTAssertFalse(answers.isEmpty, context)
                        let legal = Set(position.legalMoves().map(\.uci))
                        for answer in answers {
                            XCTAssertTrue(legal.contains(answer), "Illegal course answer \(answer): \(context)")
                            acceptedMoveCount += 1
                        }
                    }
                } else if step.type == "move" {
                    XCTFail("Move exercise is missing its FEN: \(context)")
                }
                for highlight in step.highlights ?? [] {
                    XCTAssertNotNil(ChessPosition.square(named: highlight), context)
                }
            }
        }
        XCTAssertGreaterThanOrEqual(diagramCount, 40)
        XCTAssertGreaterThanOrEqual(acceptedMoveCount, 30)
    }
}
