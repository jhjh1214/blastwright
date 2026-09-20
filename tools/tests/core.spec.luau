--!nonstrict
-- Run: tools/bin/luau.exe tools/tests/core.spec.luau
local ChainSim = require("../../src/ReplicatedStorage/Shared/ChainSim")
local Crystals = require("../../src/ReplicatedStorage/Shared/Config/Crystals")
local Charges = require("../../src/ReplicatedStorage/Shared/Config/Charges")
local Tuning = require("../../src/ReplicatedStorage/Shared/Config/Tuning")
local Seam = require("../../src/ServerScriptService/Server/Seam")
local Schema = require("../../src/ServerScriptService/Server/Schema")
local Validate = require("../../src/ServerScriptService/Server/Validate")

local ctx = { Crystals = Crystals.Defs, Charges = Charges.Defs, Tuning = Tuning }

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("PASS  " .. name)
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a)), 2)
	end
end

local N = Tuning.GridSize
local function grid(fill) -- fill(x, z) -> kind | nil
	local cells = {}
	for z = 1, N do
		for x = 1, N do
			local k = fill(x, z)
			if k then
				cells[ChainSim.Key(N, x, z)] = { Kind = k }
			end
		end
	end
	return { Size = N, Cells = cells }
end
local function cap(x, z) return { X = x, Z = z, Kind = "Basic" } end

test("basic charge pops the 3x3 block around it (radius 1.5)", function()
	local r = ChainSim.Run(grid(function() return "Glimmerstone" end), { cap(5, 5) }, ctx)
	eq(r.Pops, 9, "pops")
	eq(r.Raw, 45, "raw value")
end)

test("charge at a corner does not error or pop out of bounds", function()
	local r = ChainSim.Run(grid(function() return "Glimmerstone" end), { cap(1, 1) }, ctx)
	eq(r.Pops, 4, "pops")
end)

test("volatile crystals chain outward through a line", function()
	local g = grid(function(x, z) if z == 5 then return "Kindlequartz" end end)
	local r = ChainSim.Run(g, { cap(1, 5) }, ctx)
	eq(r.Pops, 9, "whole row chains")
	eq(r.Tier, "Rumble", "tier")
end)

test("chain stops at inert crystals", function()
	local g = grid(function(x, z) if z == 5 and x <= 4 then return "Kindlequartz" end if z == 5 then return "Glimmerstone" end end)
	local r = ChainSim.Run(g, { cap(1, 5) }, ctx)
	-- volatile 1..4 chain; inert at x=5 (within 1.5 of x=4) pops but does not propagate; x=6 untouched
	eq(r.Pops, 5, "pops")
end)

test("events are ordered by time", function()
	local g = grid(function() return "Kindlequartz" end)
	local r = ChainSim.Run(g, { cap(5, 5) }, ctx)
	for i = 2, #r.Events do
		if r.Events[i].T < r.Events[i - 1].T then error("out of order at " .. i) end
	end
end)

test("amplifier raises value of crystals popped after it", function()
	-- Resonite at (5,5) fires at t=0 (charge center), neighbors after.
	local g = grid(function(x, z) if x == 5 and z == 5 then return "Resonite" end if math.abs(x - 5) <= 1 and math.abs(z - 5) <= 1 then return "Glimmerstone" end end)
	local r = ChainSim.Run(g, { cap(5, 5) }, ctx)
	eq(r.Events[1].Kind, "Resonite", "amp first")
	eq(r.Events[2].Value, 8, "5 * 1.5 rounds to 8 (7.5 -> 8)")
	eq(r.PeakMult, 1.5, "peak")
end)

test("unstable halves the multiplier but never below 1", function()
	local g = grid(function(x, z) if x == 5 and z == 5 then return "Dreadgeode" end end)
	local r = ChainSim.Run(g, { cap(5, 5) }, ctx)
	eq(r.Events[1].Mult, 1, "floor at 1")
	eq(r.Events[1].Value, 0, "no value")
	local g2 = grid(function(x, z) if x == 5 and z == 5 then return "Resonite" end if x == 5 and z == 6 then return "Dreadgeode" end end)
	local r2 = ChainSim.Run(g2, { cap(5, 5) }, ctx)
	eq(r2.Events[2].Mult, 1, "1.5 * 0.5 -> floored to 1")
end)

test("prism beams along its row, shaft charge along its column", function()
	local g = grid(function(x, z) if z == 5 and x == 5 then return "Lensglass" end if z == 5 then return "Glimmerstone" end end)
	local r = ChainSim.Run(g, { cap(5, 5) }, ctx)
	eq(r.Pops, 9, "prism hits the whole row (range 5)")
	local g2 = grid(function(x) if x == 3 then return "Glimmerstone" end end)
	local r2 = ChainSim.Run(g2, { { X = 3, Z = 5, Kind = "Shaft" } }, ctx)
	eq(r2.Pops, 9, "column of 9 (range 4 each way)")
end)

test("tier bonus scales total", function()
	local r = ChainSim.Run(grid(function() return "Glimmerstone" end), { cap(5, 5) }, ctx)
	eq(r.Tier, "Rumble", "9 pops")
	eq(r.Total, math.floor(45 * 1.10), "total")
end)

test("momentum threshold respects override", function()
	local g = grid(function() return "Glimmerstone" end)
	eq(ChainSim.Run(g, { cap(5, 5) }, ctx).Momentum, false, "9 < 10")
	local c2 = { Crystals = ctx.Crystals, Charges = ctx.Charges, Tuning = ctx.Tuning, MomentumPops = 8 }
	eq(ChainSim.Run(g, { cap(5, 5) }, c2).Momentum, true, "9 >= 8")
end)

test("radius bonus widens basic charge only", function()
	local g = grid(function() return "Glimmerstone" end)
	local c2 = { Crystals = ctx.Crystals, Charges = ctx.Charges, Tuning = ctx.Tuning, RadiusBonus = 0.5 }
	eq(ChainSim.Run(g, { cap(5, 5) }, c2).Pops, 13, "radius 2.0 = 3x3 + 4 axis tips")
end)

