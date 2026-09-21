--!nonstrict
-- Crystal-mix balance harness. For each candidate spawn-weight set it plays many seams with two planners and reports how
-- hard the puzzle is: pops per volley, how much of the grid gets cleared, longest chain, shards per seam.
-- Run: tools/bin/luau.exe tools/sim/balance.luau -a [stratum] [seamsPerCase]
-- It edits crystal weights in memory only; nothing on disk changes.
local ChainSim = require("../../src/ReplicatedStorage/Shared/ChainSim")
local Crystals = require("../../src/ReplicatedStorage/Shared/Config/Crystals")
local Charges = require("../../src/ReplicatedStorage/Shared/Config/Charges")
local Tuning = require("../../src/ReplicatedStorage/Shared/Config/Tuning")
local Seam = require("../../src/ServerScriptService/Server/Seam")

local a1, a2 = ...
local STRATUM = tonumber(a1) or 1
local SEAMS = tonumber(a2) or 40
local N = Tuning.GridSize

local rngState = 555
local function rnd(n)
	rngState = rngState * 48271 % 2147483647
	return rngState % n + 1
end

local ctx = { Crystals = Crystals.Defs, Charges = Charges.Defs, Tuning = Tuning }

local function play(policy, seed, chargeKinds)
	local grid = Seam.Generate(Crystals, Tuning, STRATUM, seed)
	local valuable = Seam.CountValuable(grid, Crystals)
	local charges, earned, popped, pops, volleys, best = Tuning.BaseCharges, 0, 0, 0, 0, 0
	while charges > 0 do
		local bestCand, bestResult = nil, nil
		local tries = policy == "casual" and 6 or N * N
		for i = 1, tries do
			local cand
			if policy == "casual" then
				cand = { X = rnd(N), Z = rnd(N), Kind = chargeKinds[rnd(#chargeKinds)] }
			else
				cand = { X = (i - 1) % N + 1, Z = (i - 1) // N + 1, Kind = "Basic" }
			end
			local r = ChainSim.Run(grid, { cand }, ctx)
			if bestResult == nil or r.Total > bestResult.Total then
				bestCand, bestResult = cand, r
			end
		end
		if bestResult == nil or bestResult.Total <= 0 then
			break
		end
		charges -= 1
		volleys += 1
		for _, ev in bestResult.Events do
			grid.Cells[ChainSim.Key(N, ev.X, ev.Z)] = nil
			if Crystals.Defs[ev.Kind].Value > 0 then
				popped += 1
			end
		end
		earned += bestResult.Total
		pops += bestResult.Pops
		best = math.max(best, bestResult.Pops)
		if bestResult.Momentum then
			charges = math.min(charges + 1, Tuning.BaseCharges)
		end
	end
	local fraction = valuable > 0 and popped / valuable or 1
	if fraction >= Tuning.ClearBonusMinFraction then
		earned += math.floor(earned * Tuning.ClearBonusRate * fraction)
	end
	return { earned = earned, pops = pops, volleys = volleys, best = best, cleared = fraction, valuable = valuable }
end

local function measure(policy)
	local sum = { earned = 0, pops = 0, volleys = 0, best = 0, cleared = 0, fullClear = 0, valuable = 0 }
	for s = 1, SEAMS do
		local r = play(policy, s * 104729 + 7, { "Basic" })
		sum.earned += r.earned
		sum.pops += r.pops
		sum.volleys += r.volleys
		sum.best = math.max(sum.best, r.best)
		sum.cleared += r.cleared
		sum.valuable += r.valuable
		if r.cleared >= 0.999 then
			sum.fullClear += 1
		end
	end
	return sum
end

local function report(label, sum)
	print(("  %-8s pops/volley %5.1f | cleared %3.0f%% (full clears %2d/%d) | longest chain %3d | %6.0f shards/seam"):format(
		label, sum.pops / math.max(sum.volleys, 1), 100 * sum.cleared / SEAMS, sum.fullClear, SEAMS, sum.best, sum.earned / SEAMS))
end

-- Weight sets to try, applied to crystals that exist in this stratum.
local cases = {
	{ name = "current", w = {} },
	{ name = "kindle 10", w = { Kindlequartz = 10 } },
	{ name = "kindle 7", w = { Kindlequartz = 7 } },
	{ name = "kindle 5", w = { Kindlequartz = 5 } },
	{ name = "kindle 7, more resonite", w = { Kindlequartz = 7, Resonite = 14 } },
	{ name = "TUNED A", w = { Kindlequartz = 7, Resonite = 10, Lensglass = 4, Slowburn = 4, Echostone = 3, Dreadgeode = 14 } },
	{ name = "TUNED B", w = { Kindlequartz = 6, Resonite = 10, Lensglass = 3, Slowburn = 3, Echostone = 2, Dreadgeode = 16 } },
}

local original = {}
for id, def in Crystals.Defs do
	original[id] = def.Weight
end

print(("Stratum %d, %d seams per case, 4 charges, Basic charge only, no upgrades:"):format(STRATUM, SEAMS))
for _, case in cases do
	for id, w in original do
		Crystals.Defs[id].Weight = case.w[id] or w
	end
	print(case.name)
	report("greedy", measure("greedy"))
	report("casual", measure("casual"))
end
