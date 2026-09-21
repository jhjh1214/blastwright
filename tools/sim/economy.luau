--!nonstrict
-- Economy simulation: a bot plays a whole career using the REAL rules (ChainSim, Seam.Generate, Tuning, Upgrades,
-- Charges, Strata) and reports how many seams each milestone takes. Run: tools/bin/luau.exe tools/sim/economy.luau
--
-- The bot's planner is intentionally simple and cautious: one charge per volley, the single best cell (and best charge
-- kind) found by brute force. A skilled human planting several charges per volley will beat it; a casual one may not
-- match it. It counts ONLY blasting income (no dailies, weeklies, goals or geode caches), so real progression is
-- somewhat faster. Treat the output as a pacing sanity check, not a promise.
local ChainSim = require("../../src/ReplicatedStorage/Shared/ChainSim")
local Crystals = require("../../src/ReplicatedStorage/Shared/Config/Crystals")
local Charges = require("../../src/ReplicatedStorage/Shared/Config/Charges")
local Tuning = require("../../src/ReplicatedStorage/Shared/Config/Tuning")
local Upgrades = require("../../src/ReplicatedStorage/Shared/Config/Upgrades")
local Strata = require("../../src/ReplicatedStorage/Shared/Config/Strata")
local Seam = require("../../src/ServerScriptService/Server/Seam")

-- Arguments (after -a): [maxSeams] [policy]. policy = greedy (default, brute-force best cell) or casual (best of 6
-- random tries per volley, roughly an average player). Example: tools/bin/luau.exe tools/sim/economy.luau -a 400 casual
local arg1, arg2 = ...
local MAX_SEAMS = tonumber(arg1) or 220
local POLICY = arg2 or "greedy"
local rngState = 987654321
local function rnd(n)
	rngState = rngState * 48271 % 2147483647
	return rngState % n + 1
end
local SECONDS_PER_SEAM = 100 -- rough: planning, walking, and the cascade animations

local N = Tuning.GridSize

local function context(state)
	return {
		Crystals = Crystals.Defs,
		Charges = Charges.Defs,
		Tuning = Tuning,
		RadiusBonus = (state.up.BlastRadius or 0) * Upgrades.Defs.BlastRadius.PerLevel,
		MomentumPops = Tuning.MomentumPops - (state.up.Momentum or 0) * Upgrades.Defs.Momentum.PerLevel,
	}
end

