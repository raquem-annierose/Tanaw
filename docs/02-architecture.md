# 02: Architecture & Repo Setup

## Quick answers
**Lua ba?** Yes, technically **Luau**: Roblox's version of Lua with optional types. Same basics as Lua.

**Separate repo for frontend and logic?** **No, not for Roblox.** A Roblox game isn't a website with a separate frontend + backend server. The client and server code ship together in one place file. Splitting them into two repos makes every feature need two PRs that must be merged at the same time, which causes *more* conflicts, not fewer.

Instead: **one repo per game, with clear folders** for client / server / shared. That gives you the "easy to read, fewer conflicts" goal.

**APIs ba ang way sa Roblox?** Inside the game, no HTTP APIs. Client and server talk through **RemoteEvents / RemoteFunctions** (think of them like API endpoints inside the game). You only use real HTTP APIs for outside stuff (Discord webhooks, a website) via `HttpService` or Roblox **Open Cloud**.

## How a Roblox game is split

```
 PLAYER'S DEVICE (Client)            ROBLOX SERVER (Server)
 ─────────────────────────           ─────────────────────────
 LocalScripts                        Scripts
 - UI (menus, sticker editor)        - Matching players
 - Camera, input, effects            - Saving data (DataStore)
 - Plays sounds/animations           - Filtering text
        │                                   ▲
        └──── RemoteEvent: "PlaceSticker" ──┘
              (client asks, server checks + does it)

 SHARED (ModuleScripts both can use): configs, types, constants
```

**Golden rule:** never trust the client. The client *asks*, the server *decides* (checks the request, filters text, saves data).

## Recommended repos
Local layout: `roblox-builder/` is just a parent folder on your PC (not a repo). Each game is its own repo inside it.

```
C:\Users\raque\dev\roblox-builder\     ← parent folder, NOT a git repo
├─ tanaw\                              ← repo: github.com/raquem-annierose/Tanaw
├─ <game-2>\                           ← future repo
└─ niera-shared\                       ← future repo (game 2+)
```

| Repo | Purpose |
|---|---|
| `tanaw` | First game: its docs, specs, tickets, and (from Phase 2) the code |
| `niera-shared` *(later, game 2+)* | Shared Luau modules reused across games (UI kit, utils) |

## Tooling (code in VS Code, build in Studio)
| Tool | Why |
|---|---|
| **Roblox Studio** | Building maps, models, testing |
| **Rojo** | Syncs `.luau` files from your repo into Studio, so code lives in Git |
| **VS Code + Luau LSP** extension | Autocomplete, type hints |
| **StyLua** | Auto-formats code → same style for everyone, fewer silly diffs |
| **Selene** | Linter: catches mistakes |
| **Wally** *(optional)* | Package manager for Luau libraries |
| **Aftman / Rokit** | Installs the above tools with pinned versions |

**Code** lives in Git (via Rojo). **Builds** (Lara's café, the map) live in Studio. Save them as models (`.rbxm`) in `assets/` or keep them in the published place via **Team Create**.

## Game repo folder structure
```
tanaw/
├─ default.project.json      # Rojo config
├─ aftman.toml               # tool versions
├─ stylua.toml / selene.toml
├─ src/
│  ├─ client/                # → StarterPlayerScripts
│  │  ├─ init.client.luau
│  │  ├─ ui/                 # StickerEditor, MatchPrompt, CafeMenu
│  │  └─ controllers/        # CameraController, SitController
│  ├─ server/                # → ServerScriptService
│  │  ├─ init.server.luau
│  │  └─ services/           # MatchService, StickerService, DataService
│  └─ shared/                # → ReplicatedStorage
│     ├─ Remotes.luau        # ALL RemoteEvents defined in one place
│     ├─ Config.luau         # prices, prompts, colors
│     └─ Types.luau
├─ assets/                   # exported models (.rbxm) e.g. Cafe.rbxm
└─ docs/                     # plans, specs, tickets (already here)
```

**Feature = one folder per side.** Example: Sticker feature → `client/ui/StickerEditor.luau` + `server/services/StickerService.luau` + entries in `shared/Remotes.luau`. One person owns one feature at a time = almost no conflicts.

## Collab rules
1. `main` always works. Never push directly; use branches + Pull Requests.
2. Branch names: `feat/sticker-maker`, `fix/sit-bug`, `art/cafe-v1`.
3. One feature = one owner = one branch.
4. Run StyLua before committing.
5. Builders (Lara) work in Studio via Team Create; scripters work in VS Code via Rojo. Don't both edit the same script in Studio and in the repo.
6. Name things in English, PascalCase for modules (`StickerService`), camelCase for variables.
