# Tanaw

A cozy hilltop café hangout on Roblox by **NieRa Studios**. This repo holds the plans, specs, and tickets, and from Phase 2 on, the game code (see [docs/02-architecture.md](docs/02-architecture.md)).

**Community:** NieRa Studios
**First game:** **Tanaw**, a chill hilltop café hangout

| Doc                                                | What's inside                                                     |
| -------------------------------------------------- | ----------------------------------------------------------------- |
| [docs/01-vision.md](docs/01-vision.md)             | Idea, community/game name options, theme, features                |
| [docs/02-architecture.md](docs/02-architecture.md) | How Roblox code works, repo setup, folder structure, collab rules |
| [docs/03-roadmap.md](docs/03-roadmap.md)           | Learning journey: phases and to-do checklist                      |
| [docs/04-tickets.md](docs/04-tickets.md)           | Brainstorm + build tickets (copy these into GitHub Issues later)  |

**FigJam brainstorm board:** https://www.figma.com/board/OSW6eQhloNPseKiGv3PYhD

## Setup (do this once after cloning)

### 1. Install these first

| Tool                        | Why                                                        | Get it                                                                               |
| --------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **Git**                     | Version control                                            | git-scm.com                                                                          |
| **Node.js 20+**             | Runs the commit and lint tools                             | nodejs.org                                                                           |
| **pnpm**                    | Package manager for this repo (don't use npm or yarn)      | `npm install -g pnpm`, or pnpm.io/installation                                       |
| **Rokit**                   | Installs the Roblox tools (Rojo, luau-lsp, Selene, StyLua) | github.com/rojo-rbx/rokit/releases → download the zip, then run `rokit self-install` |
| **Roblox Studio**           | Building and testing the game                              | create.roblox.com                                                                    |
| **VS Code** _(recommended)_ | Code editor                                                | code.visualstudio.com                                                                |

Restart your terminal after installing Rokit so it's on your PATH.

### 2. Clone and install

```bash
git clone git@github.com:raquem-annierose/Tanaw.git
cd Tanaw
pnpm install         # commitlint, husky, Prettier, StyLua + turns on the git hooks
rokit install        # Rojo, luau-lsp, Selene, StyLua (answer "yes" to trust them)
```

Or do both in one step: `pnpm bootstrap`.

### 3. VS Code

Open the folder and click **Install** when VS Code suggests the recommended extensions (Luau LSP, StyLua, Selene).

### 4. Check it works

```bash
selene --version
pnpm check
```

### Everyday commands

| Command           | What it does                                               |
| ----------------- | ---------------------------------------------------------- |
| `pnpm check`      | Everything below in one go (same as the pre-commit hook)   |
| `pnpm format`     | Auto-format docs/configs (Prettier) and Luau code (StyLua) |
| `pnpm lint`       | Run Selene on `src/`                                       |
| `pnpm typecheck`  | Luau type check on `src/` (like `tsc --noEmit`)            |
| `pnpm commitlint` | Check your branch's commit messages vs `origin/main`       |

### Syncing code into Studio (Rojo)

```bash
rojo serve
```

Then in Roblox Studio, open the **Rojo** plugin and click **Connect**. Edits in `src/` show up in Studio live. Install the plugin once with `rojo plugin install`.

Before your first commit, read [.github/COMMIT_AND_LINT_GUIDELINES.md](.github/COMMIT_AND_LINT_GUIDELINES.md). Commits that don't follow it are blocked.

## Status

- [x] Pick community name: NieRa Studios
- [x] Pick game name: Tanaw
- [ ] Check NieRa Studios is free on Roblox, Discord, TikTok, GitHub
- [ ] Finish Phase 0 of the roadmap
