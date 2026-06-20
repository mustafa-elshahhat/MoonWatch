// Protocol drift guard (SP-002).
//
// The watch-party protocol is defined three times — C# (shared/protocol),
// Dart (shared/lib/protocol), and TypeScript (this project's src/protocol).
// The C# and Dart copies live under shared/ and are exercised by the server
// build and shared/test, but the TypeScript copy has no build-time tie to the
// canonical source. This script compares the set of event/hub-method string
// VALUES across all three files and fails (exit 1) if they diverge, so a
// renamed/added/removed event in any language breaks CI instead of silently
// shipping a TV/server mismatch.
//
// Run via `npm run check:protocol` (wired into the Samsung TV CI job).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..', '..');

const sources = {
  'C# (shared/protocol/RoomEvents.cs)': resolve(repoRoot, 'shared/protocol/RoomEvents.cs'),
  'Dart (shared/lib/protocol/room_events.dart)': resolve(repoRoot, 'shared/lib/protocol/room_events.dart'),
  'TypeScript (client_samsung_tv/src/protocol/roomEvents.ts)': resolve(here, '..', 'src/protocol/roomEvents.ts'),
};

/** Extract every quoted string literal (single or double) from a file. */
function extractStringValues(file) {
  const text = readFileSync(file, 'utf8');
  const values = new Set();
  // Match "..." or '...' literals. The RoomEvents files contain only the
  // protocol constant values, so this captures exactly the event/method names.
  const re = /"([^"\\]*)"|'([^'\\]*)'/g;
  let match;
  while ((match = re.exec(text)) !== null) {
    const value = match[1] ?? match[2];
    if (value && value.length > 0) values.add(value);
  }
  return values;
}

const sets = Object.fromEntries(
  Object.entries(sources).map(([label, file]) => [label, extractStringValues(file)]),
);

// Use the union as the reference, then report what each source is missing/has extra.
const union = new Set();
for (const set of Object.values(sets)) for (const v of set) union.add(v);

let hasDrift = false;
const lines = [];
for (const [label, set] of Object.entries(sets)) {
  const missing = [...union].filter((v) => !set.has(v)).sort();
  if (missing.length > 0) {
    hasDrift = true;
    lines.push(`  ${label} is MISSING: ${missing.join(', ')}`);
  }
}

if (hasDrift) {
  console.error('Protocol drift detected — event/method strings differ across C#, Dart, and TypeScript:');
  for (const line of lines) console.error(line);
  console.error('\nKeep shared/protocol/RoomEvents.cs, shared/lib/protocol/room_events.dart, and');
  console.error('client_samsung_tv/src/protocol/roomEvents.ts in sync.');
  process.exit(1);
}

console.log(`Protocol drift check passed: ${union.size} event/method strings aligned across C#, Dart, and TypeScript.`);
