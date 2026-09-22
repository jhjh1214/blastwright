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

-- Prices come from the config so these tests survive any rebalance.
local CHEAPEST_UPGRADE = math.huge
for _, def in Upgrades.Defs do CHEAPEST_UPGRADE = math.min(CHEAPEST_UPGRADE, def.Costs[1]) end
local AREA2_COST = Strata[2].Cost
local function withCommas(n)
	local out = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
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
	local o = Objectives.Roam(snap({ Shards = CHEAPEST_UPGRADE, Stats = { TotalPops = 12 } }), 0, 0, ocfg)
	eq(o.Id, "FirstUpgrade", "id")
	eq(o.Highlight, "Forge", "highlight")
	local poor = Objectives.Roam(snap({ Shards = CHEAPEST_UPGRADE - 1, Stats = { TotalPops = 12 } }), 0, 0, ocfg)
	eq(poor.Id, "Earn", "cannot afford yet")
end)

test("objectives: earning toward the next area points at a pad and names the area", function()
	local o = Objectives.Roam(snap({ Shards = 300, Upgrades = { ExtraCharge = 1 }, Stats = { TotalPops = 50, BestDepth = 4, BossesSlain = 1 } }), 0, 0, ocfg)
	eq(o.Id, "Earn", "id")
	eq(o.Target ~= nil, true, "target")
	eq(o.Text:find("Prism Veins", 1, true) ~= nil, true, "names next area")
	eq(o.Text:find(withCommas(AREA2_COST - 300), 1, true) ~= nil, true, "shows how many more shards are needed")
end)

test("objectives: enough shards to unlock the next area highlights the Forge", function()
	local o = Objectives.Roam(snap({ Shards = AREA2_COST, Upgrades = { ExtraCharge = 1 }, Stats = { TotalPops = 50 } }), 0, 0, ocfg)
	eq(o.Id, "UnlockArea", "id")
	eq(o.Highlight, "Forge", "highlight")
	eq(o.Text:find(withCommas(AREA2_COST), 1, true) ~= nil, true, "thousands separator")
end)

