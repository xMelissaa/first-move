# Validation status

## Passed in this workspace

- Bundled course: 8 units, 32 lessons, 108 steps, 70 questions, 45 diagrams, and 33 accepted move answers.
- Every bundled FEN and accepted UCI move checked with chess.js 1.4.0. Specific checks include mate/stalemate examples, mate-in-one answers, fork targets, castling rook placement, en-passant capture removal, and castling through attack.
- Independent oracle: 128 positions and 440 resulting states, including White and Black turns, castling, promotions, en passant, check, checkmate, and stalemate. These are reference fixtures; this check does not execute the Swift engine.
- Swift Tree-sitter parsing: all app and test source files parse without syntax errors. A deliberately malformed source file was used as a negative control and correctly failed the checker. Parsing is not type-checking.
- XcodeGen and workflow YAML parsing, embedded Python syntax, Info.plist/entitlements/privacy-manifest parsing, bundled icon dimensions, and source archive contents.
- Independent static code review found and corrected Swift language-mode configuration, feature-flag parsing, multi-view card layout, and en-passant repetition identity.

## Prepared, not yet executed

- Native engine XCTest: standard initial/Kiwipete/endgame perft counts, special rules, pins, legal moves, FEN and check states.
- Native parity XCTest: compare the Swift engine with the 128-position independent oracle and 440 transitions, plus every course position and answer.
- Native progress XCTest: XP caps, streaks across DST/year boundaries, review schedules, account isolation, merges, resets and backup restores.
- Native UI tests: onboarding, goal/name settings, wrong-answer retries, first lesson completion, XP/unlock persistence after relaunch, tabs, legal board destinations and undo. Screenshot attachments are included in the tests.

These need the cloud Mac workflow. No Apple compiler, iPhone simulator, signed device, TestFlight upload, or iCloud round-trip was available in this Windows authoring session. A source package is not proof that these native checks pass.
