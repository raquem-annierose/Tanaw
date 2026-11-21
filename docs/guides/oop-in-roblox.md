# OOP in Roblox (Luau)

How we write "objects" in Tanaw: when to use a class, how to write one in `--!strict` Luau, and how to clean it up so the game doesn't leak memory.

## Quick answers

**May classes ba sa Luau?** No `class` keyword. You build classes from a table plus a **metatable**. It works the same way in practice: `Thing.new()` makes an object, `thing:doSomething()` calls a method.

**Kailangan ba lahat OOP?** No. Use a class only when the game has **many of the same thing**. If there is only **one** of something, a plain module is simpler.

| There is…                               | Use                  | Tanaw examples                                           |
| --------------------------------------- | -------------------- | -------------------------------------------------------- |
| **one** of it for the game              | a module (singleton) | `RadioService`, `MusicController`, `TimeOfDayController` |
| **many** of it, each with its own state | a **class**          | each pose seat, each stall, each NPC, each table         |

Our services and controllers are already "objects": a module with `start()` and private state. That is the singleton pattern. A class is the same idea, except you can make as many as you need.

## The basic class

```lua
--!strict
-- A pallet seat with a "Sit" prompt. One PoseSeat per Seat tagged "PoseSeat".

local PoseSeat = {}
PoseSeat.__index = PoseSeat

-- The object's fields. Only list what the object owns.
type Fields = {
	seat: Seat,
	prompt: ProximityPrompt,
	connections: { RBXScriptConnection },
}

export type PoseSeat = typeof(setmetatable({} :: Fields, PoseSeat))

-- Constructor: makes one object. Note the dot (.new), not a colon.
function PoseSeat.new(seat: Seat): PoseSeat
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sit"
	prompt.Parent = seat

	local self = setmetatable({
		seat = seat,
		prompt = prompt,
		connections = {},
	}, PoseSeat)

	table.insert(self.connections, prompt.Triggered:Connect(function(player: Player)
		self:sit(player)
	end))

	return self
end

-- Method: written with an explicit `self` so strict mode knows its type.
function PoseSeat.sit(self: PoseSeat, player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and not self.seat.Occupant then
		self.seat:Sit(humanoid)
	end
end

-- Cleanup: undo everything new() did.
function PoseSeat.destroy(self: PoseSeat)
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	self.prompt:Destroy()
end

return PoseSeat
```

Using it:

```lua
local PoseSeat = require(script.Parent.PoseSeat)

local seatObject = PoseSeat.new(workspace.Pallet.Seat)
seatObject:sit(player)   -- colon: passes seatObject as `self`
seatObject:destroy()
```

### How it works (the metatable part)

1. `PoseSeat` is a normal table holding the methods.
2. `PoseSeat.__index = PoseSeat` means: "if a field is missing on an object, look in `PoseSeat`."
3. `setmetatable(fields, PoseSeat)` links the object to the class.
4. `seatObject:sit(player)` → `sit` isn't on the object → Luau finds it on `PoseSeat` → runs `PoseSeat.sit(seatObject, player)`.

So every object has its **own data** (`seat`, `prompt`) but **shares the methods**.

### `.` vs `:` (the #1 bug)

| Write                    | Means                              |
| ------------------------ | ---------------------------------- |
| `PoseSeat.new(seat)`     | constructor: no `self` yet         |
| `seatObject:sit(player)` | method call: `self = seatObject`   |
| `seatObject.sit(player)` | ❌ `self` becomes `player`, breaks |

Rule: **`.new`** for the constructor, **`:`** for everything you call on an object.

## Objects from tags (the pattern we use most)

In Tanaw, builders mark things in Studio with **CollectionService tags** (`PoseSeat`, `WarmLight`, `AvatarNpc`). Code then gives each tagged part its own object. Always handle three cases: already there, added later (streaming), and removed.

```lua
local CollectionService = game:GetService("CollectionService")
local PoseSeat = require(script.Parent.PoseSeat)

local TAG = "PoseSeat"
local objects: { [Instance]: PoseSeat.PoseSeat } = {}

local function add(instance: Instance)
	if instance:IsA("Seat") and not objects[instance] then
		objects[instance] = PoseSeat.new(instance)
	end
end

local function remove(instance: Instance)
	local object = objects[instance]
	if object then
		object:destroy()
		objects[instance] = nil
	end
end

for _, instance in CollectionService:GetTagged(TAG) do
	add(instance)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
```

The service stays a singleton (`SitService.start()`). It just **owns many PoseSeat objects**.

## Cleanup: always write `destroy()`

Roblox doesn't clean up your connections for you. If an object connects to an event and is never disconnected, the function and everything it uses stay in memory forever (a **memory leak**). In a hangout game where servers run for hours, leaks pile up.

Rules:

- Every `:Connect(...)` inside an object goes into `self.connections`.
- Every `Instance.new` the object made gets `:Destroy()` in `destroy()`.
- Remove the object from any lookup table (`objects[instance] = nil`).
- Per-player objects: destroy them on `Players.PlayerRemoving`.

## Inheritance: avoid it, use composition

Luau can do inheritance (a class whose `__index` points to another class), but it gets confusing fast and strict types don't like it. Prefer **composition**: an object _has_ other objects.

```lua
-- ❌ Inheritance: VendorNpc extends Npc extends Character…
-- ✅ Composition: a Stall has an Npc and a Menu
local self = setmetatable({
	npc = Npc.new(marker),
	menu = StallMenu.new(items),
}, Stall)
```

If two classes share code, move it into a small helper module both can `require`.

## Client, server, and objects

- An object lives on **one side only**. A server object can't be sent to a client through a RemoteEvent. Only plain data goes through (numbers, strings, tables, Instances).
- Want both sides to know an object's state? Put it on the **Instance** as an **attribute** (`seat:SetAttribute("Pose", "CrossLegs")`). Clients read it with `GetAttributeChangedSignal`. `SitPoseController` already works this way.
- Server objects make decisions (who sits, what's saved). Client objects only show things (camera, UI, effects).

## Where class files go

```
src/
├─ server/
│  ├─ services/        # singletons: SitService, RadioService
│  └─ classes/         # server-only classes: PoseSeat, Stall
├─ client/
│  ├─ controllers/     # singletons
│  └─ classes/         # client-only classes: e.g. a UI card
└─ shared/
   └─ classes/         # used by both sides (rare)
```

One class per file, and the file name matches the class name (`PoseSeat.luau` → `PoseSeat`).

## Checklist before committing a class

- [ ] Is there really **more than one** of this thing? If not, use a plain module.
- [ ] `--!strict` at the top, `export type` for the object.
- [ ] Constructor is `Class.new(...)`. Methods are called with `:`.
- [ ] Every connection is stored and disconnected in `destroy()`.
- [ ] Whoever calls `new()` also calls `destroy()` (tag removed, player left, character died).
- [ ] No inheritance chains; compose objects instead.
- [ ] State the other side needs is on an attribute, not sent as an object.
