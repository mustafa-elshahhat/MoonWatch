#!/usr/bin/env node
/**
 * Package the built TV app into a Tizen .wgt with NO spaces in the filename.
 *
 * The widget <name> in config.xml is "MoonWatchTV" (no space), so the Tizen
 * CLI already emits "MoonWatchTV.wgt" — this script wires that into one npm
 * command and defensively normalizes the filename if a spaced one ever shows up.
 *
 * Usage:
 *   npm run package:tizen
 *   npm run package:tizen -- --profile <certificateProfileName>
 *   TIZEN_PROFILE=<name> npm run package:tizen
 *
 * Packages the CURRENT contents of dist/. Run `npm run build` first for a fresh
 * build (this script builds automatically only if dist/ is missing).
 */
import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, renameSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(root, 'dist');
const OUTPUT = 'MoonWatchTV.wgt';
const isWin = process.platform === 'win32';

function arg(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

const profile = arg('profile') || process.env.TIZEN_PROFILE || 'moonwatch_tv_emulator';

function run(command, args, cwd) {
  return spawnSync(command, args, { cwd, stdio: 'inherit', shell: isWin });
}

function hasTizenCli() {
  const probe = spawnSync('tizen', ['version'], { stdio: 'ignore', shell: isWin });
  return !probe.error && probe.status === 0;
}

function printManualSteps() {
  console.error('\n✗ The Tizen CLI ("tizen") was not found on PATH.');
  console.error('  The web build in dist/ is ready. Package it manually with Tizen Studio CLI:');
  console.error('    cd dist');
  console.error(`    tizen package -t wgt -s ${profile} -- .`);
  console.error(`    tizen install -n ${OUTPUT}`);
  console.error('  Install Tizen Studio + the TV extension and create the certificate profile first.');
}

// 1. Build if dist/ is missing.
if (!existsSync(join(dist, 'config.xml'))) {
  console.log('• dist/ not found — running build…');
  const build = run('npm', ['run', 'build'], root);
  if (build.status !== 0) process.exit(build.status ?? 1);
}

// 2. Package with the Tizen CLI.
if (!hasTizenCli()) {
  printManualSteps();
  process.exit(1);
}

console.log(`• Packaging dist/ with certificate profile "${profile}"…`);
const pack = run('tizen', ['package', '-t', 'wgt', '-s', profile, '--', '.'], dist);
if (pack.status !== 0) {
  console.error('\n✗ tizen package failed. Check that the certificate profile exists and is valid.');
  process.exit(pack.status ?? 1);
}

// 3. Guarantee a space-free output filename.
const wgts = readdirSync(dist).filter((file) => file.toLowerCase().endsWith('.wgt'));
const spaced = wgts.find((file) => file !== OUTPUT);
if (spaced && !existsSync(join(dist, OUTPUT))) {
  renameSync(join(dist, spaced), join(dist, OUTPUT));
  console.log(`• Renamed "${spaced}" → ${OUTPUT}`);
}

if (!existsSync(join(dist, OUTPUT))) {
  console.error(`\n✗ Expected dist/${OUTPUT} but it was not produced.`);
  process.exit(1);
}

console.log(`\n✓ Packaged dist/${OUTPUT}`);
console.log(`  Install on the emulator:  cd dist && tizen install -n ${OUTPUT}`);
