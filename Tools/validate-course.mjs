import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { Chess } from 'chess.js';

const coursePath = process.argv[2]
  ? resolve(process.argv[2])
  : fileURLToPath(new URL('../Knightly/Resources/course.json', import.meta.url));
const fixturePath = fileURLToPath(new URL('../KnightlyTests/Fixtures/chess-parity.json', import.meta.url));
const course = JSON.parse(readFileSync(coursePath, 'utf8'));
const fixture = JSON.parse(readFileSync(fixturePath, 'utf8'));
const toUCI = move => move.from + move.to + (move.promotion ?? '');
const legalUCI = position => position.moves({ verbose: true }).map(toUCI).sort();
const applyUCI = (position, uci) => position.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });
const status = position => ({ isCheck: position.isCheck(), isCheckmate: position.isCheckmate(), isStalemate: position.isStalemate() });

function assertPositionIsConsistent(fen, context) {
  const position = new Chess(fen);
  // A legal diagram may have the moving king in check; the other king cannot
  // already be in check. Clear EP before reversing the active-color field.
  const fields = fen.split(/\s+/);
  fields[1] = position.turn() === 'w' ? 'b' : 'w';
  fields[3] = '-';
  assert.equal(new Chess(fields.join(' ')).isCheck(), false, `${context}: inactive king is already in check`);
  return position;
}

