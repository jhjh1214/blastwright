--!strict
-- Deterministic seam (cavern grid) generation. Pure: no Roblox APIs.
local Seam = {}

-- Park-Miller PRNG: products stay under 2^53, so it is exact in Luau doubles.
local function makeRng(seed: number)
	local state = seed % 2147483646 + 1
	return function(): number
		state = state * 48271 % 2147483647
		return state / 2147483647
	end
end

-- crystals: Config.Crystals (Defs + Order), tuning: Config.Tuning
-- mutationChance overrides tuning.MutationChance (used by the Prismatic Luck gamepass).
function Seam.Generate(crystals: any, tuning: any, stratum: number, seed: number, mutationChance: number?)
	local rng = makeRng(seed)
	local size = tuning.GridSize
	local emptyWeight = 12
	local chance = mutationChance or tuning.MutationChance

	local pool: { { Id: string, Weight: number } } = {}
	local total = emptyWeight
	for _, id in crystals.Order do
		local def = crystals.Defs[id]
		if def.Stratum <= stratum then
			table.insert(pool, { Id = id, Weight = def.Weight })
			total += def.Weight
		end
	end

	local cells: { [number]: { Kind: string, Mutated: boolean? } } = {}
	for z = 1, size do
		for x = 1, size do
			local roll = rng() * total
			for _, entry in pool do
				roll -= entry.Weight
				if roll < 0 then
					local def = crystals.Defs[entry.Id]
					local mutated = def.Value > 0 and rng() < chance
					cells[(z - 1) * size + x] = { Kind = entry.Id, Mutated = mutated or nil }
					break
				end
			end
		end
	end
	return { Size = size, Cells = cells }
end

-- Number of crystals that are worth popping (excludes hazards).
function Seam.CountValuable(grid: any, crystals: any): number
	local n = 0
	for _, cell in grid.Cells do
		if crystals.Defs[cell.Kind].Value > 0 then
			n += 1
		end
	end
	return n
end

return Seam
