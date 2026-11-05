# Validation status

## Passed in this workspace

- Bundled course: 8 units, 32 lessons, 108 steps, 70 questions, 45 diagrams, and 33 accepted move answers.
- Every bundled FEN and accepted UCI move checked with chess.js 1.4.0. Specific checks include mate/stalemate examples, mate-in-one answers, fork targets, castling rook placement, en-passant capture removal, and castling through attack.
- Independent oracle: 128 positions and 440 resulting states, including White and Black turns, castling, promotions, en passant, check, checkmate, and stalemate. These are reference fixtures; this check does not execute the Swift engine.
- Swift Tree-sitter parsing: all app and test source files parse without syntax errors. A deliberately malformed source file was used as a negative control and correctly failed the checker. Parsing is not type-checking.
- XcodeGen and workflow YAML parsing, embedded Python syntax, Info.plist/entitlements/privacy-manifest parsing, bundled icon dimensions, and source archive contents.
- Independent static code review found and corrected Swift language-mode configuration, feature-flag parsing, multi-view card layout, and en-passant repetition identity.

## Passed on Apple's toolchain in the cloud

- Native engine XCTest: standard initial/Kiwipete/endgame perft counts, special rules, pins, legal moves, FEN and check states.
- Native parity XCTest: compare the Swift engine with the 128-position independent oracle and 440 transitions, plus every course position and answer.
- Native progress XCTest: XP caps, streaks across DST/year boundaries, review schedules, account isolation, merges, resets and backup restores.
- Native UI tests: onboarding, goal/name settings, wrong-answer retries, first lesson completion, XP/unlock persistence after relaunch, tabs, legal board destinations and undo. Screenshot attachments are included in the tests.

All 35 native unit tests and 2 UI tests passed with zero failures. The run used Xcode 26.6 and an iPhone Air simulator on a GitHub-hosted Mac. Its test step ended with `TEST SUCCEEDED`; screenshot capture and artifact upload also succeeded.

- Tested app source: `400b1bafaec3b6ce338cc4b1a04bd770a62d8859`.
- [Successful run](https://github.com/xMelissaa/first-move/actions/runs/42095101106), completed November 5, 2026.
- Unit suites: ChessParityTests (3), ChessPositionTests (20), PositionHistoryTests (2), ProgressTests (8), TrainingBotTests (2).
- UI suite: FirstMoveUITests (2), covering real launch/interaction/persistence.
- The captured learning-path screen was visually inspected after the run.
- All 40 uploaded source files matched their local Git blob hashes before this documentation update.

## Remaining signed-release checks

No physical iPhone, signed TestFlight upload, Apple sign-in entitlement, or iCloud round-trip has been tested yet. Those require the user's Apple developer enrollment and signing setup. Check smaller iPhone layouts, larger accessibility text, VoiceOver navigation, and two-device cloud synchronization before release. A passing simulator run is evidence for the tested configuration, not a guarantee of mistake-free software.