assert.ok(course.units.length >= 8, 'Course should have at least eight units');
assert.ok(course.lessons.length >= 32, 'Course should have at least 32 lessons');
const unitIDs = new Set(course.units.map(unit => unit.id));
assert.equal(unitIDs.size, course.units.length, 'Unit identifiers must be unique');
assert.equal(new Set(course.lessons.map(lesson => lesson.id)).size, course.lessons.length, 'Lesson identifiers must be unique');
let diagrams = 0, acceptedMoves = 0, questions = 0, steps = 0;
for (const unit of course.units) {
  assert.ok(course.lessons.some(lesson => lesson.unit === unit.id), `${unit.id}: unit has no lessons`);
  assert.match(unit.color, /^#[0-9a-f]{6}$/i, `${unit.id}: invalid color`);
}
for (const lesson of course.lessons) {
  assert.ok(unitIDs.has(lesson.unit), `${lesson.id}: missing unit`);
  assert.ok(Number.isInteger(lesson.xp) && lesson.xp > 0, `${lesson.id}: invalid XP`);
  assert.ok(Number.isInteger(lesson.minutes) && lesson.minutes > 0, `${lesson.id}: invalid duration`);
  assert.ok(lesson.steps.length >= 3, `${lesson.id}: incomplete lesson`);
  assert.ok(lesson.steps.some(step => step.type !== 'read'), `${lesson.id}: no knowledge check`);
  for (const [index, step] of lesson.steps.entries()) {
    steps += 1;
    const context = `${lesson.id}, step ${index + 1}`;
    let position;
    if (step.fen) { position = assertPositionIsConsistent(step.fen, context); diagrams += 1; }
    for (const highlight of step.highlights ?? []) assert.match(highlight, /^[a-h][1-8]$/, `${context}: invalid highlighted square`);
    if (step.type === 'read') {
      assert.ok(step.title && step.body, `${context}: incomplete explanation`);
    } else if (step.type === 'choice') {
      questions += 1;
      assert.ok(step.prompt && step.explanation, `${context}: missing prompt or feedback`);
      assert.ok(Array.isArray(step.options) && step.options.length >= 2, `${context}: too few choices`);
      assert.ok(Number.isInteger(step.answer) && step.answer >= 0 && step.answer < step.options.length, `${context}: invalid answer index`);
      assert.equal(new Set(step.options).size, step.options.length, `${context}: duplicate options`);
    } else if (step.type === 'move') {
      questions += 1;
      assert.ok(position, `${context}: missing position`);
      assert.ok(step.prompt && step.explanation && step.hint, `${context}: missing prompt, feedback, or hint`);
      assert.ok(step.accept?.length, `${context}: no accepted move`);
      assert.equal(new Set(step.accept).size, step.accept.length, `${context}: duplicate answers`);
      const legal = legalUCI(position);
      for (const uci of step.accept) {
        assert.match(uci, /^[a-h][1-8][a-h][1-8][qrbn]?$/, `${context}: malformed UCI answer`);
        assert.ok(legal.includes(uci), `${context}: illegal answer ${uci}`);
        const next = new Chess(step.fen);
        const played = applyUCI(next, uci);
        assert.ok(played, `${context}: answer did not apply`);
        if (/checkmate/i.test(step.prompt)) assert.equal(next.isCheckmate(), true, `${context}: claimed mate is not mate`);
        if (/capture/i.test(step.prompt)) assert.ok(played.captured, `${context}: expected a capture`);
        if (lesson.id === 'knight-forks') {
          assert.ok(next.isCheck() && next.isAttacked('c8', 'w'), 'Knight fork must check and attack the queen');
        }
        if (lesson.id === 'ready-to-keep-learning') {
          assert.ok(next.isCheck() && next.isAttacked('a8', 'w'), 'Final fork must check and attack the rook');
        }
        acceptedMoves += 1;
      }
    } else {
      assert.fail(`${context}: unsupported step type ${step.type}`);
    }
  }
}

// Recheck the portable oracle file so accidental fixture edits fail clearly.
// The native XCTest suite compares its own engine with these expectations.
assert.equal(fixture.schemaVersion, 1);
assert.equal(fixture.oracle, 'chess.js@1.4.0');
assert.ok(fixture.positions.length >= 100 && fixture.positions.length <= 150);
assert.equal(new Set(fixture.positions.map(p => p.id)).size, fixture.positions.length);
const coverage = { white: 0, black: 0, castling: 0, enPassant: 0, promotion: 0, check: 0, mate: 0, stalemate: 0 };
let transitions = 0;
for (const expected of fixture.positions) {
  const position = assertPositionIsConsistent(expected.fen, expected.id);
  assert.deepEqual(legalUCI(position), [...expected.legalMoves].sort(), `${expected.id}: oracle move mismatch`);
  for (const [key, value] of Object.entries(status(position))) assert.equal(value, expected[key], `${expected.id}: ${key}`);
  coverage[position.turn() === 'w' ? 'white' : 'black'] += 1;
  coverage.check += Number(position.isCheck());
  coverage.mate += Number(position.isCheckmate());
  coverage.stalemate += Number(position.isStalemate());
  for (const move of position.moves({ verbose: true })) {
    coverage.castling += Number(/[kq]/.test(move.flags));
    coverage.enPassant += Number(move.flags.includes('e'));
    coverage.promotion += Number(Boolean(move.promotion));
  }
  for (const transition of expected.transitions) {
    const next = new Chess(expected.fen);
    applyUCI(next, transition.uci);
    assert.equal(next.fen(), transition.fen, `${expected.id}: result of ${transition.uci}`);
    for (const [key, value] of Object.entries(status(next))) assert.equal(value, transition[key], `${expected.id}: result ${key}`);
    transitions += 1;
  }
}
for (const [feature, count] of Object.entries(coverage)) assert.ok(count > 0, `Fixture lacks ${feature} coverage`);
assert.ok(transitions >= 300, 'Fixture needs at least 300 checked result states');
assert.ok(diagrams >= 40 && acceptedMoves >= 30, 'Course needs enough interactive board practice');

console.log(`Course verified: ${course.units.length} units, ${course.lessons.length} lessons, ${steps} steps, ${questions} questions, ${diagrams} diagrams, ${acceptedMoves} legal accepted moves.`);
console.log(`Oracle verified: ${fixture.positions.length} positions, ${transitions} result states. Coverage: ${JSON.stringify(coverage)}.`);
console.log('These checks validate content and oracle data. Run the XCTest suite on macOS to verify the native Swift engine against the oracle.');