test("objectives: everything unlocked falls back to exploring for caches", function()
	local o = Objectives.Roam(snap({ Shards = 9999, Upgrades = { ExtraCharge = 3 }, StrataUnlocked = #Strata, Caches = { S1 = true, P2 = true }, Stats = { TotalPops = 999, BestDepth = 4, BossesSlain = 1 } }), 0, 0, ocfg)
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
local WeekCfg = require("../../src/ReplicatedStorage/Shared/Config/Weeklies")
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

test("dailies: combat kinds (Slays, Critical) exist in daily and weekly pools and accumulate per event", function()
	for _, cfg in { DailiesCfg, WeekCfg } do
		for _, kind in { "Slays", "Critical" } do
			local found = false
			for _, tpl in cfg.Templates do if tpl.Kind == kind then found = true end end
			eq(found, true, kind .. " template present")
		end
	end
	local defs = { { Slot = 1, Id = "S", Kind = "Slays", Target = 3, Text = "", RewardBase = 1 } }
	local daily = { Day = 5, Progress = {}, Claimed = {} }
	Dailies.Record(daily, defs, "Slays", 1)
	Dailies.Record(daily, defs, "Slays", 1)
	eq(daily.Progress["1"], 2, "sums kills")
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
	check(Products.CosmeticProducts, Products.CosmeticProductOrder, "cosmetic products")
	check(Products.Offers, Products.OfferOrder, "offers")
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
	eq(o.Highlight, "Daily", "the Daily button pulses")
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
	local KNOWN = { TotalPops = true, BestChain = true, SeamsCleared = true, TotalShards = true, Caches = true, Codex = true, Prismatic = true, Strata = true, BestDepth = true, ExpeditionsWon = true, LurkersSlain = true, BossesSlain = true }
	local valued = 0
	for _, def in Crystals.Defs do if def.Value > 0 then valued += 1 end end
	local limit = {
		Caches = #WorldCfg.Caches,
		Codex = #Crystals.Order,
		Prismatic = valued,
		Strata = #Strata,
		BestDepth = require("../../src/ReplicatedStorage/Shared/Config/Expedition").Floors,
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
	eq(o.Highlight, "Goals", "the Goals button pulses")
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

local Cosmetics = require("../../src/ReplicatedStorage/Shared/Cosmetics")
local CosCfg = require("../../src/ReplicatedStorage/Shared/Config/Cosmetics")

test("cosmetics: config has one free default first, unique ids, valid colors and real unlock goals", function()
	local seen, free = {}, 0
	for i, def in CosCfg.Defs do
		if seen[def.Id] then error("duplicate cosmetic " .. def.Id) end
		seen[def.Id] = true
		if type(def.Name) ~= "string" or def.Name == "" then error(def.Id .. " needs a name") end
		if #def.Color ~= 3 then error(def.Id .. " color needs r,g,b") end
		for _, c in def.Color do
			if c < 0 or c > 255 or c % 1 ~= 0 then error(def.Id .. " has an invalid color channel") end
		end
		if def.UnlockGoal == nil and not def.Shop then
			free += 1
			eq(i, 1, "the free default must be first")
		end
		if def.UnlockGoal ~= nil and Achievements.Find(AchCfg, def.UnlockGoal) == nil then
			error(def.Id .. " unlocks from a goal that does not exist: " .. def.UnlockGoal)
		end
	end
	eq(free, 1, "exactly one free default")
	eq(CosCfg.Defs[1].Id, CosCfg.DefaultId, "DefaultId names the first entry")
end)

test("cosmetics: ownership comes from claimed goals or purchases; the default is always owned", function()
	local d = Schema.Default()
	local unlockable = nil
	for _, def in CosCfg.Defs do if def.UnlockGoal then unlockable = def break end end
	local shopItem = nil
	for _, def in CosCfg.Defs do if def.Shop then shopItem = def break end end
	eq(Cosmetics.IsOwned(d, CosCfg, CosCfg.DefaultId), true, "default owned from the start")
	eq(Cosmetics.IsOwned(d, CosCfg, unlockable.Id), false, "goal-gated style locked")
	d.Achievements.Claimed[unlockable.UnlockGoal] = true
	eq(Cosmetics.IsOwned(d, CosCfg, unlockable.Id), true, "claiming the goal unlocks it")
	eq(Cosmetics.IsOwned(d, CosCfg, shopItem.Id), false, "shop item locked until purchased")
	d.Cosmetics.Owned[shopItem.Id] = true
	eq(Cosmetics.IsOwned(d, CosCfg, shopItem.Id), true, "purchase unlocks it")
	eq(Cosmetics.IsOwned(d, CosCfg, "Nonexistent"), false, "unknown id")
	eq(Cosmetics.IsOwned(d, CosCfg, "__index"), false, "junk id")
end)

test("cosmetics: only owned, real, string ids can be equipped; a bad saved choice falls back to the default", function()
	local d = Schema.Default()
	local locked = nil
	for _, def in CosCfg.Defs do if def.UnlockGoal then locked = def break end end
	eq(Cosmetics.CanEquip(d, CosCfg, CosCfg.DefaultId), true, "default")
	eq(Cosmetics.CanEquip(d, CosCfg, locked.Id), false, "locked")
	for _, bad in { 5, true, "", "nope", "__index" } do
		eq(Cosmetics.CanEquip(d, CosCfg, bad), false, "bad id " .. tostring(bad))
	end
	eq(Cosmetics.CanEquip(d, CosCfg, nil), false, "nil")
	d.Cosmetics.Equipped.BlastColor = locked.Id -- tampered or stale save: equipped but not owned
	eq(Cosmetics.Active(d, CosCfg).Id, CosCfg.DefaultId, "falls back to the default")
	d.Achievements.Claimed[locked.UnlockGoal] = true
	eq(Cosmetics.Active(d, CosCfg).Id, locked.Id, "works once it is owned")
end)

test("cosmetics: the client view lists every style with owned/equipped flags and unlock hints", function()
	local d = Schema.Default()
	local view = Cosmetics.View(d, CosCfg, AchCfg)
	eq(#view, #CosCfg.Defs, "one row per style")
	eq(view[1].Owned, true, "default owned")
	eq(view[1].Equipped, true, "default equipped")
	for i = 2, #view do
		eq(view[i].Equipped, false, "only one equipped")
		if not view[i].Owned and (view[i].Unlock == nil or view[i].Unlock == "") then error(view[i].Id .. " locked style needs an unlock hint") end
	end
end)

test("schema: v4 saves migrate to v5 with the default style equipped", function()
	local d = Schema.Migrate({ SchemaVersion = 4, Shards = 12, Achievements = { Claimed = { Pops1 = true } } })
	eq(d.SchemaVersion, Schema.CURRENT_VERSION, "version")
	eq(Schema.CURRENT_VERSION >= 5, true, "v5 exists")
	eq(d.Cosmetics.Equipped.BlastColor, "Classic", "default equipped")
	eq(type(d.Cosmetics.Owned), "table", "owned map")
	eq(d.Achievements.Claimed.Pops1, true, "goals kept")
	eq(d.Shards, 12, "shards kept")
end)

test("products: cosmetic products point at real shop styles, and every shop style is buyable", function()
	eq(type(Products.CosmeticProducts), "table", "cosmetic product table exists")
	local styleByShop = {}
	for _, def in CosCfg.Defs do
		if def.Shop then styleByShop[def.Id] = false end
	end
	local seenIds = {}
	for _, list in { Products.DeveloperProducts, Products.CosmeticProducts, Products.Gamepasses } do
		for _, d in list do
			if d.Id ~= nil then
				if seenIds[d.Id] then error("product id " .. d.Id .. " is used twice across the catalogue") end
				seenIds[d.Id] = true
			end
		end
	end
	for key, d in Products.CosmeticProducts do
		if Products.DeveloperProducts[key] ~= nil then error(key .. " exists as both a shard pack and a cosmetic product") end
		if type(d.Name) ~= "string" or type(d.Description) ~= "string" then error(key .. " needs a name and description") end
		if styleByShop[d.Cosmetic] == nil then error(key .. " grants " .. tostring(d.Cosmetic) .. ", which is not a Shop style") end
		styleByShop[d.Cosmetic] = true
	end
	for id, bought in styleByShop do
		if not bought then error("shop style " .. id .. " has no product, so nobody could ever get it") end
	end
	eq(#Products.CosmeticProductOrder, (function() local n = 0 for _ in Products.CosmeticProducts do n += 1 end return n end)(), "order lists every cosmetic product")
end)

test("receipts: granting a cosmetic marks it owned, once, and never touches shards", function()
	local d = Schema.Default()
	local shardsBefore = d.Shards
	Receipts.GrantCosmetic(d, "NeonPink")
	eq(d.Cosmetics.Owned.NeonPink, true, "owned")
	eq(Cosmetics.IsOwned(d, CosCfg, "NeonPink"), true, "ownership rules agree")
	eq(d.Shards, shardsBefore, "no shards granted")
	Receipts.GrantCosmetic(d, "NeonPink")
	eq(d.Cosmetics.Owned.NeonPink, true, "granting twice is harmless")
end)

test("goals: newly completed goals are reported once, and already-complete ones are never announced", function()
	local d = serverData()
	local first, second = AchCfg.Defs[1], AchCfg.Defs[2]
	d.Stats.TotalPops = first.Target -- one goal already complete when the player joins
	local seen = {}
	local initial = Achievements.NewlyComplete(d, AchCfg, seen)
	eq(#initial, 1, "join-time scan sees the existing completion")
	eq(#Achievements.NewlyComplete(d, AchCfg, seen), 0, "nothing new on a repeat scan")
	d.Stats.TotalPops = second.Target
	local fresh = Achievements.NewlyComplete(d, AchCfg, seen)
	eq(#fresh, 1, "exactly the newly reached goal")
	eq(fresh[1].Id, second.Id, "it is the second tier")
	eq(#Achievements.NewlyComplete(d, AchCfg, seen), 0, "announced only once")
end)

test("goals: a goal that is already claimed counts as seen, so it is never announced", function()
	local d = serverData()
	local def = AchCfg.Defs[1]
	d.Stats.TotalPops = def.Target
	d.Achievements.Claimed[def.Id] = true
	local seen = {}
	Achievements.NewlyComplete(d, AchCfg, seen)
	d.Stats.TotalPops = def.Target + 1
	eq(#Achievements.NewlyComplete(d, AchCfg, seen), 0, "no re-announcement")
end)

test("goals: several goals crossing at once are all reported, in config order", function()
	local d = serverData()
	local seen = {}
	Achievements.NewlyComplete(d, AchCfg, seen)
	d.Stats.TotalPops = 1e6
	d.Stats.BestChain = 40
	local list = Achievements.NewlyComplete(d, AchCfg, seen)
	local sawPops, sawChain, lastIndex = false, false, 0
	for _, def in list do
		if def.Stat == "TotalPops" then sawPops = true end
		if def.Stat == "BestChain" then sawChain = true end
		local index
		for i, x in AchCfg.Defs do if x.Id == def.Id then index = i end end
		if index < lastIndex then error("not in config order") end
		lastIndex = index
	end
	eq(sawPops and sawChain, true, "both stats reported")
end)

local Board = require("../../src/ReplicatedStorage/Shared/Board")

test("board: ranks by value, breaks ties by name, and caps the row count", function()
	local rows = {
		{ Name = "Dov", Value = 7 },
		{ Name = "Bea", Value = 40 }, -- ties listed out of alphabetical order on purpose
		{ Name = "Cara", Value = 12 },
		{ Name = "Abe", Value = 40 },
	}
	local sorted = Board.Rank(rows, 3)
	eq(#sorted, 3, "capped at 3")
	eq(sorted[1].Name, "Abe", "highest first")
	eq(sorted[2].Name, "Bea", "tie broken alphabetically")
	eq(sorted[3].Name, "Cara", "then by value")
	eq(rows[1].Name, "Dov", "input order not mutated")
end)

test("board: ignores junk rows instead of crashing", function()
	local sorted = Board.Rank({ { Name = "Ok", Value = 5 }, { Name = "NaN", Value = 0 / 0 }, { Name = "Inf", Value = math.huge }, { Name = "Neg", Value = -3 }, { Name = 5, Value = 9 }, { Value = 4 }, "row", { Name = "Str", Value = "9" } }, 10)
	eq(#sorted, 1, "only the valid row survives")
	eq(sorted[1].Name, "Ok", "the valid one")
end)

test("board: text shows rank, a truncated name and the value, and a friendly empty state", function()
	local text = Board.Format("LONGEST CHAINS", { { Name = "A very very long player name indeed", Value = 1234 }, { Name = "Bo", Value = 35 } }, 10)
	local lines = {}
	for line in string.gmatch(text, "[^\n]+") do table.insert(lines, line) end
	eq(lines[1], "LONGEST CHAINS", "title")
	eq(lines[2]:find(" 1 ", 1, true) ~= nil, true, "rank 1 shown")
	eq(lines[2]:find("A very very long", 1, true) ~= nil, true, "name truncated but recognisable")
	eq(lines[2]:find("indeed", 1, true), nil, "long name is cut off")
	eq(lines[2]:find("1,234", 1, true) ~= nil, true, "thousands separator")
	eq(lines[3]:find("Bo", 1, true) ~= nil and lines[3]:find("35", 1, true) ~= nil, true, "second row")
	local empty = Board.Format("LONGEST CHAINS", {}, 10)
	eq(empty:find("Be the first", 1, true) ~= nil, true, "empty state invites the first entry")
end)

test("board: a tied group is ordered alphabetically no matter how it arrives", function()
	local names = { "Abe", "Bea", "Cal", "Dee" }
	local function permutations(list)
		local out = {}
		local function go(arr, n)
			if n == 1 then table.insert(out, table.clone(arr)) return end
			for i = 1, n do
				arr[i], arr[n] = arr[n], arr[i]
				go(arr, n - 1)
				arr[i], arr[n] = arr[n], arr[i]
			end
		end
		go(table.clone(list), #list)
		return out
	end
	local perms = permutations(names)
	eq(#perms, 24, "all 24 arrival orders")
	for _, order in perms do
		local rows = {}
		for _, name in order do table.insert(rows, { Name = name, Value = 30 }) end
		local ranked = Board.Rank(rows, 10)
		for i = 1, 4 do
			if ranked[i].Name ~= names[i] then error("arrival order " .. table.concat(order, ",") .. " produced " .. ranked[i].Name .. " at " .. i) end
		end
	end
end)


test("weekly: weeks start on Monday 00:00 UTC and last exactly seven days", function()
	local monday = 1704067200 -- 2024-01-01 00:00:00 UTC, a Monday
	local week = Dailies.WeekNumber(monday)
	eq(Dailies.WeekNumber(monday - 1), week - 1, "the second before Monday belongs to the previous week")
	eq(Dailies.WeekNumber(monday + 3 * 86400 + 12345), week, "midweek")
	eq(Dailies.WeekNumber(monday + 7 * 86400 - 1), week, "Sunday 23:59:59 is still this week")
	eq(Dailies.WeekNumber(monday + 7 * 86400), week + 1, "next Monday starts a new week")
	eq(Dailies.SecondsUntilWeekReset(monday), 7 * 86400, "a full week left at the very start")
	eq(Dailies.SecondsUntilWeekReset(monday + 7 * 86400 - 1), 1, "one second left")
	eq(Dailies.SecondsUntilWeekReset(monday + 2 * 86400 + 3600), 5 * 86400 - 3600, "midweek countdown")
end)

test("weekly: three distinct objectives per week, rising targets and rewards, harder than the daily ones", function()
	for w = 2800, 2840 do
		local defs = Dailies.ForDay(w, WeekCfg)
		eq(#defs, 3, "three objectives")
		eq(defs[1].Id ~= defs[2].Id and defs[2].Id ~= defs[3].Id and defs[1].Id ~= defs[3].Id, true, "distinct")
		if not (defs[1].RewardBase < defs[2].RewardBase and defs[2].RewardBase < defs[3].RewardBase) then error("rewards do not rise in week " .. w) end
	end
	for i, def in WeekCfg.Templates do
		local daily = nil
		for _, d in DailiesCfg.Templates do if d.Kind == def.Kind then daily = d end end
		if daily == nil then error("weekly kind " .. def.Kind .. " is not a daily kind, so it would never be recorded") end
		for slot = 1, 3 do
			if def.Targets[slot] <= daily.Targets[slot] then error(def.Id .. " weekly target " .. slot .. " must exceed the daily one") end
		end
	end
	eq(WeekCfg.SlotRewards[1] > DailiesCfg.SlotRewards[3], true, "weekly rewards dwarf daily ones")
end)

test("schema: v5 saves migrate to v6 with an empty weekly record", function()
	local d = Schema.Migrate({ SchemaVersion = 5, Shards = 9, Cosmetics = { Owned = { NeonPink = true }, Equipped = { BlastColor = "Classic" } } })
	eq(d.SchemaVersion, Schema.CURRENT_VERSION, "version")
	eq(Schema.CURRENT_VERSION >= 6, true, "v6 exists")
	eq(d.Weekly.Day, 0, "weekly period")
	eq(next(d.Weekly.Progress), nil, "weekly progress")
	eq(d.Cosmetics.Owned.NeonPink, true, "cosmetics kept")
	eq(d.Shards, 9, "shards kept")
end)

test("objectives: a finished weekly objective is surfaced too", function()
	local data = snap({ Stats = { TotalPops = 20 }, Weeklies = { { Slot = 2, Progress = 9, Target = 9, Claimed = false } } })
	eq(Objectives.Roam(data, 0, 0, ocfg).Id, "ClaimDaily", "weekly claim nudges through the same objective")
	data.Weeklies[1].Claimed = true
	eq(Objectives.Roam(data, 0, 0, ocfg).Id ~= "ClaimDaily", true, "claimed one no longer nags")
end)

test("settings: screen shake is a valid boolean setting, defaults on, and old saves get the default", function()
	local k, v = Validate.Setting("Shake", false)
	eq(k, "Shake", "shake key accepted")
	eq(v, false, "false is valid")
	eq(Validate.Setting("Shake", "off"), nil, "non-boolean rejected")
	eq(Validate.Setting("shake", true), nil, "case matters")
	eq(Schema.Default().Settings.Shake, true, "on by default")
	local old = Schema.Migrate({ SchemaVersion = 5, Settings = { Music = false, Sfx = true } })
	eq(old.Settings.Shake, true, "an old save without the key gets the default")
	eq(old.Settings.Music, false, "existing choices are kept")
end)

test("balance: one charge never clears the grid on average (planning matters) and chains still happen", function()
	-- Measured with tools/sim/balance.luau after the rebalance: about 26%, 36%, 45%, 52% of the grid for areas 1 to 4.
	-- Thresholds sit above that so ordinary tuning is fine, but bringing back supercritical chains (every charge
	-- cascading across the whole grid, as with 18% Kindlequartz) fails here.
	local ceiling = { 0.40, 0.50, 0.60, 0.66 }
	local floor = { 0.12, 0.15, 0.18, 0.20 }
	for stratum = 1, 4 do
		local sum = 0
		for seed = 1, 24 do
			local g = Seam.Generate(Crystals, Tuning, stratum, seed * 31337 + 5)
			local valuable = Seam.CountValuable(g, Crystals)
			local best = 0
			for z = 1, N do
				for x = 1, N do
					best = math.max(best, ChainSim.Run(g, { cap(x, z) }, ctx).Pops)
				end
			end
			sum += best / valuable
		end
		local mean = sum / 24
		if mean > ceiling[stratum] then error(("area %d: the best single charge pops %.0f%% of the grid on average (limit %.0f%%): chains are too easy"):format(stratum, mean * 100, ceiling[stratum] * 100)) end
		if mean < floor[stratum] then error(("area %d: the best single charge pops only %.0f%% (floor %.0f%%): chains are too weak"):format(stratum, mean * 100, floor[stratum] * 100)) end
	end
end)

local Events = require("../../src/ReplicatedStorage/Shared/Events")
local EventsCfg = require("../../src/ReplicatedStorage/Shared/Config/Events")

local MONDAY = 1704067200 -- 2024-01-01 00:00:00 UTC
local DAY, HOUR = 86400, 3600

local function ids(list)
	local out = {}
	for _, e in list do out[e.Id] = true end
	return out
end

test("events: day of week is Monday-based and rolls over at UTC midnight", function()
	eq(Events.DayOfWeek(MONDAY), 0, "Monday")
	eq(Events.DayOfWeek(MONDAY + DAY - 1), 0, "still Monday one second before midnight")
	eq(Events.DayOfWeek(MONDAY + DAY), 1, "Tuesday")
	eq(Events.DayOfWeek(MONDAY + 5 * DAY), 5, "Saturday")
	eq(Events.DayOfWeek(MONDAY + 6 * DAY), 6, "Sunday")
	eq(Events.DayOfWeek(MONDAY + 7 * DAY), 0, "Monday again")
end)

test("events: the weekend event covers Saturday and Sunday exactly", function()
	local weekend = EventsCfg.Defs[1]
	eq(weekend.Id, "PrismaticWeekend", "first event is the weekend one")
	eq(ids(Events.Active(MONDAY + 4 * DAY + 23 * HOUR + 3599, EventsCfg)).PrismaticWeekend, nil, "Friday 23:59:59 is not the weekend")
	eq(ids(Events.Active(MONDAY + 5 * DAY, EventsCfg)).PrismaticWeekend, true, "Saturday 00:00:00 starts it")
	eq(ids(Events.Active(MONDAY + 6 * DAY + 23 * HOUR + 3599, EventsCfg)).PrismaticWeekend, true, "Sunday 23:59:59 is still in it")
	eq(ids(Events.Active(MONDAY + 7 * DAY, EventsCfg)).PrismaticWeekend, nil, "Monday 00:00:00 ends it")
end)

test("events: a daily window includes its start, excludes its end, and reports time left", function()
	local hh
	for _, d in EventsCfg.Defs do if d.Id == "HappyHour" then hh = d end end
	local startAt = MONDAY + hh.StartHour * HOUR
	eq(ids(Events.Active(startAt - 1, EventsCfg)).HappyHour, nil, "one second before")
	eq(ids(Events.Active(startAt, EventsCfg)).HappyHour, true, "at the start")
	local endAt = MONDAY + hh.EndHour * HOUR
	eq(ids(Events.Active(endAt - 1, EventsCfg)).HappyHour, true, "one second before the end")
	eq(ids(Events.Active(endAt, EventsCfg)).HappyHour, nil, "at the end")
	for _, e in Events.Active(startAt + 1800, EventsCfg) do
		if e.Id == "HappyHour" then eq(e.EndsIn, (hh.EndHour - hh.StartHour) * HOUR - 1800, "time left counts down to the end of the window") end
	end
end)

test("events: effects combine (multiply rates, add charges) and nothing active means no change", function()
	local none = Events.Combine({})
	eq(none.MutationMult, 1, "no mutation change")
	eq(none.ShardMult, 1, "no shard change")
	eq(none.ChargeBonus, 0, "no extra charges")
	local saturdayHappyHour
	for _, d in EventsCfg.Defs do if d.Id == "HappyHour" then saturdayHappyHour = MONDAY + 5 * DAY + d.StartHour * HOUR + 60 end end
	local both = Events.Combine(Events.Active(saturdayHappyHour, EventsCfg))
	eq(both.MutationMult > 1, true, "weekend raises Prismatic chance")
	eq(both.ShardMult > 1, true, "happy hour raises payouts")
	local wednesday = Events.Combine(Events.Active(MONDAY + 2 * DAY + 12 * HOUR, EventsCfg))
	eq(wednesday.ChargeBonus >= 1, true, "midweek event gives an extra charge")
	local manual = Events.Combine({ { Effects = { ShardMult = 2 } }, { Effects = { ShardMult = 3, ChargeBonus = 1 } }, { Effects = { ChargeBonus = 2 } } })
	eq(manual.ShardMult, 6, "shard multipliers multiply")
	eq(manual.ChargeBonus, 3, "charge bonuses add")
end)

test("events: config is valid (unique ids, real weekdays and hours, known positive effects)", function()
	local seen = {}
	local KNOWN = { MutationMult = true, ShardMult = true, ChargeBonus = true, LurkerMult = true, DamageMult = true, BountyMult = true }
	for _, d in EventsCfg.Defs do
		if seen[d.Id] then error("duplicate event " .. d.Id) end
		seen[d.Id] = true
		if type(d.Name) ~= "string" or d.Name == "" or type(d.Description) ~= "string" or d.Description == "" then error(d.Id .. " needs a name and description") end
		if #d.Weekdays == 0 then error(d.Id .. " never happens") end
		for _, w in d.Weekdays do if w < 0 or w > 6 or w % 1 ~= 0 then error(d.Id .. " has an invalid weekday") end end
		if not (d.StartHour >= 0 and d.EndHour <= 24 and d.StartHour < d.EndHour) then error(d.Id .. " has an invalid time window") end
		local any = false
		for k, v in d.Effects do
			if not KNOWN[k] then error(d.Id .. " has unknown effect " .. k) end
			if type(v) ~= "number" or v <= 0 then error(d.Id .. " effect " .. k .. " must be positive") end
			any = true
		end
		if not any then error(d.Id .. " has no effect") end
		if d.Effects.ShardMult and d.Effects.ShardMult > 3 then error(d.Id .. " shard bonus is too generous") end
	end
end)

local RateLimiter = require("../../src/ServerScriptService/Server/RateLimiter")

test("rate limiter: a burst is allowed, then calls are refused", function()
	local rl = RateLimiter.new()
	for i = 1, 5 do
		eq(rl:Allow(1, "Buy", 100, 2, 5), true, "call " .. i .. " within the burst")
	end
	eq(rl:Allow(1, "Buy", 100, 2, 5), false, "the sixth instant call is refused")
	eq(rl:Allow(1, "Buy", 100, 2, 5), false, "and stays refused")
end)

test("rate limiter: tokens refill at the configured rate and never exceed the burst", function()
	local rl = RateLimiter.new()
	for _ = 1, 5 do rl:Allow(1, "Buy", 0, 2, 5) end
	eq(rl:Allow(1, "Buy", 0.4, 2, 5), false, "0.8 of a token is not enough")
	eq(rl:Allow(1, "Buy", 0.5, 2, 5), true, "one full token after 0.5s at 2 per second")
	eq(rl:Allow(1, "Buy", 0.5, 2, 5), false, "and only one")
	for _ = 1, 5 do
		eq(rl:Allow(1, "Buy", 1000, 2, 5), true, "after a long pause the full burst is back")
	end
	eq(rl:Allow(1, "Buy", 1000, 2, 5), false, "but never more than the burst")
end)

test("rate limiter: players and remotes are limited independently, and Forget resets a player", function()
	local rl = RateLimiter.new()
	for _ = 1, 3 do rl:Allow(1, "Buy", 0, 1, 3) end
	eq(rl:Allow(1, "Buy", 0, 1, 3), false, "player 1 is out")
	eq(rl:Allow(2, "Buy", 0, 1, 3), true, "player 2 is unaffected")
	eq(rl:Allow(1, "Claim", 0, 1, 3), true, "another remote of player 1 is unaffected")
	rl:Forget(1)
	eq(rl:Allow(1, "Buy", 0, 1, 3), true, "a forgotten player starts fresh (no leak across sessions)")
end)

test("rate limiter: a clock that goes backwards or bad settings cannot grant free calls", function()
	local rl = RateLimiter.new()
	for _ = 1, 3 do rl:Allow(1, "Buy", 100, 1, 3) end
	eq(rl:Allow(1, "Buy", 50, 1, 3), false, "time going backwards does not refill")
	eq(rl:Allow(1, "Buy", 100, 0, 3), false, "a zero rate refuses")
	eq(rl:Allow(1, "Buy", 100, 1, 0), false, "a zero burst refuses")
	eq(rl:Allow(1, "Buy", 100, 0 / 0, 3), false, "NaN rate refuses")
	eq(rl:Allow(1, "Buy", 100 + 0 / 0, 1, 3), false, "NaN time refuses")
end)

local Community = require("../../src/ReplicatedStorage/Shared/Community")
local CommCfg = require("../../src/ReplicatedStorage/Shared/Config/Community")

test("server goal: the target grows with the number of players and is capped", function()
	local one = Community.Target(1, CommCfg)
	eq(one, CommCfg.BasePops, "one player uses the base target")
	eq(Community.Target(0, CommCfg), one, "no players is treated as one")
	eq(Community.Target(4, CommCfg), CommCfg.BasePops + 3 * CommCfg.PopsPerPlayer, "each extra player adds a share")
	eq(Community.Target(500, CommCfg), CommCfg.MaxTarget, "capped")
	local last = 0
	for n = 1, 16 do
		local t = Community.Target(n, CommCfg)
		eq(t >= last, true, "never shrinks as players are added")
		last = t
	end
	eq(Community.Target(16, CommCfg) <= CommCfg.MaxTarget, true, "16 players stay under the cap")
end)

test("server goal: progress accumulates, completes exactly once, and remembers who contributed", function()
	local s = Community.New(1, 2, CommCfg)
	eq(s.Progress, 0, "starts empty")
	eq(s.Target, Community.Target(2, CommCfg), "target for two players")
	eq(Community.Contribute(s, 11, 10), false, "not done yet")
	eq(Community.Contribute(s, 12, 0), false, "a zero contribution does nothing")
	eq(s.Contributors[12], nil, "and is not recorded as contributing")
	eq(Community.Contribute(s, 11, s.Target), true, "this pushes it over the line")
	eq(Community.Contribute(s, 12, 50), false, "already complete: no second completion")
	eq(s.Done, true, "marked done")
	local who = Community.Rewardees(s)
	table.sort(who)
	eq(#who, 2, "both contributors are rewardees")
	eq(who[1], 11, "first")
	eq(who[2], 12, "second")
end)

test("server goal: junk contributions are ignored", function()
	local s = Community.New(1, 1, CommCfg)
	Community.Contribute(s, 1, -5)
	Community.Contribute(s, 1, 0 / 0)
	Community.Contribute(s, 1, math.huge)
	eq(s.Progress, 0, "nothing counted")
	eq(next(s.Contributors), nil, "nobody recorded")
end)

test("server goal: the frenzy boosts payouts only while it lasts", function()
	local s = Community.New(1, 1, CommCfg)
	eq(Community.Mult(s, 0, CommCfg), 1, "no frenzy before completion")
	Community.StartFrenzy(s, 100, CommCfg)
	eq(Community.Mult(s, 100, CommCfg), CommCfg.FrenzyShardMult, "boosted at the start")
	eq(Community.Mult(s, 100 + CommCfg.FrenzySeconds - 0.001, CommCfg), CommCfg.FrenzyShardMult, "boosted until the end")
	eq(Community.Mult(s, 100 + CommCfg.FrenzySeconds, CommCfg), 1, "back to normal at the end")
	eq(Community.FrenzyLeft(s, 100 + 10), CommCfg.FrenzySeconds - 10, "time left counts down")
	eq(Community.FrenzyLeft(s, 100 + CommCfg.FrenzySeconds + 50), 0, "never negative")
end)

test("server goal: a new round starts empty, retargets for the current player count, and keeps no contributors", function()
	local s = Community.New(1, 1, CommCfg)
	Community.Contribute(s, 7, s.Target)
	local nextRound = Community.New(s.Round + 1, 6, CommCfg)
	eq(nextRound.Round, 2, "round advances")
	eq(nextRound.Progress, 0, "empty")
	eq(nextRound.Done, false, "not done")
	eq(nextRound.Target, Community.Target(6, CommCfg), "retargeted")
	eq(next(nextRound.Contributors), nil, "fresh contributor list")
end)

test("server goal: the client view is small and complete", function()
	local s = Community.New(3, 1, CommCfg)
	Community.Contribute(s, 1, 40)
	Community.StartFrenzy(s, 10, CommCfg)
	local v = Community.View(s, 20, CommCfg)
	eq(v.Round, 3, "round")
	eq(v.Progress, 40, "progress")
	eq(v.Target, s.Target, "target")
	eq(v.FrenzyLeft, CommCfg.FrenzySeconds - 10, "frenzy time left")
	eq(v.Done, false, "not done")
end)

test("server goal: config is sane (rewards positive, frenzy modest, target reachable)", function()
	eq(CommCfg.BasePops > 0 and CommCfg.PopsPerPlayer > 0, true, "positive targets")
	eq(CommCfg.MaxTarget >= CommCfg.BasePops, true, "cap above the base")
	eq(CommCfg.RewardShards > 0, true, "positive reward")
	eq(CommCfg.FrenzyShardMult > 1 and CommCfg.FrenzyShardMult <= 2, true, "frenzy boosts but modestly")
	eq(CommCfg.FrenzySeconds > 0 and CommCfg.NewRoundDelay >= 0, true, "timings")
end)

test("server goal: reaching the target exactly completes it, one short does not", function()
	local a = Community.New(1, 1, CommCfg)
	eq(Community.Contribute(a, 1, a.Target - 1), false, "one short of the target")
	eq(Community.Contribute(a, 1, 1), true, "the last pop lands exactly on the target and completes it")
	local b = Community.New(1, 1, CommCfg)
	eq(Community.Contribute(b, 1, b.Target), true, "a single contribution equal to the target completes it")
end)

test("cross charge: covers its row and column with distances, counts the center once, and clips at the edge", function()
	local set, n = cellSet(ChainSim.BlastCells("Cross", 5, 5, 0, 3, N))
	eq(n, 13, "4 arms of 3 plus the center")
	eq(set["5,5"], 0, "center once")
	eq(set["8,5"], 3, "row arm end")
	eq(set["2,5"], 3, "row arm other end")
	eq(set["5,8"], 3, "column arm end")
	eq(set["6,6"], nil, "diagonals are not covered")
	local _, corner = cellSet(ChainSim.BlastCells("Cross", 1, 1, 0, 3, N))
	eq(corner, 7, "corner keeps two arms of 3 plus the center")
	local _, wide = cellSet(ChainSim.BlastCells("Cross", 5, 5, 0, 20, N))
	eq(wide, 2 * N - 1, "a huge range covers exactly one full row and one full column")
end)

test("cross charge: the simulation uses it, sources point at the charge cell, and it is a priced unlock", function()
	local g = grid(function(x, z) if (x == 2 and z == 5) or (x == 5 and z == 8) or (x == 6 and z == 6) then return "Glimmerstone" end end)
	local r = ChainSim.Run(g, { { X = 5, Z = 5, Kind = "Cross" } }, ctx)
	eq(r.Pops, 2, "row and column crystals pop, the diagonal one does not")
	eq(findEvent(r, 2, 5).SX, 5, "source x is the charge cell")
	eq(findEvent(r, 5, 8).SZ, 5, "source z is the charge cell")
	eq(Charges.Defs.Cross.UnlockCost > Charges.Defs.Shaft.UnlockCost, true, "priced above the shaft charge")
	eq(Charges.Order[#Charges.Order], "Shock", "listed last so the selector grows in unlock order")
	eq(Charges.Defs.Shock.UnlockCost > Charges.Defs.Cross.UnlockCost, true, "the shockwave is the priciest unlock")
	eq(#Charges.Order, (function() local n = 0 for _ in Charges.Defs do n += 1 end return n end)(), "Order lists every charge")
end)

local function withMods(mods)
	return { Crystals = ctx.Crystals, Charges = ctx.Charges, Tuning = ctx.Tuning, Modifiers = mods }
end

test("modifiers: AmplifierMult scales what each Resonite adds to the multiplier", function()
	local g = grid(function(x, z)
		if x == 5 and z == 5 then return "Resonite" end
		if x == 6 and z == 5 then return "Glimmerstone" end
	end)
	local plain = ChainSim.Run(g, { cap(5, 5) }, ctx)
	eq(findEvent(plain, 6, 5).Mult, 1.5, "normal: +0.5")
	local boosted = ChainSim.Run(g, { cap(5, 5) }, withMods({ AmplifierMult = 2 }))
	eq(findEvent(boosted, 6, 5).Mult, 2, "doubled: +1.0")
	eq(findEvent(boosted, 6, 5).Value, 10, "5 x 2.0")
end)

test("modifiers: UnstableShield stops Dreadgeodes halving the multiplier", function()
	local g = grid(function(x, z)
		if x == 5 and z == 5 then return "Resonite" end
		if x == 6 and z == 5 then return "Dreadgeode" end
		if x == 4 and z == 5 then return "Glimmerstone" end
	end)
	local plain = ChainSim.Run(g, { cap(5, 5) }, ctx)
	local shielded = ChainSim.Run(g, { cap(5, 5) }, withMods({ UnstableShield = true }))
	eq(findEvent(plain, 6, 5).Mult, 1, "normal: 1.5 halved and floored to 1")
	eq(findEvent(shielded, 6, 5).Mult, 1.5, "shielded: multiplier survives")
end)

test("modifiers: VolatileRadiusBonus widens Kindlequartz blasts only", function()
	local g = grid(function(x, z)
		if x == 5 and z == 5 then return "Kindlequartz" end
		if x == 7 and z == 5 then return "Glimmerstone" end
	end)
	eq(ChainSim.Run(g, { cap(5, 5) }, ctx).Pops, 1, "normal radius 1.5 never reaches two cells away")
	eq(ChainSim.Run(g, { cap(5, 5) }, withMods({ VolatileRadiusBonus = 0.5 })).Pops, 2, "radius 2 reaches it")
	local slow = grid(function(x, z)
		if x == 5 and z == 5 then return "Slowburn" end
		if x == 8 and z == 5 then return "Glimmerstone" end
	end)
	eq(ChainSim.Run(slow, { cap(5, 5) }, withMods({ VolatileRadiusBonus = 5 })).Pops, 1, "the bonus does not apply to Slowburn")
end)

test("modifiers: RelayValueMult and ValueMult scale payouts", function()
	local g = grid(function(x, z) if x == 5 and z == 5 then return "Echostone" end end)
	eq(ChainSim.Run(g, { cap(5, 5) }, ctx).Raw, 12, "echostone base value")
	eq(ChainSim.Run(g, { cap(5, 5) }, withMods({ RelayValueMult = 3 })).Raw, 36, "relay value x3")
	local inert = grid(function(x, z) if x == 5 and z == 5 then return "Glimmerstone" end end)
	eq(ChainSim.Run(inert, { cap(5, 5) }, withMods({ RelayValueMult = 3 })).Raw, 5, "relay bonus leaves other crystals alone")
	eq(ChainSim.Run(inert, { cap(5, 5) }, withMods({ ValueMult = 2 })).Raw, 10, "global value x2")
end)

test("modifiers: no modifiers, or an empty table, change nothing", function()
	local g = Seam.Generate(Crystals, Tuning, 4, 777)
	local a = ChainSim.Run(g, { cap(3, 3), cap(7, 7) }, ctx)
	local b = ChainSim.Run(g, { cap(3, 3), cap(7, 7) }, withMods({}))
	eq(a.Total, b.Total, "same payout")
	eq(#a.Events, #b.Events, "same events")
	eq(a.PeakMult, b.PeakMult, "same multiplier")
end)

local Expedition = require("../../src/ReplicatedStorage/Shared/Expedition")
local ExpCfg = require("../../src/ReplicatedStorage/Shared/Config/Expedition")

local function lcg(seed)
	local s = seed
	return function() s = s * 48271 % 2147483647 return s / 2147483647 end
end

local function startRun(charges)
	return Expedition.New(ExpCfg, charges or 4)
end

test("expedition: a new run starts on floor 1 with the given charges and nothing banked", function()
	local run = startRun(5)
	eq(run.Floor, 1, "floor")
	eq(run.Floors, ExpCfg.Floors, "floor count from config")
	eq(run.Charges, 5, "charges")
	eq(run.StartCharges, 5, "start charges remembered")
	eq(run.Haul, 0, "no haul")
	eq(#run.Relics, 0, "no relics")
	eq(run.Phase, "Blasting", "phase")
	eq(run.Cleared, 0, "nothing cleared")
end)

test("expedition: floors get harder with depth but never beyond the areas you have unlocked", function()
	eq(Expedition.FloorStratum(1, 4, ExpCfg), 1, "floor 1")
	eq(Expedition.FloorStratum(2, 4, ExpCfg), 1, "floor 2")
	eq(Expedition.FloorStratum(3, 4, ExpCfg), 2, "floor 3")
	eq(Expedition.FloorStratum(5, 4, ExpCfg), 3, "floor 5")
	eq(Expedition.FloorStratum(8, 4, ExpCfg), 4, "floor 8")
	eq(Expedition.FloorStratum(8, 2, ExpCfg), 2, "capped by unlocked areas")
	eq(Expedition.FloorStratum(8, 1, ExpCfg), 1, "an area-1 player stays in area 1")
	eq(Expedition.FloorStratum(1, 0, ExpCfg), 1, "never below 1")
	local last = 0
	for f = 1, ExpCfg.Floors do
		local s = Expedition.FloorStratum(f, 4, ExpCfg)
		eq(s >= last, true, "never gets easier as you descend")
		last = s
	end
end)

test("expedition: each descent offers three cards with all three routes and distinct, unowned relics", function()
	local run = startRun()
	local cards = Expedition.Choices(run, lcg(11), ExpCfg)
	eq(#cards, 3, "three cards")
	local routes, relics = {}, {}
	for _, c in cards do
		routes[c.Route] = (routes[c.Route] or 0) + 1
		if c.Relic then
			if relics[c.Relic] then error("relic offered twice: " .. c.Relic) end
			relics[c.Relic] = true
			if ExpCfg.Relics[c.Relic] == nil then error("unknown relic " .. c.Relic) end
		end
	end
	for name in ExpCfg.Routes do eq(routes[name], 1, "route " .. name .. " offered exactly once") end
	run.Relics = { "ResonantCore", "SteadyHands" }
	for seed = 1, 60 do
		for _, c in Expedition.Choices(run, lcg(seed), ExpCfg) do
			if c.Relic == "ResonantCore" or c.Relic == "SteadyHands" then error("an owned relic was offered again") end
		end
	end
	local a, b = Expedition.Choices(startRun(), lcg(5), ExpCfg), Expedition.Choices(startRun(), lcg(5), ExpCfg)
	for i = 1, 3 do
		eq(a[i].Route, b[i].Route, "deterministic route")
		eq(a[i].Relic, b[i].Relic, "deterministic relic")
	end
end)

test("expedition: when almost every relic is owned, cards simply carry fewer relics", function()
	local run = startRun()
	local all = {}
	for id in ExpCfg.Relics do table.insert(all, id) end
	table.sort(all)
	for i = 1, #all - 1 do table.insert(run.Relics, all[i]) end
	local cards = Expedition.Choices(run, lcg(3), ExpCfg)
	eq(#cards, 3, "still three cards")
	local withRelic = 0
	for _, c in cards do if c.Relic then withRelic += 1 end end
	eq(withRelic, 1, "only the one remaining relic is on offer")
end)

test("expedition: finishing a floor adds the haul, and collapse needs BOTH too little cleared AND no charges", function()
	local run = startRun()
	eq(Expedition.FloorEnded(run, 1000, 0.8, 2, lcg(1), ExpCfg), "Choose", "cleared enough with charges left")
	eq(run.Haul, 1000, "haul added")
	eq(run.Charges, 2, "leftover charges carry over")
	eq(run.Phase, "Choosing", "waiting for a choice")
	eq(#run.Choices, 3, "cards ready")
	eq(run.Cleared, 1, "one floor cleared")

	local weak = startRun()
	eq(Expedition.FloorEnded(weak, 400, 0.2, 3, lcg(1), ExpCfg), "Choose", "little cleared but charges remain: the run continues")
	local out = startRun()
	eq(Expedition.FloorEnded(out, 400, 0.2, 0, lcg(1), ExpCfg), "Collapse", "little cleared and no charges: collapse")
	eq(out.Phase, "Ended", "run over")
	local edge = startRun()
	eq(Expedition.FloorEnded(edge, 400, ExpCfg.ClearToAdvance, 0, lcg(1), ExpCfg), "Choose", "exactly the clear threshold survives")
	local justUnder = startRun()
	eq(Expedition.FloorEnded(justUnder, 400, ExpCfg.ClearToAdvance - 0.001, 0, lcg(1), ExpCfg), "Collapse", "just under collapses")
end)

test("expedition: the last floor ends in victory and a finished run cannot continue", function()
	local run = startRun()
	run.Floor = run.Floors
	eq(Expedition.FloorEnded(run, 500, 0.9, 1, lcg(1), ExpCfg), "Victory", "cleared the final floor")
	eq(run.Phase, "Ended", "over")
	eq(Expedition.Pick(run, 1, ExpCfg), false, "cannot pick after the run ended")
	local mid = startRun()
	mid.Phase = "Blasting"
	eq(Expedition.Pick(mid, 1, ExpCfg), false, "cannot pick while still blasting")
end)

test("expedition: picking a card applies its route and relic and descends", function()
	local function findCard(run, route) for i, c in run.Choices do if c.Route == route then return i end end end
	local run = startRun(4)
	Expedition.FloorEnded(run, 100, 0.9, 2, lcg(7), ExpCfg)
	for _, c in run.Choices do c.Room = "Mining" end -- isolate the route: rooms are tested separately
	local steady = findCard(run, "Steady")
	local relic = run.Choices[steady].Relic
	local extra = relic and ExpCfg.Relics[relic].Modifiers.ExtraCharges or 0 -- Deep Pockets adds a charge on top of the route
	eq(Expedition.Pick(run, steady, ExpCfg), true, "valid pick")
	eq(run.Floor, 2, "descended")
	eq(run.Phase, "Blasting", "blasting again")
	eq(run.Charges, 2 + ExpCfg.Routes.Steady.ChargeDelta + extra, "steady route gives its charge (plus any relic charge)")
	eq(run.ValueMult, ExpCfg.Routes.Steady.ValueMult, "route value multiplier")
	if relic then eq(run.Relics[#run.Relics], relic, "relic added") end
	eq(Expedition.Pick(run, 1, ExpCfg), false, "cannot pick twice")

	local rich = startRun(4)
	Expedition.FloorEnded(rich, 100, 0.9, 2, lcg(7), ExpCfg)
	for _, c in rich.Choices do c.Room = "Mining" end -- isolate the route: rooms are tested separately
	local richCard = findCard(rich, "Rich")
	local richRelic = rich.Choices[richCard].Relic
	local richExtra = richRelic and ExpCfg.Relics[richRelic].Modifiers.ExtraCharges or 0
	Expedition.Pick(rich, richCard, ExpCfg)
	eq(rich.ValueMult, ExpCfg.Routes.Rich.ValueMult, "rich vein doubles payouts")
	eq(rich.Charges, math.max(1, 2 + ExpCfg.Routes.Rich.ChargeDelta) + richExtra, "rich vein costs a charge (plus any relic charge)")

	local rest = startRun(4)
	Expedition.FloorEnded(rest, 100, 0.9, 1, lcg(7), ExpCfg)
	for _, c in rest.Choices do c.Room = "Mining" end -- isolate the route: rooms are tested separately
	Expedition.Pick(rest, findCard(rest, "Rest"), ExpCfg)
	eq(rest.Charges, rest.StartCharges, "rest stop refills to full")
end)

test("expedition: a route can never leave you with zero charges, and bad picks are refused", function()
	local run = startRun(4)
	Expedition.FloorEnded(run, 0, 0.9, 0, lcg(9), ExpCfg)
	for i, c in run.Choices do
		if c.Route == "Rich" then
			Expedition.Pick(run, i, ExpCfg)
			eq(run.Charges >= 1, true, "at least one charge always remains")
		end
	end
	local r2 = startRun(4)
	Expedition.FloorEnded(r2, 0, 0.9, 2, lcg(9), ExpCfg)
	for _, bad in { 0, 4, -1, 1.5, "1", true, 0 / 0 } do
		eq(Expedition.Pick(r2, bad, ExpCfg), false, "rejected " .. tostring(bad))
	end
	eq(Expedition.Pick(r2, nil, ExpCfg), false, "rejected nil")
	eq(r2.Floor, 1, "nothing changed after bad picks")
end)

test("expedition: relic modifiers combine correctly (multiply rates, add radii, any shield, add momentum)", function()
	local run = startRun()
	local none = Expedition.Modifiers(run, ExpCfg)
	eq(none.AmplifierMult, 1, "neutral amplifier")
	eq(none.ValueMult, 1, "neutral value")
	eq(none.VolatileRadiusBonus, 0, "neutral radius")
	eq(none.UnstableShield, false, "no shield")
	eq(none.MomentumPopsDelta, 0, "neutral momentum")
	eq(none.MutationChanceMult, 1, "neutral luck")
	run.Relics = { "ResonantCore", "SteadyHands", "WideBursts", "Prospector", "MomentumCharm", "LuckyPrisms" }
	run.ValueMult = 2 -- a rich vein this floor
	local m = Expedition.Modifiers(run, ExpCfg)
	eq(m.AmplifierMult, ExpCfg.Relics.ResonantCore.Modifiers.AmplifierMult, "amplifier")
	eq(m.UnstableShield, true, "shield")
	eq(m.VolatileRadiusBonus, ExpCfg.Relics.WideBursts.Modifiers.VolatileRadiusBonus, "radius")
	eq(math.abs(m.ValueMult - 2 * ExpCfg.Relics.Prospector.Modifiers.ValueMult) < 1e-9, true, "relic value multiplies with the route value")
	eq(m.MomentumPopsDelta, ExpCfg.Relics.MomentumCharm.Modifiers.MomentumPopsDelta, "momentum")
	eq(m.MutationChanceMult, ExpCfg.Relics.LuckyPrisms.Modifiers.MutationChanceMult, "luck")
end)

test("expedition: banking pays the haul with a depth bonus and a victory bonus; salvage is a fraction; nothing negative", function()
	local run = startRun()
	run.Haul, run.Cleared = 10000, 0
	eq(Expedition.Bank(run, ExpCfg, false), 10000, "no floors cleared: haul as is")
	run.Cleared = 4
	eq(Expedition.Bank(run, ExpCfg, false), math.floor(10000 * (1 + ExpCfg.DepthBonusPerFloor * 4) + 0.5), "depth bonus")
	eq(Expedition.Bank(run, ExpCfg, true), math.floor(10000 * (1 + ExpCfg.DepthBonusPerFloor * 4) * ExpCfg.VictoryBonus + 0.5), "victory bonus on top")
	eq(Expedition.Salvage(run, ExpCfg), math.floor(10000 * ExpCfg.SalvageFraction), "salvage")
	eq(Expedition.Salvage(run, ExpCfg) < Expedition.Bank(run, ExpCfg, false), true, "collapsing always pays less than banking")
	run.Haul = 0
	eq(Expedition.Bank(run, ExpCfg, true), 0, "nothing to bank")
	eq(Expedition.Salvage(run, ExpCfg), 0, "nothing to salvage")
end)

test("expedition: the client view carries what the HUD, the cards and the preview need", function()
	local run = startRun(4)
	Expedition.FloorEnded(run, 2500, 0.8, 3, lcg(2), ExpCfg)
	local v = Expedition.View(run, ExpCfg)
	eq(v.Floor, 1, "floor")
	eq(v.Floors, ExpCfg.Floors, "floors")
	eq(v.Haul, 2500, "haul")
	eq(v.Charges, 3, "charges")
	eq(v.Phase, "Choosing", "phase")
	eq(#v.Choices, 3, "cards")
	for _, c in v.Choices do
		eq(type(c.RouteName), "string", "route name")
		eq(type(c.RouteDescription), "string", "route description")
	end
	eq(v.BankNow, Expedition.Bank(run, ExpCfg, false), "what banking would pay right now")
	eq(type(v.Modifiers), "table", "modifiers for the preview")
end)

test("expedition: config is valid (routes, relics, rewards)", function()
	local KNOWN = { AmplifierMult = true, UnstableShield = true, VolatileRadiusBonus = true, RelayValueMult = true, ValueMult = true, MomentumPopsDelta = true, MutationChanceMult = true, ExtraCharges = true, HeartsBonus = true, DamageMult = true, LastStandMult = true, KillRefund = true, CriticalPopsDelta = true, HeartOnCritical = true, BountyMult = true, MonsterHPMult = true }
	eq(ExpCfg.Floors >= 4 and ExpCfg.Floors <= 12, true, "a run of sensible length")
	eq(ExpCfg.SalvageFraction > 0 and ExpCfg.SalvageFraction < 1, true, "salvage is a fraction")
	eq(ExpCfg.ClearToAdvance > 0 and ExpCfg.ClearToAdvance < 1, true, "clear threshold")
	eq(ExpCfg.VictoryBonus > 1, true, "victory pays extra")
	eq(ExpCfg.DepthBonusPerFloor > 0, true, "depth pays extra")
	local routes = 0
	for name, r in ExpCfg.Routes do
		routes += 1
		eq(type(r.Name) == "string" and type(r.Description) == "string", true, name .. " text")
		eq(r.ValueMult == nil or r.ValueMult > 0, true, name .. " value multiplier")
	end
	eq(routes, 3, "exactly three routes so every descent can offer each once")
	local relics = 0
	for id, relic in ExpCfg.Relics do
		relics += 1
		eq(type(relic.Name) == "string" and relic.Name ~= "" and type(relic.Description) == "string", true, id .. " text")
		local any = false
		for k, v in relic.Modifiers do
			any = true
			if not KNOWN[k] then error(id .. " has unknown modifier " .. k) end
			if type(v) ~= "boolean" and type(v) ~= "number" then error(id .. " modifier " .. k .. " must be a number or boolean") end
			if k == "ValueMult" and v > 2 then error(id .. " value multiplier is too generous") end
		end
		eq(any, true, id .. " does something")
	end
	eq(relics >= 6, true, "enough relics that runs differ")
end)

test("expedition: stacked relics of the same kind multiply (or add, for radii) instead of overwriting", function()
	local cfg = { Relics = {
		A = { Modifiers = { AmplifierMult = 2, ValueMult = 1.5, RelayValueMult = 2, MutationChanceMult = 3, VolatileRadiusBonus = 0.5, MomentumPopsDelta = -2 } },
		B = { Modifiers = { AmplifierMult = 3, ValueMult = 2, RelayValueMult = 5, MutationChanceMult = 2, VolatileRadiusBonus = 0.25, MomentumPopsDelta = -1 } },
	} }
	local run = Expedition.New(ExpCfg, 4)
	run.Relics = { "A", "B" }
	local m = Expedition.Modifiers(run, cfg)
	eq(m.AmplifierMult, 6, "2 x 3")
	eq(m.ValueMult, 3, "1.5 x 2")
	eq(m.RelayValueMult, 10, "2 x 5")
	eq(m.MutationChanceMult, 6, "3 x 2")
	eq(m.VolatileRadiusBonus, 0.75, "0.5 + 0.25")
	eq(m.MomentumPopsDelta, -3, "-2 + -1")
end)

test("schema: v6 saves migrate to v7 with expedition stats and keep every other stat", function()
	local d = Schema.Migrate({ SchemaVersion = 6, Shards = 5, Stats = { TotalPops = 99, BestChain = 21, SeamsCleared = 3, TotalShards = 700 } })
	eq(d.SchemaVersion, Schema.CURRENT_VERSION, "version")
	eq(Schema.CURRENT_VERSION >= 7, true, "v7 exists")
	eq(d.Stats.BestDepth, 0, "best depth defaults to 0")
	eq(d.Stats.ExpeditionsWon, 0, "wins default to 0")
	eq(d.Stats.TotalPops, 99, "existing stats kept")
	eq(d.Stats.BestChain, 21, "existing stats kept")
	eq(Schema.Default().Stats.BestDepth, 0, "new profiles start at 0")
end)

test("goals: expedition depth and wins are readable stats", function()
	local d = serverData()
	d.Stats.BestDepth, d.Stats.ExpeditionsWon = 6, 3
	eq(Achievements.Value(d, "BestDepth"), 6, "depth")
	eq(Achievements.Value(d, "ExpeditionsWon"), 3, "wins")
	local seenDepth, seenWins = false, false
	for _, def in AchCfg.Defs do
		if def.Stat == "BestDepth" then seenDepth = true end
		if def.Stat == "ExpeditionsWon" then seenWins = true end
	end
	eq(seenDepth and seenWins, true, "goals exist for both")
end)

local Puzzle = require("../../src/ReplicatedStorage/Shared/Puzzle")
local PuzzleCfg = require("../../src/ReplicatedStorage/Shared/Config/Puzzle")

test("puzzle: the seed depends only on the day, and differs between days", function()
	eq(Puzzle.Seed(20000), Puzzle.Seed(20000), "same day, same seed")
	eq(Puzzle.Seed(20000) ~= Puzzle.Seed(20001), true, "next day differs")
end)

test("puzzle: everyone gets the same grid for a day", function()
	local a = Seam.Generate(Crystals, Tuning, PuzzleCfg.Stratum, Puzzle.Seed(20000), PuzzleCfg.MutationChance)
	local b = Seam.Generate(Crystals, Tuning, PuzzleCfg.Stratum, Puzzle.Seed(20000), PuzzleCfg.MutationChance)
	for i = 1, N * N do
		local ca, cb = a.Cells[i], b.Cells[i]
		eq(ca and ca.Kind, cb and cb.Kind, "cell " .. i)
	end
end)

test("puzzle: par is what a greedy player scores, and three charges beat one", function()
	local g = grid(function(x, z) if x == 5 then return "Glimmerstone" end end)
	local par, picks = Puzzle.Par(g, ctx, 3, ChainSim.Run)
	eq(#picks, 3, "three charges chosen")
	local single = ChainSim.Run(g, { cap(5, 5) }, ctx).Total
	eq(par > single, true, "three charges beat one")
	eq(par, ChainSim.Run(g, picks, ctx).Total, "par equals the greedy volley's real score")
end)

test("puzzle: par never changes the grid", function()
	local g = grid(function(x, z) if (x + z) % 3 == 0 then return "Glimmerstone" end end)
	local before = 0
	for _ in g.Cells do before += 1 end
	Puzzle.Par(g, ctx, 3, ChainSim.Run)
	local after = 0
	for _ in g.Cells do after += 1 end
	eq(after, before, "cells untouched")
end)

test("puzzle: an empty grid has a par of zero and no medal", function()
	local par, picks = Puzzle.Par(grid(function() return nil end), ctx, 3, ChainSim.Run)
	eq(#picks, 0, "no pointless charges are chosen")
	eq(par, 0, "par")
	eq(Puzzle.Medal(0, par, PuzzleCfg), nil, "no medal for nothing")
end)

test("puzzle: medals follow the ratio to par at their exact boundaries", function()
	local m = PuzzleCfg.Medals
	for i, medal in m do
		local at = math.ceil(medal.Ratio * 1000)
		eq(Puzzle.Medal(at, 1000, PuzzleCfg), medal.Name, medal.Name .. " at its threshold")
		eq(Puzzle.Medal(at - 1, 1000, PuzzleCfg), i > 1 and m[i - 1].Name or nil, "just under " .. medal.Name)
	end
end)

test("puzzle: streak continues on consecutive days, holds within a day, resets after a gap", function()
	eq(Puzzle.Streak(0, 0, 100), 1, "first ever")
	eq(Puzzle.Streak(99, 4, 100), 5, "yesterday continues")
	eq(Puzzle.Streak(100, 5, 100), 5, "same day unchanged")
	eq(Puzzle.Streak(97, 9, 100), 1, "gap resets")
end)

test("puzzle: streak bonus grows per day and is capped", function()
	eq(Puzzle.Reward(1000, 1, PuzzleCfg), 1000, "no bonus on day one")
	local capped = Puzzle.Reward(1000, PuzzleCfg.MaxStreakDays, PuzzleCfg)
	eq(capped > Puzzle.Reward(1000, 2, PuzzleCfg), true, "grows")
	eq(Puzzle.Reward(1000, 500, PuzzleCfg), capped, "capped")
end)

test("puzzle: config medals ascend and rewards rise with them", function()
	for i = 2, #PuzzleCfg.Medals do
		eq(PuzzleCfg.Medals[i].Ratio > PuzzleCfg.Medals[i - 1].Ratio, true, "ratio ascends at " .. i)
		eq(PuzzleCfg.Medals[i].Reward > PuzzleCfg.Medals[i - 1].Reward, true, "reward ascends at " .. i)
	end
end)

test("puzzle: schema v8 adds a puzzle record and keeps old saves intact", function()
	local d = Schema.Migrate({ SchemaVersion = 7, Shards = 42 })
	eq(d.Shards, 42, "shards kept")
	eq(d.Puzzle.Day, 0, "day")
	eq(d.Puzzle.Streak, 0, "streak")
	eq(d.Puzzle.Medal, "", "medal")
	eq(Schema.CURRENT_VERSION >= 8, true, "version")
end)

local Farm = require("../../src/ReplicatedStorage/Shared/Farm")
local FarmCfg = require("../../src/ReplicatedStorage/Shared/Config/Farm")

test("farm: pending grows with time at the level's rate and is capped by storage hours", function()
	local rate = FarmCfg.Levels[1].PerHour
	eq(Farm.Pending({ Level = 1, LastCollect = 1000 }, 1000, FarmCfg), 0, "nothing at the same instant")
	eq(Farm.Pending({ Level = 1, LastCollect = 1000 }, 1000 + 1800, FarmCfg), math.floor(rate / 2), "half an hour")
	local full = Farm.Pending({ Level = 1, LastCollect = 0 }, FarmCfg.CapHours * 3600, FarmCfg)
	eq(full, rate * FarmCfg.CapHours, "a full store")
	eq(Farm.Pending({ Level = 1, LastCollect = 0 }, FarmCfg.CapHours * 3600 * 10, FarmCfg), full, "never more than the cap")
end)

test("farm: a clock that goes backwards or a corrupt record gives nothing", function()
	eq(Farm.Pending({ Level = 1, LastCollect = 5000 }, 4000, FarmCfg), 0, "clock went back")
	eq(Farm.Pending({ Level = 0, LastCollect = 0 }, 99999, FarmCfg), 0, "level zero")
	eq(Farm.Pending({ Level = 999, LastCollect = 0 }, 99999, FarmCfg), 0, "unknown level")
	eq(Farm.Pending({ Level = 1, LastCollect = 0 / 0 }, 99999, FarmCfg), 0, "NaN time")
end)

test("farm: collecting pays the pending amount and restarts the timer", function()
	local farm = { Level = 2, LastCollect = 0 }
	local amount = Farm.Collect(farm, 3600, FarmCfg)
	eq(amount, FarmCfg.Levels[2].PerHour, "one hour of level 2")
	eq(farm.LastCollect, 3600, "timer restarted")
	eq(Farm.Collect(farm, 3600, FarmCfg), 0, "nothing left right away")
end)

test("farm: upgrading pays out pending first at the OLD rate, then charges the cost", function()
	local farm = { Level = 1, LastCollect = 0 }
	local cost = FarmCfg.Levels[2].Cost
	local ok, paid = Farm.Upgrade(farm, 3600, cost, FarmCfg)
	eq(ok, true, "upgraded")
	eq(paid, FarmCfg.Levels[1].PerHour, "an hour at the old rate was collected")
	eq(farm.Level, 2, "level")
	eq(farm.LastCollect, 3600, "timer restarted")
end)

test("farm: upgrade is refused without the shards and at the top level, changing nothing", function()
	local farm = { Level = 1, LastCollect = 0 }
	local ok, why = Farm.Upgrade(farm, 3600, FarmCfg.Levels[2].Cost - 1, FarmCfg)
	eq(ok, false, "too poor")
	eq(farm.Level, 1, "level unchanged")
	eq(farm.LastCollect, 0, "timer unchanged")
	local top = { Level = #FarmCfg.Levels, LastCollect = 0 }
	eq((Farm.Upgrade(top, 3600, 1e12, FarmCfg)), false, "already max")
	eq(top.Level, #FarmCfg.Levels, "still max")
end)

test("farm: config levels get richer and dearer", function()
	for i = 2, #FarmCfg.Levels do
		eq(FarmCfg.Levels[i].PerHour > FarmCfg.Levels[i - 1].PerHour, true, "rate rises at " .. i)
		eq(FarmCfg.Levels[i].Cost > FarmCfg.Levels[i - 1].Cost, true, "cost rises at " .. i)
	end
end)

test("farm: schema v9 gives old saves a level-1 farm that starts now-ish", function()
	local d = Schema.Migrate({ SchemaVersion = 8, Shards = 7 })
	eq(d.Shards, 7, "shards kept")
	eq(d.Farm.Level, 1, "level")
	eq(d.Farm.LastCollect, 0, "no backpay: server stamps the time on load")
	eq(Schema.CURRENT_VERSION >= 9, true, "version")
end)

local Lurker = require("../../src/ReplicatedStorage/Shared/Lurker")
local LurkerCfg = require("../../src/ReplicatedStorage/Shared/Config/Lurkers")
local lctx = { Crystals = Crystals.Defs, Charges = Charges.Defs, Tuning = Tuning, BlastCells = ChainSim.BlastCells }
local function seqRng(...) local v, i = { ... }, 0 return function() i += 1 return v[(i - 1) % #v + 1] end end

test("lurker: spawn chance rises with area and expedition floor and is capped", function()
	local a = Lurker.SpawnChance(1, 0, LurkerCfg)
	eq(Lurker.SpawnChance(3, 0, LurkerCfg) > a, true, "deeper area")
	eq(Lurker.SpawnChance(1, 4, LurkerCfg) > a, true, "deeper floor")
	eq(Lurker.SpawnChance(4, 50, LurkerCfg), LurkerCfg.Spawn.Cap, "capped")
end)

test("lurker: a kind is only picked from monsters allowed in that area", function()
	for i = 1, 20 do
		local kind = Lurker.PickKind(1, i / 21, LurkerCfg)
		eq(LurkerCfg.Defs[kind].Stratum <= 1, true, "area-1 kinds only")
	end
	local seen = {}
	for i = 1, 30 do seen[Lurker.PickKind(4, i / 31, LurkerCfg)] = true end
	local n = 0 for _ in seen do n += 1 end
	eq(n, #LurkerCfg.Order, "every kind appears deep down")
end)

test("lurker: it hides under a valuable crystal, never under an empty cell or a hazard", function()
	local g = grid(function(x, z) if x == 3 and z == 4 then return "Glimmerstone" end if x == 6 and z == 6 then return "Dreadgeode" end end)
	for i = 1, 10 do
		local h = Lurker.Hide(g, lctx, "Gnasher", i / 11)
		eq(h.X == 3 and h.Z == 4, true, "the only valuable crystal")
	end
	eq(Lurker.Hide(grid(function() return nil end), lctx, "Gnasher", 0.5), nil, "nowhere to hide")
end)

test("lurker: it emerges exactly when its cell is popped", function()
	local h = { Kind = "Gnasher", X = 5, Z = 5 }
	local r = ChainSim.Run(grid(function(x, z) if x == 5 and z == 5 then return "Glimmerstone" end end), { cap(5, 5) }, ctx)
	eq(Lurker.Revealed(h, r.Events), true, "popped")
	local miss = ChainSim.Run(grid(function(x, z) if x == 2 and z == 2 then return "Glimmerstone" end end), { cap(2, 2) }, ctx)
	eq(Lurker.Revealed(h, miss.Events), false, "elsewhere")
	local m = Lurker.New("Gnasher", 5, 5, LurkerCfg)
	eq(m.HP, LurkerCfg.Defs.Gnasher.HP, "full health")
end)

test("lurker: a direct charge hit does the charge's damage; a miss does none", function()
	local m = Lurker.New("Gnasher", 5, 5, LurkerCfg)
	local none = { Events = {} }
	eq(Lurker.Damage(m, { cap(5, 5) }, none, lctx, LurkerCfg), LurkerCfg.Damage.Direct.Basic, "direct")
	eq(Lurker.Damage(m, { cap(9, 9) }, none, lctx, LurkerCfg), 0, "miss")
	eq(Lurker.Damage(m, { { X = 5, Z = 9, Kind = "Shaft" } }, none, lctx, LurkerCfg), LurkerCfg.Damage.Direct.Shaft, "a shaft reaches down the column")
end)

test("lurker: each charge counts separately and splash from adjacent pops is capped", function()
	local m = Lurker.New("Gnasher", 5, 5, LurkerCfg)
	local two = Lurker.Damage(m, { cap(5, 5), cap(5, 6) }, { Events = {} }, lctx, LurkerCfg)
	eq(two, LurkerCfg.Damage.Direct.Basic * 2, "two charges both cover it")
	local events = {}
	for i = 1, 8 do events[i] = { X = 4 + (i % 3), Z = 4 + (i % 2) } end -- all within 1 of (5,5) except none
	local splash = Lurker.Damage(m, {}, { Events = events }, lctx, LurkerCfg)
	eq(splash, LurkerCfg.Damage.Splash * LurkerCfg.Damage.SplashCap, "capped")
	eq(Lurker.Damage(m, {}, { Events = { { X = 9, Z = 9 } } }, lctx, LurkerCfg), 0, "far pops do nothing")
end)

test("lurker: armor cuts each direct hit (never below 1) and a weakness doubles it", function()
	local brute = Lurker.New("Brute", 5, 5, LurkerCfg)
	local def = LurkerCfg.Defs.Brute
	local basic = Lurker.Damage(brute, { cap(5, 5) }, { Events = {} }, lctx, LurkerCfg)
	eq(basic, math.max(1, LurkerCfg.Damage.Direct.Basic - def.Armor), "armor reduces")
	local cross = Lurker.Damage(brute, { { X = 5, Z = 5, Kind = "Cross" } }, { Events = {} }, lctx, LurkerCfg)
	eq(cross, math.max(1, LurkerCfg.Damage.Direct.Cross - def.Armor) * 2, "weak to Cross")
end)

test("lurker: Hit lowers health, reports death at zero, and never goes negative", function()
	local m = Lurker.New("Gnasher", 5, 5, LurkerCfg)
	eq(Lurker.Hit(m, 1), true, "alive")
	eq(m.HP, LurkerCfg.Defs.Gnasher.HP - 1, "hp")
	eq(Lurker.Hit(m, 999), false, "dead")
	eq(m.HP, 0, "floored")
end)

test("lurker: a Gnasher eats adjacent valuable crystals and only those", function()
	local g = grid(function(x, z)
		if x == 4 and z == 5 then return "Glimmerstone" end
		if x == 6 and z == 5 then return "Glimmerstone" end
		if x == 5 and z == 6 then return "Dreadgeode" end
		if x == 9 and z == 9 then return "Glimmerstone" end
	end)
	local m = Lurker.New("Gnasher", 5, 5, LurkerCfg)
	local act = Lurker.Act(m, g, lctx, LurkerCfg)
	eq(#act.Eaten, math.min(2, LurkerCfg.Defs.Gnasher.Params.PerTurn), "eats up to its appetite")
	eq(g.Cells[ChainSim.Key(N, 5, 6)] ~= nil, true, "hazards are left alone")
	eq(g.Cells[ChainSim.Key(N, 9, 9)] ~= nil, true, "far crystals untouched")
end)

test("lurker: with nothing adjacent a Gnasher steps toward the nearest crystal onto an empty cell", function()
	local g = grid(function(x, z) if x == 9 and z == 5 then return "Glimmerstone" end end)
	local m = Lurker.New("Gnasher", 5, 5, LurkerCfg)
	local act = Lurker.Act(m, g, lctx, LurkerCfg)
	eq(#act.Eaten, 0, "nothing to eat")
	eq(m.X, 6, "moved one step east")
	eq(m.Z, 5, "same row")
end)

test("lurker: a Sapper drains charges every turn; a Brute smashes the rig on its schedule and telegraphs it", function()
	local g = grid(function() return nil end)
	local sap = Lurker.New("Sapper", 5, 5, LurkerCfg)
	eq(Lurker.Act(sap, g, lctx, LurkerCfg).ChargesDrained, LurkerCfg.Defs.Sapper.Params.Amount, "drain")
	local brute = Lurker.New("Brute", 5, 5, LurkerCfg)
	local every = LurkerCfg.Defs.Brute.Params.EveryTurns
	local hits, warned = 0, false
	for turn = 1, every * 2 do
		if Lurker.Telegraph(brute, LurkerCfg) then warned = true end
		hits += Lurker.Act(brute, g, lctx, LurkerCfg).HeartsLost
	end
	eq(hits, 2, "one smash per cycle")
	eq(warned, true, "the smash is announced a turn ahead")
end)

test("lurker: the bounty is paid per monster kind and repairs cost a fraction of the seam's earnings", function()
	eq(Lurker.Bounty("Brute", LurkerCfg), LurkerCfg.Defs.Brute.Bounty, "bounty")
	eq(Lurker.RepairFee(1000, LurkerCfg), math.floor(1000 * LurkerCfg.Defeat.RepairFraction), "repair fee")
	eq(Lurker.RepairFee(0, LurkerCfg), 0, "nothing earned, nothing owed")
end)

test("lurker: config sanity (monsters get tougher, values positive)", function()
	eq(LurkerCfg.Hearts >= 2, true, "at least two hearts")
	for id, def in LurkerCfg.Defs do
		eq(def.HP > 0 and def.Bounty > 0, true, id .. " has health and a bounty")
		eq(LurkerCfg.Damage.Direct[def.Weak or "Basic"] ~= nil, true, id .. " weakness is a real charge")
	end
end)

test("lurker: splash only counts pops within one cell on BOTH axes", function()
	local m = Lurker.New("Gnasher", 5, 5, LurkerCfg)
	eq(Lurker.Damage(m, {}, { Events = { { X = 5, Z = 7 } } }, lctx, LurkerCfg), 0, "two cells away in z")
	eq(Lurker.Damage(m, {}, { Events = { { X = 7, Z = 5 } } }, lctx, LurkerCfg), 0, "two cells away in x")
	eq(Lurker.Damage(m, {}, { Events = { { X = 6, Z = 6 } } }, lctx, LurkerCfg), LurkerCfg.Damage.Splash, "diagonal neighbour")
end)

test("lurker: the smash warning shows exactly one turn before it lands", function()
	local brute = Lurker.New("Brute", 5, 5, LurkerCfg)
	local g = grid(function() return nil end)
	local every = LurkerCfg.Defs.Brute.Params.EveryTurns
	for turn = 1, every * 2 do
		local warned = Lurker.Telegraph(brute, LurkerCfg)
		local hit = Lurker.Act(brute, g, lctx, LurkerCfg).HeartsLost
		eq(warned, hit == 1, "warning matches the hit on turn " .. turn)
	end
end)

test("lurker: a Gnasher never eats more than its appetite, never eats hazards, never steps onto a crystal", function()
	local g = grid(function(x, z)
		if x == 5 and z == 4 then return "Dreadgeode" end -- scanned first
		if (x == 4 and z == 5) or (x == 6 and z == 5) or (x == 5 and z == 6) then return "Glimmerstone" end
	end)
	local m = Lurker.New("Gnasher", 5, 5, LurkerCfg)
	local act = Lurker.Act(m, g, lctx, LurkerCfg)
	eq(#act.Eaten, LurkerCfg.Defs.Gnasher.Params.PerTurn, "appetite respected")
	eq(g.Cells[ChainSim.Key(N, 5, 4)] ~= nil, true, "hazard survives")
	local blocked = grid(function(x, z)
		if x == 9 and z == 5 then return "Glimmerstone" end
		if x == 6 and z == 5 then return "Dreadgeode" end
	end)
	local m2 = Lurker.New("Gnasher", 5, 5, LurkerCfg)
	Lurker.Act(m2, blocked, lctx, LurkerCfg)
	eq(blocked.Cells[ChainSim.Key(N, m2.X, m2.Z)], nil, "it stands on an empty cell")
end)

test("lurker: a Gnasher heads for the NEAREST crystal, not the first one it finds", function()
	local g = grid(function(x, z)
		if x == 7 and z == 5 then return "Glimmerstone" end
		if x == 5 and z == 9 then return "Glimmerstone" end
	end)
	local m = Lurker.New("Gnasher", 5, 5, LurkerCfg)
	Lurker.Act(m, g, lctx, LurkerCfg)
	eq(m.X, 6, "east toward the near one")
	eq(m.Z, 5, "same row")
end)

test("schema: v9 saves migrate to v10 with a slain counter and keep every other stat", function()
	local d = Schema.Migrate({ SchemaVersion = 9, Stats = { TotalPops = 50, BestDepth = 4 } })
	eq(d.Stats.LurkersSlain, 0, "slain defaults to 0")
	eq(d.Stats.TotalPops, 50, "existing stat kept")
	eq(d.Stats.BestDepth, 4, "existing stat kept")
	eq(Schema.CURRENT_VERSION >= 10, true, "version")
	eq(Schema.Default().Stats.LurkersSlain, 0, "new profiles start at 0")
end)

local Power = require("../../src/ReplicatedStorage/Shared/Power")
local Boss = require("../../src/ReplicatedStorage/Shared/Boss")
local BossCfg = require("../../src/ReplicatedStorage/Shared/Config/Bosses")
local PowerCfg = BossCfg.Power
local TitanDef = BossCfg.Defs.Titan
local bctx = { Crystals = Crystals.Defs, Charges = Charges.Defs, Tuning = Tuning, BlastCells = ChainSim.BlastCells, Size = N }
local function lcg(seed) local s = seed return function() s = (s * 48271) % 2147483647 return s / 2147483647 end end
local function fullGrid() return grid(function() return "Glimmerstone" end) end
local function fakeResult(pops, events) return { Pops = pops, Events = events or {} } end

test("power: tiers pick the highest reached and give 1 below the first", function()
	eq((Power.Tier(PowerCfg.Tiers[1].Pops - 1, PowerCfg)), 1, "too small")
	for _, t in PowerCfg.Tiers do
		local mult, name = Power.Tier(t.Pops, PowerCfg)
		eq(mult, t.Damage, t.Name .. " multiplier at its threshold")
		eq(name, t.Name, t.Name .. " name")
	end
	eq((Power.Tier(9999, PowerCfg)), PowerCfg.Tiers[#PowerCfg.Tiers].Damage, "no higher than the top tier")
end)

test("power: tiers ascend in both size and damage, and Critical Mass starts at the config chain length", function()
	for i = 2, #PowerCfg.Tiers do
		eq(PowerCfg.Tiers[i].Pops > PowerCfg.Tiers[i - 1].Pops and PowerCfg.Tiers[i].Damage > PowerCfg.Tiers[i - 1].Damage, true, "ascending at " .. i)
	end
	eq(Power.StartsCritical(PowerCfg.CriticalPops, PowerCfg), true, "at the threshold")
	eq(Power.StartsCritical(PowerCfg.CriticalPops - 1, PowerCfg), false, "just under")
end)

test("power: Critical Mass boosts the next volleys, counts down, and a new huge chain refreshes it", function()
	local left, started = Power.Advance(0, PowerCfg.CriticalPops, PowerCfg)
	eq(left, PowerCfg.CriticalVolleys, "starts")
	eq(started, true, "reported as just started")
	eq(Power.Multiplier(3, left, PowerCfg), PowerCfg.CriticalDamage, "boosts a small chain while active")
	eq(Power.Multiplier(3, 0, PowerCfg), 1, "no boost when not active")
	local l1 = Power.Advance(left, 3, PowerCfg)
	eq(l1, PowerCfg.CriticalVolleys - 1, "counts down")
	local l0 = Power.Advance(1, 3, PowerCfg)
	eq(l0, 0, "runs out")
	eq(Power.Advance(0, 3, PowerCfg), 0, "never negative")
	local again, restarted = Power.Advance(1, PowerCfg.CriticalPops, PowerCfg)
	eq(again, PowerCfg.CriticalVolleys, "refreshed")
	eq(restarted, false, "but not announced as new")
	eq(Power.Multiplier(PowerCfg.CriticalPops, 1, PowerCfg), PowerCfg.Tiers[#PowerCfg.Tiers].Damage * PowerCfg.CriticalDamage, "tier and Critical multiply")
end)

test("boss: a new fight clears the 3x3 core and picks armor nodes on valuable crystals outside it", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(7))
	for dz = -1, 1 do for dx = -1, 1 do eq(g.Cells[ChainSim.Key(N, 5 + dx, 5 + dz)], nil, "core cell empty") end end
	eq(#b.Nodes, TitanDef.Nodes, "node count")
	eq(b.Phase, "Armor", "starts in armor")
	eq(b.HP, TitanDef.MaxHP, "full health")
	for _, n in b.Nodes do
		eq(g.Cells[ChainSim.Key(N, n.X, n.Z)] ~= nil, true, "node sits on a crystal")
	end
end)

test("boss: armor takes no damage; popping the last node breaks it, hurts a little and refunds a charge", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	local first = b.Nodes[1]
	local o = Boss.Apply(b, {}, fakeResult(20, { { X = first.X, Z = first.Z } }), bctx, BossCfg, 1, g, lcg(1))
	eq(o.NodesBroken, 1, "one node")
	eq(b.HP, TitanDef.MaxHP, "armor: no damage")
	eq(b.Phase, "Armor", "still armored")
	local events = {}
	for _, n in b.Nodes do table.insert(events, { X = n.X, Z = n.Z }) end
	local o2 = Boss.Apply(b, {}, fakeResult(3, events), bctx, BossCfg, 1, g, lcg(1))
	eq(b.Phase, "Attack", "armor broken")
	eq(b.HP, TitanDef.MaxHP - TitanDef.ArmorBreakDamage, "armor-break damage")
	eq(o2.PhaseChanged, true, "phase change reported")
	eq(o2.Refund, TitanDef.PhaseRefund, "refund")
end)

test("boss: in the attack phase a charge on the core, nearby pops and a long chain all add up, scaled by power", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes = "Attack", {}
	local events = { { X = 5, Z = 3 }, { X = 3, Z = 5 } } -- within 2 of the core
	local dmg = Boss.Apply(b, { cap(5, 5) }, fakeResult(8, events), bctx, BossCfg, 1, g, lcg(1)).Damage
	eq(dmg, TitanDef.Direct.Basic + 2 * TitanDef.Splash + 8 // TitanDef.PopsPerBonus, "direct + splash + chain bonus")
	local b2 = Boss.New("Titan", fullGrid(), bctx, BossCfg, lcg(3))
	b2.Phase, b2.Nodes = "Attack", {}
	local doubled = Boss.Apply(b2, { cap(5, 5) }, fakeResult(8, events), bctx, BossCfg, 2, g, lcg(1)).Damage
	eq(doubled, dmg * 2, "power doubles it")
	local b3 = Boss.New("Titan", fullGrid(), bctx, BossCfg, lcg(3))
	b3.Phase, b3.Nodes = "Attack", {}
	eq(Boss.Apply(b3, { cap(1, 1) }, fakeResult(0, {}), bctx, BossCfg, 1, g, lcg(1)).Damage, 0, "a miss does nothing")
end)

test("boss: splash is capped and a Cross charge reaches the core from a distance", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes = "Attack", {}
	local many = {}
	for i = 1, 20 do many[i] = { X = 4 + i % 3, Z = 4 } end
	eq(Boss.Apply(b, {}, fakeResult(0, many), bctx, BossCfg, 1, g, lcg(1)).Damage, TitanDef.SplashCap * TitanDef.Splash, "capped")
	local b2 = Boss.New("Titan", fullGrid(), bctx, BossCfg, lcg(3))
	b2.Phase, b2.Nodes = "Attack", {}
	eq(Boss.Apply(b2, { { X = 5, Z = 9, Kind = "Cross" } }, fakeResult(0, {}), bctx, BossCfg, 1, g, lcg(1)).Damage, TitanDef.Direct.Cross, "cross reaches the core column")
end)

test("boss: HP thresholds move it through weak, enrage and finisher, refunding a charge each time", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes = "Attack", {}
	b.HP = b.MaxHP
	local function setHP(fraction) b.HP = math.ceil(b.MaxHP * fraction) + 1 end
	setHP(TitanDef.AttackEnd)
	local o = Boss.Apply(b, { cap(5, 5) }, fakeResult(4, {}), bctx, BossCfg, 1, g, lcg(1))
	eq(b.Phase, "Weak", "into the weak-point phase")
	eq(o.Refund, TitanDef.PhaseRefund, "refund")
	eq(#b.Weak, TitanDef.Weak.Count, "weak points chosen")
	b.Phase = "Weak"
	b.Weak = { { X = 1, Z = 1 }, { X = 9, Z = 9 } }
	b.HP = math.floor(b.MaxHP * TitanDef.WeakEnd) + TitanDef.Weak.One -- lands exactly on the threshold
	Boss.Apply(b, {}, fakeResult(1, { { X = 1, Z = 1 } }), bctx, BossCfg, 1, g, lcg(1)) -- one weak point hit
	eq(b.Phase, "Enrage", "into enrage")
	eq(#b.Weak, 0, "weak points gone outside their phase")
	b.Phase = "Enrage"
	setHP(TitanDef.FinisherAt)
	Boss.Apply(b, { cap(5, 5) }, fakeResult(4, {}), bctx, BossCfg, 1, g, lcg(1))
	eq(b.Phase, "Finisher", "into the finisher")
end)

test("boss: in the weak-point phase hitting both points beats one, which beats none", function()
	local function fight(events, pops)
		local g = fullGrid()
		local b = Boss.New("Titan", g, bctx, BossCfg, lcg(11))
		b.Phase, b.Nodes = "Weak", {}
		b.Weak = { { X = 1, Z = 1 }, { X = 9, Z = 9 } }
		local o = Boss.Apply(b, {}, fakeResult(pops, events), bctx, BossCfg, 1, g, lcg(2))
		return o.Damage, o.WeakHit
	end
	local none, n0 = fight({}, 6)
	local one, n1 = fight({ { X = 1, Z = 1 } }, 6)
	local both, n2 = fight({ { X = 1, Z = 1 }, { X = 9, Z = 9 } }, 6)
	eq(n0 == 0 and n1 == 1 and n2 == 2, true, "weak hits counted")
	eq(none, 6 // TitanDef.Weak.PopsPerMiss, "a miss only gets chain damage")
	eq(one, TitanDef.Weak.One, "one point")
	eq(both, TitanDef.Weak.Both, "both points")
	eq(both > one and one > none, true, "ordering")
end)

test("boss: weak points are spread out, on crystals, and never inside the core", function()
	for seed = 1, 12 do
		local g = fullGrid()
		local b = Boss.New("Titan", g, bctx, BossCfg, lcg(seed))
		b.Phase, b.Nodes = "Attack", {}
		b.HP = math.floor(b.MaxHP * TitanDef.AttackEnd) + 1
		Boss.Apply(b, { cap(5, 5) }, fakeResult(4, {}), bctx, BossCfg, 1, g, lcg(seed + 50))
		eq(#b.Weak, 2, "two points")
		local a, c = b.Weak[1], b.Weak[2]
		eq(math.max(math.abs(a.X - c.X), math.abs(a.Z - c.Z)) >= TitanDef.Weak.MinDist, true, "spread apart")
		for _, w in b.Weak do
			eq(g.Cells[ChainSim.Key(N, w.X, w.Z)] ~= nil, true, "on a crystal")
			eq(math.abs(w.X - 5) <= 1 and math.abs(w.Z - 5) <= 1, false, "outside the core")
		end
	end
end)

test("boss: the finisher needs one big chain or Critical power; failing heals it and it stays a finisher", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes, b.HP = "Finisher", {}, 5
	local o = Boss.Apply(b, {}, fakeResult(TitanDef.Finisher.Pops - 1, {}), bctx, BossCfg, 1, g, lcg(1))
	eq(o.Killed, false, "too small")
	eq(b.Phase, "Finisher", "still a finisher")
	eq(b.HP, 5 + TitanDef.Finisher.HealOnFail, "healed a little")
	eq(b.FinisherTries, 1, "try counted")
	local o2 = Boss.Apply(b, {}, fakeResult(TitanDef.Finisher.Pops, {}), bctx, BossCfg, 1, g, lcg(1))
	eq(o2.Killed, true, "a big chain ends it")
	eq(b.Phase, "Dead", "dead")
	local b2 = Boss.New("Titan", fullGrid(), bctx, BossCfg, lcg(3))
	b2.Phase, b2.Nodes, b2.HP = "Finisher", {}, 5
	eq(Boss.Apply(b2, {}, fakeResult(2, {}), bctx, BossCfg, 2, fullGrid(), lcg(1)).Killed, true, "Critical Mass power also finishes it")
end)

local function markAttack(b, g, seed)
	local turns = 0
	repeat
		local o = Boss.Act(b, g, bctx, BossCfg, false, lcg(seed + turns))
		turns += 1
		if o.HeartsLost > 0 then error("an attack landed before one was marked") end
	until #b.Telegraph > 0 or turns > 6
	return turns
end

test("boss: an attack is telegraphed a turn ahead, then lands: it wrecks crystals on the line and costs a heart", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes = "Attack", {}
	local turns = markAttack(b, g, 21)
	eq(turns, TitanDef.AttackEvery, "the attack phase marks a line every AttackEvery turns")
	eq(#b.Telegraph, N, "one full line is marked")
	local marked = {}
	for _, c in b.Telegraph do marked[#marked + 1] = { X = c.X, Z = c.Z } end
	local o = Boss.Act(b, g, bctx, BossCfg, false, lcg(99))
	eq(o.HeartsLost, 1, "the marked line hits")
	eq(#o.Hit, N, "the whole line")
	for _, c in marked do eq(g.Cells[ChainSim.Key(N, c.X, c.Z)], nil, "line crystals destroyed") end
end)

test("boss: a dodge cancels the heart loss, still wrecks the line, and goes on cooldown", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes = "Attack", {}
	markAttack(b, g, 21)
	eq(Boss.CanDodge(b), true, "ready while an attack is marked")
	local o = Boss.Act(b, g, bctx, BossCfg, true, lcg(22))
	eq(o.Dodged, true, "dodged")
	eq(o.HeartsLost, 0, "no heart lost")
	eq(#o.Eaten > 0, true, "the line is still wrecked")
	eq(b.DodgeCooldown, TitanDef.Dodge.Cooldown, "cooldown starts")
	eq(Boss.CanDodge(b), false, "not ready")
	for i = 1, TitanDef.Dodge.Cooldown do Boss.Act(b, g, bctx, BossCfg, false, lcg(30 + i)) end
	eq(b.DodgeCooldown, 0, "cooldown runs down")
end)

test("boss: popping enough crystals on the marked line cuts the attack: no damage, nothing wrecked, no dodge spent", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes = "Attack", {}
	markAttack(b, g, 21)
	local events = {}
	for i = 1, TitanDef.CutPops do events[i] = { X = b.Telegraph[i].X, Z = b.Telegraph[i].Z } end
	eq(Boss.Cut(b, { Events = events }, BossCfg), true, "enough pops on the line")
	local fewer = {}
	for i = 1, TitanDef.CutPops - 1 do fewer[i] = events[i] end
	eq(Boss.Cut(b, { Events = fewer }, BossCfg), false, "one short")
	local off = {}
	for z = 1, N do
		for x = 1, N do
			local onLine = false
			for _, c in b.Telegraph do if c.X == x and c.Z == z then onLine = true end end
			if not onLine and #off < TitanDef.CutPops + 2 then off[#off + 1] = { X = x, Z = z } end
		end
	end
	eq(Boss.Cut(b, { Events = off }, BossCfg), false, "pops off the line (even in its row or column neighbours) do not count")
	local o = Boss.Act(b, g, bctx, BossCfg, true, lcg(50), true)
	eq(o.Cut, true, "cut")
	eq(o.HeartsLost, 0, "no damage")
	eq(#o.Eaten, 0, "nothing wrecked")
	eq(b.DodgeCooldown, 0, "the dodge was not spent")
	local quiet = Boss.New("Titan", fullGrid(), bctx, BossCfg, lcg(3))
	eq(Boss.Cut(quiet, { Events = events }, BossCfg), false, "nothing marked, nothing to cut")
end)

test("boss: armor phase does not attack; enrage marks two lines", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	Boss.Act(b, g, bctx, BossCfg, false, lcg(5))
	eq(#b.Telegraph, 0, "armor: quiet")
	b.Phase = "Enrage"
	local found = false
	for seed = 1, 20 do
		Boss.Act(b, g, bctx, BossCfg, false, lcg(seed))
		if #b.Telegraph == N * 2 then found = true end
		if #b.Telegraph ~= N * 2 and #b.Telegraph ~= N then error("unexpected telegraph size " .. #b.Telegraph) end
	end
	eq(found, true, "two distinct lines appear")
end)

test("boss: the client view carries what the HUD needs and nothing mutable is shared badly", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	local v = Boss.View(b, BossCfg)
	eq(v.Name, TitanDef.Name, "name")
	eq(v.HP, TitanDef.MaxHP, "hp")
	eq(v.Phase, "Armor", "phase")
	eq(#v.Nodes, TitanDef.Nodes, "nodes shown")
	eq(v.Core.X, 5, "core")
end)

test("boss: config sanity (phase thresholds descend, floors name real bosses)", function()
	eq(TitanDef.AttackEnd > TitanDef.WeakEnd and TitanDef.WeakEnd > TitanDef.FinisherAt and TitanDef.FinisherAt > 0, true, "thresholds descend")
	for floor, kind in BossCfg.BossFloors do eq(BossCfg.Defs[kind] ~= nil and floor >= 1, true, "boss floor " .. floor) end
	eq(BossCfg.BossFloors[4], "Titan", "the first boss arrives on floor 4")
end)

test("boss: phase boundaries are inclusive (exactly on the threshold counts as crossing it)", function()
	local function land(fromPhase, startHP, hitCell)
		local g = fullGrid()
		local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
		b.Phase, b.Nodes, b.HP = fromPhase, {}, startHP
		if fromPhase == "Weak" then b.Weak = { { X = 1, Z = 1 }, { X = 9, Z = 9 } } end
		-- Attack/Enrage: a charge on the core with 4 pops does Direct.Basic + 4 // PopsPerBonus damage
		Boss.Apply(b, { cap(5, 5) }, fakeResult(4, hitCell and { { X = 1, Z = 1 } } or {}), bctx, BossCfg, 1, g, lcg(1))
		return b
	end
	local hit = TitanDef.Direct.Basic + 4 // TitanDef.PopsPerBonus
	eq(land("Attack", math.floor(TitanDef.MaxHP * TitanDef.AttackEnd) + hit, false).Phase, "Weak", "exactly at the attack threshold")
	eq(land("Attack", math.floor(TitanDef.MaxHP * TitanDef.AttackEnd) + hit + 1, false).Phase, "Attack", "one HP above stays")
	eq(land("Enrage", math.floor(TitanDef.MaxHP * TitanDef.FinisherAt) + hit, false).Phase, "Finisher", "exactly at the finisher threshold")
	eq(land("Weak", math.floor(TitanDef.MaxHP * TitanDef.WeakEnd) + TitanDef.Weak.One, true).Phase, "Enrage", "exactly at the weak threshold")
end)

test("boss: breaking armor never kills, even with enormous power", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	local events = {}
	for _, n in b.Nodes do table.insert(events, { X = n.X, Z = n.Z }) end
	local o = Boss.Apply(b, {}, fakeResult(3, events), bctx, BossCfg, 1000, g, lcg(1))
	eq(o.Killed, false, "not killed by the armor break")
	eq(b.HP >= 1, true, "at least 1 HP")
	eq(b.Phase, "Attack", "phase")
end)

test("boss: a failed finisher stays a finisher even when the heal lifts it above the threshold", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes = "Finisher", {}
	b.HP = math.floor(TitanDef.MaxHP * TitanDef.FinisherAt) -- right at the edge
	Boss.Apply(b, {}, fakeResult(1, {}), bctx, BossCfg, 1, g, lcg(1))
	eq(b.HP > TitanDef.MaxHP * TitanDef.FinisherAt, true, "healed above the finisher line")
	eq(b.Phase, "Finisher", "still the finisher")
end)

test("boss: the weak-point phase only attacks on even turns", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes = "Weak", {}
	Boss.Act(b, g, bctx, BossCfg, false, lcg(4))
	eq(#b.Telegraph, 0, "turn 1: quiet")
	Boss.Act(b, g, bctx, BossCfg, false, lcg(5))
	eq(#b.Telegraph, N, "turn 2: a line is marked")
end)

test("boss: enrage never marks the same line twice, and dodge is only offered while an attack is marked", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes = "Enrage", {}
	Boss.Act(b, g, bctx, BossCfg, false, function() return 0.3 end) -- both rolls pick the same line
	eq(#b.Telegraph, N, "one line, not two copies of it")
	local q = Boss.New("Titan", fullGrid(), bctx, BossCfg, lcg(3))
	Boss.Act(q, fullGrid(), bctx, BossCfg, false, lcg(1))
	eq(Boss.CanDodge(q), false, "nothing marked, nothing to dodge")
end)

test("boss: weak points avoid a crystal-filled core and still appear when crystals are few and close together", function()
	local g = fullGrid() -- core NOT cleared here
	local b = Boss.New("Titan", fullGrid(), bctx, BossCfg, lcg(3))
	b.Phase, b.Nodes = "Attack", {}
	b.HP = math.floor(b.MaxHP * TitanDef.AttackEnd) + 1
	for seed = 1, 40 do
		b.Phase, b.HP = "Attack", math.floor(b.MaxHP * TitanDef.AttackEnd) + 1
		Boss.Apply(b, { cap(5, 5) }, fakeResult(4, {}), bctx, BossCfg, 1, g, lcg(seed))
		for _, w in b.Weak do eq(math.abs(w.X - 5) <= 1 and math.abs(w.Z - 5) <= 1, false, "never in the core") end
	end
	local sparse = grid(function(x, z) if z == 1 and (x == 1 or x == 2) then return "Glimmerstone" end end)
	local b2 = Boss.New("Titan", sparse, bctx, BossCfg, lcg(3))
	b2.Phase, b2.Nodes = "Attack", {}
	b2.HP = math.floor(b2.MaxHP * TitanDef.AttackEnd) + 1
	Boss.Apply(b2, { cap(5, 5) }, fakeResult(4, {}), bctx, BossCfg, 1, sparse, lcg(9))
	eq(#b2.Weak, 2, "both points found even though they are adjacent")
end)

test("schema: v10 saves migrate to v11 with a bosses counter and keep every other stat", function()
	local d = Schema.Migrate({ SchemaVersion = 10, Stats = { LurkersSlain = 7, TotalPops = 20 } })
	eq(d.Stats.BossesSlain, 0, "defaults to 0")
	eq(d.Stats.LurkersSlain, 7, "existing stat kept")
	eq(d.Stats.TotalPops, 20, "existing stat kept")
	eq(Schema.CURRENT_VERSION >= 11, true, "version")
end)

local BossFloorsCfg = require("../../src/ReplicatedStorage/Shared/Config/Bosses").BossFloors

test("expedition rooms: the boss floors in the expedition config match the boss config exactly", function()
	for f in ExpCfg.BossFloors do eq(BossFloorsCfg[f] ~= nil, true, "floor " .. f .. " is a boss floor in both") end
	for f in BossFloorsCfg do eq(ExpCfg.BossFloors[f], true, "floor " .. f .. " listed in the expedition config") end
	for f in ExpCfg.BossFloors do eq(f <= ExpCfg.Floors, true, "boss floor inside the run") end
end)

test("expedition rooms: every card shows a room; the descent before a boss offers only the boss", function()
	local run = startRun()
	run.Floor = 3 -- next floor is 4, a boss floor
	for _, c in Expedition.Choices(run, lcg(5), ExpCfg) do eq(c.Room, "Boss", "boss room") end
	run.Floor = 1
	for seed = 1, 30 do
		for _, c in Expedition.Choices(run, lcg(seed), ExpCfg) do
			eq(ExpCfg.Rooms[c.Room] ~= nil, true, "a real room: " .. tostring(c.Room))
		end
	end
end)

test("expedition rooms: rooms respect their first floor, and three different kinds are offered when enough exist", function()
	local run = startRun()
	run.Floor = 1 -- next floor 2: only rooms with MinFloor <= 2
	for seed = 1, 60 do
		for _, c in Expedition.Choices(run, lcg(seed), ExpCfg) do
			eq(ExpCfg.Rooms[c.Room].MinFloor <= 2, true, c.Room .. " is not available on floor 2")
		end
	end
	run.Floor = 5 -- next floor 6: everything is available
	for seed = 1, 60 do
		local seen, n = {}, 0
		for _, c in Expedition.Choices(run, lcg(seed), ExpCfg) do
			if not seen[c.Room] then seen[c.Room] = true n += 1 end
		end
		eq(n, 3, "three distinct rooms")
	end
end)

test("expedition rooms: heavier rooms show up more often", function()
	local run = startRun()
	run.Floor = 5
	local counts = {}
	for seed = 1, 400 do
		for _, c in Expedition.Choices(run, lcg(seed * 13), ExpCfg) do counts[c.Room] = (counts[c.Room] or 0) + 1 end
	end
	eq(counts.Mining > (counts.Chaos or 0) * 2, true, "Mining (weight 4) is far commoner than Chaos (weight 1)")
	eq((counts.Chaos or 0) > 0, true, "but Chaos does appear")
	eq(counts.Mining > counts.Treasure and counts.Treasure > counts.Chaos, true, "the ordering follows the weights (4 > 2 > 1)")
end)

test("expedition rooms: picking a Treasure Vault multiplies payouts and rare-crystal odds for that floor only", function()
	local run = startRun()
	Expedition.FloorEnded(run, 100, 0.9, 3, lcg(2), ExpCfg)
	run.Choices = { { Route = "Steady", Room = "Treasure" } }
	eq(Expedition.Pick(run, 1, ExpCfg), true, "picked")
	eq(run.Room, "Treasure", "room recorded")
	eq(run.ValueMult, 1 * ExpCfg.Rooms.Treasure.ValueMult, "value multiplier from the room")
	local m = Expedition.Modifiers(run, ExpCfg)
	eq(m.MutationChanceMult, ExpCfg.Rooms.Treasure.MutationMult, "rare crystals likelier")
	local fx = Expedition.RoomEffects(run, ExpCfg)
	eq(fx.NoLurker, true, "nothing hides in a vault")
	Expedition.FloorEnded(run, 100, 0.9, 3, lcg(2), ExpCfg)
	run.Choices = { { Route = "Steady", Room = "Mining" } }
	Expedition.Pick(run, 1, ExpCfg)
	eq(run.ValueMult, 1, "the bonus does not carry to the next floor")
	eq(Expedition.Modifiers(run, ExpCfg).MutationChanceMult, 1, "neither does the luck")
end)

test("expedition rooms: combat and elite rooms wake a Lurker; elite scales it and promises a relic", function()
	local run = startRun()
	Expedition.FloorEnded(run, 0, 0.9, 3, lcg(2), ExpCfg)
	run.Choices = { { Route = "Steady", Room = "Combat" } }
	Expedition.Pick(run, 1, ExpCfg)
	local c = Expedition.RoomEffects(run, ExpCfg)
	eq(c.Awake, true, "awake")
	eq(c.RelicReward, false, "no relic for a normal nest")
	Expedition.FloorEnded(run, 0, 0.9, 3, lcg(2), ExpCfg)
	run.Choices = { { Route = "Steady", Room = "Elite" } }
	Expedition.Pick(run, 1, ExpCfg)
	local e = Expedition.RoomEffects(run, ExpCfg)
	eq(e.Awake, true, "awake")
	eq(e.HPMult, ExpCfg.Rooms.Elite.HPMult, "tougher")
	eq(e.BountyMult, ExpCfg.Rooms.Elite.BountyMult, "richer")
	eq(e.RelicReward, true, "relic reward")
	eq(Expedition.RoomEffects(startRun(), ExpCfg).Awake, false, "a fresh mining floor has no awake Lurker")
end)

test("expedition rooms: a Chaos Rift rolls one event by the rng, applies it, and forgets it on the next floor", function()
	local ids = {}
	for id in ExpCfg.ChaosEvents do ids[#ids + 1] = id end
	table.sort(ids)
	for i, id in ids do
		local run = startRun(5)
		Expedition.FloorEnded(run, 0, 0.9, 5, lcg(2), ExpCfg)
		run.Choices = { { Route = "Steady", Room = "Chaos" } }
		Expedition.Pick(run, 1, ExpCfg, function() return (i - 0.5) / #ids end)
		eq(run.Chaos, id, "the rng picks event " .. id)
		local ev = ExpCfg.ChaosEvents[id]
		eq(run.ValueMult, (ev.ValueMult or 1), "event value multiplier")
		eq(run.MutationMult, ev.MutationMult or 1, "event luck")
		eq(run.Charges, math.max(1, 5 + 1 + (ev.ChargeDelta or 0)), "event charge change on top of the route's +1")
		eq(Expedition.RoomEffects(run, ExpCfg).Awake, ev.Lurker == true, "event Lurker flag")
		eq(Expedition.RoomEffects(run, ExpCfg).BountyMult, ev.BountyMult or 1, "event bounty")
		eq(type(Expedition.View(run, ExpCfg).Chaos), "string", "the HUD gets its name")
	end
	local run = startRun(5)
	Expedition.FloorEnded(run, 0, 0.9, 5, lcg(2), ExpCfg)
	run.Choices = { { Route = "Steady", Room = "Chaos" } }
	Expedition.Pick(run, 1, ExpCfg, lcg(9))
	Expedition.FloorEnded(run, 0, 0.9, 5, lcg(2), ExpCfg)
	run.Choices = { { Route = "Steady", Room = "Mining" } }
	Expedition.Pick(run, 1, ExpCfg)
	eq(run.Chaos, nil, "the event is gone")
end)

test("expedition rooms: chaos never leaves fewer than one charge", function()
	local run = startRun(1)
	Expedition.FloorEnded(run, 0, 0.9, 1, lcg(2), ExpCfg)
	run.Choices = { { Route = "Rich", Room = "Chaos" } } -- Rich is -1, Frenzy is -2
	Expedition.Pick(run, 1, ExpCfg, -- 0.5 selects Frenzy (-2 charges)
		 function() return 0.5 end)
	eq(run.Charges, 1, "clamped to one charge, not negative")
end)

test("expedition relics: taking one adds its one-off effects; an Elite reward gives an unowned one and stops when all are owned", function()
	local run = startRun(4)
	run.Hearts = 3
	Expedition.AddRelic(run, "DeepPockets", ExpCfg)
	eq(run.Charges, 5, "extra charge now")
	eq(run.StartCharges, 5, "and kept")
	Expedition.AddRelic(run, "IronRig", ExpCfg)
	eq(run.Hearts, 4, "extra heart now")
	eq(Expedition.HeartsBonus(run, ExpCfg), 1, "and remembered as a bonus")
	local got = Expedition.GrantRelic(run, lcg(4), ExpCfg)
	eq(got ~= "DeepPockets" and got ~= "IronRig" and ExpCfg.Relics[got] ~= nil, true, "a new relic")
	eq(#run.Relics, 3, "owned")
	local n = 0
	for id in ExpCfg.Relics do n += 1 end
	for _ = 1, n do Expedition.GrantRelic(run, lcg(4), ExpCfg) end
	eq(#run.Relics, n, "every relic owned once, no duplicates")
	eq(Expedition.GrantRelic(run, lcg(4), ExpCfg), nil, "nothing left to give")
end)

test("expedition relics: the combat relics combine (damage multiplies, last stand takes the best, refunds and bounties add up)", function()
	local run = startRun()
	run.Relics = { "ShockwaveCore", "LastStand", "SecondWind", "FocusedLens", "BountyHunter", "VampiricSparks" }
	local m = Expedition.Modifiers(run, ExpCfg)
	eq(m.DamageMult, ExpCfg.Relics.ShockwaveCore.Modifiers.DamageMult, "damage")
	eq(m.LastStandMult, ExpCfg.Relics.LastStand.Modifiers.LastStandMult, "last stand")
	eq(m.KillRefund, 1, "refund")
	eq(m.CriticalPopsDelta, -4, "critical sooner")
	eq(m.BountyMult, 2, "bounty")
	eq(m.MonsterHPMult, 1.25, "the trade-off")
	eq(m.HeartOnCritical, 1, "heal on critical")
	run.Relics = { "ShockwaveCore", "ShockwaveCore" }
	eq(math.abs(Expedition.Modifiers(run, ExpCfg).DamageMult - 1.3 * 1.3) < 1e-9, true, "stacked damage multiplies")
	eq(Expedition.Modifiers(startRun(), ExpCfg).DamageMult, 1, "no relics, no bonus")
end)

test("expedition relics: every relic belongs to a known family and families are all represented", function()
	local families = {}
	for id, r in ExpCfg.Relics do families[r.Family] = true end
	for _, f in { "Echo", "Explosion", "Combo", "Risk" } do eq(families[f], true, "family " .. f) end
	for id, r in ExpCfg.Relics do eq(type(r.Family) == "string" and r.Family ~= "", true, id .. " has a family") end
end)

test("expedition rooms: config sanity (weights, first floors, at least one always-available room, chaos events valid)", function()
	local any = false
	for id, r in ExpCfg.Rooms do
		eq(r.Weight > 0 and r.MinFloor >= 1, true, id .. " weight and floor")
		if r.MinFloor == 1 then any = true end
		eq(type(r.Name) == "string" and type(r.Description) == "string", true, id .. " text")
	end
	eq(any, true, "some room can appear on floor 2")
	local avail2 = 0
	for _, r in ExpCfg.Rooms do if r.MinFloor <= 2 then avail2 += 1 end end
	eq(avail2 >= 3, true, "three kinds are available from floor 2, so the first choice is real")
	for id, e in ExpCfg.ChaosEvents do
		eq(type(e.Name) == "string" and type(e.Description) == "string", true, id .. " text")
		eq(e.ValueMult == nil or e.ValueMult > 0, true, id .. " value")
	end
end)

test("power: a relic can lower the Critical Mass threshold, never below one pop", function()
	eq(Power.StartsCritical(PowerCfg.CriticalPops - 4, PowerCfg, -4), true, "sooner with the lens")
	eq(Power.StartsCritical(PowerCfg.CriticalPops - 5, PowerCfg, -4), false, "but not sooner than that")
	eq(Power.StartsCritical(0, PowerCfg, -999), false, "a chain of nothing is never critical")
	eq(Power.StartsCritical(1, PowerCfg, -999), true, "one pop is the floor")
	local left, started = Power.Advance(0, PowerCfg.CriticalPops - 2, PowerCfg, -2)
	eq(left, PowerCfg.CriticalVolleys, "advance honours the shift")
	eq(started, true, "and reports it")
end)

test("lurker: a Skitter runs two cells a turn, eats on arrival, and is fragile", function()
	local g = grid(function(x, z) if x == 8 and z == 5 then return "Glimmerstone" end end)
	local m = Lurker.New("Skitter", 4, 5, LurkerCfg)
	local a = Lurker.Act(m, g, lctx, LurkerCfg)
	eq(m.X, 6, "two steps east")
	eq(#a.Eaten, 0, "not there yet")
	local b = Lurker.Act(m, g, lctx, LurkerCfg)
	eq(#b.Eaten, 1, "arrives next to it and eats within the same turn")
	eq(m.X, 7, "one step then the meal")
	eq(g.Cells[ChainSim.Key(N, 8, 5)], nil, "the crystal is gone")
	local far = Lurker.New("Skitter", 1, 1, LurkerCfg)
	local gg = grid(function(x, z) if x == 9 and z == 9 then return "Glimmerstone" end end)
	Lurker.Act(far, gg, lctx, LurkerCfg)
	eq(far.X == 3 and far.Z == 3, true, "diagonal dash of two cells")
	eq(LurkerCfg.Defs.Skitter.HP < LurkerCfg.Defs.Gnasher.HP, true, "fragile")
	eq(LurkerCfg.Defs.Skitter.Stratum, 1, "appears in the first area")
end)

test("lurker: a Skitter with nothing to run to stays put, and never eats more than its appetite in one turn", function()
	local empty = grid(function() return nil end)
	local m = Lurker.New("Skitter", 5, 5, LurkerCfg)
	local a = Lurker.Act(m, empty, lctx, LurkerCfg)
	eq(m.X == 5 and m.Z == 5 and #a.Eaten == 0 and a.Moved == false, true, "idle")
	local crowd = grid(function(x, z) if math.abs(x - 5) <= 1 and math.abs(z - 5) <= 1 and not (x == 5 and z == 5) then return "Glimmerstone" end end)
	local b = Lurker.Act(Lurker.New("Skitter", 5, 5, LurkerCfg), crowd, lctx, LurkerCfg)
	eq(#b.Eaten, LurkerCfg.Defs.Skitter.Params.PerTurn, "one crystal per turn")
end)

test("lurker: a Leech steals a fixed share of the payout every turn and does nothing else", function()
	local g = grid(function(x, z) if x == 6 and z == 5 then return "Glimmerstone" end end)
	local m = Lurker.New("Leech", 5, 5, LurkerCfg)
	local a = Lurker.Act(m, g, lctx, LurkerCfg)
	eq(a.Stolen, LurkerCfg.Defs.Leech.Params.Fraction, "steals its share")
	eq(#a.Eaten == 0 and a.ChargesDrained == 0 and a.HeartsLost == 0 and a.Moved == false, true, "nothing else")
	eq(g.Cells[ChainSim.Key(N, 6, 5)] ~= nil, true, "leaves the crystals alone")
	eq(Lurker.Act(Lurker.New("Gnasher", 5, 5, LurkerCfg), g, lctx, LurkerCfg).Stolen, 0, "other kinds steal nothing")
	eq(LurkerCfg.Defs.Leech.Params.Fraction > 0 and LurkerCfg.Defs.Leech.Params.Fraction < 1, true, "a fraction")
end)

test("lurker: a Skitter stops after eating, and one boxed in by hazards simply stays where it is", function()
	local g = grid(function(x, z)
		if x == 6 and z == 5 then return "Glimmerstone" end
		if x == 9 and z == 9 then return "Glimmerstone" end
	end)
	local m = Lurker.New("Skitter", 5, 5, LurkerCfg)
	local a = Lurker.Act(m, g, lctx, LurkerCfg)
	eq(#a.Eaten, 1, "ate the neighbour")
	eq(m.X == 5 and m.Z == 5 and a.Moved == false, true, "and did not keep running")
	local boxed = grid(function(x, z)
		if math.abs(x - 5) <= 1 and math.abs(z - 5) <= 1 and not (x == 5 and z == 5) then return "Dreadgeode" end
		if x == 9 and z == 9 then return "Glimmerstone" end
	end)
	local b = Lurker.New("Skitter", 5, 5, LurkerCfg)
	local act = Lurker.Act(b, boxed, lctx, LurkerCfg)
	eq(b.X == 5 and b.Z == 5 and act.Moved == false, true, "nowhere to step")
end)

local Mastery = require("../../src/ReplicatedStorage/Shared/Mastery")
local MasteryCfg = require("../../src/ReplicatedStorage/Shared/Config/Mastery")
local function fresh() return { Done = {}, Title = "" } end
local function perfect() return { HeartsLost = 0, Volleys = 6, FinalPops = 25, HeartsLeft = 3 } end
local function ids(list) local out = {} for _, o in list do out[#out + 1] = o.Id end return table.concat(out, ",") end

test("mastery: a flawless, fast, big-finish fight completes those three but not Iron Will", function()
	local got = Mastery.Evaluate("Titan", perfect(), {}, MasteryCfg)
	eq(ids(got), "TitanFlawless,TitanSwift,TitanBigFinish", "config order, iron will needs exactly 1 heart")
end)

test("mastery: every check kind is inclusive at its boundary and fails just outside", function()
	local function has(metrics, id) for _, o in Mastery.Evaluate("Titan", metrics, {}, MasteryCfg) do if o.Id == id then return true end end return false end
	local base = { HeartsLost = 1, Volleys = 99, FinalPops = 0, HeartsLeft = 2 }
	local function with(k, v) local m = table.clone(base) m[k] = v return m end
	eq(has(with("HeartsLost", 0), "TitanFlawless"), true, "0 hearts lost")
	eq(has(with("HeartsLost", 1), "TitanFlawless"), false, "1 heart lost")
	eq(has(with("Volleys", 8), "TitanSwift"), true, "exactly 8 volleys")
	eq(has(with("Volleys", 9), "TitanSwift"), false, "9 volleys")
	eq(has(with("FinalPops", 20), "TitanBigFinish"), true, "exactly 20 pops")
	eq(has(with("FinalPops", 19), "TitanBigFinish"), false, "19 pops")
	eq(has(with("HeartsLeft", 1), "TitanIronWill"), true, "exactly 1 heart")
	eq(has(with("HeartsLeft", 2), "TitanIronWill"), false, "2 hearts is too safe")
	eq(has(with("HeartsLeft", 0), "TitanIronWill"), false, "0 hearts is not a win")
end)

test("mastery: objectives already done are not offered again, and other bosses' objectives are ignored", function()
	eq(ids(Mastery.Evaluate("Titan", perfect(), { TitanFlawless = true }, MasteryCfg)), "TitanSwift,TitanBigFinish", "flawless already done")
	eq(ids(Mastery.Evaluate("Nobody", perfect(), {}, MasteryCfg)), "", "no objectives for an unknown boss")
end)

test("mastery: granting marks objectives done, pays once, and a repeat pays nothing", function()
	local m = fresh()
	local got = Mastery.Evaluate("Titan", perfect(), m.Done, MasteryCfg)
	local reward = Mastery.Grant(m, got)
	local expected = 0
	for _, o in got do expected += o.Reward end
	eq(reward, expected, "the sum of the rewards")
	eq(m.Done.TitanFlawless, true, "marked")
	eq(Mastery.Grant(m, got), 0, "a second grant pays nothing")
end)

test("mastery: titles come only from completed objectives and only earned titles can be worn", function()
	local m = fresh()
	eq(#Mastery.Titles(m, MasteryCfg), 0, "none yet")
	eq(Mastery.Equip(m, "Untouchable", MasteryCfg), false, "not earned")
	eq(m.Title, "", "unchanged")
	Mastery.Grant(m, Mastery.Evaluate("Titan", perfect(), m.Done, MasteryCfg))
	eq(Mastery.Equip(m, "Untouchable", MasteryCfg), true, "earned")
	eq(m.Title, "Untouchable", "worn")
	eq(Mastery.Equip(m, "Cataclysm", MasteryCfg), false, "Iron Will not done")
	eq(m.Title, "Untouchable", "still the old one")
	eq(Mastery.Equip(m, "", MasteryCfg), true, "can take it off")
	eq(m.Title, "", "removed")
	eq(Mastery.Equip(m, 5, MasteryCfg), false, "junk")
	eq(Mastery.Equip(m, nil, MasteryCfg), false, "nil")
	eq(Mastery.Equip(m, { "Untouchable" }, MasteryCfg), false, "a table is not a title")
end)

test("mastery: the view lists every objective with its state", function()
	local m = fresh()
	m.Done.TitanSwift = true
	local v = Mastery.View(m, MasteryCfg)
	eq(#v, #MasteryCfg.Objectives, "all objectives")
	for _, row in v do eq(row.Done, row.Id == "TitanSwift", row.Id) end
end)

test("mastery: config is valid (unique ids and titles, known checks, positive values, existing bosses)", function()
	local seen, titles = {}, {}
	local KNOWN = { HeartsLostAtMost = true, VolleysAtMost = true, FinalPopsAtLeast = true, EndedWithHearts = true }
	for _, o in MasteryCfg.Objectives do
		eq(seen[o.Id], nil, "duplicate id " .. o.Id) seen[o.Id] = true
		eq(titles[o.Title], nil, "duplicate title " .. o.Title) titles[o.Title] = true
		eq(KNOWN[o.Check], true, o.Id .. " uses a known check")
		eq(o.Reward > 0 and o.Value >= 0, true, o.Id .. " numbers")
		eq(BossCfg.Defs[o.Boss] ~= nil, true, o.Id .. " names a real boss")
		eq(o.Title ~= "" and #o.Title <= 24, true, o.Id .. " title fits above a head")
	end
end)

test("collection: kills and relics are recorded and the view marks what has been found", function()
	local col = { Lurkers = {}, Bosses = {}, Relics = {} }
	Mastery.RecordLurker(col, "Gnasher") Mastery.RecordLurker(col, "Gnasher") Mastery.RecordLurker(col, "Brute")
	Mastery.RecordBoss(col, "Titan")
	Mastery.RecordRelic(col, "IronRig") Mastery.RecordRelic(col, "IronRig")
	eq(col.Lurkers.Gnasher, 2, "two kills")
	local v = Mastery.CollectionView(col, LurkerCfg, BossCfg, ExpCfg)
	eq(#v.Lurkers, #LurkerCfg.Order, "every lurker has a row")
	local found = 0
	for _, r in v.Lurkers do if r.Found then found += 1 end end
	eq(found, 2, "two kinds found")
	eq(v.Lurkers[1].Kills, 2, "the count shows")
	eq(v.Bosses[1].Found, true, "boss found")
	eq(v.RelicsFound, 1, "one distinct relic")
	local n = 0 for _ in ExpCfg.Relics do n += 1 end
	eq(v.RelicsTotal, n, "total relics")
	eq(#v.Relics, n, "a row per relic")
end)

test("schema: v11 saves migrate to v12 with a collection log and mastery record and keep everything else", function()
	local d = Schema.Migrate({ SchemaVersion = 11, Shards = 9 })
	eq(d.Shards, 9, "shards kept")
	eq(next(d.Collection.Lurkers), nil, "empty lurker log")
	eq(next(d.Collection.Relics), nil, "empty relic log")
	eq(next(d.Mastery.Done), nil, "nothing mastered")
	eq(d.Mastery.Title, "", "no title")
	eq(Schema.CURRENT_VERSION >= 12, true, "version")
	local bad = Schema.Migrate({ SchemaVersion = 12, Mastery = "junk", Collection = 5 })
	eq(type(bad.Mastery), "table", "junk mastery replaced")
	eq(type(bad.Collection.Lurkers), "table", "junk collection replaced")
end)

local Grants = require("../../src/ReplicatedStorage/Shared/Grants")
local FinCfg = require("../../src/ReplicatedStorage/Shared/Config/Finishers")
local function freshSave() return Schema.Default() end

test("grants: equipping a finisher needs a known, owned id; hostile ids change nothing", function()
	local d = freshSave()
	eq(Grants.EquipFinisher(d, "Inferno", FinCfg), false, "known but not owned")
	eq(d.Finishers.Equipped, FinCfg.DefaultId, "unchanged")
	for _, junk in { 5, true, {}, "", "Nope", "inferno", string.rep("x", 5000) } do
		eq(Grants.EquipFinisher(d, junk, FinCfg), false, "junk id")
	end
	eq(d.Finishers.Equipped, FinCfg.DefaultId, "still default after junk")
	d.Finishers.Owned.Inferno = true
	eq(Grants.EquipFinisher(d, "Inferno", FinCfg), true, "owned")
	eq(d.Finishers.Equipped, "Inferno", "equipped")
	eq(Grants.EquipFinisher(d, FinCfg.DefaultId, FinCfg), true, "the default is always allowed")
end)

test("grants: shards are added, scaled by areas unlocked only when marked Scaled", function()
	local d = freshSave()
	local msgs = Grants.Apply(d, { { Kind = "Shards", Amount = 1000 }, { Kind = "Shards", Amount = 1000, Scaled = true } }, 0, 3)
	eq(d.Shards, 1000 + 3000, "flat plus scaled")
	eq(#msgs, 2, "a message each")
	local low = freshSave()
	Grants.Apply(low, { { Kind = "Shards", Amount = 500, Scaled = true } }, 0, 0)
	eq(low.Shards, 500, "never scaled below one area")
end)

test("grants: boosts start, extend by adding time (capped), keep the stronger multiplier, and expire", function()
	local d = freshSave()
	local now = 10000
	Grants.Apply(d, { { Kind = "Boost", Boost = "Shards", Mult = 2, Seconds = 900 } }, now, 1)
	eq(Grants.BoostMult(d.Boosts, "Shards", now + 899), 2, "active")
	eq(Grants.BoostMult(d.Boosts, "Shards", now + 900), 1, "expired exactly at the end")
	eq(Grants.BoostRemaining(d.Boosts, "Shards", now + 100), 800, "time left")
	eq(Grants.BoostRemaining(d.Boosts, "Shards", now + 5000), 0, "none after expiry")
	Grants.Apply(d, { { Kind = "Boost", Boost = "Shards", Mult = 3, Seconds = 900 } }, now + 100, 1)
	eq(Grants.BoostRemaining(d.Boosts, "Shards", now + 100), 1700, "durations add while running")
	eq(Grants.BoostMult(d.Boosts, "Shards", now + 100), 3, "the stronger multiplier wins")
	for _ = 1, 20 do Grants.Apply(d, { { Kind = "Boost", Boost = "Shards", Mult = 2, Seconds = 3600 } }, now + 100, 1) end
	eq(Grants.BoostRemaining(d.Boosts, "Shards", now + 100), Grants.BOOST_CAP_SECONDS, "capped at the stacking limit")
	eq(Grants.BoostMult(d.Boosts, "Luck", now), 1, "another boost is untouched")
	Grants.Apply(d, { { Kind = "Boost", Boost = "Shards", Mult = 2, Seconds = 5 } }, now + 999999, 1)
	eq(Grants.BoostRemaining(d.Boosts, "Shards", now + 999999), 5, "a stale boost restarts from now")
end)

test("grants: junk or missing boost records give a multiplier of 1", function()
	eq(Grants.BoostMult({}, "Shards", 5), 1, "no record")
	eq(Grants.BoostMult({ Shards = { Until = "x", Mult = 2 } }, "Shards", 5), 1, "bad time")
	eq(Grants.BoostMult({ Shards = { Until = 10, Mult = 0.1 } }, "Shards", 5), 1, "a boost can never slow you down")
	eq(Grants.BoostMult({ Shards = { Until = 10, Mult = "big" } }, "Shards", 5), 1, "bad multiplier")
end)

test("grants: tokens add up to a cap, can be spent one at a time, and never go negative", function()
	local d = freshSave()
	Grants.Apply(d, { { Kind = "Tokens", Token = "Revive", Count = 3 } }, 0, 1)
	eq(d.Inventory.Revive, 3, "added")
	eq(Grants.Spend(d, "Revive"), true, "spent")
	eq(d.Inventory.Revive, 2, "one fewer")
	for _ = 1, 10 do Grants.Apply(d, { { Kind = "Tokens", Token = "Revive", Count = 50 } }, 0, 1) end
	eq(d.Inventory.Revive, Grants.TOKEN_CAP, "capped")
	local empty = freshSave()
	eq(Grants.Spend(empty, "Charge"), false, "nothing to spend")
	eq(empty.Inventory.Charge, 0, "still zero")
	eq(Grants.Spend(empty, "Bogus"), false, "unknown token")
end)

test("grants: cosmetics, finishers and titles are recorded and are safe to grant twice", function()
	local d = freshSave()
	local g = { { Kind = "Cosmetic", Id = "Void" }, { Kind = "Finisher", Id = "Celestial" }, { Kind = "Title", Title = "Boss Hunter" } }
	Grants.Apply(d, g, 0, 1)
	Grants.Apply(d, g, 0, 1)
	eq(d.Cosmetics.Owned.Void, true, "blast color")
	eq(d.Finishers.Owned.Celestial, true, "finisher")
	eq(d.Mastery.Extra["Boss Hunter"], true, "title")
end)

test("grants: invalid grants are ignored entirely (nothing half-applied)", function()
	local d = freshSave()
	local before = d.Shards
	local bad = {
		{ Kind = "Shards", Amount = -5 }, { Kind = "Shards", Amount = 0 / 0 }, { Kind = "Shards", Amount = math.huge },
		{ Kind = "Boost", Boost = "Bogus", Mult = 2, Seconds = 60 }, { Kind = "Boost", Boost = "Shards", Mult = 1, Seconds = 60 }, { Kind = "Boost", Boost = "Shards", Mult = 2, Seconds = 0 },
		{ Kind = "Tokens", Token = "Revive", Count = 1.5 }, { Kind = "Tokens", Token = "Gold", Count = 1 }, { Kind = "Tokens", Token = "Revive", Count = 0 },
		{ Kind = "Cosmetic", Id = "" }, { Kind = "Finisher" }, { Kind = "Title", Title = "" }, { Kind = "Title", Title = string.rep("x", 25) },
		{ Kind = "Teleport" }, {}, "junk",
	}
	local msgs = Grants.Apply(d, bad, 0, 1)
	eq(#msgs, 0, "nothing applied")
	eq(d.Shards, before, "shards unchanged")
	eq(d.Inventory.Revive + d.Inventory.Charge, 0, "no tokens")
	eq(next(d.Finishers.Owned), nil, "no finishers")
	for _, g in bad do eq(Grants.Valid(g), false, "invalid") end
end)

test("grants: a finisher can be worn only if owned (the default always is) and known", function()
	local d = freshSave()
	eq(Grants.EquipFinisher(d, "Celestial", FinCfg), false, "not owned")
	eq(d.Finishers.Equipped, "Gold", "unchanged")
	Grants.Apply(d, { { Kind = "Finisher", Id = "Celestial" } }, 0, 1)
	eq(Grants.EquipFinisher(d, "Celestial", FinCfg), true, "owned now")
	eq(d.Finishers.Equipped, "Celestial", "worn")
	eq(Grants.EquipFinisher(d, "Gold", FinCfg), true, "the default is always available")
	eq(Grants.EquipFinisher(d, "Bogus", FinCfg), false, "unknown")
	d.Finishers.Owned.Bogus = true
	eq(Grants.EquipFinisher(d, "Bogus", FinCfg), false, "owned but not a real finisher")
	eq(Grants.EquipFinisher(d, 7, FinCfg), false, "junk")
	eq(Grants.EquipFinisher(d, nil, FinCfg), false, "nil")
end)

test("mastery: purchased titles can be worn like earned ones, and are listed after them in a stable order", function()
	local m = { Done = {}, Title = "", Extra = { ["Zeta Title"] = true, ["Alpha Title"] = true } }
	local titles = Mastery.Titles(m, MasteryCfg)
	eq(titles[1], "Alpha Title", "sorted")
	eq(titles[2], "Zeta Title", "sorted")
	eq(Mastery.Equip(m, "Zeta Title", MasteryCfg), true, "a purchased title can be worn")
	eq(m.Title, "Zeta Title", "worn")
	eq(Mastery.Equip(m, "Not Owned", MasteryCfg), false, "an unowned one cannot")
end)

test("offers: config is valid (valid grants, real cosmetics and finishers, ordered tiers)", function()
	local seen = {}
	local tierRank = {}
	for i, t in Products.TierOrder do tierRank[t] = i end
	local CATEGORIES = { Boosts = true, Support = true, Finishers = true, Bundles = true }
	local shopStyles, finisherIds = {}, {}
	for _, d in CosCfg.Defs do shopStyles[d.Id] = true end
	for _, d in FinCfg.Defs do finisherIds[d.Id] = true end
	eq(#Products.OfferOrder, (function() local n = 0 for _ in Products.Offers do n += 1 end return n end)(), "order lists every offer")
	local lastRank, lastPrice = 0, 0
	for _, key in Products.OfferOrder do
		local o = Products.Offers[key]
		eq(o ~= nil, true, key .. " exists")
		eq(seen[key], nil, "duplicate " .. key) seen[key] = true
		-- id well-formedness and no cross-category collisions: checked once, for every product group, in
		-- "products: config is valid and never contains invented ids"
		eq(type(o.Name) == "string" and type(o.Description) == "string", true, key .. " text")
		eq(CATEGORIES[o.Category], true, key .. " category")
		eq(tierRank[o.Tier] ~= nil, true, key .. " tier")
		eq(tierRank[o.Tier] >= lastRank, true, key .. " is listed in ascending tier order")
		eq(o.PriceHint >= lastPrice or tierRank[o.Tier] > lastRank, true, key .. " price hint does not go backwards inside a tier")
		lastRank, lastPrice = tierRank[o.Tier], o.PriceHint
		eq(#o.Grants > 0, true, key .. " gives something")
		for _, g in o.Grants do
			eq(Grants.Valid(g), true, key .. " has a valid grant")
			if g.Kind == "Cosmetic" then eq(shopStyles[g.Id], true, key .. " grants a real blast color") end
			if g.Kind == "Finisher" then eq(finisherIds[g.Id] and g.Id ~= FinCfg.DefaultId, true, key .. " grants a real, non-default finisher") end
		end
	end
	local floors = { Tiny = 5, Small = 49, Medium = 149, Large = 399, Premium = 999 }
	local ceilings = { Tiny = 25, Small = 99, Medium = 299, Large = 799, Premium = 1e9 }
	for _, o in Products.Offers do
		eq(o.PriceHint >= floors[o.Tier] and o.PriceHint <= ceilings[o.Tier], true, o.Name .. " price hint sits in its tier's range")
	end
	if Products.Club.SubscriptionId ~= nil then
		eq(type(Products.Club.SubscriptionId) == "string" and Products.Club.SubscriptionId ~= "", true, "the subscription id, once set, is a real non-empty string")
	end
	eq(Products.Club.MonthlyShards > 0 and #Products.Club.Title <= 24, true, "club config")
end)

test("offers: no offer id collides with a shard pack, cosmetic product or pass key, and shop finishers are all sold somewhere", function()
	for key in Products.Offers do
		eq(Products.DeveloperProducts[key], nil, key .. " also a shard pack")
		eq(Products.CosmeticProducts[key], nil, key .. " also a cosmetic product")
		eq(Products.Gamepasses[key], nil, key .. " also a pass")
	end
	local sold = {}
	for _, o in Products.Offers do for _, g in o.Grants do if g.Kind == "Finisher" then sold[g.Id] = true end end end
	for _, d in FinCfg.Defs do if d.Shop then eq(sold[d.Id], true, d.Id .. " finisher is for sale") end end
end)

test("schema: v12 saves migrate to v13 with boosts, tokens, finishers and club records", function()
	local d = Schema.Migrate({ SchemaVersion = 12, Shards = 4, Mastery = { Done = { TitanSwift = true }, Title = "Speed Blaster" } })
	eq(d.Shards, 4, "shards kept")
	eq(d.Mastery.Done.TitanSwift, true, "mastery kept")
	eq(d.Mastery.Title, "Speed Blaster", "title kept")
	eq(type(d.Mastery.Extra), "table", "extra titles added")
	eq(d.Boosts.Shards.Until, 0, "no boost")
	eq(d.Inventory.Revive, 0, "no tokens")
	eq(d.Finishers.Equipped, "Gold", "default finisher")
	eq(d.Club.LastMonth, 0, "club unclaimed")
	eq(Schema.CURRENT_VERSION >= 13, true, "v13 exists")
end)

test("grants: adding a weaker boost never weakens a running one, and one huge purchase is capped from the start", function()
	local d = freshSave()
	Grants.Apply(d, { { Kind = "Boost", Boost = "Shards", Mult = 3, Seconds = 600 } }, 100, 1)
	Grants.Apply(d, { { Kind = "Boost", Boost = "Shards", Mult = 2, Seconds = 600 } }, 100, 1)
	eq(Grants.BoostMult(d.Boosts, "Shards", 100), 3, "still the stronger one")
	local big = freshSave()
	Grants.Apply(big, { { Kind = "Boost", Boost = "Luck", Mult = 2, Seconds = 999999 } }, 100, 1)
	eq(Grants.BoostRemaining(big.Boosts, "Luck", 100), Grants.BOOST_CAP_SECONDS, "capped even when fresh")
end)

test("mastery: a title flagged false in the purchased list is not offered", function()
	local m = { Done = {}, Title = "", Extra = { Gone = false, Kept = true } }
	local titles = Mastery.Titles(m, MasteryCfg)
	eq(#titles, 1, "only the owned one")
	eq(titles[1], "Kept", "kept")
end)

test("expedition: WouldCollapse matches FloorEnded (too little cleared AND no charges), so a revive can be offered before committing", function()
	eq(Expedition.WouldCollapse(0.49, 0, ExpCfg), true, "under the line, no charges")
	eq(Expedition.WouldCollapse(0.5, 0, ExpCfg), false, "exactly on the line survives")
	eq(Expedition.WouldCollapse(0.49, 1, ExpCfg), false, "a charge left")
	eq(Expedition.WouldCollapse(0.9, 0, ExpCfg), false, "mostly cleared")
	for _, case in { { 0.1, 0 }, { 0.5, 0 }, { 0.2, 2 }, { 1, 0 } } do
		local run = startRun(4)
		local outcome = Expedition.FloorEnded(run, 10, case[1], case[2], lcg(2), ExpCfg)
		eq(outcome == "Collapse", Expedition.WouldCollapse(case[1], case[2], ExpCfg), "consistent for " .. case[1] .. "/" .. case[2])
	end
end)

test("grants: the month number changes exactly at the UTC month boundary", function()
	local jan31 = 1706745599 -- 2024-01-31 23:59:59 UTC
	local feb1 = 1706745600 -- 2024-02-01 00:00:00 UTC
	eq(Grants.MonthNumber(feb1), Grants.MonthNumber(jan31) + 1, "next month")
	eq(Grants.MonthNumber(jan31), Grants.MonthNumber(jan31 - 86400 * 20), "same month earlier")
	eq(Grants.MonthNumber(1704067199) + 1, Grants.MonthNumber(1704067200), "year rollover (Dec 2023 to Jan 2024) is one step")
end)

test("events: the combat effects multiply across events and are neutral when nothing is active", function()
	local none = Events.Combine({})
	eq(none.LurkerMult == 1 and none.DamageMult == 1 and none.BountyMult == 1, true, "neutral")
	local both = Events.Combine({ { Effects = { LurkerMult = 3, DamageMult = 1.5 } }, { Effects = { LurkerMult = 2, BountyMult = 1.5 } } })
	eq(both.LurkerMult, 6, "spawn chances multiply")
	eq(both.DamageMult, 1.5, "damage")
	eq(both.BountyMult, 1.5, "bounty")
	eq(both.MutationMult == 1 and both.ShardMult == 1 and both.ChargeBonus == 0, true, "other effects untouched")
end)

test("events: Lurker Swarm Friday is all Friday only, Explosive Sunday all Sunday, Crystal Storm is 20:00-21:00 every day", function()
	local function has(now, id) for _, e in Events.Active(now, EventsCfg) do if e.Id == id then return true end end return false end
	local FRIDAY, SUNDAY = MONDAY + 4 * DAY, MONDAY + 6 * DAY
	eq(has(FRIDAY, "LurkerSwarmFriday") and has(FRIDAY + DAY - 1, "LurkerSwarmFriday"), true, "all Friday")
	eq(has(FRIDAY - 1, "LurkerSwarmFriday") or has(FRIDAY + DAY, "LurkerSwarmFriday"), false, "not Thursday or Saturday")
	eq(has(SUNDAY + 5 * HOUR, "ExplosiveSunday") and not has(SUNDAY + DAY, "ExplosiveSunday"), true, "Sunday only")
	eq(has(MONDAY + 20 * HOUR, "CrystalStorm") and has(MONDAY + 21 * HOUR - 1, "CrystalStorm"), true, "inside the hour")
	eq(has(MONDAY + 20 * HOUR - 1, "CrystalStorm") or has(MONDAY + 21 * HOUR, "CrystalStorm"), false, "outside it")
end)

local BossRT = require("../../src/ReplicatedStorage/Shared/BossRT")
local RT = TitanDef.RT
local function firstThen(first, seed)
	local rest, called = lcg(seed), false
	return function() if not called then called = true return first end return rest() end
end
local function armedState(now) local st = BossRT.New(now or 0, "Titan", BossCfg) st.NextAt = 0 return st end

test("bossrt: a new fight waits before its first attack and has no threats or shield", function()
	local st = BossRT.New(100, "Titan", BossCfg)
	eq(st.NextAt, 100 + RT.FirstAttackDelay, "first attack delay")
	eq(#st.Threats, 0, "no threats")
	eq(BossRT.IsShielded(st, 100), false, "no shield")
	eq(BossRT.Spawn(st, "Attack", "Titan", fullGrid(), bctx, 100 + RT.FirstAttackDelay - 0.01, lcg(1), BossCfg), nil, "too early")
end)

test("bossrt: attacks start only when due, only in phases that attack, and never beyond the phase's limit", function()
	local st = armedState()
	eq(BossRT.Spawn(st, "Armor", "Titan", fullGrid(), bctx, 5, lcg(1), BossCfg), nil, "the armor phase does not attack")
	local t1 = BossRT.Spawn(st, "Attack", "Titan", fullGrid(), bctx, 5, lcg(1), BossCfg)
	eq(t1 ~= nil, true, "spawned")
	eq(st.NextAt, 5 + RT.Interval.Attack, "the next wind-up is an interval later")
	eq(BossRT.Spawn(st, "Attack", "Titan", fullGrid(), bctx, 5 + RT.Interval.Attack, lcg(2), BossCfg), nil, "attack phase allows one threat at a time")
	local st2 = armedState()
	eq(BossRT.Spawn(st2, "Enrage", "Titan", fullGrid(), bctx, 1, lcg(1), BossCfg) ~= nil, true, "first enrage attack")
	eq(BossRT.Spawn(st2, "Enrage", "Titan", fullGrid(), bctx, 1 + RT.Interval.Enrage, lcg(2), BossCfg) ~= nil, true, "a second at once in enrage")
	eq(BossRT.Spawn(st2, "Enrage", "Titan", fullGrid(), bctx, 1 + 2 * RT.Interval.Enrage, lcg(3), BossCfg), nil, "but no third")
	eq(t1.LandsAt, 5 + RT[t1.Type].Delay, "lands after its telegraph delay")
end)

test("bossrt: a slam marks a full row or column, and both orientations occur", function()
	local seenH, seenV = false, false
	for seed = 1, 30 do
		local t = BossRT.Spawn(armedState(), "Attack", "Titan", fullGrid(), bctx, 1, lcg(seed), BossCfg)
		eq(t.Type, "Slam", "the attack phase only slams")
		eq(#t.Cells, N, "a full line")
		local sameX, sameZ = true, true
		for _, c in t.Cells do
			if c.X ~= t.Cells[1].X then sameX = false end
			if c.Z ~= t.Cells[1].Z then sameZ = false end
		end
		eq(sameX ~= sameZ, true, "one axis fixed")
		if sameX then seenV = true else seenH = true end
	end
	eq(seenH and seenV, true, "rows and columns")
end)

test("bossrt: meteors aim at crystals outside the core, spaced apart, and do not spawn with nothing to hit", function()
	for seed = 1, 20 do
		local t = BossRT.Spawn(armedState(), "Weak", "Titan", fullGrid(), bctx, 1, firstThen(0.9, seed), BossCfg)
		eq(t.Type, "Meteor", "the rng picked a meteor")
		eq(#t.Zones >= 1 and #t.Zones <= RT.Meteor.Zones, true, "up to the configured number of zones")
		for i, z in t.Zones do
			eq(math.abs(z.X - 5) <= 1 and math.abs(z.Z - 5) <= 1, false, "outside the core")
			for j = i + 1, #t.Zones do
				eq(math.max(math.abs(z.X - t.Zones[j].X), math.abs(z.Z - t.Zones[j].Z)) >= 3, true, "zones do not overlap")
			end
		end
	end
	eq(BossRT.Spawn(armedState(), "Weak", "Titan", grid(function() return nil end), bctx, 1, firstThen(0.9, 1), BossCfg), nil, "an empty grid has nothing to aim at")
end)

test("bossrt: corruption marks crystals outside the core, and does not spawn on an empty grid", function()
	local t = BossRT.Spawn(armedState(), "Enrage", "Titan", fullGrid(), bctx, 1, firstThen(0.99, 4), BossCfg)
	eq(t.Type, "Corruption", "picked")
	eq(#t.Marks, RT.Corruption.Marks, "the configured number of marks")
	for _, m in t.Marks do eq(math.abs(m.X - 5) <= 1 and math.abs(m.Z - 5) <= 1, false, "outside the core") end
	eq(BossRT.Spawn(armedState(), "Enrage", "Titan", grid(function() return nil end), bctx, 1, firstThen(0.99, 4), BossCfg), nil, "nothing to corrupt")
end)

test("bossrt: enough pops on a slam line cut it, and it stays cut", function()
	local st = armedState()
	local t = BossRT.Spawn(st, "Attack", "Titan", fullGrid(), bctx, 1, lcg(3), BossCfg)
	local few, enough = {}, {}
	for i = 1, TitanDef.CutPops - 1 do few[i] = { X = t.Cells[i].X, Z = t.Cells[i].Z, Kind = "Glimmerstone" } end
	for i = 1, TitanDef.CutPops do enough[i] = { X = t.Cells[i].X, Z = t.Cells[i].Z, Kind = "Glimmerstone" } end
	eq(BossRT.Counter(st, few, bctx, "Titan", BossCfg).Cut, 0, "one short")
	eq(t.Cancelled, false, "still live")
	eq(BossRT.Counter(st, { { X = 99, Z = 99, Kind = "Glimmerstone" } }, bctx, "Titan", BossCfg).Cut, 0, "pops elsewhere")
	eq(BossRT.Counter(st, enough, bctx, "Titan", BossCfg).Cut, 1, "cut")
	eq(t.Cancelled, true, "cancelled")
	eq(BossRT.Counter(st, enough, bctx, "Titan", BossCfg).Cut, 0, "not counted twice, even if the same pops are reported again")
	eq(t.Cancelled, true, "and stays cancelled")
end)

test("bossrt: each prism (Lensglass) pop deflects one meteor zone; other crystals do not", function()
	local st = armedState()
	local t = BossRT.Spawn(st, "Weak", "Titan", fullGrid(), bctx, 1, firstThen(0.9, 8), BossCfg)
	local zones = #t.Zones
	eq(BossRT.Counter(st, { { X = 1, Z = 1, Kind = "Kindlequartz" }, { X = 2, Z = 1, Kind = "Glimmerstone" } }, bctx, "Titan", BossCfg).Deflected, 0, "no prism, no deflection")
	local r = BossRT.Counter(st, { { X = 1, Z = 1, Kind = "Lensglass" } }, bctx, "Titan", BossCfg)
	eq(r.Deflected, 1, "one pop, one zone")
	local cancelled = 0
	for _, z in t.Zones do if z.Cancelled then cancelled += 1 end end
	eq(cancelled, 1, "exactly one zone cancelled")
	local many = {}
	for i = 1, 6 do many[i] = { X = i, Z = 1, Kind = "Lensglass" } end
	BossRT.Counter(st, many, bctx, "Titan", BossCfg)
	cancelled = 0
	for _, z in t.Zones do if z.Cancelled then cancelled += 1 end end
	eq(cancelled, zones, "extra prisms cannot cancel more zones than exist")
end)

test("bossrt: popping marked crystals purifies them, unmarked ones stay marked", function()
	local st = armedState()
	local t = BossRT.Spawn(st, "Enrage", "Titan", fullGrid(), bctx, 1, firstThen(0.99, 4), BossCfg)
	local first = { X = t.Marks[1].X, Z = t.Marks[1].Z }
	local r = BossRT.Counter(st, { { X = first.X, Z = first.Z, Kind = "Glimmerstone" } }, bctx, "Titan", BossCfg)
	eq(r.Purified, 1, "one purified")
	eq(#t.Marks, RT.Corruption.Marks - 1, "one fewer mark")
	for _, m in t.Marks do eq(m.X == first.X and m.Z == first.Z, false, "the purified one is gone") end
end)

test("bossrt: threats land exactly at their time (inclusive) and are removed from the state", function()
	local st = armedState()
	local t = BossRT.Spawn(st, "Attack", "Titan", fullGrid(), bctx, 10, lcg(2), BossCfg)
	eq(#BossRT.Due(st, t.LandsAt - 0.001), 0, "not yet")
	eq(#st.Threats, 1, "still waiting")
	local due = BossRT.Due(st, t.LandsAt)
	eq(#due, 1, "due at the exact time")
	eq(#st.Threats, 0, "removed")
	eq(#BossRT.Due(st, t.LandsAt + 5), 0, "gone for good")
end)

test("bossrt: dodge is a timed shield with a cooldown, ready again exactly when it expires", function()
	local st = BossRT.New(0, "Titan", BossCfg)
	eq(BossRT.Shield(st, 10, "Titan", BossCfg), true, "starts")
	eq(BossRT.IsShielded(st, 10 + RT.ShieldSeconds - 0.01), true, "inside the window")
	eq(BossRT.IsShielded(st, 10 + RT.ShieldSeconds), false, "over at the boundary")
	eq(BossRT.Shield(st, 10 + RT.DodgeCooldown - 0.01, "Titan", BossCfg), false, "still cooling down")
	eq(BossRT.Shield(st, 10 + RT.DodgeCooldown, "Titan", BossCfg), true, "ready at the boundary")
end)

test("bossrt: a landing slam wrecks its line and costs a heart, unless shielded (crystals still fall) or cut", function()
	local function slam()
		local g = fullGrid()
		local st = armedState()
		local t = BossRT.Spawn(st, "Attack", "Titan", g, bctx, 1, lcg(5), BossCfg)
		return g, t
	end
	local g, t = slam()
	local r = BossRT.Resolve(t, g, bctx, false, BossCfg)
	eq(r.HeartsLost, 1, "a heart")
	eq(#r.Destroyed, N, "the whole line")
	for _, c in t.Cells do eq(g.Cells[ChainSim.Key(N, c.X, c.Z)], nil, "destroyed") end
	local g2, t2 = slam()
	local blocked = BossRT.Resolve(t2, g2, bctx, true, BossCfg)
	eq(blocked.HeartsLost == 0 and blocked.Blocked == true, true, "the shield blocks the heart")
	eq(#blocked.Destroyed, N, "but not the crystal damage")
	local g3, t3 = slam()
	t3.Cancelled = true
	local cut = BossRT.Resolve(t3, g3, bctx, false, BossCfg)
	eq(cut.HeartsLost == 0 and #cut.Destroyed == 0 and cut.Cancelled == true, true, "a cut slam does nothing")
end)

test("bossrt: meteors wreck only live zones (clipped at the edge), cost one heart in total, and do nothing if all are deflected", function()
	local g = fullGrid()
	local t = { Id = 1, Type = "Meteor", LandsAt = 0, Cancelled = false, Cells = {}, Marks = {}, Zones = { { X = 1, Z = 1, Cancelled = false }, { X = 9, Z = 9, Cancelled = true }, { X = 5, Z = 2, Cancelled = false } } }
	local r = BossRT.Resolve(t, g, bctx, false, BossCfg)
	eq(r.HeartsLost, 1, "one heart even with two live zones")
	eq(#r.Destroyed, 4 + 9, "a corner zone (4 cells) plus a full zone (9)")
	eq(g.Cells[ChainSim.Key(N, 9, 9)] ~= nil, true, "the deflected zone is untouched")
	local all = { Id = 2, Type = "Meteor", LandsAt = 0, Cancelled = false, Cells = {}, Marks = {}, Zones = { { X = 4, Z = 4, Cancelled = true } } }
	local none = BossRT.Resolve(all, fullGrid(), bctx, false, BossCfg)
	eq(none.HeartsLost == 0 and #none.Destroyed == 0 and none.Cancelled == true, true, "fully deflected")
end)

test("bossrt: corruption turns surviving marks into Dreadgeodes for free of hearts, skips missing crystals, and cancels when purified", function()
	local g = fullGrid()
	g.Cells[ChainSim.Key(N, 2, 2)] = nil
	local t = { Id = 1, Type = "Corruption", LandsAt = 0, Cancelled = false, Cells = {}, Zones = {}, Marks = { { X = 1, Z = 1 }, { X = 2, Z = 2 }, { X = 8, Z = 8 } } }
	local r = BossRT.Resolve(t, g, bctx, false, BossCfg)
	eq(r.HeartsLost, 0, "no heart")
	eq(#r.Corrupted, 2, "the two crystals that still exist")
	eq(g.Cells[ChainSim.Key(N, 1, 1)].Kind, "Dreadgeode", "corrupted")
	eq(g.Cells[ChainSim.Key(N, 2, 2)], nil, "an empty cell is not filled")
	local pure = BossRT.Resolve({ Id = 2, Type = "Corruption", LandsAt = 0, Cancelled = false, Cells = {}, Zones = {}, Marks = {} }, fullGrid(), bctx, false, BossCfg)
	eq(pure.Cancelled and #pure.Corrupted == 0, true, "all purified")
end)

test("bossrt: the view reports time left (never negative), shield and dodge state", function()
	local st = armedState()
	local t = BossRT.Spawn(st, "Attack", "Titan", fullGrid(), bctx, 10, lcg(2), BossCfg)
	local v = BossRT.View(st, 10, BossCfg, "Titan")
	eq(math.abs(v.Threats[1].LandsIn - RT.Slam.Delay) < 1e-9, true, "full delay at the start")
	eq(BossRT.View(st, 10 + 99, BossCfg, "Titan").Threats[1].LandsIn, 0, "clamped at zero")
	eq(v.DodgeReady, true, "dodge ready")
	BossRT.Shield(st, 10, "Titan", BossCfg)
	local v2 = BossRT.View(st, 10.5, BossCfg, "Titan")
	eq(v2.Shielded == true and v2.DodgeReady == false, true, "shielded, cooling down")
	eq(math.abs(v2.DodgeLeft - (RT.DodgeCooldown - 0.5)) < 1e-9, true, "cooldown left")
end)

test("bossrt: config is sane (known attack types, fair telegraph windows, shield shorter than its cooldown)", function()
	local KNOWN = { Slam = true, Meteor = true, Corruption = true }
	for phase, list in RT.Attacks do
		eq(RT.Interval[phase] ~= nil and RT.MaxThreats[phase] ~= nil, true, phase .. " has an interval and a limit")
		for _, a in list do eq(KNOWN[a] and RT[a] ~= nil, true, phase .. " lists a real attack " .. a) end
	end
	for name in KNOWN do eq(RT[name].Delay >= 2, true, name .. " gives at least 2 seconds to react") end
	eq(RT.ShieldSeconds < RT.DodgeCooldown, true, "the shield is shorter than its cooldown")
	eq(RT.Corruption.Marks >= 1 and RT.Meteor.Zones >= 1, true, "positive counts")
	eq(RT.Interval.Enrage < RT.Interval.Attack, true, "enrage attacks faster")
end)

test("bosses: every defined boss has complete real-time config and can be fought from armor to defeat", function()
	local KNOWN = { Slam = true, Meteor = true, Corruption = true }
	local n = 0
	for kind, def in BossCfg.Defs do
		n += 1
		eq(def.MaxHP > 0 and def.Bounty > 0 and def.Nodes >= 1, true, kind .. " basics")
		eq(def.AttackEnd > def.WeakEnd and def.WeakEnd > def.FinisherAt and def.FinisherAt > 0, true, kind .. " phase thresholds descend")
		for phase, list in def.RT.Attacks do
			eq(def.RT.Interval[phase] ~= nil and def.RT.MaxThreats[phase] ~= nil, true, kind .. " " .. phase .. " has timing")
			for _, a in list do eq(KNOWN[a] and def.RT[a] ~= nil, true, kind .. " " .. phase .. " uses a real attack") end
		end
		for name in KNOWN do eq(def.RT[name].Delay >= 2, true, kind .. " " .. name .. " is reactable") end
		-- a fight: clear the armor, then hit hard until it dies
		local g = fullGrid()
		local b = Boss.New(kind, g, bctx, BossCfg, lcg(5))
		eq(#b.Nodes, def.Nodes, kind .. " armor nodes")
		local nodes = {}
		for _, node in b.Nodes do nodes[#nodes + 1] = { X = node.X, Z = node.Z } end
		Boss.Apply(b, {}, fakeResult(3, nodes), bctx, BossCfg, 1, g, lcg(1))
		eq(b.Phase, "Attack", kind .. " armor breaks")
		local guard = 0
		while b.Phase ~= "Dead" and guard < 60 do
			guard += 1
			Boss.Apply(b, { cap(5, 5) }, fakeResult(def.Finisher.Pops, {}), bctx, BossCfg, 3, g, lcg(guard))
		end
		eq(b.Phase, "Dead", kind .. " can be defeated")
		-- and each phase's attacks can actually spawn on a full grid
		for phase, list in def.RT.Attacks do
			local st = armedState()
			eq(BossRT.Spawn(st, phase, kind, fullGrid(), bctx, 1, lcg(9), BossCfg) ~= nil, true, kind .. " " .. phase .. " spawns")
		end
	end
	eq(n >= 2, true, "at least two bosses exist")
	for f, kind in BossCfg.BossFloors do eq(BossCfg.Defs[kind] ~= nil, true, "floor " .. f .. " names a real boss") end
	eq(BossCfg.BossFloors[4] ~= BossCfg.BossFloors[8], true, "the two boss floors are different fights")
end)

test("objectives: once the basics are known the player is pointed at Expeditions, then at the first boss, then released", function()
	local base = { Shards = 0, Stats = { TotalPops = 60 } }
	eq(Objectives.Roam(snap({ Stats = { TotalPops = 29 } }), 0, 0, ocfg).Id, "Earn", "too new for the suggestion")
	local intro = Objectives.Roam(snap(base), 0, 0, ocfg)
	eq(intro.Id, "TryExpedition", "the Expedition hint")
	eq(intro.Target ~= nil, true, "points at a pad")
	local shallow = Objectives.Roam(snap({ Stats = { TotalPops = 60, BestDepth = 2 } }), 0, 0, ocfg)
	eq(shallow.Id, "FaceTitan", "dive to floor 4")
	eq(string.find(shallow.Text, "2", 1, true) ~= nil, true, "shows how deep you got")
	local ready = Objectives.Roam(snap({ Stats = { TotalPops = 60, BestDepth = 4 } }), 0, 0, ocfg)
	eq(ready.Id, "FaceTitan", "still the boss quest")
	eq(ready.Text ~= shallow.Text, true, "different text once you have reached it")
	eq(Objectives.Roam(snap({ Stats = { TotalPops = 60, BestDepth = 4, BossesSlain = 1 } }), 0, 0, ocfg).Id, "Earn", "quest done: back to the normal path")
end)

test("objectives: an affordable area unlock and pending claims still outrank the Expedition suggestion", function()
	eq(Objectives.Roam(snap({ Shards = AREA2_COST, Upgrades = { ExtraCharge = 1 }, Stats = { TotalPops = 60 } }), 0, 0, ocfg).Id, "UnlockArea", "unlock first")
	eq(Objectives.Roam(snap({ Goals = { { Complete = true, Claimed = false } }, Stats = { TotalPops = 60 } }), 0, 0, ocfg).Id, "ClaimGoal", "claim first")
end)

test("objectives: a Lurker on the grid turns the in-blast hint into a fight hint, even for veterans", function()
	local hint = Objectives.Blast({ Stats = { TotalPops = 5000 }, Monster = { Name = "Gnasher" } }, 0)
	eq(hint.Id, "Fight", "fight hint")
	eq(string.find(hint.Text, "Gnasher", 1, true) ~= nil, true, "names it")
	eq(Objectives.Blast({ Stats = { TotalPops = 5000 } }, 0), nil, "veterans get no hint otherwise")
end)

test("lurker: before the first kill a player who knows the basics gets a pity spawn chance, never lower than normal", function()
	local base = Lurker.SpawnChance(1, 0, LurkerCfg)
	eq(Lurker.SpawnChance(1, 0, LurkerCfg, true), math.max(base, LurkerCfg.Spawn.FirstFightChance), "pity chance")
	eq(Lurker.SpawnChance(1, 0, LurkerCfg, false), base, "no pity otherwise")
	eq(Lurker.SpawnChance(4, 6, LurkerCfg, true) >= Lurker.SpawnChance(4, 6, LurkerCfg), true, "never lowers a high chance")
	eq(LurkerCfg.Spawn.FirstFightChance > base and LurkerCfg.Spawn.FirstFightChance <= 1, true, "config sanity")
end)

test("objectives: the Expedition hint starts at exactly 30 pops and the boss text switches exactly at floor 4", function()
	eq(Objectives.Roam(snap({ Stats = { TotalPops = 30 } }), 0, 0, ocfg).Id, "TryExpedition", "at 30 pops")
	local three = Objectives.Roam(snap({ Stats = { TotalPops = 60, BestDepth = 3 } }), 0, 0, ocfg)
	eq(string.find(three.Text, "best so far", 1, true) ~= nil, true, "floor 3 still says to dive deeper")
	local four = Objectives.Roam(snap({ Stats = { TotalPops = 60, BestDepth = 4 } }), 0, 0, ocfg)
	eq(string.find(four.Text, "best so far", 1, true) == nil, true, "floor 4 says you have arrived")
end)

test("lurker: the pity chance never lowers a chance that is already higher", function()
	local cfg = { Spawn = { BaseChance = 0.9, PerStratum = 0, PerFloor = 0, Cap = 1, FirstFightChance = 0.6 } }
	eq(Lurker.SpawnChance(1, 0, cfg, true), 0.9, "keeps the higher chance")
end)

test("boss: the planning estimate matches what Apply really does, in every phase, for many volleys and powers", function()
	local checked = 0
	for _, kind in { "Titan", "Warden" } do
		local def = BossCfg.Defs[kind]
		for _, phase in { "Armor", "Attack", "Weak", "Enrage", "Finisher" } do
			for seed = 1, 25 do
				local rng = lcg(seed * 31 + #phase)
				local g = fullGrid()
				local b = Boss.New(kind, g, bctx, BossCfg, lcg(seed))
				b.Phase = phase
				if phase ~= "Armor" then b.Nodes = {} end
				b.HP = math.max(2, math.floor(def.MaxHP * (0.2 + rng() * 0.7)))
				if phase == "Weak" then b.Weak = { { X = 1 + seed % 9, Z = 1 }, { X = 9, Z = 1 + seed % 9 } } end
				local events = {}
				for i = 1, math.floor(rng() * 12) do events[#events + 1] = { X = 1 + math.floor(rng() * 9), Z = 1 + math.floor(rng() * 9), Kind = "Glimmerstone" } end
				if phase == "Armor" and rng() < 0.6 then for _, n in b.Nodes do events[#events + 1] = { X = n.X, Z = n.Z, Kind = "Glimmerstone" } end end
				if phase == "Weak" and rng() < 0.5 then events[#events + 1] = { X = b.Weak[1].X, Z = b.Weak[1].Z, Kind = "Glimmerstone" } end
				local result = fakeResult(math.floor(rng() * 30), events)
				local volley = rng() < 0.5 and { cap(5, 5) } or { { X = 5, Z = 9, Kind = "Cross" } }
				local power = ({ 1, 1.25, 1.5, 2 })[1 + math.floor(rng() * 4)]
				local before = b.HP
				local view = Boss.View(b, BossCfg)
				local est = Boss.Estimate(view, volley, result, bctx, BossCfg, power)
				local real = Boss.Apply(b, volley, result, bctx, BossCfg, power, g, lcg(seed))
				eq(est.Damage, math.min(real.Damage, before), ("%s %s seed %d damage"):format(kind, phase, seed))
				eq(est.Killed, real.Killed, ("%s %s seed %d kill"):format(kind, phase, seed))
				if phase == "Armor" then eq(est.NodesBroken, real.NodesBroken, "nodes broken") end
				if phase == "Weak" then eq(est.WeakHit, real.WeakHit, "weak hit") end
				checked += 1
			end
		end
	end
	eq(checked, 250, "all scenarios ran")
end)

test("boss: estimating never changes the boss it looks at", function()
	local g = fullGrid()
	local b = Boss.New("Titan", g, bctx, BossCfg, lcg(2))
	local view = Boss.View(b, BossCfg)
	local hp, nodes = view.HP, #view.Nodes
	Boss.Estimate(view, { cap(5, 5) }, fakeResult(20, {}), bctx, BossCfg, 2)
	eq(view.HP, hp, "hp untouched")
	eq(#view.Nodes, nodes, "nodes untouched")
	eq(b.HP, hp, "the real boss untouched")
end)

test("bossrt: simulating a volley reports exactly what Counter would do, and changes nothing", function()
	for seed = 1, 30 do
		local st = armedState()
		local g = fullGrid()
		local phase = ({ "Attack", "Weak", "Enrage" })[1 + seed % 3]
		BossRT.Spawn(st, phase, "Titan", g, bctx, 1, lcg(seed), BossCfg)
		if phase == "Enrage" then BossRT.Spawn(st, phase, "Titan", g, bctx, 1 + RT.Interval.Enrage, lcg(seed + 40), BossCfg) end
		local events = {}
		local rng = lcg(seed * 13)
		for i = 1, 14 do
			local t = st.Threats[1 + math.floor(rng() * #st.Threats)]
			local kind = rng() < 0.3 and "Lensglass" or "Glimmerstone"
			if t and t.Cells[1] and rng() < 0.7 then events[#events + 1] = { X = t.Cells[math.min(#t.Cells, 1 + i % 9)].X, Z = t.Cells[math.min(#t.Cells, 1 + i % 9)].Z, Kind = kind }
			elseif t and t.Marks[1] and rng() < 0.7 then events[#events + 1] = { X = t.Marks[1 + i % #t.Marks].X, Z = t.Marks[1 + i % #t.Marks].Z, Kind = kind }
			else events[#events + 1] = { X = 1 + i % 9, Z = 1 + (i * 3) % 9, Kind = kind } end
		end
		local view = BossRT.View(st, 1, BossCfg, "Titan")
		local sim = BossRT.Simulate(view.Threats, events, bctx, "Titan", BossCfg)
		for _, t in view.Threats do
			eq(t.Cancelled, false, "the view's threats were not touched")
		end
		local real = BossRT.Counter(st, events, bctx, "Titan", BossCfg)
		eq(sim.Cut, real.Cut, "cut seed " .. seed)
		eq(sim.Deflected, real.Deflected, "deflected seed " .. seed)
		eq(sim.Purified, real.Purified, "purified seed " .. seed)
		for _, o in sim.Outcomes do
			for _, t in st.Threats do
				if t.Id == o.Id then
					local fully = (t.Type == "Slam" and t.Cancelled) or (t.Type == "Meteor" and (function() for _, z in t.Zones do if not z.Cancelled then return false end end return true end)()) or (t.Type == "Corruption" and #t.Marks == 0)
					eq(o.Fully, fully, "fully stopped agrees for " .. t.Type)
				end
			end
		end
	end
end)


-- Notice Board contracts ---------------------------------------------------------------------------------------------
local Contracts = require("../../src/ReplicatedStorage/Shared/Contracts")
local ContractCfg = require("../../src/ReplicatedStorage/Shared/Config/Contracts")

test("contracts: three distinct offers a day, deterministic, targets rise by tier", function()
	for day = 20000, 20060 do
		local a, b = Contracts.ForDay(day, ContractCfg), Contracts.ForDay(day, ContractCfg)
		eq(#a, 3, "three offers")
		eq(a[1].Id ~= a[2].Id and a[2].Id ~= a[3].Id and a[1].Id ~= a[3].Id, true, "distinct templates")
		for i = 1, 3 do
			eq(a[i].Id, b[i].Id, "same day same offers")
			eq(a[i].Tier, i, "tier order")
		end
	end
	for _, t in ContractCfg.Templates do
		eq(t.Targets[1] < t.Targets[2] and t.Targets[2] < t.Targets[3], true, t.Id .. " targets rise")
	end
	eq(#ContractCfg.Rewards, #ContractCfg.Tiers, "a reward per tier")
end)

test("contracts: accept one at a time, count only matching events after accepting, claim once", function()
	local offers = {
		{ Tier = 1, Id = "H", Kind = "Slay", Param = "Gnasher", Target = 3, Text = "", TierName = "Easy" },
		{ Tier = 2, Id = "C", Kind = "Chain", Target = 20, Text = "", TierName = "Standard" },
		{ Tier = 3, Id = "B", Kind = "Boss", Target = 2, Text = "", TierName = "Hard" },
	}
	local s = Contracts.Default()
	Contracts.Ensure(s, 5)
	Contracts.Record(s, offers, "Slay", "Gnasher", 1)
	eq(s.Progress, 0, "nothing counts before accepting")
	for _, junk in { 0, 4, -1, 1.5, "1", true, {}, 0 / 0 } do
		eq(Contracts.Accept(s, junk, offers), false, "junk tier")
	end
	eq(Contracts.Accept(s, 1, offers), true, "accepted")
	eq(Contracts.Accept(s, 2, offers), false, "only one at a time")
	Contracts.Record(s, offers, "Slay", "Skitter", 1)
	eq(s.Progress, 0, "wrong lurker does not count")
	Contracts.Record(s, offers, "Chain", nil, 30)
	eq(s.Progress, 0, "wrong kind does not count")
	Contracts.Record(s, offers, "Slay", "Gnasher", 1)
	Contracts.Record(s, offers, "Slay", "Gnasher", 5)
	eq(s.Progress, 3, "capped at target")
	eq(Contracts.Claim(s, offers), 1, "claim returns the tier")
	eq(Contracts.Claim(s, offers), nil, "nothing to claim twice")
	eq(Contracts.Accept(s, 1, offers), false, "a finished contract cannot be retaken today")
	eq(Contracts.Accept(s, 2, offers), true, "another can be")
	Contracts.Record(s, offers, "Chain", nil, 12)
	Contracts.Record(s, offers, "Chain", nil, 8)
	eq(s.Progress, 12, "chain keeps the best")
	Contracts.Record(s, offers, "Chain", nil, 99)
	eq(s.Progress, 20, "chain capped at the target")
	eq(Contracts.Claim(s, offers), 2, "complete: claim")
	eq(Contracts.Accept(s, 3, offers), true, "next")
	eq(Contracts.Claim(s, offers), nil, "incomplete cannot be claimed")
	eq(Contracts.Abandon(s), true, "abandon")
	eq(s.Progress, 0, "progress lost")
	Contracts.Ensure(s, 6)
	eq(next(s.Done), nil, "a new day clears what was done")
end)

test("contracts: every reward is a valid grant and every kind is one the server records", function()
	local Grants2 = require("../../src/ReplicatedStorage/Shared/Grants")
	for _, list in ContractCfg.Rewards do
		for _, g in list do eq(Grants2.Valid(g), true, "valid grant") end
	end
	local recorded = { Slay = true, Chain = true, Critical = true, Boss = true, Floor = true }
	for _, t in ContractCfg.Templates do eq(recorded[t.Kind], true, t.Id .. " kind recorded") end
end)

test("schema: v13 saves migrate to v14 with an empty contract record", function()
	local d = Schema.Migrate({ SchemaVersion = 13, Shards = 7 })
	eq(d.SchemaVersion, Schema.CURRENT_VERSION, "version")
	eq(Schema.CURRENT_VERSION >= 14, true, "v14 exists")
	eq(d.Contract.Active, 0, "no active contract")
	eq(d.Shards, 7, "shards kept")
end)

-- World boss ---------------------------------------------------------------------------------------------------------
local WorldBoss = require("../../src/ReplicatedStorage/Shared/WorldBoss")
local WBCfg = require("../../src/ReplicatedStorage/Shared/Config/WorldBoss")

test("worldboss: the window opens at the start of each cycle and closes exactly after ActiveSeconds", function()
	local base = 1800 * 1000
	local w = WorldBoss.Window(base, WBCfg)
	eq(w.Active, true, "open at the very start")
	eq(w.EndsIn, WBCfg.ActiveSeconds, "full time left")
	eq(WorldBoss.Window(base + WBCfg.ActiveSeconds - 1, WBCfg).Active, true, "last second still open")
	local closed = WorldBoss.Window(base + WBCfg.ActiveSeconds, WBCfg)
	eq(closed.Active, false, "closed at ActiveSeconds")
	eq(closed.NextIn, 1800 - WBCfg.ActiveSeconds, "time until the next one")
	eq(WorldBoss.Window(base + 1799, WBCfg).NextIn, 1, "one second before the next")
	eq(WorldBoss.Window(base + 1800, WBCfg).Cycle, 1001, "next cycle number")
end)

test("worldboss: hp scales with players, never below the minimum", function()
	eq(WorldBoss.MaxHP(1, WBCfg), WBCfg.BaseHP + WBCfg.HPPerPlayer * WBCfg.MinPlayers, "solo is treated as the minimum")
	eq(WorldBoss.MaxHP(10, WBCfg), WBCfg.BaseHP + WBCfg.HPPerPlayer * 10, "ten players")
	eq(WorldBoss.MaxHP(0, WBCfg) > 0, true, "zero players still positive")
end)

test("worldboss: volley damage grows faster than pops, junk does nothing", function()
	eq(WorldBoss.VolleyDamage(0, WBCfg), 0, "no pops")
	eq(WorldBoss.VolleyDamage(-5, WBCfg), 0, "negative")
	eq(WorldBoss.VolleyDamage(0 / 0, WBCfg), 0, "NaN")
	eq(WorldBoss.VolleyDamage(40, WBCfg) > 2 * WorldBoss.VolleyDamage(20, WBCfg), true, "a big chain beats two small ones")
	eq(WorldBoss.VolleyDamage(1e9, WBCfg), WorldBoss.VolleyDamage(500, WBCfg), "capped")
end)

test("worldboss: hits accumulate per player, the boss falls exactly at zero and takes nothing after", function()
	local st = WorldBoss.New(1, 3, WBCfg)
	local total = 0
	total += WorldBoss.Hit(st, 11, 20, WBCfg)
	total += WorldBoss.Hit(st, 22, 10, WBCfg)
	eq(st.HP, st.MaxHP - total, "hp went down by what was dealt")
	eq(st.Damage[11], WorldBoss.VolleyDamage(20, WBCfg), "player one")
	eq(WorldBoss.Hit(st, "x" :: any, 20, WBCfg), 0, "junk user id")
	local dealt = WorldBoss.Hit(st, 11, 500, WBCfg)
	eq(dealt <= st.MaxHP, true, "cannot deal more than the boss had")
	eq(st.Done, true, "down")
	eq(st.HP, 0, "exactly zero, never negative")
	eq(WorldBoss.Hit(st, 22, 30, WBCfg), 0, "no damage after it is down")
	local sum = 0
	for _, d in st.Damage do sum += d end
	eq(sum, st.MaxHP, "all damage recorded adds up to the boss's hp")
end)

test("worldboss: ranking breaks ties by user id, settlement pays once with tiers", function()
	local st = WorldBoss.New(1, 3, WBCfg)
	st.Damage = { [5] = 100, [3] = 100, [9] = 300, [7] = 10, [2] = 60, [8] = 40 }
	local order = WorldBoss.Ranking(st)
	eq(order[1].UserId, 9, "top damage")
	eq(order[2].UserId, 3, "tie: lower id first")
	eq(order[3].UserId, 5, "tie: higher id second")
	st.Done = true
	local pay = WorldBoss.Settle(st, WBCfg)
	local by = {}
	for _, p in pay do by[p.UserId] = p end
	eq(by[7], nil, "below MinDamage gets nothing")
	eq(#by[9].Grants, #WBCfg.Rewards.Participant + #WBCfg.Rewards.Defeated + #WBCfg.Rewards.Top, "top three get everything")
	eq(#by[2].Grants, #WBCfg.Rewards.Participant + #WBCfg.Rewards.Defeated, "rank 4 gets participant and defeat rewards")
	eq(#WorldBoss.Settle(st, WBCfg), 0, "settling twice pays nothing")
	local lost = WorldBoss.New(2, 3, WBCfg)
	lost.Damage = { [1] = 500 }
	local consolation = WorldBoss.Settle(lost, WBCfg)
	eq(#consolation[1].Grants, #WBCfg.Rewards.Participant, "if it was not beaten only the participant reward")
end)

test("worldboss: every reward is a valid grant and the view hides a settled boss", function()
	local G = require("../../src/ReplicatedStorage/Shared/Grants")
	for _, list in WBCfg.Rewards do
		for _, g in list do eq(G.Valid(g), true, "valid grant") end
	end
	local st = WorldBoss.New(1, 3, WBCfg)
	eq(WorldBoss.View(st, 1800 * 5 + 10, WBCfg).Active, true, "up")
	eq(WorldBoss.View(nil, 1800 * 5 + 10, WBCfg).Active, false, "none")
	WorldBoss.Settle(st, WBCfg)
	eq(WorldBoss.View(st, 1800 * 5 + 10, WBCfg).Active, false, "settled")
end)

-- Blastwright Plus ---------------------------------------------------------------------------------------------------
local PlusMod = require("../../src/ReplicatedStorage/Shared/Plus")
local PlusCfg = require("../../src/ReplicatedStorage/Shared/Config/Plus")

test("plus: the daily gift is paid once per UTC day and never for junk or a clock that went backwards", function()
	local st = PlusMod.Default()
	eq(PlusMod.ClaimDaily(st, 20000), true, "first claim")
	eq(PlusMod.ClaimDaily(st, 20000), false, "same day")
	eq(PlusMod.ClaimDaily(st, 19999), false, "an earlier day")
	eq(PlusMod.ClaimDaily(st, 0 / 0), false, "NaN")
	eq(PlusMod.ClaimDaily(st, "x" :: any), false, "junk")
	eq(PlusMod.ClaimDaily(st, 20001), true, "next day")
end)

test("plus: config points at a real pass, a valid title and valid gift grants; the save migrates to v15", function()
	local G = require("../../src/ReplicatedStorage/Shared/Grants")
	eq(Products.Gamepasses[PlusCfg.Pass] ~= nil, true, "pass exists")
	eq(G.Valid({ Kind = "Title", Title = PlusCfg.Title }), true, "title valid")
	for _, g in PlusCfg.DailyGift do eq(G.Valid(g), true, "gift grant valid") end
	local d = Schema.Migrate({ SchemaVersion = 14, Shards = 3 })
	eq(d.Plus.LastDay, 0, "plus record")
	eq(Schema.CURRENT_VERSION >= 15, true, "v15 exists")
	local d2 = freshSave()
	G.Apply(d2, { { Kind = "Title", Title = PlusCfg.Title } }, 0, 1)
	G.Apply(d2, { { Kind = "Title", Title = PlusCfg.Title } }, 0, 1)
	eq(d2.Mastery.Extra[PlusCfg.Title], true, "title granted (twice is harmless)")
end)

-- Assay Office -------------------------------------------------------------------------------------------------------
local Assay = require("../../src/ReplicatedStorage/Shared/Assay")
local AssayCfg = require("../../src/ReplicatedStorage/Shared/Config/Assay")
local AssayKinds = { "Glimmerstone", "Kindlequartz" }

test("assay: tiers rise, and pops are counted per kind ignoring junk", function()
	for i = 2, #AssayCfg.Tiers do
		eq(AssayCfg.Tiers[i].Pops > AssayCfg.Tiers[i - 1].Pops and AssayCfg.Tiers[i].Reward > AssayCfg.Tiers[i - 1].Reward, true, "tier " .. i .. " rises")
	end
	local st = Assay.Default()
	Assay.Record(st, "Glimmerstone", 30)
	Assay.Record(st, "Glimmerstone", 0)
	Assay.Record(st, "Glimmerstone", -4)
	Assay.Record(st, "Glimmerstone", 0 / 0)
	Assay.Record(st, 5 :: any, 10)
	eq(st.Pops.Glimmerstone, 30, "only the good record counted")
	eq(st.Pops.Kindlequartz, nil, "other kinds untouched")
end)

test("assay: a tier is claimable exactly at its threshold, once, only for real kinds and real tiers", function()
	local st = Assay.Default()
	Assay.Record(st, "Glimmerstone", AssayCfg.Tiers[1].Pops - 1)
	eq(Assay.Claim(st, "Glimmerstone", 1, AssayKinds, AssayCfg), nil, "one short")
	Assay.Record(st, "Glimmerstone", 1)
	for _, junk in { 0, 9, -1, 1.5, "1", true, {} } do
		eq(Assay.Claim(st, "Glimmerstone", junk, AssayKinds, AssayCfg), nil, "junk tier")
	end
	for _, junk in { 5, true, {}, "Nope", "" } do
		eq(Assay.Claim(st, junk, 1, AssayKinds, AssayCfg), nil, "junk kind")
	end
	eq(Assay.Claim(st, "Glimmerstone", 1, AssayKinds, AssayCfg), AssayCfg.Tiers[1].Reward, "exactly at the threshold")
	eq(Assay.Claim(st, "Glimmerstone", 1, AssayKinds, AssayCfg), nil, "only once")
	eq(Assay.Claim(st, "Glimmerstone", 2, AssayKinds, AssayCfg), nil, "the next tier is not reached")
	eq(Assay.Claim(st, "Kindlequartz", 1, AssayKinds, AssayCfg), nil, "another kind has no pops")
	Assay.Record(st, "Ghost", 5000)
	eq(Assay.Claim(st, "Ghost", 1, AssayKinds, AssayCfg), nil, "a kind that is not a crystal cannot be claimed even with pops recorded")
end)

test("assay: the title needs every kind at the title tier, and the view lists what can be claimed", function()
	local st = Assay.Default()
	local need = AssayCfg.Tiers[AssayCfg.TitleTier].Pops
	Assay.Record(st, "Glimmerstone", need)
	eq(Assay.TitleEarned(st, AssayKinds, AssayCfg), false, "one kind is not enough")
	Assay.Record(st, "Kindlequartz", need - 1)
	eq(Assay.TitleEarned(st, AssayKinds, AssayCfg), false, "one pop short")
	Assay.Record(st, "Kindlequartz", 1)
	eq(Assay.TitleEarned(st, AssayKinds, AssayCfg), true, "all kinds at Master")
	eq(Assay.TitleEarned(st, {}, AssayCfg), false, "no kinds, no title")
	local v = Assay.View(st, AssayKinds, AssayCfg)
	eq(#v[1].Claimable, AssayCfg.TitleTier, "tiers up to Master are claimable")
	eq(v[1].Next.Index, AssayCfg.TitleTier + 1, "the next goal is the tier after")
	Assay.Claim(st, "Glimmerstone", 1, AssayKinds, AssayCfg)
	eq(#Assay.View(st, AssayKinds, AssayCfg)[1].Claimable, AssayCfg.TitleTier - 1, "a claimed tier leaves the list")
end)

test("assay: the save migrates to v16 with an empty record and the title is a valid grant", function()
	local d = Schema.Migrate({ SchemaVersion = 15, Shards = 2 })
	eq(next(d.Assay.Pops), nil, "empty")
	eq(Schema.CURRENT_VERSION >= 16, true, "v16 exists")
	eq(require("../../src/ReplicatedStorage/Shared/Grants").Valid({ Kind = "Title", Title = AssayCfg.Title }), true, "title valid")
end)

-- Trait tree and shape extras ----------------------------------------------------------------------------------------
local Loadout = require("../../src/ReplicatedStorage/Shared/Loadout")
local TraitsCfg = require("../../src/ReplicatedStorage/Shared/Config/Traits")
local function shapeSet(cells)
	local set, n = {}, 0
	for _, c in cells do set[c.X .. "," .. c.Z] = c; n += 1 end
	return set, n
end

test("shapes: a Ring skips its middle, Width thickens lines, Diagonal adds the star, nothing is counted twice", function()
	local ring, rn = shapeSet(ChainSim.BlastCells("Ring", 5, 5, 2.5, 0, 9, { Inner = 1 }))
	eq(ring["5,5"], nil, "the centre is skipped")
	eq(ring["6,5"], nil, "the touching neighbour is skipped (distance 1 is not beyond the hole)")
	eq(ring["6,6"] ~= nil and ring["7,5"] ~= nil and ring["7,6"] ~= nil, true, "the ring itself")
	eq(ring["8,5"], nil, "beyond the outer radius")
	eq(rn, 16, "sixteen cells in a 1 to 2.5 ring")
	local _, filled = shapeSet(ChainSim.BlastCells("Ring", 5, 5, 2.5, 0, 9, { Inner = 0 }))
	eq(filled, 21, "no hole: the whole disc of radius 2.5, middle included")
	local _, plain = shapeSet(ChainSim.BlastCells("Column", 5, 5, 0, 4, 9))
	eq(plain, 9, "a plain column is one lane")
	local wide, wn = shapeSet(ChainSim.BlastCells("Column", 5, 5, 0, 4, 9, { Width = 1 }))
	eq(wn, 27, "width 1 = three lanes")
	eq(wide["4,1"] ~= nil and wide["6,9"] ~= nil, true, "the outer lanes reach the ends")
	local _, wider = shapeSet(ChainSim.BlastCells("Column", 5, 5, 0, 4, 9, { Width = 2 }))
	eq(wider, 45, "width 2 = five lanes")
	local _, edge = shapeSet(ChainSim.BlastCells("Column", 1, 5, 0, 4, 9, { Width = 1 }))
	eq(edge, 18, "lanes are clipped at the grid edge")
	local _, cross = shapeSet(ChainSim.BlastCells("Cross", 5, 5, 0, 4, 9))
	eq(cross, 17, "a plain cross of range 4")
	local star, sn = shapeSet(ChainSim.BlastCells("Cross", 5, 5, 0, 4, 9, { Diagonal = true }))
	eq(sn, 33, "a star adds 16 diagonal cells (4 per diagonal arm)")
	eq(star["6,6"] ~= nil and star["9,1"] ~= nil and star["1,9"] ~= nil, true, "diagonals reach the corners")
	local _, thick = shapeSet(ChainSim.BlastCells("Cross", 5, 5, 0, 4, 9, { Width = 1 }))
	eq(thick, 45, "thick arms: two 3x9 bars overlapping in a 3x3, counted once")
end)

test("shapes: a charge's DirectMult pays only the crystals it hits directly, not the ones the chain reaches", function()
	local function ctxWith(mult)
		local charges = { Basic = { Name = "b", Shape = "Radius", Radius = 1.5, DirectMult = mult } }
		return { Crystals = Crystals.Defs, Charges = charges, Tuning = Tuning }
	end
	local g = { Size = 9, Cells = {} }
	g.Cells[ChainSim.Key(9, 5, 5)] = { Kind = "Glimmerstone" }
	g.Cells[ChainSim.Key(9, 5, 6)] = { Kind = "Kindlequartz" } -- volatile: sets off its neighbours as a chain
	g.Cells[ChainSim.Key(9, 5, 8)] = { Kind = "Glimmerstone" } -- reached only by the chain, not by the charge
	local base = ChainSim.Run(g, { { X = 5, Z = 5, Kind = "Basic" } }, ctxWith(nil))
	local boosted = ChainSim.Run(g, { { X = 5, Z = 5, Kind = "Basic" } }, ctxWith(2))
	eq(base.Pops, boosted.Pops, "the mult never changes what pops")
	local function valueAt(result, x, z)
		for _, ev in result.Events do if ev.X == x and ev.Z == z then return ev.Value, ev.Cause end end
		return nil
	end
	local v1, c1 = valueAt(base, 5, 5)
	local v2 = valueAt(boosted, 5, 5)
	eq(c1, "Charge", "the cell under the charge is a direct hit")
	eq(v2, v1 * 2, "direct hits pay double")
	local far1, farCause = valueAt(base, 5, 8)
	local far2 = valueAt(boosted, 5, 8)
	if far1 ~= nil then
		eq(farCause ~= "Charge", true, "the far crystal was set off by the chain")
		eq(far2, far1, "chain-reached crystals are not boosted")
	end
end)

test("traits: config is coherent (every node listed once, requirements and groups make sense, costs rise by tier)", function()
	local seen = {}
	for _, id in TraitsCfg.Order do
		eq(TraitsCfg.Nodes[id] ~= nil, true, id .. " is defined")
		eq(seen[id], nil, id .. " listed once")
		seen[id] = true
	end
	for id, node in TraitsCfg.Nodes do
		eq(seen[id], true, id .. " is in Order")
		eq(Charges.Defs[node.Branch] ~= nil, true, id .. " belongs to a real charge")
		eq(node.Cost > 0, true, id .. " costs something")
		if node.Requires then
			local req = TraitsCfg.Nodes[node.Requires]
			eq(req ~= nil and req.Branch == node.Branch and req.Tier == node.Tier - 1, true, id .. " requires the previous tier of its own branch")
		else
			eq(node.Tier, 1, id .. " with no requirement is tier 1")
		end
		if node.Group then
			local rivals = 0
			for _, other in TraitsCfg.Nodes do if other.Group == node.Group then rivals += 1 end end
			eq(rivals, 2, id .. " is one of exactly two in its fork")
		end
	end
	for _, branch in TraitsCfg.BranchOrder do
		local tiers = { 0, 0, 0 }
		for _, node in TraitsCfg.Nodes do if node.Branch == branch then tiers[node.Tier] += 1 end end
		eq(tiers[1] == 1 and tiers[2] == 2 and tiers[3] == 2, true, branch .. " has 1 + 2 + 2 nodes")
	end
	eq(#TraitsCfg.BranchOrder, #Charges.Order, "every charge has a branch")
end)

test("traits: buying needs the charge, the previous tier, shards and respects the fork", function()
	local st = Loadout.Default()
	local basicOnly = { Basic = true }
	eq(select(1, Loadout.CanBuy(st, "BoreBroad", TraitsCfg, basicOnly, 1e9)), false, "the charge is not unlocked")
	eq(select(1, Loadout.CanBuy(st, "CapShaped", TraitsCfg, basicOnly, 1e9)), false, "tier 2 needs tier 1")
	eq(select(1, Loadout.CanBuy(st, "CapPacked", TraitsCfg, basicOnly, TraitsCfg.Nodes.CapPacked.Cost - 1)), false, "one shard short")
	eq(Loadout.Buy(st, "CapPacked", TraitsCfg, basicOnly, TraitsCfg.Nodes.CapPacked.Cost), TraitsCfg.Nodes.CapPacked.Cost, "bought exactly at the price")
	eq(Loadout.Buy(st, "CapPacked", TraitsCfg, basicOnly, 1e9), nil, "cannot be bought twice")
	eq(Loadout.Buy(st, "CapShaped", TraitsCfg, basicOnly, 1e9) ~= nil, true, "the fork: take one")
	eq(select(1, Loadout.CanBuy(st, "CapWide", TraitsCfg, basicOnly, 1e9)), false, "the rival is locked out")
	eq(select(1, Loadout.CanBuy(st, "CapMega", TraitsCfg, basicOnly, 1e9)), false, "the rival's capstone needs the rival")
	eq(select(1, Loadout.CanBuy(st, "CapDemolition", TraitsCfg, basicOnly, 1e9)), true, "the chosen path continues")
	for _, junk in { 5, true, {}, "Nope", "", "__index" } do
		eq(select(1, Loadout.CanBuy(st, junk, TraitsCfg, basicOnly, 1e9)), false, "junk id")
		eq(Loadout.Buy(st, junk, TraitsCfg, basicOnly, 1e9), nil, "junk id cannot be bought")
	end
end)

test("traits: respec clears only that branch and takes the fork back", function()
	local st = Loadout.Default()
	local all = { Basic = true, Shaft = true }
	Loadout.Buy(st, "CapPacked", TraitsCfg, all, 1e9)
	Loadout.Buy(st, "CapShaped", TraitsCfg, all, 1e9)
	Loadout.Buy(st, "BoreBroad", TraitsCfg, all, 1e9)
	eq(Loadout.Respec(st, 5 :: any, TraitsCfg), 0, "junk branch")
	eq(Loadout.Respec(st, "Cross", TraitsCfg), 0, "an empty branch removes nothing")
	eq(Loadout.Respec(st, "Basic", TraitsCfg), 2, "two removed")
	eq(st.Owned.BoreBroad, true, "another branch is untouched")
	eq(Loadout.Buy(st, "CapPacked", TraitsCfg, all, 1e9) ~= nil, true, "start again")
	eq(Loadout.Buy(st, "CapWide", TraitsCfg, all, 1e9) ~= nil, true, "and take the other fork")
end)

test("traits: effective charges apply owned effects only, never mutate the base, and match what ChainSim covers", function()
	local base = Charges.Defs
	local before = base.Shaft.Width
	local st = Loadout.Default()
	local all = { Basic = true, Shaft = true, Cross = true, Shock = true }
	local plain = Loadout.Charges(base, st, TraitsCfg, 0)
	eq(plain.Basic.Radius, base.Basic.Radius, "no traits: unchanged")
	for _, id in { "CapPacked", "CapWide", "CapMega", "BoreBroad", "BoreTrench", "CrossHeavy", "CrossStar", "ShockTuned", "ShockCore" } do
		st.Owned[id] = true
	end
	local eff = Loadout.Charges(base, st, TraitsCfg, 0.5)
	eq(eff.Basic.Radius, base.Basic.Radius + 0.5 + 0.5 + 0.75 + 0.5, "cap: packed + wide + mega + the Fat Fuse bonus")
	eq(eff.Shaft.Width, 2, "bore: two width upgrades")
	eq(eff.Cross.Diagonal, true, "cross: star")
	eq(eff.Cross.DirectMult, 1.25, "cross: heavy arms")
	eq(eff.Shock.Radius, base.Shock.Radius + 0.5, "shock: tuned coil")
	eq(eff.Shock.Inner, 0, "shock core fills the hole (never below zero)")
	eq(eff.Shaft.Radius or 0, 0, "the fat-fuse bonus is only for round blasts")
	eq(base.Shaft.Width, before, "the base definitions are untouched")
	local _, cells = shapeSet(ChainSim.BlastCells(eff.Shaft.Shape, 5, 5, eff.Shaft.Radius or 0, eff.Shaft.Range or 0, 9, eff.Shaft))
	eq(cells, 45, "the sim covers five lanes for a Trench bore")
end)

test("charges: every charge type has a role line, a priced unlock except the first, and a Direct damage entry for combat", function()
	local LurkerCfg2 = require("../../src/ReplicatedStorage/Shared/Config/Lurkers")
	local BossCfg2 = require("../../src/ReplicatedStorage/Shared/Config/Bosses")
	for id, def in Charges.Defs do
		eq(type(def.Role) == "string" and def.Role ~= "", true, id .. " has a role")
		eq(id == "Basic" or (def.UnlockCost or 0) > 0, true, id .. " is a priced unlock")
		eq(LurkerCfg2.Damage.Direct[id] ~= nil, true, id .. " has Lurker damage")
		for kind, boss in BossCfg2.Defs do eq(boss.Direct[id] ~= nil, true, kind .. " boss has damage for " .. id) end
	end
end)

test("upgrades: every rig upgrade has ascending prices; unlock prices rise across areas and charges", function()
	local U = require("../../src/ReplicatedStorage/Shared/Config/Upgrades")
	local Strata2 = require("../../src/ReplicatedStorage/Shared/Config/Strata")
	for _, id in U.Order do
		local d = U.Defs[id]
		eq(d ~= nil and #d.Costs >= 1 and d.PerLevel > 0, true, id .. " is defined")
		for i = 2, #d.Costs do eq(d.Costs[i] > d.Costs[i - 1], true, id .. " price rises") end
	end
	for i = 2, #Strata2 do eq(Strata2[i].Cost > Strata2[i - 1].Cost, true, "area price rises") end
end)

-- Specimens, Track and Streak ------------------------------------------------------------------------------------------
local Specimens = require("../../src/ReplicatedStorage/Shared/Specimens")
local SpecCfg = require("../../src/ReplicatedStorage/Shared/Config/Specimens")
local Track = require("../../src/ReplicatedStorage/Shared/Track")
local TrackCfg = require("../../src/ReplicatedStorage/Shared/Config/Track")
local Streak = require("../../src/ReplicatedStorage/Shared/Streak")
local StreakCfg = require("../../src/ReplicatedStorage/Shared/Config/Streak")
local GrantsMod = require("../../src/ReplicatedStorage/Shared/Grants")

local function seqRng(list)
	local i = 0
	return function() i += 1; return list[(i - 1) % #list + 1] end
end
local function lcgRng(seed)
	local s = seed
	return function() s = (s * 48271) % 2147483647; return s / 2147483647 end
end

test("specimens: config is coherent (rarities rise in value, milestones fit the cabinet and rise)", function()
	for i = 2, #SpecCfg.Rarities do
		eq(SpecCfg.Rarities[i].Weight < SpecCfg.Rarities[i - 1].Weight, true, "rarer grades have lower weight")
		eq(SpecCfg.Rarities[i].Dust > SpecCfg.Rarities[i - 1].Dust, true, "rarer grades are worth more dust")
	end
	local total = #Crystals.Order * #SpecCfg.Rarities
	local last = 0
	for _, m in SpecCfg.Milestones do
		eq(m.Found > last and m.Found <= total, true, m.Title .. " is reachable and rising")
		eq(GrantsMod.Valid({ Kind = "Title", Title = m.Title }), true, m.Title .. " is a valid title")
		last = m.Found
	end
	eq(SpecCfg.Milestones[#SpecCfg.Milestones].Found, total, "the last milestone is the complete cabinet")
end)

test("specimens: drop chance grows with the chain and is capped; empty volleys never drop", function()
	eq(Specimens.DropChance(0, SpecCfg), 0, "no pops")
	eq(Specimens.DropChance(-3, SpecCfg), 0, "negative")
	eq(Specimens.DropChance(0 / 0, SpecCfg), 0, "NaN")
	eq(Specimens.DropChance(30, SpecCfg) > Specimens.DropChance(10, SpecCfg), true, "bigger chain, better chance")
	eq(Specimens.DropChance(9999, SpecCfg), SpecCfg.MaxChance, "capped")
	local st = Specimens.Default()
	eq(Specimens.Roll(seqRng({ 0 }), {}, 30, 1, st, SpecCfg), nil, "no popped kinds, no drop")
	eq(Specimens.Roll(seqRng({ 0.99 }), { "Glimmerstone" }, 30, 1, st, SpecCfg), nil, "a high roll misses")
	local drop = Specimens.Roll(seqRng({ 0, 0, 0 }), { "Glimmerstone", "Kindlequartz" }, 30, 1, st, SpecCfg)
	eq(drop ~= nil and drop.Kind == "Glimmerstone" and drop.Rarity == "Common", true, "lowest rolls give the first kind and the lowest grade")
	eq(drop.Id, "Glimmerstone:Common", "the id joins kind and grade")
end)

test("specimens: a big chain leans toward better grades, and luck helps (measured over many rolls)", function()
	local function share(pops, luck)
		local rng, hits, n = lcgRng(99), 0, 4000
		local st = Specimens.Default()
		for _ = 1, n do
			local r = Specimens.RollRarity(rng, pops, luck, st.Pity, SpecCfg)
			if r ~= "Common" and r ~= "Uncommon" then hits += 1 end
		end
		return hits / n
	end
	eq(share(40, 1) > share(5, 1) * 1.5, true, "a 40-pop chain finds Rare or better much more often than a 5-pop one")
	eq(share(20, 3) > share(20, 1), true, "more luck, better grades")
	eq(share(20, 0) > 0, true, "with no luck the top grades are still possible")
end)

test("specimens: pity forces at least Epic then Legendary, and is reset by a top grade", function()
	local st = Specimens.Default()
	st.Pity.Epic = SpecCfg.EpicPity
	for seed = 1, 200 do
		local r = Specimens.RollRarity(lcgRng(seed), 1, 0, st.Pity, SpecCfg)
		eq(r == "Common" or r == "Uncommon" or r == "Rare", false, "epic pity: never below Epic")
	end
	st.Pity.Legendary = SpecCfg.LegendaryPity
	for seed = 1, 200 do
		local r = Specimens.RollRarity(lcgRng(seed), 1, 0, st.Pity, SpecCfg)
		eq(r == "Legendary" or r == "Mythic", true, "legendary pity: at least Legendary")
	end
	local s2 = Specimens.Default()
	Specimens.Record(s2, { Kind = "Glimmerstone", Rarity = "Common", Id = "Glimmerstone:Common" }, SpecCfg)
	eq(s2.Pity.Epic, 1, "a common find advances the pity")
	Specimens.Record(s2, { Kind = "Glimmerstone", Rarity = "Epic", Id = "Glimmerstone:Epic" }, SpecCfg)
	eq(s2.Pity.Epic, 0, "an epic resets the epic pity")
	eq(s2.Pity.Legendary, 2, "but not the legendary pity")
	Specimens.Record(s2, { Kind = "Glimmerstone", Rarity = "Mythic", Id = "Glimmerstone:Mythic" }, SpecCfg)
	eq(s2.Pity.Legendary, 0, "a mythic resets both")
end)

test("specimens: recording marks new finds, pays dust for duplicates, counts the cabinet, pays each milestone once", function()
	local st = Specimens.Default()
	local drop = { Kind = "Resonite", Rarity = "Rare", Id = "Resonite:Rare" }
	local first = Specimens.Record(st, drop, SpecCfg)
	eq(first.New and first.Dust == 0 and first.Count == 1, true, "a first find is new and pays no dust")
	local dupe = Specimens.Record(st, drop, SpecCfg)
	eq(dupe.New == false and dupe.Count == 2 and dupe.Dust == SpecCfg.Rarities[3].Dust, true, "a duplicate pays the grade's dust")
	eq(Specimens.FoundCount(st), 1, "duplicates do not add slots")
	eq(st.Total, 2, "the total counts every drop")
	local m1 = SpecCfg.Milestones[1].Found
	for i = 1, m1 - 1 do
		Specimens.Record(st, { Kind = "K" .. i, Rarity = "Common", Id = "K" .. i .. ":Common" }, SpecCfg)
	end
	eq(#Specimens.NewMilestones(st, SpecCfg), 1, "the first milestone is reached")
	eq(#Specimens.NewMilestones(st, SpecCfg), 0, "and only paid once")
	local view = Specimens.View(st, { "Resonite" }, SpecCfg)
	eq(view[1].Have, 1, "the view counts grades found")
	eq(view[1].Grades[3].Count, 2, "and how many of each")
end)

test("track: levels need rising xp, xp is added safely, levels reached are reported", function()
	eq(Track.XpForLevel(1, TrackCfg), TrackCfg.XpBase, "level 1")
	eq(Track.XpForLevel(5, TrackCfg), TrackCfg.XpBase + 4 * TrackCfg.XpStep, "level 5")
	local st = Track.Default()
	local b, a = Track.Add(st, TrackCfg.XpBase - 1, TrackCfg)
	eq(b == 0 and a == 0, true, "one xp short of the first level")
	b, a = Track.Add(st, 1, TrackCfg)
	eq(b == 0 and a == 1, true, "exactly at the first level")
	for _, junk in { -50, 0, 0 / 0, math.huge, 1e12 } do
		local xp = st.Xp
		Track.Add(st, junk, TrackCfg)
		eq(st.Xp, xp, "junk xp changes nothing")
	end
	local level, into, need = Track.Progress(st.Xp, TrackCfg)
	eq(level == 2 and into == 0 and need == Track.XpForLevel(2, TrackCfg), true, "progress inside the level")
	local x = TrackCfg.Xp
	eq(Track.VolleyXp(0, TrackCfg), x.VolleyBase, "an empty volley still earns the base")
	eq(Track.VolleyXp(10000, TrackCfg), x.VolleyBase + x.PopsCap, "volley xp is capped")
end)

test("track: rewards need the level, premium needs the pass, nothing is claimed twice", function()
	local st = Track.Default()
	eq(Track.Claim(st, 1, false, false, TrackCfg), nil, "level 1 not reached")
	Track.Add(st, 100000, TrackCfg)
	for _, junk in { 0, -1, 1.5, "1", true, {} } do
		eq(Track.Claim(st, junk :: any, false, false, TrackCfg), nil, "junk level")
	end
	eq(Track.Claim(st, 1, "no" :: any, false, TrackCfg), nil, "junk track")
	eq(Track.Claim(st, 1, true, false, TrackCfg), nil, "premium without the pass")
	eq(Track.Claim(st, 1, true, true, TrackCfg) ~= nil, true, "premium with the pass")
	eq(Track.Claim(st, 1, true, true, TrackCfg), nil, "premium only once")
	eq(Track.Claim(st, 1, false, false, TrackCfg) ~= nil, true, "the free reward is independent")
	eq(Track.Claim(st, 1, false, false, TrackCfg), nil, "free only once")
	local reached = Track.LevelsReached(st.Xp, TrackCfg)
	eq(reached > TrackCfg.MaxLevel, true, "enough xp to go past the end")
	eq(Track.Claim(st, TrackCfg.MaxLevel + 1, true, true, TrackCfg), nil, "no premium reward beyond the last level")
	eq(Track.Claim(st, TrackCfg.MaxLevel + 1, false, false, TrackCfg) ~= nil, true, "but a small free reward for every extra level")
	local pass = Track.Default()
	Track.Add(pass, Track.XpForLevel(1, TrackCfg) * 3 + TrackCfg.XpStep * 3, TrackCfg)
	local before = Track.ClaimableCount(pass, false, TrackCfg)
	eq(Track.ClaimableCount(pass, true, TrackCfg) > before, true, "owning the pass adds claimable premium rewards")
end)

test("track: config is coherent (every level has a free and premium reward, all grants valid, titles unique)", function()
	eq(#TrackCfg.Levels, TrackCfg.MaxLevel, "a reward pair per level")
	local titles = {}
	for i, lvl in TrackCfg.Levels do
		eq(#lvl.Free > 0 and #lvl.Premium > 0, true, "level " .. i .. " has both rewards")
		for _, list in { lvl.Free, lvl.Premium } do
			for _, g in list do
				eq(GrantsMod.Valid(g), true, "level " .. i .. " grant valid")
				if g.Kind == "Title" then
					eq(titles[g.Title], nil, g.Title .. " is unique")
					titles[g.Title] = true
				end
			end
		end
	end
	for _, g in TrackCfg.BonusPerLevelAfterMax do eq(GrantsMod.Valid(g), true, "post-max grant valid") end
	local total = 0
	for l = 1, TrackCfg.MaxLevel do total += Track.XpForLevel(l, TrackCfg) end
	eq(total > 5000 and total < 60000, true, "the whole track is a few hours of xp, not minutes or months")
end)

test("streak: consecutive days build the streak, a miss resets it, Plus forgives one miss, once per day", function()
	local st = Streak.Default()
	eq(Streak.Claim(st, 100, false, StreakCfg) ~= nil, true, "first claim")
	eq(st.Count, 1, "day one")
	eq(Streak.Claim(st, 100, false, StreakCfg), nil, "not twice in a day")
	eq(Streak.Claim(st, 99, false, StreakCfg), nil, "not for an earlier day")
	eq(Streak.Claim(st, 0 / 0, false, StreakCfg), nil, "NaN")
	eq(Streak.Claim(st, "x" :: any, false, StreakCfg), nil, "junk")
	Streak.Claim(st, 101, false, StreakCfg)
	eq(st.Count, 2, "the next day continues")
	Streak.Claim(st, 103, false, StreakCfg)
	eq(st.Count, 1, "a missed day resets")
	Streak.Claim(st, 105, true, StreakCfg)
	eq(st.Count, 2, "Plus keeps the streak through one missed day")
	Streak.Claim(st, 108, true, StreakCfg)
	eq(st.Count, 1, "but not through two")
end)

test("streak: the cycle repeats every seven days, every reward is valid, the view says what to expect", function()
	eq(#StreakCfg.Days, 7, "a week")
	for i, day in StreakCfg.Days do
		for _, g in day do eq(GrantsMod.Valid(g), true, "day " .. i .. " grant valid") end
	end
	eq(Streak.CycleDay(1, StreakCfg), 1, "first day")
	eq(Streak.CycleDay(7, StreakCfg), 7, "seventh day")
	eq(Streak.CycleDay(8, StreakCfg), 1, "then it starts over")
	eq(Streak.CycleDay(15, StreakCfg), 1, "and again")
	local st = Streak.Default()
	local v = Streak.View(st, 50, false, StreakCfg)
	eq(v.CanClaim and v.Count == 1 and v.CycleDay == 1, true, "a new player can claim day one")
	Streak.Claim(st, 50, false, StreakCfg)
	v = Streak.View(st, 50, false, StreakCfg)
	eq(v.CanClaim == false and v.Count == 1, true, "claimed today")
	v = Streak.View(st, 51, false, StreakCfg)
	eq(v.CanClaim and v.Count == 2 and v.CycleDay == 2, true, "tomorrow is day two")
	v = Streak.View(st, 55, false, StreakCfg)
	eq(v.Count, 1, "after a long gap the next claim restarts at day one")
end)

test("grants: describe gives readable text for every kind", function()
	local text = GrantsMod.Describe({ { Kind = "Shards", Amount = 12500, Scaled = true }, { Kind = "Tokens", Token = "Revive", Count = 2 }, { Kind = "Boost", Boost = "Luck", Mult = 2, Seconds = 900 }, { Kind = "Title", Title = "X" }, { Kind = "Finisher", Id = "Void" }, { Kind = "Cosmetic", Id = "Toxic" } })
	eq(text, "12,500 shards per area, 2 revive tokens, 2x luck 15m, title X, Void finisher, Toxic blasts", "the whole line")
end)

test("schema: v17 saves migrate to v18 with specimens, track and streak records", function()
	local d = Schema.Migrate({ SchemaVersion = 17, Shards = 6 })
	eq(d.Specimens.Total, 0, "specimens")
	eq(d.Track.Xp, 0, "track")
	eq(d.Streak.LastDay, 0, "streak")
	eq(Schema.CURRENT_VERSION >= 18, true, "v18 exists")
	eq(d.Shards, 6, "kept")
end)

-- Ascension ------------------------------------------------------------------------------------------------------------
local Ascension = require("../../src/ReplicatedStorage/Shared/Ascension")
local AscCfg = require("../../src/ReplicatedStorage/Shared/Config/Ascension")

test("ascension: config is coherent (every tier pays more, has a valid unique title, tiers are named)", function()
	local titles = {}
	for i, t in AscCfg.Tiers do
		eq(t.RewardMult > 1, true, "tier " .. i .. " pays more")
		eq(titles[t.Title], nil, "unique title")
		titles[t.Title] = true
		eq(require("../../src/ReplicatedStorage/Shared/Grants").Valid({ Kind = "Title", Title = t.Title }), true, "valid title")
		eq(type(t.Name) == "string" and type(t.Description) == "string", true, "named")
	end
	local prev = 1
	for i = 1, #AscCfg.Tiers do
		local m = Ascension.Effects(i, AscCfg).RewardMult
		eq(m > prev, true, "the combined reward rises with the tier")
		prev = m
	end
end)

test("ascension: effects accumulate up to the tier, clamp junk levels, and never take the rig below the minimum", function()
	local none = Ascension.Effects(0, AscCfg)
	eq(none.LurkerHP == 1 and none.BossHP == 1 and none.ChargeDelta == 0 and none.HeartsDelta == 0 and none.RewardMult == 1, true, "tier 0 changes nothing")
	local one = Ascension.Effects(1, AscCfg)
	eq(one.LurkerHP, 1.25, "tier 1")
	local two = Ascension.Effects(2, AscCfg)
	eq(two.LurkerHP, 1.25, "tier 2 keeps tier 1's rule")
	eq(two.ChargeDelta, -1, "and adds its own")
	local top = Ascension.Effects(#AscCfg.Tiers, AscCfg)
	eq(top.HeartsDelta, -1, "hearts")
	eq(top.ClearBonus, 0.15, "clear bonus")
	eq(top.LurkerHP, 1.25 * 1.25, "lurker health stacks")
	local over = Ascension.Effects(999, AscCfg)
	eq(over.RewardMult, top.RewardMult, "a level past the top is the top")
	eq(Ascension.Effects(-4, AscCfg).RewardMult, 1, "negative is normal")
	eq(Ascension.StartCharges(1, #AscCfg.Tiers, AscCfg), AscCfg.MinCharges, "never below the minimum charges")
	eq(Ascension.StartCharges(5, 2, AscCfg), 4, "one fewer charge at tier 2")
end)

test("ascension: you can pick any tier up to the highest unlocked, nothing else", function()
	local st = Ascension.Default()
	eq(Ascension.Select(st, 0, AscCfg), true, "normal is always allowed")
	eq(Ascension.Select(st, 1, AscCfg), false, "tier 1 is locked at the start")
	st.Unlocked = 2
	eq(Ascension.Select(st, 2, AscCfg), true, "the highest unlocked")
	eq(st.Selected, 2, "selected")
	eq(Ascension.Select(st, 3, AscCfg), false, "one too high")
	for _, junk in { -1, 1.5, "1", true, {}, 0 / 0, math.huge } do
		eq(Ascension.Select(st, junk, AscCfg), false, "junk level")
	end
	eq(st.Selected, 2, "junk never changes the selection")
	st.Unlocked = 999
	eq(Ascension.Select(st, 999, AscCfg), false, "cannot pick a tier that does not exist")
end)

test("ascension: winning at your top tier unlocks the next and earns the title; winning lower does not", function()
	local st = Ascension.Default()
	local r = Ascension.OnWin(st, 0, AscCfg)
	eq(r.Unlocked, 1, "the first normal win opens tier 1")
	eq(r.Title, nil, "no title for a normal win")
	r = Ascension.OnWin(st, 0, AscCfg)
	eq(r.Unlocked, nil, "a second normal win unlocks nothing more")
	r = Ascension.OnWin(st, 1, AscCfg)
	eq(r.Unlocked == 2 and r.Title == AscCfg.Tiers[1].Title, true, "winning tier 1 opens tier 2 and pays its title")
	r = Ascension.OnWin(st, 1, AscCfg)
	eq(r.Unlocked, nil, "replaying a lower tier unlocks nothing")
	st.Unlocked = #AscCfg.Tiers
	r = Ascension.OnWin(st, #AscCfg.Tiers, AscCfg)
	eq(r.Unlocked, nil, "nothing above the top tier")
	eq(st.Unlocked, #AscCfg.Tiers, "unchanged")
	eq(r.Title, AscCfg.Tiers[#AscCfg.Tiers].Title, "the top tier still pays its title")
end)

test("ascension: a run's hearts delta shifts the heart bonus, and the save migrates to v19", function()
	local run = Expedition.New(ExpCfg, 4)
	eq(Expedition.HeartsBonus(run, ExpCfg), 0, "no bonus")
	run.HeartsDelta = -1
	eq(Expedition.HeartsBonus(run, ExpCfg), -1, "one fewer heart")
	local d = Schema.Migrate({ SchemaVersion = 18, Shards = 5 })
	eq(d.Ascension.Unlocked, 0, "no tier unlocked")
	eq(Schema.CURRENT_VERSION >= 19, true, "v19 exists")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
