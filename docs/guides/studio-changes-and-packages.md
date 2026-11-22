# Studio Changes & Packages

How changes are tracked in Tanaw, and how to undo a mistake without losing everyone else's work.

## Quick answers

**Bakit di lumalabas sa git ang edits ko sa Studio?** Rojo only syncs one way: **files → Studio**. Anything you change inside Studio (parts, models, or a script edited in Studio's editor) is never written back to the repo.

**So saan dapat mag-edit?**

| What you're changing         | Edit it in    | Where it's saved                        | How to undo                      |
| ---------------------------- | ------------- | --------------------------------------- | -------------------------------- |
| Code (`.luau`)               | VS Code       | Git (pushed to GitHub)                  | `git revert` / restore a file    |
| Map, models, parts, lighting | Roblox Studio | The place file on Roblox (Save/Publish) | Package history or place history |

**Edited a script in Studio?** Rojo overwrites it on the next sync. Move the change into the `.luau` file in VS Code instead.

## Packages (undo one model)

A **package** is a model with its own version history. If someone breaks the Stalls, you roll back **only the Stalls**. Hiraya, the seating, and everything else stay as they are.

Packages we use: `Hiraya`, `Stalls`, `Seating`, `Plateau` (with `Terraces` inside), `StringLights`, `ParkingLot`, `Playground`, `Surroundings`. `Overlook` itself is a plain Model, not a package. Turn a new big build into a package the same way.

### Make a package

1. Explorer → right-click the model → **Convert to Package**.
2. **Title**: the model's name. **Description**: one line on what it is.
3. **Ownership: NieRa Studios**. Always the group, never your own account. Group packages can be edited by every group member. A package owned by one person can't be edited by the others unless that person gives them access.
4. Leave the other options on their defaults → **Submit**.

### Edit a package

1. Change the model in Studio like normal.
2. Right-click the package → **Publish to Package** (or click the package icon in Explorer). Until you publish, your change only exists in this place.
3. Each publish becomes a new version with **who** made it and **when**.

### Undo a package change

1. Right-click the package → **Package Details** (or open it on the Creator Dashboard).
2. Open **Versions**, find the last good one, and restore it.
3. Make sure the place gets the restored version (update the package in Studio if it asks), then save.

## Place Version History (undo everything)

Every save and publish of the whole place is kept.

1. Go to **create.roblox.com** → Creations → the experience (DEV / STAGING / PROD) → **Places** → the place → **Version History**.
2. Each version shows who saved it and when.
3. **Restore** brings back the whole place as it was. **Download** gets a copy to look at first.

⚠️ Restoring the place also throws away every **good** change made after that version. Use package history when only one model is broken.

## Ctrl+Z in Team Create

Undo only covers **your own** changes in **this session**. It can't undo a collaborator's change, and it's gone after you close Studio.

## Habits that keep history useful

- Publish a package right after finishing a change to it, not at the end of the day. Small versions are easier to roll back.
- Save/publish the place after a big change so Version History has a clean point to return to.
- Tell the other person in chat before editing the same model so you don't overwrite each other.
- Code changes go through git with a commit message (see `.github/COMMIT_AND_LINT_GUIDELINES.md`).