-- Plays one seam greedily. Returns shards earned (including the clear bonus), pops, volleys, best chain.
local function playSeam(state, seed)
	local grid = Seam.Generate(Crystals, Tuning, state.stratum, seed)
	local ctx = context(state)
	local maxCharges = Tuning.BaseCharges + (state.up.ExtraCharge or 0) * Upgrades.Defs.ExtraCharge.PerLevel
	local charges = maxCharges
	local valuable = Seam.CountValuable(grid, Crystals)
	local earned, poppedValuable, pops, volleys, bestChain = 0, 0, 0, 0, 0

	while charges > 0 do
		local best, bestResult = nil, nil
		if POLICY == "casual" then
			local kinds = {}
			for kind in state.charges do
				table.insert(kinds, kind)
			end
			table.sort(kinds)
			for _ = 1, 6 do
				local cand = { X = rnd(N), Z = rnd(N), Kind = kinds[rnd(#kinds)] }
				local r = ChainSim.Run(grid, { cand }, ctx)
				if bestResult == nil or r.Total > bestResult.Total then
					best, bestResult = cand, r
				end
			end
		else
			for z = 1, N do
				for x = 1, N do
					for kind in state.charges do
						local r = ChainSim.Run(grid, { { X = x, Z = z, Kind = kind } }, ctx)
						if bestResult == nil or r.Total > bestResult.Total then
							best, bestResult = { X = x, Z = z, Kind = kind }, r
						end
					end
				end
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
				poppedValuable += 1
			end
		end
		earned += bestResult.Total
		pops += bestResult.Pops
		bestChain = math.max(bestChain, bestResult.Pops)
		if bestResult.Momentum then
			charges = math.min(charges + 1, maxCharges)
		end
	end

	local fraction = valuable > 0 and poppedValuable / valuable or 1
	if fraction >= Tuning.ClearBonusMinFraction then
		earned += math.floor(earned * Tuning.ClearBonusRate * fraction)
	end
	return earned, pops, volleys, bestChain
end

-- Everything the bot may buy next, cheapest sensible first, with the next area taking priority when affordable.
local function nextPurchase(state)
	local nextArea = Strata[state.stratum + 1]
	if nextArea and state.shards >= nextArea.Cost then
		return { Kind = "Area", Cost = nextArea.Cost, Name = nextArea.Name }
	end
	local options = {}
	for _, id in Upgrades.Order do
		local level = state.up[id] or 0
		local cost = Upgrades.Defs[id].Costs[level + 1]
		if cost then
			table.insert(options, { Kind = "Upgrade", Id = id, Cost = cost, Name = Upgrades.Defs[id].Name .. " " .. (level + 1) })
		end
	end
	for id, def in Charges.Defs do
		if def.UnlockCost and not state.charges[id] then
			table.insert(options, { Kind = "Charge", Id = id, Cost = def.UnlockCost, Name = def.Name })
		end
	end
	table.sort(options, function(a, b) return a.Cost < b.Cost end)
	local cheapest = options[1]
	if cheapest and state.shards >= cheapest.Cost then
		return cheapest
	end
	return nil
end

local state = { shards = 0, stratum = 1, up = {}, charges = { Basic = true }, seams = 0 }
local perStratum = {} -- [stratum] = { seams, shards, pops, volleys, best }
local log = {}
local started = os.clock()

for s = 1, MAX_SEAMS do
	state.seams = s
	local earned, pops, volleys, bestChain = playSeam(state, s * 7919 + 13)
	state.shards += earned
	local st = perStratum[state.stratum] or { seams = 0, shards = 0, pops = 0, volleys = 0, best = 0 }
	perStratum[state.stratum] = st
	st.seams += 1
	st.shards += earned
	st.pops += pops
	st.volleys += volleys
	st.best = math.max(st.best, bestChain)

	while true do
		local p = nextPurchase(state)
		if not p then break end
		state.shards -= p.Cost
		if p.Kind == "Area" then
			state.stratum += 1
		elseif p.Kind == "Upgrade" then
			state.up[p.Id] = (state.up[p.Id] or 0) + 1
		else
			state.charges[p.Id] = true
		end
		table.insert(log, { Seam = s, Text = ("bought %s (%d shards)"):format(p.Name, p.Cost), Minutes = s * SECONDS_PER_SEAM / 60 })
	end
	if state.stratum == #Strata and (state.up.ExtraCharge or 0) >= 3 and (state.up.BlastRadius or 0) >= 3 and (state.up.Momentum or 0) >= 2 then
		break
	end
end

print(("Economy simulation [%s planner]: %d seams played in %.1fs of CPU (blasting income only)"):format(POLICY, state.seams, os.clock() - started))
print(("Assuming about %d s of real play per seam.\n"):format(SECONDS_PER_SEAM))
print("Purchase timeline (seam number, rough play time):")
for _, e in log do
	print(("  seam %3d  ~%3.0f min   %s"):format(e.Seam, e.Minutes, e.Text))
end
print("\nPer area (average per seam):")
for n = 1, #Strata do
	local st = perStratum[n]
	if st then
		print(("  %-18s %3d seams | %6.0f shards/seam | %4.1f pops/seam | %3.1f volleys/seam | best chain %d"):format(Strata[n].Name, st.seams, st.shards / st.seams, st.pops / st.seams, st.volleys / st.seams, st.best))
	else
		print(("  %-18s not reached within %d seams"):format(Strata[n].Name, MAX_SEAMS))
	end
end
