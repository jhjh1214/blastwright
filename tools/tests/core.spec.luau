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
	eq(#W.Sites, 12, "3 biomes x 4 sites")
	local half = (Tuning.GridSize * Tuning.CellSize + 6) / 2
	for i, a in W.Sites do
		eq(a.Id, i, "sequential id")
		if a.X - half < W.Bounds.MinX or a.X + half > W.Bounds.MaxX or a.Z - half < W.Bounds.MinZ or a.Z + half > W.Bounds.MaxZ then
			error("site out of bounds: " .. a.Name)
		end
		if math.sqrt((a.X - W.Hub.X) ^ 2 + (a.Z - W.Hub.Z) ^ 2) < W.Hub.Radius + half then error("site overlaps hub: " .. a.Name) end
		if W.DistToPath(a.X, a.Z) < half + W.PathHalfWidth then error("site blocks a path: " .. a.Name) end
		for j = i + 1, #W.Sites do
			local b = W.Sites[j]
			if math.abs(a.X - b.X) < half * 2 + 4 and math.abs(a.Z - b.Z) < half * 2 + 4 then error("sites overlap: " .. a.Name .. " / " .. b.Name) end
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
	eq(W.AreaName(-95, 300), "The Deep Roads", "between")
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
	local o = Objectives.Roam(snap({ Shards = 9999, Upgrades = { ExtraCharge = 3 }, StrataUnlocked = 3, Caches = { S1 = true, P2 = true }, Stats = { TotalPops = 999 } }), 0, 0, ocfg)
	eq(o.Id, "Explore", "id")
	eq(o.Text:find("2/17", 1, true) ~= nil, true, "cache progress")
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

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
