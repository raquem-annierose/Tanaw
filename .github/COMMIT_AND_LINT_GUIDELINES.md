# Commit & Lint Guidelines (Roblox / Luau)

Every commit is checked automatically. If a check fails, the commit is blocked; fix it and try again.

| Check                    | Tool                       | JS/TS equivalent | When it runs                      |
| ------------------------ | -------------------------- | ---------------- | --------------------------------- |
| Commit message format    | **commitlint** (via husky) | same             | On every `git commit`             |
| Docs/config formatting   | **Prettier**               | same             | Before every commit (md/json/yml) |
| Luau formatting          | **StyLua**                 | Prettier         | Before every commit (`src/`)      |
| Luau mistakes            | **Selene**                 | ESLint           | Before every commit (`src/`)      |
| Luau types (`--!strict`) | **luau-lsp analyze**       | `tsc --noEmit`   | Before every commit (`src/`)      |

## First-time setup

```bash
pnpm install         # commitlint, husky, Prettier, StyLua + turns on the git hooks
rokit install        # Rojo, luau-lsp, Selene, StyLua (install Rokit first: github.com/rojo-rbx/rokit)
```

In VS Code, install the recommended extensions when asked (Luau LSP, StyLua, Selene).

---

## 1. Commit messages

### Format

```
type(Scope): message
```

All three parts are required.

### Type

| Type       | Use it for                                     |
| ---------- | ---------------------------------------------- |
| `feat`     | A new feature (sticker maker, matching tables) |
| `fix`      | A bug fix                                      |
| `refactor` | Code cleanup that doesn't change behavior      |
| `perf`     | Making things faster or lighter                |
| `test`     | Adding or changing tests                       |
| `docs`     | Docs only (README, specs, tickets)             |
| `style`    | Formatting only, no logic change               |
| `chore`    | Setup, configs, tools, dependency updates      |
| `ci`       | GitHub Actions / automation                    |
| `build`    | Rojo project or build setup                    |
| `revert`   | Undoing an earlier commit                      |
| `asset`    | Roblox builds: maps, models, UI art, sounds    |

### Scope: PascalCase, always

The scope names the part of the game you touched.

- ✅ `feat(StickerMaker): add color picker`
- ❌ `feat(stickerMaker): add color picker` (camelCase)
- ❌ `feat: add color picker` (no scope)

Common scopes: `StickerMaker`, `Matching`, `Cafe`, `Overlook`, `Ui`, `DataStore`, `Lint`, `Docs`.

### Message

- Start with a lowercase verb, written as a command: _add_, _fix_, _remove_, _update_.
- ✅ `fix(Cafe): stop drink from floating after sitting`
- ❌ `fix(Cafe): Fixed the drink bug.`

### Length: keep the first line short

- The first line (`type(Scope): message`) can be **at most 100 characters**.
- Aim for **92 or less**. When GitHub squash-merges a PR it adds ` (#12)` at the end, which can push a long title over the limit.
- Keep only **one** `(#NN)` at the end. Delete older ones before squashing again.
- Body lines (optional, below a blank line) are also max 100 characters each.

### Merge commits follow the format too

Don't keep git's default `Merge branch 'main' of …`. Rename it:

```
chore(Git): merge main into feat/sticker-maker
```

### No AI co-author lines

Don't add `Co-Authored-By:` or "Generated with …" lines to commits or PRs.

### Check before you push

```bash
git fetch origin
pnpm commitlint        # checks every commit on your branch vs origin/main, no ✖ allowed
```

Fix a bad message **before** pushing: `git commit --amend -m "type(Scope): message"`.
If it's already pushed to _your own_ branch, amend and `git push --force-with-lease`.
Never force-push `main`.

### Examples

```
feat(StickerMaker): add shape and color picker
fix(Matching): unpair players when one leaves the table
asset(Cafe): add counter and menu board models
refactor(DataStore): move save logic into DataService
docs(Roadmap): mark phase 0 as done
chore(Lint): add stylua and selene configs
```

---

## 2. Code style (StyLua)

StyLua formats all `.luau` files the same way, so nobody argues about spacing and diffs stay clean. Settings are in `stylua.toml`: tabs, 100-char lines, double quotes, always use `()` on calls.

```bash
pnpm format            # fix formatting in src/
pnpm format:check      # only check, don't change
```

Tip: turn on **Format on Save** in VS Code with the StyLua extension.

## 3. Linting (Selene)

Selene catches mistakes in Luau code. Settings are in `selene.toml` (uses the Roblox standard library).

| Rule              | Level      | Meaning                                                         |
| ----------------- | ---------- | --------------------------------------------------------------- |
| `unused_variable` | ❌ Error   | Remove unused variables, or name them `_` / `_name`             |
| `global_usage`    | ❌ Error   | No globals: use `local`, or put shared values in a ModuleScript |
| `shadowing`       | ⚠️ Warning | Don't reuse a variable name inside an inner scope               |

```bash
pnpm lint              # run Selene on src/
pnpm check             # Prettier + StyLua + Selene + type check, same as the pre-commit hook
```

## 4. Type checking (Luau `--!strict`)

Luau has TypeScript-style types built in. `.luaurc` sets every file to **strict** mode, and the pre-commit hook blocks the commit on any type error.

```lua
--!strict
type Sticker = {
	shape: string,
	color: Color3,
	text: string?, -- optional, like `text?: string` in TS
}

local function placeSticker(player: Player, sticker: Sticker): boolean
	return true
end
```

```bash
pnpm typecheck         # Rojo sourcemap + luau-lsp analyze on src/
```

The type check uses Rojo's sourcemap to understand where scripts live in the game (`ReplicatedStorage.Shared`, etc.), and downloads Roblox's type definitions once into `.luau-types/`.

### Luau habits we follow

- Use `local` for everything. No globals.
- Use `print`/`warn` only while debugging; remove them before committing, except in a proper logger module.
- Prefix unused parameters with `_`:
  ```lua
  Players.PlayerAdded:Connect(function(player, _extra)
  	print(player.Name)
  end)
  ```
- Never trust the client. Check and filter everything that arrives through a RemoteEvent on the server.

---

## Quick checklist

- [ ] `type(PascalScope): lowercase message`
- [ ] First line ≤ 92 characters (hard limit 100), only one `(#NN)`
- [ ] No `Merge branch …` default messages
- [ ] No `Co-Authored-By` lines
- [ ] `pnpm check` passes (format, lint and types)
- [ ] `pnpm commitlint` shows no ✖ before pushing
