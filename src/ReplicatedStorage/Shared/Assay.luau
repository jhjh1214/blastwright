--!strict
-- Assay Office logic. Pure (no Roblox APIs). State (save data `Assay`): { Pops = { [crystalKind] = count },
-- Claimed = { ["Kind:tierIndex"] = true } }. The server records pops and pays; the client only displays.
local Assay = {}

function Assay.Default()
	return { Pops = {}, Claimed = {} }
end

local function claimKey(kind: string, tier: number): string
	return kind .. ":" .. tier
end

function Assay.Record(state: any, kind: string, amount: number)
	if type(kind) ~= "string" or amount ~= amount or amount <= 0 then
		return
	end
	state.Pops[kind] = (state.Pops[kind] or 0) + math.floor(amount)
end

-- Is this tier reached (and not yet taken) for this kind?
function Assay.CanClaim(state: any, kind: any, tier: any, kinds: { string }, cfg: any): boolean
	if type(kind) ~= "string" or table.find(kinds, kind) == nil then
		return false
	end
	if type(tier) ~= "number" or tier ~= math.floor(tier) or cfg.Tiers[tier] == nil then
		return false
	end
	return (state.Pops[kind] or 0) >= cfg.Tiers[tier].Pops and not state.Claimed[claimKey(kind, tier)]
end

-- Take a tier: returns the shard reward, or nil when it cannot be claimed.
function Assay.Claim(state: any, kind: any, tier: any, kinds: { string }, cfg: any): number?
	if not Assay.CanClaim(state, kind, tier, kinds, cfg) then
		return nil
	end
	state.Claimed[claimKey(kind, tier)] = true
	return cfg.Tiers[tier].Reward
end

-- True when every kind has REACHED the title tier (claimed or not), so the title cannot be lost by not claiming.
function Assay.TitleEarned(state: any, kinds: { string }, cfg: any): boolean
	local need = cfg.Tiers[cfg.TitleTier].Pops
	for _, kind in kinds do
		if (state.Pops[kind] or 0) < need then
			return false
		end
	end
	return #kinds > 0
end

-- What the client shows: per kind, its pops, the next tier to work toward (nil when all done) and how many can be claimed.
function Assay.View(state: any, kinds: { string }, cfg: any)
	local list = {}
	for _, kind in kinds do
		local pops = state.Pops[kind] or 0
		local nextTier, claimable = nil, {}
		for i, tier in cfg.Tiers do
			local taken = state.Claimed[claimKey(kind, i)] == true
			if pops >= tier.Pops and not taken then
				table.insert(claimable, i)
			end
			if pops < tier.Pops and nextTier == nil then
				nextTier = { Index = i, Id = tier.Id, Pops = tier.Pops, Reward = tier.Reward }
			end
		end
		table.insert(list, { Kind = kind, Pops = pops, Next = nextTier, Claimable = claimable })
	end
	return list
end

return Assay
