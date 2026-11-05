#!/usr/bin/env node
/**
 * Supplemental Swift syntax scan that can run on Windows. This is a Tree-sitter
 * parse, not Swift type checking, an iOS build, or a replacement for XCTest.
 *
 * Install Tools devDependencies, then run:
 *   node Tools/check-swift-syntax.mjs
 * An optional --runtime DIRECTORY resolves tooling from a separate package.json.
 * An optional --root DIRECTORY selects a different project checkout.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const toolsDir = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
// The Swift grammar is large. Limit WASM compilation to its baseline single-thread
// mode so Node 22/24 does not create a large background optimizing-compiler pool.
if (!args.includes('--syntax-worker')) {
  const worker = spawnSync(process.execPath, [
    '--liftoff-only', '--no-wasm-async-compilation', '--wasm-num-compilation-tasks=0',
    fileURLToPath(import.meta.url), '--syntax-worker', ...args,
  ], { stdio: 'inherit' });
  if (worker.error) process.stderr.write(`${worker.error.message}\n`);
  process.exit(worker.status ?? 2);
}
function option(name, fallback) {
  const index = args.indexOf(name);
  if (index < 0) return fallback;
  if (!args[index + 1]) throw new Error(`${name} requires a directory`);
  return path.resolve(args[index + 1]);
}

async function swiftFiles(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    if (['node_modules', '.git', '.build', 'DerivedData', 'build'].includes(entry.name)) continue;
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await swiftFiles(target));
    else if (entry.isFile() && entry.name.endsWith('.swift')) files.push(target);
  }
  return files.sort();
}

const flag = (node, property) => typeof node[property] === 'function' ? node[property]() : node[property];

try {
  const root = option('--root', path.resolve(toolsDir, '..'));
  const runtimeDir = option('--runtime', toolsDir);
  const require = createRequire(path.join(runtimeDir, 'package.json'));
  const binding = require('web-tree-sitter');
  const Parser = binding.Parser ?? binding.default ?? binding;
  await Parser.init();
  const Language = binding.Language ?? Parser.Language;
  const language = await Language.load(require.resolve('tree-sitter-wasms/out/tree-sitter-swift.wasm'));
  const parser = new Parser();
  parser.setLanguage(language);
  const files = await swiftFiles(root);
  if (files.length === 0) throw new Error(`No Swift source files found in ${root}`);

  const failures = [];
  let linesChecked = 0;
  for (const file of files) {
    const source = await fs.readFile(file, 'utf8');
    const lines = source.split(/\r?\n/);
    linesChecked += lines.length;
    const tree = parser.parse(source);
    if (!tree) throw new Error(`Parser returned no syntax tree for ${file}`);
    const errors = [];
    const visit = node => {
      if (node.type === 'ERROR' || flag(node, 'isMissing')) {
        errors.push({
          line: node.startPosition.row + 1,
          column: node.startPosition.column + 1,
          type: node.type,
          missing: Boolean(flag(node, 'isMissing')),
          text: lines[node.startPosition.row]?.trim().slice(0, 200) ?? '',
        });
      }
      for (const child of node.children) visit(child);
    };
    if (flag(tree.rootNode, 'hasError')) visit(tree.rootNode);
    if (errors.length) failures.push({ file: path.relative(root, file).replaceAll('\\', '/'), errors });
    tree.delete();
  }
  parser.delete();
  const summary = {
    check: 'Tree-sitter Swift syntax parse',
    limitation: 'This does not type-check Swift, build the iOS app, or execute XCTest.',
    filesChecked: files.length,
    linesChecked,
    syntaxErrors: failures.reduce((sum, item) => sum + item.errors.length, 0),
    failures,
  };
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`, () => process.exit(failures.length ? 1 : 0));
} catch (error) {
  process.stderr.write(`Swift syntax tooling failed: ${error.message || error.stack || String(error)}\n`);
  process.exitCode = 2;
}
