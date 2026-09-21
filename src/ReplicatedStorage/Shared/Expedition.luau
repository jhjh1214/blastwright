--!strict
-- Expedition run logic. Pure: no Roblox APIs and no clock; randomness is passed in as a function returning [0, 1).
-- The server owns the run and applies it around ChainSim; clients only ever receive View.

export type Card = { Route: string, Relic: string? }
export type Run = {
	Floor: number,
	Floors: number,
	Charges: number,
	StartCharges: number,
	Haul: number,
	Relics: { string },
	Phase: string, -- Blasting | Choosing | Ended
	Cleared: number,
	ValueMult: number, -- the current floor's route multiplier (a Rich Vein makes it 2)
	Choices: { Card },
	Hearts: number?, -- rig hearts, owned by the server (Lurker fights); nil until set
}

local Expedition = {}

function Expedition.New(cfg: any, startCharges: number): Run
	return {
		Floor = 1,
		Floors = cfg.Floors,
		Charges = startCharges,
		StartCharges = startCharges,
		Haul = 0,
		Relics = {},
		Phase = "Blasting",
		Cleared = 0,
		ValueMult = 1,
		Choices = {},
	}
end

-- Deeper floors use later areas' crystals, but never an area the player has not unlocked (two floors per area).
function Expedition.FloorStratum(floor: number, unlockedAreas: number, cfg: any): number
	local byDepth = 1 + (floor - 1) // 2
	return math.max(1, math.min(byDepth, unlockedAreas))
end

local function sortedKeys(t: { [string]: any }): { string }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

local function shuffle(list: { any }, rng: () -> number)
	for i = #list, 2, -1 do
		local j = math.floor(rng() * i) + 1
		list[i], list[j] = list[j], list[i]
	end
end

local function owns(run: Run, relicId: string): boolean
	for _, id in run.Relics do
		if id == relicId then
			return true
		end
	end
	return false
end

-- Three cards, each with a different route, and distinct relics the player does not already have.
function Expedition.Choices(run: Run, rng: () -> number, cfg: any): { Card }
	local routes = sortedKeys(cfg.Routes)
	shuffle(routes, rng)
	local pool = {}
	for _, id in sortedKeys(cfg.Relics) do
		if not owns(run, id) then
			table.insert(pool, id)
		end
	end
	shuffle(pool, rng)
	local cards: { Card } = {}
	for i, route in routes do
		table.insert(cards, { Route = route, Relic = pool[i] })
	end
	return cards
end

-- Called when a floor ends. Adds the floor's payout to the haul and decides what happens next:
-- "Collapse" (too little cleared AND no charges left), "Victory" (final floor cleared) or "Choose".
function Expedition.FloorEnded(run: Run, payout: number, clearedFraction: number, chargesLeft: number, rng: () -> number, cfg: any): string
	run.Haul += payout
	run.Charges = chargesLeft
	if clearedFraction < cfg.ClearToAdvance and chargesLeft <= 0 then
		run.Phase = "Ended"
		return "Collapse"
	end
	run.Cleared += 1
	if run.Floor >= run.Floors then
		run.Phase = "Ended"
		return "Victory"
	end
	run.Phase = "Choosing"
	run.Choices = Expedition.Choices(run, rng, cfg)
	return "Choose"
end

-- Apply the chosen card and descend. Returns false (and changes nothing) for anything but a valid pick while choosing.
function Expedition.Pick(run: Run, index: any, cfg: any): boolean
	if run.Phase ~= "Choosing" then
		return false
	end
	if type(index) ~= "number" or index ~= index or index % 1 ~= 0 or index < 1 or index > #run.Choices then
		return false
	end
	local card = run.Choices[index]
	local route = cfg.Routes[card.Route]
	if route.Refill then
		run.Charges = run.StartCharges
	else
		run.Charges = math.max(1, run.Charges + (route.ChargeDelta or 0)) -- never strand the player with zero
	end
	run.ValueMult = route.ValueMult or 1
	if card.Relic then
		table.insert(run.Relics, card.Relic)
		local extra = cfg.Relics[card.Relic].Modifiers.ExtraCharges
		if extra then
			run.StartCharges += extra
			run.Charges += extra
		end
	end
	run.Floor += 1
	run.Phase = "Blasting"
	run.Choices = {}
	return true
end

-- Combined effect of every relic plus the current route, in the shape ChainSim (and the run) expect.
function Expedition.Modifiers(run: Run, cfg: any)
	local m = {
		AmplifierMult = 1,
		ValueMult = run.ValueMult,
		RelayValueMult = 1,
		MutationChanceMult = 1,
		VolatileRadiusBonus = 0,
		MomentumPopsDelta = 0,
		UnstableShield = false,
	}
	for _, id in run.Relics do
		local r = cfg.Relics[id].Modifiers
		m.AmplifierMult *= r.AmplifierMult or 1
		m.ValueMult *= r.ValueMult or 1
		m.RelayValueMult *= r.RelayValueMult or 1
		m.MutationChanceMult *= r.MutationChanceMult or 1
		m.VolatileRadiusBonus += r.VolatileRadiusBonus or 0
		m.MomentumPopsDelta += r.MomentumPopsDelta or 0
		if r.UnstableShield then
			m.UnstableShield = true
		end
	end
	return m
end

-- What banking pays: the haul, plus a bonus per floor cleared, plus a bonus for finishing the whole dive.
function Expedition.Bank(run: Run, cfg: any, victory: boolean): number
	local amount = run.Haul * (1 + cfg.DepthBonusPerFloor * run.Cleared)
	if victory then
		amount *= cfg.VictoryBonus
	end
	return math.max(0, math.floor(amount + 0.5))
end

-- What a collapse keeps.
function Expedition.Salvage(run: Run, cfg: any): number
	return math.max(0, math.floor(run.Haul * cfg.SalvageFraction))
end

-- Everything the client needs: HUD numbers, the cards, and the modifiers so the preview matches the real rules.
function Expedition.View(run: Run, cfg: any)
	local relics = {}
	for _, id in run.Relics do
		table.insert(relics, { Name = cfg.Relics[id].Name, Description = cfg.Relics[id].Description })
	end
	local cards = {}
	for _, card in run.Choices do
		local route = cfg.Routes[card.Route]
		local relic = card.Relic and cfg.Relics[card.Relic] or nil
		table.insert(cards, {
			Route = card.Route,
			RouteName = route.Name,
			RouteDescription = route.Description,
			Relic = card.Relic,
			RelicName = relic and relic.Name or "",
			RelicDescription = relic and relic.Description or "",
		})
	end
	return {
		Floor = run.Floor,
		Floors = run.Floors,
		Charges = run.Charges,
		Haul = run.Haul,
		Phase = run.Phase,
		Hearts = run.Hearts,
		Relics = relics,
		Choices = cards,
		BankNow = Expedition.Bank(run, cfg, false),
		SalvageNow = Expedition.Salvage(run, cfg),
		Modifiers = Expedition.Modifiers(run, cfg),
	}
end

return Expedition