test("simulation is deterministic and does not mutate the grid", function()
	local g = Seam.Generate(Crystals, Tuning, 2, 1234)
	local before = 0
	for _ in g.Cells do before += 1 end
	local a = ChainSim.Run(g, { cap(3, 3), cap(7, 7) }, ctx)
	local b = ChainSim.Run(g, { cap(3, 3), cap(7, 7) }, ctx)
	eq(a.Total, b.Total, "total")
	eq(#a.Events, #b.Events, "events")
	local after = 0
	for _ in g.Cells do after += 1 end
	eq(after, before, "grid untouched")
end)

test("charge on an empty cell still hits neighbors", function()
	local g = grid(function(x, z) if x == 6 and z == 5 then return "Glimmerstone" end end)
	eq(ChainSim.Run(g, { cap(5, 5) }, ctx).Pops, 1, "pops")
end)

test("seam generation is seeded and stratum-gated", function()
	local a = Seam.Generate(Crystals, Tuning, 1, 99)
	local b = Seam.Generate(Crystals, Tuning, 1, 99)
	for k, c in a.Cells do eq(b.Cells[k].Kind, c.Kind, "same seed same grid") end
	for _, c in a.Cells do
		if c.Kind == "Lensglass" or c.Kind == "Dreadgeode" then error("stratum 2 crystal in stratum 1") end
	end
	local sawPrism = false
	for s = 1, 20 do
		for _, c in Seam.Generate(Crystals, Tuning, 2, s).Cells do
			if c.Kind == "Lensglass" then sawPrism = true end
		end
	end
	eq(sawPrism, true, "stratum 2 spawns lensglass")
end)

test("schema: default, reconcile, migrate and sanitize", function()
	local d = Schema.Migrate(nil)
	eq(d.SchemaVersion, Schema.CURRENT_VERSION, "version")
	local partial = Schema.Migrate({ Shards = 50.7, Stats = { BestChain = 12 } })
	eq(partial.Shards, 50, "floored")
	eq(partial.Stats.BestChain, 12, "kept")
	eq(partial.Stats.TotalPops, 0, "filled")
	eq(partial.UnlockedCharges.Basic, true, "basic always owned")
	eq(Schema.Migrate({ Shards = -5 }).Shards, 0, "negative")
	eq(Schema.Migrate({ Shards = 0 / 0 }).Shards, 0, "nan")
	eq(Schema.Migrate({ Shards = math.huge }).Shards, 0, "inf")
	eq(Schema.Migrate({ Progress = "bad" }).Progress.StrataUnlocked, 1, "wrong type replaced")
	local a, b = Schema.Default(), Schema.Default()
	a.Codex.Discovered.X = true
	eq(b.Codex.Discovered.X, nil, "defaults not shared")
end)

test("validate: accepts a clean volley and rebuilds it", function()
	local raw = { { X = 3, Z = 4, Kind = "Basic", Evil = "x" } }
	local out, why = Validate.Volley(raw, 4, { Basic = true }, 9, 8)
	eq(why, nil, "reason")
	eq(out[1].X, 3, "x")
	eq(out[1].Evil, nil, "extra field stripped")
	if out[1] == raw[1] then error("client table reused") end
end)

test("validate: rejects hostile payloads", function()
	local unlocked = { Basic = true }
	local function bad(p, what, left)
		local out = Validate.Volley(p, left or 4, unlocked, 9, 8)
		if out ~= nil then error("accepted: " .. what) end
	end
	bad(nil, "nil")
	bad("x", "string")
	bad(42, "number")
	bad({}, "empty")
	bad({ 1 }, "non-table entry")
	bad({ { X = 1.5, Z = 1, Kind = "Basic" } }, "fractional")
	bad({ { X = 0 / 0, Z = 1, Kind = "Basic" } }, "nan")
	bad({ { X = math.huge, Z = 1, Kind = "Basic" } }, "inf")
	bad({ { X = 0, Z = 1, Kind = "Basic" } }, "below range")
	bad({ { X = 10, Z = 1, Kind = "Basic" } }, "above range")
	bad({ { X = "3", Z = 1, Kind = "Basic" } }, "string coord")
	bad({ { X = 1, Z = 1, Kind = "Shaft" } }, "locked charge")
	bad({ { X = 1, Z = 1, Kind = "__index" } }, "junk kind")
	bad({ { X = 1, Z = 1, Kind = 5 } }, "numeric kind")
	bad({ { X = 1, Z = 1, Kind = "Basic" }, { X = 1, Z = 1, Kind = "Basic" } }, "duplicate cell")
	bad({ { X = 1, Z = 1, Kind = "Basic" }, { X = 2, Z = 2, Kind = "Basic" } }, "more than charges left", 1)
	bad({ { X = 1, Z = 1, Kind = "Basic" } }, "no charges left", 0)
	local nine = {}
	for i = 1, 9 do nine[i] = { X = i, Z = 1, Kind = "Basic" } end
	bad(nine, "over hard cap", 99)
end)

test("delayed crystal pops one delay after being hit, last, cashing in the multiplier", function()
	local g = grid(function(x, z)
		if z ~= 5 then return nil end
		if x == 5 then return "Resonite" end
		if x == 4 then return "Glimmerstone" end
		if x == 6 then return "Slowburn" end
	end)
	local r = ChainSim.Run(g, { cap(5, 5) }, ctx)
	eq(r.Pops, 3, "pops")
	local last = r.Events[3]
	eq(last.Kind, "Slowburn", "slowburn pops last")
	eq(last.Lit ~= nil, true, "fuse lit time reported")
	if math.abs((last.T - last.Lit) - 1.0) > 1e-9 then error("delay is not 1.0s: " .. (last.T - last.Lit)) end
	eq(last.Value, 30, "20 x 1.5 multiplier from Resonite")
	eq(r.Events[1].Lit, nil, "non-delayed has no Lit")
end)

test("delayed crystal blasts radius 2 when it finally pops", function()
	local g = grid(function(x, z)
		if x == 5 and z == 5 then return "Slowburn" end
		if x == 7 and z == 5 then return "Glimmerstone" end
	end)
	local r = ChainSim.Run(g, { cap(5, 5) }, ctx)
	eq(r.Pops, 2, "inert two cells away is reached by the delayed blast")
	if r.Events[2].T <= 1.0 then error("second pop should come after the delay") end
end)

test("delayed crystal that is never hit never pops", function()
	local g = grid(function(x, z) if x == 9 and z == 9 then return "Slowburn" end end)
	eq(ChainSim.Run(g, { cap(1, 1) }, ctx).Pops, 0, "pops")
end)

test("slowburn only appears from stratum 3", function()
	for s = 1, 30 do
		for _, c in Seam.Generate(Crystals, Tuning, 2, s).Cells do
			if c.Kind == "Slowburn" then error("slowburn in stratum 2") end
		end
	end
	local saw = false
	for s = 1, 20 do
		for _, c in Seam.Generate(Crystals, Tuning, 3, s).Cells do
			if c.Kind == "Slowburn" then saw = true end
		end
	end
	eq(saw, true, "stratum 3 spawns slowburn")
end)

test("world: sites are unique, in bounds, and clear of each other, hub and paths", function()
	local W = require("../../src/ReplicatedStorage/Shared/Config/World")
	eq(#W.Sites, 16, "4 biomes x 4 sites")
	local half = W.PadRadius -- pads are round
	for i, a in W.Sites do
		eq(a.Id, i, "sequential id")
		if a.X - half < W.Bounds.MinX or a.X + half > W.Bounds.MaxX or a.Z - half < W.Bounds.MinZ or a.Z + half > W.Bounds.MaxZ then
			error("site out of bounds: " .. a.Name)
		end
		if math.sqrt((a.X - W.Hub.X) ^ 2 + (a.Z - W.Hub.Z) ^ 2) < W.Hub.Radius + half then error("site overlaps hub: " .. a.Name) end
		if W.DistToPath(a.X, a.Z) < half + W.PathHalfWidth then error("site blocks a path: " .. a.Name) end
		for j = i + 1, #W.Sites do
			local b = W.Sites[j]
			if math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) < half * 2 + 4 then error("sites overlap: " .. a.Name .. " / " .. b.Name) end
		end
	end
end)

test("world: every site stratum has a matching config and a crystal unlocked by it", function()
	local W = require("../../src/ReplicatedStorage/Shared/Config/World")
	local Strata = require("../../src/ReplicatedStorage/Shared/Config/Strata")
	for _, s in W.Sites do
		if Strata[s.Stratum] == nil then error("no stratum config for " .. s.Name) end
	end
	for n = 1, #Strata do
		local found = false
		for _, def in Crystals.Defs do if def.Stratum == n then found = true end end
		if not found then error("stratum " .. n .. " introduces no crystal") end
	end
end)

test("world: caches are unique, in bounds, and off sites and paths", function()
	local W = require("../../src/ReplicatedStorage/Shared/Config/World")
	local seen = {}
	for _, c in W.Caches do
		if seen[c.Id] then error("duplicate cache id " .. c.Id) end
		seen[c.Id] = true
		if c.Reward <= 0 then error("bad reward " .. c.Id) end
		if c.X < W.Bounds.MinX or c.X > W.Bounds.MaxX or c.Z < W.Bounds.MinZ or c.Z > W.Bounds.MaxZ then error("cache out of bounds " .. c.Id) end
		if W.DistToPath(c.X, c.Z) < W.PathHalfWidth + 4 then error("cache on a path " .. c.Id) end
		for _, s in W.Sites do
			if math.sqrt((c.X - s.X) ^ 2 + (c.Z - s.Z) ^ 2) < W.SiteClearRadius then error("cache inside site clearance " .. c.Id .. " / " .. s.Name) end
		end
		if math.sqrt((c.X - W.Hub.X) ^ 2 + (c.Z - W.Hub.Z) ^ 2) < W.Hub.Radius + 10 and c.Biome ~= "Hub" then error("biome cache in hub " .. c.Id) end
	end
end)

test("world: area names and segment distance", function()
	local W = require("../../src/ReplicatedStorage/Shared/Config/World")
	eq(W.AreaName(0, 0), "Blastwright Depot", "hub")
	eq(W.AreaName(-190, 0), "Glimmer Shallows", "shallows")
	eq(W.AreaName(190, 10), "Prism Veins", "prism")
	eq(W.AreaName(0, -230), "Ember Hollows", "ember")
	eq(W.AreaName(0, 230), "Echo Caverns", "echo")
	eq(W.AreaName(-190, -190), "The Deep Roads", "between")
	eq(W.DistToSegment(5, 5, 0, 0, 10, 0), 5, "perpendicular")
	eq(W.DistToSegment(-3, 4, 0, 0, 10, 0), 5, "clamped to endpoint")
end)

test("schema: v1 saves migrate to v2 with caches and keep progress", function()
	local v1 = { SchemaVersion = 1, Shards = 321, Upgrades = { ExtraCharge = 2 } }
	local d = Schema.Migrate(v1)
	eq(d.SchemaVersion, Schema.CURRENT_VERSION, "version")
	eq(Schema.CURRENT_VERSION >= 2, true, "v2 exists")
	eq(d.Shards, 321, "shards kept")
	eq(d.Upgrades.ExtraCharge, 2, "upgrades kept")
	eq(type(d.Caches), "table", "caches added")
end)

local Objectives = require("../../src/ReplicatedStorage/Shared/Objectives")
local Strata = require("../../src/ReplicatedStorage/Shared/Config/Strata")
local Upgrades = require("../../src/ReplicatedStorage/Shared/Config/Upgrades")
local WorldCfg = require("../../src/ReplicatedStorage/Shared/Config/World")
local ocfg = { Strata = Strata, Upgrades = Upgrades.Defs, World = WorldCfg, Tuning = Tuning }
local function snap(over)
	local d = { Shards = 0, Upgrades = {}, StrataUnlocked = 1, Caches = {}, Stats = { TotalPops = 0 } }
	for k, v in over or {} do d[k] = v end
	return d
end

test("objectives: brand-new player is sent to the nearest stratum-1 pad", function()
	local o = Objectives.Roam(snap(), 0, 0, ocfg)
	eq(o.Id, "GoBlast", "id")
	eq(o.Target ~= nil, true, "has target")
	local near = Objectives.NearestSite(ocfg, 0, 0, 1)
	eq(near.Stratum, 1, "stratum 1 site")
	eq(o.Target.X, near.X, "target x is that site's station")
	-- a player standing next to a west pad must be sent to a west pad, not an east one
	local west = Objectives.Roam(snap(), -200, 40, ocfg)
	eq(west.Target.X < 0, true, "west player gets a west pad")
end)

test("objectives: affordable first upgrade highlights the Forge", function()
	local o = Objectives.Roam(snap({ Shards = 150, Stats = { TotalPops = 12 } }), 0, 0, ocfg)
	eq(o.Id, "FirstUpgrade", "id")
	eq(o.Highlight, "Forge", "highlight")
	local poor = Objectives.Roam(snap({ Shards = 149, Stats = { TotalPops = 12 } }), 0, 0, ocfg)
	eq(poor.Id, "Earn", "cannot afford yet")
end)

test("objectives: earning toward the next area points at a pad and names the area", function()
	local o = Objectives.Roam(snap({ Shards = 300, Upgrades = { ExtraCharge = 1 }, Stats = { TotalPops = 50 } }), 0, 0, ocfg)
	eq(o.Id, "Earn", "id")
	eq(o.Target ~= nil, true, "target")
	eq(o.Text:find("Prism Veins", 1, true) ~= nil, true, "names next area")
	eq(o.Text:find("900", 1, true) ~= nil, true, "1200 - 300 = 900 more")
end)

test("objectives: enough shards to unlock the next area highlights the Forge", function()
	local o = Objectives.Roam(snap({ Shards = 1200, Upgrades = { ExtraCharge = 1 }, Stats = { TotalPops = 50 } }), 0, 0, ocfg)
	eq(o.Id, "UnlockArea", "id")
	eq(o.Highlight, "Forge", "highlight")
	eq(o.Text:find("1,200", 1, true) ~= nil, true, "thousands separator")
end)

test("objectives: everything unlocked falls back to exploring for caches", function()
	local o = Objectives.Roam(snap({ Shards = 9999, Upgrades = { ExtraCharge = 3 }, StrataUnlocked = #Strata, Caches = { S1 = true, P2 = true }, Stats = { TotalPops = 999 } }), 0, 0, ocfg)
	eq(o.Id, "Explore", "id")
	eq(o.Text:find(("2/%d"):format(#WorldCfg.Caches), 1, true) ~= nil, true, "cache progress")
	eq(o.Target, nil, "no arrow: caches are meant to be found")
end)

test("objectives: in-blast hints follow the plant/detonate steps and stop for veterans", function()
	eq(Objectives.Blast(snap(), 0).Id, "Plant", "nothing placed")
	eq(Objectives.Blast(snap(), 2).Id, "Detonate", "charges placed")
	eq(Objectives.Blast(snap({ Stats = { TotalPops = 500 } }), 0), nil, "veteran gets no hints")
end)

test("objectives: nearest pad is really the nearest, and the station offset is pinned", function()
	-- Shallows sites are at x = -245 / -135 and z = -55 / +55.
	local a = Objectives.NearestSite(ocfg, -135, 90, 1)
	eq(a.X, -135, "near the east-south pad: x")
	eq(a.Z, 55, "near the east-south pad: z")
	local b = Objectives.NearestSite(ocfg, -245, -95, 1)
	eq(b.X, -245, "near the west-north pad: x")
	eq(b.Z, -55, "near the west-north pad: z")
	local o = Objectives.Roam(snap(), -245, -95, ocfg)
	eq(o.Target.X, -245, "arrow target x")
	eq(o.Target.Z, -55 - (Tuning.GridSize * Tuning.CellSize) / 2 - 7, "station sits 7 studs past the pad's north edge")
end)

local Dailies = require("../../src/ReplicatedStorage/Shared/Dailies")
local DailiesCfg = require("../../src/ReplicatedStorage/Shared/Config/Dailies")
local Products = require("../../src/ReplicatedStorage/Shared/Config/Products")
local Receipts = require("../../src/ServerScriptService/Server/Receipts")

test("dailies: same day gives the same three distinct objectives, different days differ", function()
	local a, b = Dailies.ForDay(20000, DailiesCfg), Dailies.ForDay(20000, DailiesCfg)
	eq(#a, 3, "three objectives")
	for i = 1, 3 do
		eq(a[i].Id, b[i].Id, "deterministic id")
		eq(a[i].Target, b[i].Target, "deterministic target")
	end
	eq(a[1].Id ~= a[2].Id and a[2].Id ~= a[3].Id and a[1].Id ~= a[3].Id, true, "distinct templates")
	local differs = false
	for d = 20001, 20030 do
		if Dailies.ForDay(d, DailiesCfg)[1].Id ~= a[1].Id then differs = true end
	end
	eq(differs, true, "days rotate")
end)

test("dailies: slots get rising rewards and readable text", function()
	for d = 20000, 20040 do
		local defs = Dailies.ForDay(d, DailiesCfg)
		for slot, def in defs do
			eq(def.Slot, slot, "slot index")
			if def.Text:find("%d") == nil then error("text has no number") end
		end
		if not (defs[1].RewardBase < defs[2].RewardBase and defs[2].RewardBase < defs[3].RewardBase) then
			error("rewards do not rise on day " .. d)
		end
	end
end)

test("dailies: record accumulates, chain takes the max, progress caps at target", function()
	local defs = {
		{ Slot = 1, Id = "P", Kind = "Pops", Target = 50, Text = "", RewardBase = 100 },
		{ Slot = 2, Id = "C", Kind = "Chain", Target = 20, Text = "", RewardBase = 100 },
	}
	local daily = { Day = 5, Progress = {}, Claimed = {} }
	Dailies.Record(daily, defs, "Pops", 30)
	Dailies.Record(daily, defs, "Pops", 30)
	eq(daily.Progress["1"], 50, "capped at target")
	Dailies.Record(daily, defs, "Chain", 12)
	Dailies.Record(daily, defs, "Chain", 7)
	eq(daily.Progress["2"], 12, "max not sum")
	Dailies.Record(daily, defs, "Chain", 99)
	eq(daily.Progress["2"], 20, "capped")
	Dailies.Record(daily, defs, "Pops", 0)
	Dailies.Record(daily, defs, "Nothing", 5)
	eq(daily.Progress["1"], 50, "ignored")
end)

test("dailies: claim only when complete, once, and only for a real slot", function()
	local defs = Dailies.ForDay(20100, DailiesCfg)
	local daily = { Day = 20100, Progress = {}, Claimed = {} }
	eq(Dailies.CanClaim(daily, defs, 1), false, "not complete")
	daily.Progress["1"] = defs[1].Target
	eq(Dailies.CanClaim(daily, defs, 1), true, "complete")
	daily.Claimed["1"] = true
	eq(Dailies.CanClaim(daily, defs, 1), false, "already claimed")
	daily.Progress["2"] = defs[2].Target
	eq(Dailies.CanClaim(daily, defs, 2.5), false, "fractional slot")
	eq(Dailies.CanClaim(daily, defs, 0), false, "slot 0")
	eq(Dailies.CanClaim(daily, defs, 4), false, "slot 4")
	eq(Dailies.CanClaim(daily, defs, "2"), false, "string slot")
	eq(Dailies.CanClaim(daily, defs, nil), false, "nil slot")
	eq(Dailies.CanClaim(daily, defs, 2), true, "slot 2 ok")
end)

test("dailies: a new day resets progress and claims; the same day does not", function()
	local daily = { Day = 7, Progress = { ["1"] = 5 }, Claimed = { ["1"] = true } }
	eq(Dailies.Refresh(daily, 7), false, "same day")
	eq(daily.Progress["1"], 5, "kept")
	eq(Dailies.Refresh(daily, 8), true, "new day")
	eq(next(daily.Progress), nil, "progress cleared")
	eq(next(daily.Claimed), nil, "claims cleared")
	eq(daily.Day, 8, "day set")
	eq(Dailies.DayNumber(86400 * 3 + 5), 3, "day number")
	eq(Dailies.SecondsUntilReset(86400 * 3 + 86300), 100, "seconds to reset")
end)

test("dailies: reward scales with unlocked strata", function()
	local def = { Slot = 1, Id = "x", Kind = "Pops", Target = 1, Text = "", RewardBase = 100 }
	eq(Dailies.Reward(def, 1), 100, "stratum 1")
	eq(Dailies.Reward(def, 3), 200, "stratum 3")
	eq(Dailies.Reward(def, 0), 100, "never below stratum 1")
end)

test("receipts: a purchase id grants once, retries are duplicates", function()
	local purchases = {}
	eq(Receipts.Apply(purchases, "abc", 100), true, "first time")
	eq(Receipts.Apply(purchases, "abc", 200), false, "retry")
	eq(purchases["abc"], 100, "original time kept")
	Receipts.Revert(purchases, "abc")
	eq(Receipts.Apply(purchases, "abc", 300), true, "after revert it can grant properly")
end)

test("receipts: history is bounded and never drops the newest purchase", function()
	local purchases = {}
	for i = 1, 400 do Receipts.Apply(purchases, "p" .. i, i) end
	local n = 0
	for _ in purchases do n += 1 end
	eq(n, 300, "capped")
	eq(purchases["p400"], 400, "newest kept")
	eq(purchases["p1"], nil, "oldest dropped")
end)

test("receipts: shard packs scale with strata and only configured ids are indexed", function()
	eq(Receipts.ShardAmount({ Amount = 500 }, 1), 500, "stratum 1")
	eq(Receipts.ShardAmount({ Amount = 500 }, 3), 1500, "stratum 3")
	eq(Receipts.ShardAmount({ Amount = 500 }, 0), 500, "floor at 1")
	local index = Receipts.ProductIndex({ A = { Id = 111 }, B = { Id = nil }, C = { Id = 333 } })
	eq(index[111], "A", "A")
	eq(index[333], "C", "C")
	eq(index[0], nil, "unconfigured is absent")
end)

test("products: config is valid and never contains invented ids", function()
	local seen = {}
	local function size(t) local n = 0 for _ in t do n += 1 end return n end
	local function check(defs, order, what)
		eq(#order, size(defs), what .. " order lists every entry")
		for _, key in order do
			local d = defs[key]
			if d == nil then error(what .. " missing " .. key) end
			if type(d.Name) ~= "string" or type(d.Description) ~= "string" then error(key .. " needs name and description") end
			if d.Id ~= nil then
				if type(d.Id) ~= "number" or d.Id <= 0 or d.Id % 1 ~= 0 then error(key .. " has a malformed id") end
				if seen[d.Id] then error("duplicate id " .. d.Id) end
				seen[d.Id] = true
			end
		end
	end
	check(Products.DeveloperProducts, Products.DeveloperProductOrder, "products")
	check(Products.Gamepasses, Products.GamepassOrder, "passes")
	for _, key in Products.DeveloperProductOrder do
		if Products.DeveloperProducts[key].Amount <= 0 then error(key .. " grants nothing") end
	end
end)

test("seam: mutation chance can be raised (Prismatic Luck)", function()
	local function count(chance)
		local n = 0
		for s = 1, 60 do
			for _, c in Seam.Generate(Crystals, Tuning, 1, s, chance).Cells do
				if c.Mutated then n += 1 end
			end
		end
		return n
	end
	local base, boosted, none = count(nil), count(Tuning.MutationChance * 2), count(0)
	eq(none, 0, "zero chance means none")
	eq(boosted > base, true, "doubling the chance yields more mutated crystals")
	eq(base > 0, true, "default chance still mutates some")
end)

test("schema: v2 saves migrate to v3 with an empty daily record", function()
	local d = Schema.Migrate({ SchemaVersion = 2, Shards = 40, Caches = { S1 = true } })
	eq(d.SchemaVersion, Schema.CURRENT_VERSION, "version")
	eq(Schema.CURRENT_VERSION >= 3, true, "v3 exists")
	eq(d.Daily.Day, 0, "daily day")
	eq(next(d.Daily.Progress), nil, "daily progress")
	eq(d.Caches.S1, true, "caches kept")
	eq(d.Shards, 40, "shards kept")
end)

test("objectives: a finished daily objective is surfaced before anything else", function()
	local data = snap({ Shards = 50, Stats = { TotalPops = 20 }, Dailies = { { Slot = 1, Progress = 10, Target = 10, Claimed = false } } })
	local o = Objectives.Roam(data, 0, 0, ocfg)
	eq(o.Id, "ClaimDaily", "id")
	eq(o.Highlight, "Forge", "menu pulses")
	data.Dailies[1].Claimed = true
	eq(Objectives.Roam(data, 0, 0, ocfg).Id ~= "ClaimDaily", true, "claimed one no longer nags")
	local fresh = snap({ Dailies = { { Slot = 1, Progress = 10, Target = 10, Claimed = false } } })
	eq(Objectives.Roam(fresh, 0, 0, ocfg).Id, "GoBlast", "brand-new player still starts at a pad")
end)

test("props: config ids are real-looking, unique and named", function()
	local PropsCfg = require("../../src/ReplicatedStorage/Shared/Config/Props")
	local seen, n = {}, 0
	for key, def in PropsCfg.Defs do
		n += 1
		if type(def.Id) ~= "number" or def.Id <= 0 or def.Id % 1 ~= 0 then error(key .. " has a malformed id") end
		if seen[def.Id] then error("duplicate prop id " .. def.Id) end
		seen[def.Id] = true
		if type(def.Name) ~= "string" or def.Name == "" then error(key .. " needs a name") end
		if type(def.Creator) ~= "string" or def.Creator == "" then error(key .. " needs a creator credit") end
	end
	eq(n >= 6, true, "a useful number of props configured")
	-- World.luau asks for these keys by name; a typo would silently fall back to procedural decor.
	for _, required in { "CrystalA", "CrystalB", "Lamp", "MushroomA", "MushroomB", "StalagmiteA", "StalagmiteB", "Crate" } do
		if PropsCfg.Defs[required] == nil then error("World.luau uses prop key " .. required .. " but it is not configured") end
	end
end)

test("sounds: ids are well-formed asset uris, groups known, loops sane", function()
	local Sounds = require("../../src/ReplicatedStorage/Shared/Config/Sounds")
	local groups = { Music = true, Ambient = true, Ui = true, Sfx = true, Reward = true }
	for name, cue in Sounds do
		if cue.Id ~= nil and not string.match(cue.Id, "^rbxassetid://%d+$") then error(name .. " has a malformed sound id: " .. tostring(cue.Id)) end
		if not groups[cue.Group] then error(name .. " uses unknown group " .. tostring(cue.Group)) end
		if type(cue.Volume) ~= "number" or cue.Volume <= 0 or cue.Volume > 1 then error(name .. " volume out of range") end
	end
	eq(Sounds.Ambience.Loop, true, "ambience loops")
	eq(Sounds.Pop.Loop, nil, "effects do not loop")
end)

test("validate: settings accept only known keys with boolean values", function()
	local k, v = Validate.Setting("Music", false)
	eq(k, "Music", "music key")
	eq(v, false, "false is a valid value")
	k, v = Validate.Setting("Sfx", true)
	eq(k, "Sfx", "sfx key")
	eq(v, true, "true")
	for _, bad in { { "Music", "yes" }, { "Music", 1 }, { "Music", nil }, { "Volume", true }, { "__index", true }, { 5, true }, { nil, true }, { "music", true }, { "", false } } do
		local key = Validate.Setting(bad[1], bad[2])
		if key ~= nil then error("accepted bad setting: " .. tostring(bad[1]) .. " = " .. tostring(bad[2])) end
	end
end)

test("music: playlist is valid, has no duplicate ids, and stays cheerful-sized", function()
	local Music = require("../../src/ReplicatedStorage/Shared/Config/Music")
	local seen, total = {}, 0
	eq(#Music.Tracks >= 6, true, "enough tracks that the shuffle does not feel repetitive")
	for i, t in Music.Tracks do
		if not string.match(t.Id, "^rbxassetid://%d+$") then error("track " .. i .. " has a malformed id") end
		if seen[t.Id] then error("duplicate track " .. t.Id) end
		seen[t.Id] = true
		if t.Name == "" or t.Artist == "" then error("track " .. i .. " needs name and artist") end
		if t.Seconds <= Music.CrossfadeSeconds * 4 then error("track " .. i .. " is too short to crossfade") end
		total += t.Seconds
	end
	eq(total >= 20 * 60, true, "at least 20 minutes before the playlist repeats")
	eq(Music.Volume > 0 and Music.Volume <= 1, true, "volume in range")
end)

test("world: round pad fits the grid, contains its station, and leaves room around it", function()
	local W = require("../../src/ReplicatedStorage/Shared/Config/World")
	local corner = ((Tuning.GridSize - 1) / 2) * Tuning.CellSize * math.sqrt(2)
	eq(W.PadRadius >= corner + 3, true, "grid corners (" .. corner .. ") fit inside the round pad with margin")
	local stationDist = (Tuning.GridSize * Tuning.CellSize) / 2 + 7
	eq(stationDist <= W.PadRadius + 2, true, "station sits on the pad rim, not off in the rocks")
	eq(W.SiteClearRadius >= W.PadRadius + 8, true, "terrain features keep clear of the pad and its rock rim")
end)

local function findEvent(result, x, z)
	for _, e in result.Events do
		if e.X == x and e.Z == z then return e end
	end
	error("no event at " .. x .. "," .. z)
end

test("chain source: direct hits name the charge cell that hit them", function()
	local g = grid(function(x, z) if x == 6 and z == 5 then return "Glimmerstone" end end)
	local e = findEvent(ChainSim.Run(g, { cap(5, 5) }, ctx), 6, 5)
	eq(e.Cause, "Charge", "cause")
	eq(e.SX, 5, "source x")
	eq(e.SZ, 5, "source z")
end)

test("chain source: a chained crystal names the crystal that set it off", function()
	local g = grid(function(x, z) if z == 5 then return "Kindlequartz" end end)
	local r = ChainSim.Run(g, { cap(1, 5) }, ctx)
	local third = findEvent(r, 3, 5)
	eq(third.Cause, "Chain", "cause")
	eq(third.SX, 2, "set off by the volatile crystal next to it, not by the charge")
	eq(third.SZ, 5, "source z")
	local fifth = findEvent(r, 5, 5)
	eq(fifth.SX, 4, "the chain hands off one crystal at a time")
end)

test("chain source: prism beams name the prism, delayed blasts name the delayed crystal", function()
	local g = grid(function(x, z) if z == 5 and x == 5 then return "Lensglass" end if z == 5 and x == 8 then return "Glimmerstone" end end)
	local beamHit = findEvent(ChainSim.Run(g, { cap(5, 5) }, ctx), 8, 5)
	eq(beamHit.Cause, "Beam", "cause")
	eq(beamHit.SX, 5, "beam source x")
	local g2 = grid(function(x, z) if x == 5 and z == 5 then return "Slowburn" end if x == 7 and z == 5 then return "Glimmerstone" end end)
	local delayedHit = findEvent(ChainSim.Run(g2, { cap(5, 5) }, ctx), 7, 5)
	eq(delayedHit.Cause, "Chain", "cause")
	eq(delayedHit.SX, 5, "delayed source x")
	eq(delayedHit.SZ, 5, "delayed source z")
end)

test("chain source: every event has one, and it is always a cell inside the grid", function()
	local g = Seam.Generate(Crystals, Tuning, 3, 4242)
	local r = ChainSim.Run(g, { cap(3, 3), cap(7, 7), { X = 5, Z = 5, Kind = "Shaft" } }, ctx)
	for _, e in r.Events do
		if type(e.SX) ~= "number" or type(e.SZ) ~= "number" then error("event without a source") end
		if e.SX < 1 or e.SX > N or e.SZ < 1 or e.SZ > N then error("source outside the grid") end
	end
end)

test("chain source: a shaft charge names its own cell for every crystal in the column", function()
	local g = grid(function(x, z) if x == 3 and (z == 2 or z == 8) then return "Glimmerstone" end end)
	local r = ChainSim.Run(g, { { X = 3, Z = 5, Kind = "Shaft" } }, ctx)
	for _, z in { 2, 8 } do
		local e = findEvent(r, 3, z)
		eq(e.SX, 3, "shaft source x for z=" .. z)
		eq(e.SZ, 5, "shaft source z for z=" .. z)
	end
end)

local function cellSet(cells)
	local set, n = {}, 0
	for _, c in cells do
		set[c.X .. "," .. c.Z] = c.D
		n += 1
	end
	return set, n
end

test("blast cells: radius 1.5 covers the 3x3 block with distances, radius 2 adds the four tips", function()
	local set, n = cellSet(ChainSim.BlastCells("Radius", 5, 5, 1.5, 0, N))
	eq(n, 9, "3x3")
	eq(set["5,5"], 0, "center distance")
	eq(set["6,5"], 1, "edge distance")
	eq(math.abs(set["6,6"] - math.sqrt(2)) < 1e-9, true, "diagonal distance")
	local _, n2 = cellSet(ChainSim.BlastCells("Radius", 5, 5, 2, 0, N))
	eq(n2, 13, "radius 2")
end)

test("blast cells: shapes are clipped to the grid", function()
	local _, corner = cellSet(ChainSim.BlastCells("Radius", 1, 1, 1.5, 0, N))
	eq(corner, 4, "corner keeps a 2x2")
	local col, colN = cellSet(ChainSim.BlastCells("Column", 3, 2, 0, 4, N))
	eq(colN, 6, "column from z=1 to z=6 (range 4 below z=2 is clipped)")
	eq(col["3,1"], 1, "column distance")
	eq(col["3,6"], 4, "column far end")
	local row, rowN = cellSet(ChainSim.BlastCells("Row", 8, 5, 0, 5, N))
	eq(rowN, 7, "row from x=3 to x=9 is 7 cells")
	eq(row["9,5"], 1, "row distance")
	local _, none = cellSet(ChainSim.BlastCells("Nonsense", 5, 5, 3, 3, N))
	eq(none, 0, "unknown shape covers nothing")
end)

local Achievements = require("../../src/ReplicatedStorage/Shared/Achievements")
local AchCfg = require("../../src/ReplicatedStorage/Shared/Config/Achievements")

local function serverData(over)
	local d = Schema.Default()
	for k, v in over or {} do d[k] = v end
	return d
end

test("goals: config is valid, unique, increasing within a stat, and reachable", function()
	local KNOWN = { TotalPops = true, BestChain = true, SeamsCleared = true, TotalShards = true, Caches = true, Codex = true, Prismatic = true, Strata = true }
	local valued = 0
	for _, def in Crystals.Defs do if def.Value > 0 then valued += 1 end end
	local limit = {
		Caches = #WorldCfg.Caches,
		Codex = #Crystals.Order,
		Prismatic = valued,
		Strata = #Strata,
	}
	local seen, lastTarget, lastReward = {}, {}, {}
	for _, def in AchCfg.Defs do
		if seen[def.Id] then error("duplicate goal id " .. def.Id) end
		seen[def.Id] = true
		if not KNOWN[def.Stat] then error(def.Id .. " uses unknown stat " .. tostring(def.Stat)) end
		if def.Target <= 0 or def.Reward <= 0 then error(def.Id .. " needs a positive target and reward") end
		if type(def.Name) ~= "string" or def.Name == "" or type(def.Description) ~= "string" then error(def.Id .. " needs text") end
		if limit[def.Stat] and def.Target > limit[def.Stat] then error(def.Id .. " target " .. def.Target .. " is unreachable (max " .. limit[def.Stat] .. ")") end
		if lastTarget[def.Stat] and def.Target <= lastTarget[def.Stat] then error(def.Id .. " target must exceed the previous tier of " .. def.Stat) end
		if lastReward[def.Stat] and def.Reward <= lastReward[def.Stat] then error(def.Id .. " reward must exceed the previous tier of " .. def.Stat) end
		lastTarget[def.Stat], lastReward[def.Stat] = def.Target, def.Reward
	end
	eq(#AchCfg.Defs >= 12, true, "a meaningful number of goals")
end)

test("goals: progress is read from the right place in the save", function()
	local d = serverData()
	d.Stats.TotalPops, d.Stats.BestChain, d.Stats.SeamsCleared, d.Stats.TotalShards = 321, 27, 9, 4567
	d.Progress.StrataUnlocked = 3
	d.Codex.Discovered = { Glimmerstone = true, Kindlequartz = true }
	d.Codex.Mutated = { Glimmerstone = true }
	d.Caches = { S1 = true, S2 = true, P1 = true }
	eq(Achievements.Value(d, "TotalPops"), 321, "pops")
	eq(Achievements.Value(d, "BestChain"), 27, "chain")
	eq(Achievements.Value(d, "SeamsCleared"), 9, "seams")
	eq(Achievements.Value(d, "TotalShards"), 4567, "shards")
	eq(Achievements.Value(d, "Strata"), 3, "strata")
	eq(Achievements.Value(d, "Codex"), 2, "codex counts discovered crystals")
	eq(Achievements.Value(d, "Prismatic"), 1, "prismatic counts mutated crystals found")
	eq(Achievements.Value(d, "Caches"), 3, "caches counts looted")
	eq(Achievements.Value(d, "Nonsense"), 0, "unknown stat is 0, not an error")
end)

test("goals: claim only when complete, once, and only for a real goal id", function()
	local first = AchCfg.Defs[1]
	local d = serverData()
	eq(Achievements.CanClaim(d, AchCfg, first.Id), false, "not complete")
	d.Stats.TotalPops = first.Target
	eq(Achievements.CanClaim(d, AchCfg, first.Id), true, "complete")
	d.Achievements.Claimed[first.Id] = true
	eq(Achievements.CanClaim(d, AchCfg, first.Id), false, "already claimed")
	d.Stats.TotalPops = 1e9
	for _, bad in { "", "__index", "nope", 5, true } do
		eq(Achievements.CanClaim(d, AchCfg, bad), false, "bad id " .. tostring(bad))
	end
	eq(Achievements.CanClaim(d, AchCfg, nil), false, "nil id")
end)

test("goals: the client view reports progress, completion and claimed state", function()
	local d = serverData()
	local def = AchCfg.Defs[1]
	d.Stats.TotalPops = math.floor(def.Target / 2)
	local view = Achievements.View(d, AchCfg)
	eq(#view, #AchCfg.Defs, "one row per goal")
	eq(view[1].Id, def.Id, "order preserved")
	eq(view[1].Progress, math.floor(def.Target / 2), "progress")
	eq(view[1].Complete, false, "incomplete")
	d.Stats.TotalPops = def.Target * 3
	d.Achievements.Claimed[def.Id] = true
	view = Achievements.View(d, AchCfg)
	eq(view[1].Progress, def.Target, "progress capped at the target for display")
	eq(view[1].Complete, true, "complete")
	eq(view[1].Claimed, true, "claimed")
end)

test("schema: v3 saves migrate to v4 with an empty goals record", function()
	local d = Schema.Migrate({ SchemaVersion = 3, Shards = 70, Daily = { Day = 5, Progress = {}, Claimed = {} } })
	eq(d.SchemaVersion, Schema.CURRENT_VERSION, "version")
	eq(Schema.CURRENT_VERSION >= 4, true, "v4 exists")
	eq(type(d.Achievements.Claimed), "table", "claimed map")
	eq(d.Daily.Day, 5, "daily kept")
	eq(d.Shards, 70, "shards kept")
end)

test("objectives: a finished goal is surfaced (after dailies), and never for a brand-new player", function()
	local data = snap({ Shards = 50, Stats = { TotalPops = 20 }, Goals = { { Id = "x", Progress = 100, Target = 100, Claimed = false, Complete = true } } })
	local o = Objectives.Roam(data, 0, 0, ocfg)
	eq(o.Id, "ClaimGoal", "id")
	eq(o.Highlight, "Forge", "menu pulses")
	data.Goals[1].Claimed = true
	eq(Objectives.Roam(data, 0, 0, ocfg).Id ~= "ClaimGoal", true, "claimed one no longer nags")
	local fresh = snap({ Goals = { { Id = "x", Progress = 100, Target = 100, Claimed = false, Complete = true } } })
	eq(Objectives.Roam(fresh, 0, 0, ocfg).Id, "GoBlast", "brand-new player still starts at a pad")
	local both = snap({ Stats = { TotalPops = 20 }, Dailies = { { Slot = 1, Progress = 5, Target = 5, Claimed = false } }, Goals = { { Id = "x", Progress = 1, Target = 1, Claimed = false, Complete = true } } })
	eq(Objectives.Roam(both, 0, 0, ocfg).Id, "ClaimDaily", "dailies come first")
end)

test("relay: popping an echostone sets off every other echostone, however far away", function()
	local g = grid(function(x, z)
		if x == 1 and z == 1 then return "Echostone" end
		if x == 9 and z == 9 then return "Echostone" end
		if x == 9 and z == 8 then return "Glimmerstone" end -- next to the far relay
		if x == 5 and z == 5 then return "Glimmerstone" end -- far from both: must NOT pop
	end)
	local r = ChainSim.Run(g, { cap(1, 1) }, ctx)
	eq(r.Pops, 3, "near relay, far relay, and the crystal beside the far relay")
	local far = findEvent(r, 9, 9)
	eq(far.Cause, "Chain", "the far relay is a chain reaction")
	eq(far.SX, 1, "set off by the near relay")
	eq(far.SZ, 1, "set off by the near relay")
	local near = findEvent(r, 1, 1)
	if math.abs((far.T - near.T) - Tuning.RelayDelay) > 1e-9 then error("the far relay must pop RelayDelay after the near one, got " .. (far.T - near.T)) end
	local beside = findEvent(r, 9, 8)
	eq(beside.SX, 9, "the far relay blasts its own neighbours")
	eq(beside.SZ, 9, "the far relay blasts its own neighbours")
	for _, e in r.Events do
		if e.X == 5 and e.Z == 5 then error("a crystal nowhere near a relay popped") end
	end
end)

test("relay: three relays all fire and the outcome does not depend on how the grid table was built", function()
	local function build(reverse)
		local cells = {}
		local keys = {}
		for z = 1, N do for x = 1, N do keys[#keys + 1] = { x, z } end end
		if reverse then
			for i = 1, #keys // 2 do keys[i], keys[#keys + 1 - i] = keys[#keys + 1 - i], keys[i] end
		end
		for _, k in keys do
			local x, z = k[1], k[2]
			local kind = nil
			if (x == 1 and z == 1) or (x == 9 and z == 1) or (x == 5 and z == 9) then kind = "Echostone"
			elseif (x + z) % 3 == 0 then kind = "Glimmerstone" end
			if kind then cells[ChainSim.Key(N, x, z)] = { Kind = kind } end
		end
		return { Size = N, Cells = cells }
	end
	local a = ChainSim.Run(build(false), { cap(1, 1) }, ctx)
	local b = ChainSim.Run(build(true), { cap(1, 1) }, ctx)
	local relays = 0
	for _, e in a.Events do if e.Kind == "Echostone" then relays += 1 end end
	eq(relays, 3, "all three relays popped")
	eq(#a.Events, #b.Events, "same number of events")
	for i = 1, #a.Events do
		local x, y = a.Events[i], b.Events[i]
		if x.X ~= y.X or x.Z ~= y.Z or x.Kind ~= y.Kind or x.Cause ~= y.Cause or x.SX ~= y.SX or math.abs(x.T - y.T) > 1e-9 then
			error("event " .. i .. " differs between construction orders")
		end
	end
	eq(a.Total, b.Total, "same payout")
end)

test("relay: a lone echostone just blasts its neighbours like a small volatile crystal", function()
	local g = grid(function(x, z) if x == 5 and z == 5 then return "Echostone" end if x == 6 and z == 5 then return "Glimmerstone" end if x == 7 and z == 5 then return "Glimmerstone" end end)
	local r = ChainSim.Run(g, { cap(5, 5) }, ctx)
	eq(r.Pops >= 2, true, "the neighbour pops")
	for _, e in r.Events do
		if e.X == 7 and e.Z == 5 and e.Cause == "Chain" and e.SX == 5 then error("radius 1 must not reach two cells away from the relay") end
	end
end)

test("echo caverns: the fourth area exists, is gated, and its sites and caches fit the map", function()
	eq(#Strata, 4, "four areas")
	eq(#WorldCfg.Biomes, 4, "four biomes")
	eq(#WorldCfg.Sites, 16, "4 biomes x 4 sites")
	eq(Crystals.Defs.Echostone.Stratum, 4, "echostone appears from area 4")
	eq(Crystals.Defs.Echostone.Behavior, "Relay", "behavior")
	for s = 1, 30 do
		for _, c in Seam.Generate(Crystals, Tuning, 3, s).Cells do
			if c.Kind == "Echostone" then error("echostone in area 3") end
		end
	end
	local saw = false
	for s = 1, 20 do
		for _, c in Seam.Generate(Crystals, Tuning, 4, s).Cells do if c.Kind == "Echostone" then saw = true end end
	end
	eq(saw, true, "area 4 spawns echostones")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
