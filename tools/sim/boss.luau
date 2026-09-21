--!nonstrict
-- Boss sanity sim: tools/bin/luau.exe tools/sim/boss.luau [runs] [startCharges]
-- A greedy bot fights the Crystal Titan on random area-1 grids with the real rules (one charge per volley, dodges when it
-- can) to see whether the fight is winnable and how long it takes. It is a floor for skill, not a ceiling.
local ChainSim = require("../../src/ReplicatedStorage/Shared/ChainSim")
local Crystals = require("../../src/ReplicatedStorage/Shared/Config/Crystals")
local Charges = require("../../src/ReplicatedStorage/Shared/Config/Charges")
local Tuning = require("../../src/ReplicatedStorage/Shared/Config/Tuning")
local BossCfg = require("../../src/ReplicatedStorage/Shared/Config/Bosses")
local LurkerCfg = require("../../src/ReplicatedStorage/Shared/Config/Lurkers")
local Seam = require("../../src/ServerScriptService/Server/Seam")
local Boss = require("../../src/ReplicatedStorage/Shared/Boss")
local Power = require("../../src/ReplicatedStorage/Shared/Power")

local runs = tonumber(({ ... })[1]) or 200
local startCharges = tonumber(({ ... })[2]) or 4
local kinds = { "Basic", "Shaft", "Cross" }
local N = Tuning.GridSize
local ctx = { Crystals = Crystals.Defs, Charges = Charges.Defs, Tuning = Tuning, BlastCells = ChainSim.BlastCells, Size = N, RadiusBonus = 0, MomentumPops = Tuning.MomentumPops }

local function lcg(seed) local s = seed return function() s = (s * 48271) % 2147483647 return s / 2147483647 end end
local function cloneGrid(g)
	local cells = {}
	for k, c in g.Cells do cells[k] = { Kind = c.Kind, Mutated = c.Mutated } end
	return { Size = g.Size, Cells = cells }
end
local function cloneBoss(b)
	local c = table.clone(b)
	c.Nodes, c.Weak, c.Telegraph = table.clone(b.Nodes), table.clone(b.Weak), table.clone(b.Telegraph)
	return c
end
local function removeEvents(g, r)
	for _, ev in r.Events do g.Cells[ChainSim.Key(N, ev.X, ev.Z)] = nil end
end

-- Score a candidate single-charge volley by simulating the boss's own response (on clones).
local function bestVolley(b, g, critical, unlocked)
	local best, bestScore
	for _, kind in unlocked do
		for z = 1, N do
			for x = 1, N do
				local volley = { { X = x, Z = z, Kind = kind } }
				local g2, b2 = cloneGrid(g), cloneBoss(b)
				local r = ChainSim.Run(g2, volley, ctx)
				removeEvents(g2, r)
				local power = Power.Multiplier(r.Pops, critical, BossCfg.Power)
				local o = Boss.Apply(b2, volley, r, ctx, BossCfg, power, g2, lcg(1))
				local score = o.Damage * 10 + o.NodesBroken * 6 + (o.Killed and 1000 or 0) + r.Pops * 0.1
				if not bestScore or score > bestScore then best, bestScore = volley, score end
			end
		end
	end
	return best
end

local wins, collapses, hearts0, volleysTotal, charges0 = 0, 0, 0, 0, 0
local unlocked = { "Basic" }
if ({ ... })[3] == "all" then unlocked = kinds end
for run = 1, runs do
	local rng = lcg(run * 7919)
	local g = Seam.Generate(Crystals, Tuning, 1, run * 104729)
	local b = Boss.New("Titan", g, ctx, BossCfg, rng)
	local charges, hearts, critical, volleys = math.max(startCharges, startCharges), LurkerCfg.Hearts, 0, 0
	local won = false
	while charges > 0 and hearts > 0 and volleys < 60 do
		volleys += 1
		local volley = bestVolley(b, g, critical, unlocked)
		charges -= #volley
		local r = ChainSim.Run(g, volley, ctx)
		removeEvents(g, r)
		local power = Power.Multiplier(r.Pops, critical, BossCfg.Power)
		critical = Power.Advance(critical, r.Pops, BossCfg.Power)
		if r.Momentum then charges = math.min(startCharges, charges + 1) end
		local o = Boss.Apply(b, volley, r, ctx, BossCfg, power, g, rng)
		if o.Killed then won = true break end
		if o.PhaseChanged then charges = math.min(startCharges, charges + o.Refund) end
		local cut = Boss.Cut(b, r, BossCfg)
		local dodge = Boss.CanDodge(b) and not cut
		local act = Boss.Act(b, g, ctx, BossCfg, dodge, rng, cut)
		hearts -= act.HeartsLost
		local remaining = 0
		for _ in g.Cells do remaining += 1 end
		if remaining == 0 then break end
	end
	if won then wins += 1 else collapses += 1 end
	volleysTotal += volleys
	hearts0 += hearts
end
print(("Titan vs greedy bot (%d runs, %d charges, %s): wins %d (%.0f%%), losses %d, avg volleys %.1f, avg hearts left %.2f"):format(
	runs, startCharges, ({ ... })[3] == "all" and "all charges" or "Basic only", wins, wins / runs * 100, collapses, volleysTotal / runs, hearts0 / runs))
