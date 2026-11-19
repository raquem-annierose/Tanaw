// Runs StyLua (format check) and Selene (lint) on src/.
// Run it through npm (`npm run check`, also used by the pre-commit hook)
// so node_modules/.bin is on PATH.
// Skips quietly when there is no src/ folder yet (before Phase 2).
const { existsSync } = require("node:fs");
const { spawnSync } = require("node:child_process");

if (!existsSync("src")) {
  process.stdout.write("check: no src/ folder yet, skipping StyLua and Selene\n");
  process.exit(0);
}

function sh(command, stdio = "inherit") {
  return spawnSync(command, { stdio, shell: true });
}

function run(label, command) {
  const result = sh(command);
  if (result.error || result.status !== 0) {
    process.stderr.write(`\ncheck: ${label} failed\n`);
    process.exit(result.status || 1);
  }
}

run("StyLua (run `npm run format` to fix)", "stylua --check src");

if (sh("selene --version", "ignore").status === 0) {
  run("Selene", "selene src");
} else {
  process.stdout.write("check: selene not installed (run `rokit install`), skipping lint\n");
}
