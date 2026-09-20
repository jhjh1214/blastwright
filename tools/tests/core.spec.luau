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
	eq(d.SchemaVersion, 1, "version")
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

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
