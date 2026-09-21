--!strict
-- What a purchased offer gives. Pure: no Roblox APIs. Each grant is { Kind = ..., ... }:
--   Shards   { Amount, Scaled? }          shards (Scaled = times the areas unlocked, like the shard packs)
--   Boost    { Boost, Mult, Seconds }     a timed multiplier ("Shards" or "Luck")
--   Tokens   { Token, Count }             "Revive" (continue a collapsed Expedition) or "Charge" (emergency charge)
--   Cosmetic { Id }                       a blast color from Config/Cosmetics
--   Finisher { Id }                       a boss-defeat effect from Config/Finishers
--   Title    { Title }                    a title to wear above the head
-- Idempotency is the receipt system's job (Receipts.Apply); this file only applies effects to a save table.
export type Grant = { Kind: string, [string]: any }

local Grants = {}

Grants.TOKEN_CAP = 99
Grants.BOOST_CAP_SECONDS = 2 * 3600 -- a boost can be stacked up to two hours ahead

-- Timed boosts. Record: data.Boosts = { Shards = { Until = unixTime, Mult = n }, Luck = { Until = unixTime, Mult = n } }
-- Start a boost, or extend a running one (durations add up to maxSeconds from now; the stronger multiplier wins).
function Grants.BoostAdd(boosts: any, kind: string, mult: number, seconds: number, now: number, maxSeconds: number)
	local b = boosts[kind]
	if not b then
		return
	end
	if b.Until > now then
		b.Until = math.min(b.Until + seconds, now + maxSeconds)
		b.Mult = math.max(b.Mult, mult)
	else
		b.Until = now + math.min(seconds, maxSeconds)
		b.Mult = mult
	end
end

function Grants.BoostMult(boosts: any, kind: string, now: number): number
	local b = boosts[kind]
	if b and type(b.Until) == "number" and b.Until > now and type(b.Mult) == "number" and b.Mult >= 1 then
		return b.Mult
	end
	return 1
end

function Grants.BoostRemaining(boosts: any, kind: string, now: number): number
	local b = boosts[kind]
	if b and type(b.Until) == "number" and b.Until > now then
		return b.Until - now
	end
	return 0
end

local TOKENS = { Revive = true, Charge = true }
local BOOSTS = { Shards = true, Luck = true }

local function positive(n: any): boolean
	return type(n) == "number" and n == n and n > 0 and n < math.huge
end

-- Validate one grant (used by the config test and before applying).
function Grants.Valid(g: any): boolean
	if type(g) ~= "table" then
		return false
	end
	if g.Kind == "Shards" then
		return positive(g.Amount)
	elseif g.Kind == "Boost" then
		return BOOSTS[g.Boost] == true and type(g.Mult) == "number" and g.Mult > 1 and positive(g.Seconds)
	elseif g.Kind == "Tokens" then
		return TOKENS[g.Token] == true and positive(g.Count) and g.Count % 1 == 0
	elseif g.Kind == "Cosmetic" or g.Kind == "Finisher" then
		return type(g.Id) == "string" and g.Id ~= ""
	elseif g.Kind == "Title" then
		return type(g.Title) == "string" and g.Title ~= "" and #g.Title <= 24
	end
	return false
end

-- Apply grants to the save. `strata` = areas unlocked (for scaled shards). Returns short messages for a toast.
function Grants.Apply(data: any, grants: { Grant }, now: number, strata: number): { string }
	local messages = {}
	for _, g in grants do
		if Grants.Valid(g) then
			if g.Kind == "Shards" then
				local amount = math.floor(g.Amount * (g.Scaled and math.max(1, math.floor(strata)) or 1))
				data.Shards += amount
				table.insert(messages, ("+%d shards"):format(amount))
			elseif g.Kind == "Boost" then
				Grants.BoostAdd(data.Boosts, g.Boost, g.Mult, g.Seconds, now, Grants.BOOST_CAP_SECONDS)
				table.insert(messages, ("%s boost x%s for %d min"):format(g.Boost, tostring(g.Mult), g.Seconds // 60))
			elseif g.Kind == "Tokens" then
				data.Inventory[g.Token] = math.min(Grants.TOKEN_CAP, (data.Inventory[g.Token] or 0) + g.Count)
				table.insert(messages, ("+%d %s"):format(g.Count, g.Token == "Revive" and "revive token(s)" or "emergency charge(s)"))
			elseif g.Kind == "Cosmetic" then
				data.Cosmetics.Owned[g.Id] = true
				table.insert(messages, g.Id .. " blast color")
			elseif g.Kind == "Finisher" then
				data.Finishers.Owned[g.Id] = true
				table.insert(messages, g.Id .. " finisher")
			elseif g.Kind == "Title" then
				data.Mastery.Extra[g.Title] = true
				table.insert(messages, "title: " .. g.Title)
			end
		end
	end
	return messages
end

-- Spend one token. Returns whether there was one.
function Grants.Spend(data: any, token: string): boolean
	if not TOKENS[token] or (data.Inventory[token] or 0) <= 0 then
		return false
	end
	data.Inventory[token] -= 1
	return true
end

-- Wear a finisher you own ("Gold", the default, is always owned).
function Grants.EquipFinisher(data: any, id: any, cfg: any): boolean
	if type(id) ~= "string" then
		return false
	end
	local known = false
	for _, def in cfg.Defs do
		if def.Id == id then
			known = true
		end
	end
	if not known or (id ~= cfg.DefaultId and not data.Finishers.Owned[id]) then
		return false
	end
	data.Finishers.Equipped = id
	return true
end

return Grants
