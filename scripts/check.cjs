// Code quality gate. Runs on every commit (pre-commit hook) and via `pnpm check`.
// Run it through pnpm so node_modules/.bin is on PATH.
//
// 1. Prettier   - formatting for md / json / yml
// 2. StyLua     - formatting for Luau (src/)
// 3. Selene     - lint for Luau (src/)
// 4. luau-lsp   - type check for Luau (src/), like `tsc --noEmit`
//
// `--only-types` runs step 4 only (`pnpm typecheck`).
const { existsSync, mkdirSync, writeFileSync } = require("node:fs");
const { spawnSync } = require("node:child_process");
const path = require("node:path");

// Keep in sync with the luau-lsp version in rokit.toml.
const LUAU_LSP_VERSION = "1.70.1";
const DEFS_URL = `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/${LUAU_LSP_VERSION}/scripts/globalTypes.None.d.luau`;
const DEFS_FILE = path.join(".luau-types", `roblox-${LUAU_LSP_VERSION}.d.luau`);
const ONLY_TYPES = process.argv.includes("--only-types");

function sh(command, stdio = "inherit") {
  return spawnSync(command, { stdio, shell: true });
}

function fail(message) {
  process.stderr.write(`\ncheck: ${message}\n`);
  process.exit(1);
}

function run(label, command, fix) {
  process.stdout.write(`\n> ${label}\n`);
  const result = sh(command);
  if (result.error || result.status !== 0) {
    fail(`${label} failed${fix ? ` (${fix})` : ""}`);
  }
}

function requireTool(name) {
  if (sh(`${name} --version`, "ignore").status !== 0) {
    fail(`${name} is not installed. Run \`rokit install\` in this folder.`);
  }
}

async function ensureDefinitions() {
  if (existsSync(DEFS_FILE)) return;
  process.stdout.write(`check: downloading Roblox type definitions (${LUAU_LSP_VERSION})\n`);
  const response = await fetch(DEFS_URL);
  if (!response.ok) fail(`could not download Roblox types (HTTP ${response.status})`);
  mkdirSync(path.dirname(DEFS_FILE), { recursive: true });
  writeFileSync(DEFS_FILE, await response.text());
}

async function typecheck() {
  ["rojo", "luau-lsp"].forEach(requireTool);
  await ensureDefinitions();
  run("Rojo sourcemap", "rojo sourcemap default.project.json --output sourcemap.json");
  run(
    "Luau type check",
    `luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox=${DEFS_FILE} src`,
  );
}

async function main() {
  if (ONLY_TYPES) {
    await typecheck();
    process.stdout.write("\ncheck: types ok ✔\n");
    return;
  }

  run("Prettier", "prettier --check .", "run `pnpm format` to fix");

  if (!existsSync("src")) {
    process.stdout.write("\ncheck: no src/ folder, skipping Luau checks\n");
    return;
  }

  ["stylua", "selene"].forEach(requireTool);
  run("StyLua", "stylua --check src", "run `pnpm format` to fix");
  run("Selene", "selene src");
  await typecheck();

  process.stdout.write("\ncheck: all good ✔\n");
}

main().catch((error) => fail(String(error)));
