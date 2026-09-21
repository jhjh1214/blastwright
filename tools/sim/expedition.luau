--!nonstrict
-- Expedition survival sim: tools/bin/luau.exe tools/sim/expedition.luau -a [runs] [startCharges] [areasUnlocked] [multi]
-- A greedy bot dives through Expedition floors with the real rules (ChainSim, Expedition cards, relic modifiers, momentum
-- refunds). It plants ONE charge per volley (or up to `multi`) on the cell that scores best, picks cards with a simple
-- policy, and never fights Lurkers or bosses (they are measured elsewhere). It answers: how often does a floor collapse,
-- and how far does a plain player get? A floor for skill, not a ceiling.
local ChainSim = require("../../src/ReplicatedStorage/Shared/ChainSim")
local Crystals = require("../../src/ReplicatedStorage/Shared/Config/Crystals")
local Charges = require("../../src/ReplicatedStorage/Shared/Config/Charges")
local Tuning = require("../../src/ReplicatedStorage/Shared/Config/Tuning")
local ExpCfg = require("../../src/ReplicatedStorage/Shared/Config/Expedition")
local Seam = require("../../src/ServerScriptService/Server/Seam")
local Expedition = require("../../src/ReplicatedStorage/Shared/Expedition")

local args = { ... }
local runs = tonumber(args[1]) or 200
local startCharges = tonumber(args[2]) or Tuning.BaseCharges
local areas = tonumber(args[3]) or 2
local multi = tonumber(args[4]) or 1
local N = Tuning.GridSize

local function lcg(seed) local s = seed return function() s = (s * 48271) % 2147483647 return s / 2147483647 end end
local function cloneGrid(g)
	local cells = {}
	for k, c in g.Cells do cells[k] = { Kind = c.Kind, Mutated = c.Mutated } end
	return { Size = g.Size, Cells = cells }
end
local function valuable(g)
	local n = 0
	for _, c in g.Cells do if Crystals.Defs[c.Kind].Value > 0 then n += 1 end end
	return n
end

local function ctxFor(run)
	local m = Expedition.Modifiers(run, ExpCfg)
	return { Crystals = Crystals.Defs, Charges = Charges.Defs, Tuning = Tuning, RadiusBonus = 0, MomentumPops = math.max(3, Tuning.MomentumPops + m.MomentumPopsDelta), Modifiers = m }
end

-- Best next volley of up to `multi` Basic charges, chosen greedily by real payout.
local function bestVolley(g, ctx, count)
	local volley = {}
	for _ = 1, count do
		local best, bestTotal = nil, -1
		for z = 1, N do
			for x = 1, N do
				local trial = table.clone(volley)
				table.insert(trial, { X = x, Z = z, Kind = "Basic" })
				local total = ChainSim.Run(g, trial, ctx).Total
				if total > bestTotal then best, bestTotal = { X = x, Z = z, Kind = "Basic" }, total end
			end
		end
		if not best then break end
		table.insert(volley, best)
	end
	return volley
end

local reached, collapsedAt, wins, haulTotal = {}, {}, 0, 0
for f = 1, ExpCfg.Floors do reached[f], collapsedAt[f] = 0, 0 end
local clearSum, clearN = {}, {}
for f = 1, ExpCfg.Floors do clearSum[f], clearN[f] = 0, 0 end

for r = 1, runs do
	local rng = lcg(r * 7919)
	local run = Expedition.New(ExpCfg, startCharges)
	local dead = false
	while not dead do
		local floor = run.Floor
		reached[floor] += 1
		local stratum = Expedition.FloorStratum(floor, areas, ExpCfg)
		local g = Seam.Generate(Crystals, Tuning, stratum, r * 104729 + floor * 31, Tuning.MutationChance * (Expedition.Modifiers(run, ExpCfg).MutationChanceMult))
		local ctx = ctxFor(run)
		local total = valuable(g)
		local popped, earned, charges = 0, 0, run.Charges
		while charges > 0 and valuable(g) > 0 do
			local volley = bestVolley(g, ctx, math.min(multi, charges))
			charges -= #volley
			local res = ChainSim.Run(g, volley, ctx)
			for _, ev in res.Events do
				local cell = g.Cells[ChainSim.Key(N, ev.X, ev.Z)]
				if cell and Crystals.Defs[cell.Kind].Value > 0 then popped += 1 end
				g.Cells[ChainSim.Key(N, ev.X, ev.Z)] = nil
			end
			earned += math.floor(res.Total * run.ValueMult)
			if res.Momentum then charges = math.min(run.StartCharges, charges + 1) end
		end
		local fraction = total > 0 and popped / total or 1
		clearSum[floor] += fraction
		clearN[floor] += 1
		local outcome = Expedition.FloorEnded(run, earned, fraction, charges, rng, ExpCfg)
		if outcome == "Collapse" then
			collapsedAt[floor] += 1
			dead = true
		elseif outcome == "Victory" then
			wins += 1
			dead = true
		else
			-- card policy: a rest when low, greed when comfortable, otherwise the safe path; always take the relic
			local pick = 1
			local want = run.Charges <= 2 and "Rest" or (run.Charges >= startCharges and "Rich" or "Steady")
			for i, c in run.Choices do if c.Route == want then pick = i end end
			Expedition.Pick(run, pick, ExpCfg, rng)
		end
	end
	haulTotal += run.Haul
end

print(("Expedition greedy bot: %d runs, %d start charges, %d areas, %d charge(s) per volley"):format(runs, startCharges, areas, multi))
for f = 1, ExpCfg.Floors do
	local cleared = clearN[f] > 0 and clearSum[f] / clearN[f] * 100 or 0
	print(("  floor %d: reached %3d%%  collapsed here %3d%%  avg grid cleared %3.0f%%"):format(f, reached[f] / runs * 100, collapsedAt[f] / runs * 100, cleared))
end
print(("  completed all floors: %d%%, average haul %d"):format(wins / runs * 100, haulTotal / runs))
