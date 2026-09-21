--!nonstrict
-- Puzzle par sweep: tools/bin/luau.exe tools/sim/puzzle.luau  (prints par and empty-grid days over 60 days)
local ChainSim = require("../../src/ReplicatedStorage/Shared/ChainSim")
local Crystals = require("../../src/ReplicatedStorage/Shared/Config/Crystals")
local Charges = require("../../src/ReplicatedStorage/Shared/Config/Charges")
local Tuning = require("../../src/ReplicatedStorage/Shared/Config/Tuning")
local PuzzleCfg = require("../../src/ReplicatedStorage/Shared/Config/Puzzle")
local Seam = require("../../src/ServerScriptService/Server/Seam")
local Puzzle = require("../../src/ReplicatedStorage/Shared/Puzzle")
local ctx = { Crystals = Crystals.Defs, Charges = Charges.Defs, Tuning = Tuning, RadiusBonus = 0, MomentumPops = Tuning.MomentumPops }
local pars, lo, hi, zero = {}, math.huge, 0, 0
for day = 20000, 20059 do
	local g = Seam.Generate(Crystals, Tuning, PuzzleCfg.Stratum, Puzzle.Seed(day), PuzzleCfg.MutationChance)
	local par = Puzzle.Par(g, ctx, PuzzleCfg.Charges, ChainSim.Run)
	table.insert(pars, par)
	lo, hi = math.min(lo, par), math.max(hi, par)
	if par == 0 then zero += 1 end
end
table.sort(pars)
print(("par over 60 days: min %d  median %d  max %d  zero-days %d"):format(lo, pars[30], hi, zero))
