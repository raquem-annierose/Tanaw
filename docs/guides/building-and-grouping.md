# Building & Grouping in Studio

How we organize the map in Tanaw: when to use a Folder, a Model, or a Package, how to name things, and how to build so the game stays readable and fast. For saving, publishing, and undoing package changes, see [Studio Changes & Packages](studio-changes-and-packages.md).

## Quick answers

**Folder o Model?** Use a **Model** for something that is one _thing_ you can see and move (a booth, a bench, a building). Use a **Folder** only to keep a list of things tidy when they don't need to move as one (e.g. `Poles`, `Plants`).

**Kailan dapat package?** One package per **area** (Hiraya, Stalls, ParkingLot…), or for a model you copy many times. Not for every small prop.

**Pwede ba package sa loob ng package?** Avoid it. You have to publish the inner one first, then the outer one, and it's easy to forget (that's how `Overlook` was stuck on an old version).

**Paano malalaman ng code kung alin ang upuan o ilaw?** **Tags**, not names or folders. A builder can rename and move things freely; only the tag matters to the code.

## The building blocks

| Element        | What it is                                            | Use it for                                                        |
| -------------- | ----------------------------------------------------- | ----------------------------------------------------------------- |
| **Part**       | A basic block, ball, or cylinder                      | Most of the map: floors, walls, tables, bulbs                     |
| **MeshPart**   | A 3D shape imported from Blender or the Toolbox       | Detailed shapes (plants, cups, chairs) that would need many Parts |
| **Union**      | Parts glued or cut together in Studio                 | Rarely. Heavier than they look; prefer a MeshPart or plain Parts  |
| **Model**      | A group with a **pivot** (one move and rotate handle) | Any object that moves, rotates, or is copied as one               |
| **Folder**     | A plain list, no position, no handle                  | Grouping things that don't move as one                            |
| **Package**    | A Model with its own **version history**              | One per area, or a model reused in many places                    |
| **Tag**        | A label (CollectionService) on a part or model        | Telling the code "this is a seat / light / NPC spot"              |
| **Attribute**  | A custom value on an instance                         | Settings the code reads, e.g. a seat's pose                       |
| **Attachment** | A point on a part                                     | Where a light, particle, or prompt sits                           |

## How to decide

```
Is it one thing you'd move, rotate, or copy as a whole?
├─ yes → Model
│        Is it a whole area, or copied in many places?
│        ├─ yes → make that Model a Package (group-owned)
│        └─ no  → leave it a plain Model
└─ no, it's just a list of similar things → Folder
```

**Examples from Tanaw**

| Thing                               | Type    | Why                                                    |
| ----------------------------------- | ------- | ------------------------------------------------------ |
| `Overlook.Stalls`                   | Package | A whole area, with its own version history             |
| `Stalls.Siomai`                     | Model   | One booth; you move it as one                          |
| `Siomai.Booth`, `.Props`, `.Lights` | Model   | Parts of the booth, so each can be selected on its own |
| `StringLights.Poles`                | Folder  | Just a list of poles; they never move together         |
| `Seating.PalletBenches.Row1_Front`  | Model   | One row you can shift as a unit                        |

## How the map is laid out

```
Workspace
├─ Overlook              ← where players play (plain Model)
│  ├─ Hiraya             ← package: the café
│  ├─ Stalls             ← package: food stalls
│  ├─ Seating            ← package: benches and café tables
│  ├─ Plateau            ← package: terraces and walkways
│  ├─ StringLights       ← package
│  ├─ ParkingLot         ← package
│  ├─ Playground         ← package
│  └─ SpawnLocation
├─ Surroundings          ← package: background only (City, MidGround)
└─ GlobalPianoConnector  ← needed by the piano; must stay in Workspace
```

Rules:

1. **Workspace is for the map.** Scripts and systems go in `ServerScriptService`, or in `src/` in the repo. Don't drop free-model scripts in Workspace.
2. **`Overlook` and `Surroundings` keep their names.** The loading screen waits for them by name.
3. **Inside an area, group by what it is**: `Booth`, `Props`, `Lights`, `Landscaping`, `Walls`, `Roof`.
4. **A new area** → make a Model under `Overlook`, build inside it, then convert it to a package (see the packages guide).

## Naming

- **PascalCase, and say what it is**: `CafeTable1`, `WheelStop`, `SecondFloorSlab`.
- **Never leave defaults**: no `Part`, `Model`, `Union`, `B`, `grass`.
- **No duplicate names at the same level** for different things. `Overlook.StringLights` and `Playground.FairyLights` are different names on purpose.
- **Many copies of the same piece can share a name**: 26 `Bulb` parts in a span is fine.
- **Directions and order go at the end**: `Row1_Front`, `Span_FL_FR`, `BackWall`.

## Tags (what the code looks for)

Add tags in Studio: select the part → Properties → **Tags** → `+`. Copying a tagged part copies the tag.

| Tag         | Put it on                                           | What happens                  |
| ----------- | --------------------------------------------------- | ----------------------------- |
| `PoseSeat`  | A `Seat`                                            | Players get the sit-pose menu |
| `WarmLight` | String lights, fairy lights, tent glow              | Follow the time of day        |
| `CityLight` | City and house window parts                         | Hidden by day, glow at night  |
| `CafeOrder` | The order spot at the counter                       | Adds the "Order" prompt       |
| `AvatarNpc` | A part on the floor, front face where the NPC looks | Spawns an NPC there           |

The Hiraya lights also carry an `IndoorLight` tag, but no code uses it yet.

If a new object should _do_ something, ask a developer which tag to use. Don't add a script to the model.

## Build so it runs well

Players are on phones. Every part costs a little, so keep these in mind:

- **Anchor everything** in the map (`Anchored = true`).
- **Turn off `CastShadow`** on tiny parts (under ~2 studs), far background, and Neon parts. Nobody sees those shadows, and the GPU still draws them.
- **Decor that nobody touches**: turn off `CanCollide`, `CanTouch`, and `CanQuery` on bulbs, wires, and small props.
- **Fewer, bigger parts** beat many small ones. A wall is one part, not ten.
- **Lights**: `PointLight` / `SpotLight` with `Shadows` off unless it really matters. A glowing Neon bulb often looks enough without a light inside.
- **Many identical details** (city windows, bricks) → one MeshPart from Blender is far cheaper than hundreds of Parts.

## Checklist before you publish a package

- [ ] Everything is inside the right group, named clearly
- [ ] No stray `Part` / `Model` / `Union` names
- [ ] Interactive things have their tag
- [ ] Everything is anchored; no scripts inside
- [ ] `CastShadow` off on tiny and far parts
- [ ] Right-click the package → **Publish to Package**, then **Save to Roblox**
