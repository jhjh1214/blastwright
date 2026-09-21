--!strict
-- Expedition run logic. Pure: no Roblox APIs and no clock; randomness is passed in as a function returning [0, 1).
-- The server owns the run and applies it around ChainSim; clients only ever receive View.

export type Card = { Route: string, Relic: string?, Room: string }
export type Run = {
	Floor: number,
	Floors: number,
	Charges: number,
	StartCharges: number,
	Haul: number,
	Relics: { string },
	Phase: string, -- Blasting | Choosing | Ended
	Cleared: number,
	ValueMult: number, -- the current floor's route/room multiplier (a Greed Path makes it 2)
	Choices: { Card },
	Hearts: number?, -- rig hearts, owned by the server (Lurker fights); nil until set
	Room: string, -- what the current floor is (Mining, Combat, Elite, Treasure, Chaos, Boss)
	Chaos: string?, -- the Chaos event rolled for the current floor
	MutationMult: number, -- rare-crystal multiplier from the current room
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
		Room = "Mining",
		MutationMult = 1,
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

-- The rooms on offer for the NEXT floor: weighted, without repeats while there are enough kinds. A boss floor is always a Boss room.
function Expedition.DrawRooms(run: Run, count: number, rng: () -> number, cfg: any): { string }
	local nextFloor = run.Floor + 1
	local out = {}
	if cfg.BossFloors[nextFloor] then
		for i = 1, count do
			out[i] = "Boss"
		end
		return out
	end
	local pool = {}
	for _, id in sortedKeys(cfg.Rooms) do
		if cfg.Rooms[id].MinFloor <= nextFloor then
			table.insert(pool, id)
		end
	end
	for i = 1, count do
		local total = 0
		for _, id in pool do
			total += cfg.Rooms[id].Weight
		end
		local roll = rng() * total
		local chosen = pool[#pool]
		for _, id in pool do
			roll -= cfg.Rooms[id].Weight
			if roll < 0 then
				chosen = id
				break
			end
		end
		out[i] = chosen
		if #pool > count - i then -- keep drawing distinct kinds while enough remain
			for idx, id in pool do
				if id == chosen then
					table.remove(pool, idx)
					break
				end
			end
		end
	end
	return out
end

-- Three cards, each with a different route, a room for the next floor, and distinct relics the player does not already have.
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
	local rooms = Expedition.DrawRooms(run, #routes, rng, cfg)
	local cards: { Card } = {}
	for i, route in routes do
		table.insert(cards, { Route = route, Relic = pool[i], Room = rooms[i] })
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

-- Take a relic: remember it and apply its one-off effects (extra charge, extra heart).
function Expedition.AddRelic(run: Run, relicId: string, cfg: any)
	table.insert(run.Relics, relicId)
	local mods = cfg.Relics[relicId].Modifiers
	if mods.ExtraCharges then
		run.StartCharges += mods.ExtraCharges
		run.Charges += mods.ExtraCharges
	end
	if mods.HeartsBonus and run.Hearts then
		run.Hearts += mods.HeartsBonus
	end
end

-- A random relic the run does not own yet (an Elite Lurker's reward). nil when it owns them all.
function Expedition.GrantRelic(run: Run, rng: () -> number, cfg: any): string?
	local pool = {}
	for _, id in sortedKeys(cfg.Relics) do
		if not owns(run, id) then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then
		return nil
	end
	local id = pool[math.min(#pool, math.floor(rng() * #pool) + 1)]
	Expedition.AddRelic(run, id, cfg)
	return id
end

-- Extra rig hearts from relics (added to the base hearts).
function Expedition.HeartsBonus(run: Run, cfg: any): number
	local n = 0
	for _, id in run.Relics do
		n += cfg.Relics[id].Modifiers.HeartsBonus or 0
	end
	return n
end

-- Apply the chosen card and descend. Returns false (and changes nothing) for anything but a valid pick while choosing.
-- `rng` decides a Chaos Rift's event (deterministic first event when omitted).
function Expedition.Pick(run: Run, index: any, cfg: any, rng: (() -> number)?): boolean
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
	run.MutationMult = 1
	run.Chaos = nil
	run.Room = card.Room
	local room = cfg.Rooms[card.Room]
	if room then
		run.ValueMult *= room.ValueMult or 1
		run.MutationMult *= room.MutationMult or 1
		if room.Chaos then
			local ids = sortedKeys(cfg.ChaosEvents)
			local id = ids[math.min(#ids, math.floor((rng and rng() or 0) * #ids) + 1)]
			local event = cfg.ChaosEvents[id]
			run.Chaos = id
			run.ValueMult *= event.ValueMult or 1
			run.MutationMult *= event.MutationMult or 1
			run.Charges = math.max(1, run.Charges + (event.ChargeDelta or 0))
		end
	end
	if card.Relic then
		Expedition.AddRelic(run, card.Relic, cfg)
	end
	run.Floor += 1
	run.Phase = "Blasting"
	run.Choices = {}
	return true
end

-- What the current room asks of the server: an awake Lurker (its health and bounty scaling), a relic reward, or no Lurker at all.
function Expedition.RoomEffects(run: Run, cfg: any)
	local room = cfg.Rooms[run.Room]
	local event = run.Chaos and cfg.ChaosEvents[run.Chaos] or nil
	local fx = { Awake = false, HPMult = 1, BountyMult = 1, RelicReward = false, NoLurker = false }
	if room then
		fx.Awake = room.Lurker == true
		fx.HPMult = room.HPMult or 1
		fx.BountyMult = room.BountyMult or 1
		fx.RelicReward = room.RelicReward == true
		fx.NoLurker = room.NoLurker == true
	end
	if event then
		fx.Awake = fx.Awake or event.Lurker == true
		fx.BountyMult *= event.BountyMult or 1
	end
	return fx
end

-- Combined effect of every relic plus the current route and room, in the shape ChainSim (and the run) expect.
function Expedition.Modifiers(run: Run, cfg: any)
	local m = {
		AmplifierMult = 1,
		ValueMult = run.ValueMult,
		RelayValueMult = 1,
		MutationChanceMult = run.MutationMult or 1,
		VolatileRadiusBonus = 0,
		MomentumPopsDelta = 0,
		UnstableShield = false,
		DamageMult = 1,
		LastStandMult = 1,
		KillRefund = 0,
		CriticalPopsDelta = 0,
		HeartOnCritical = 0,
		BountyMult = 1,
		MonsterHPMult = 1,
	}
	for _, id in run.Relics do
		local r = cfg.Relics[id].Modifiers
		m.AmplifierMult *= r.AmplifierMult or 1
		m.ValueMult *= r.ValueMult or 1
		m.RelayValueMult *= r.RelayValueMult or 1
		m.MutationChanceMult *= r.MutationChanceMult or 1
		m.VolatileRadiusBonus += r.VolatileRadiusBonus or 0
		m.MomentumPopsDelta += r.MomentumPopsDelta or 0
		m.DamageMult *= r.DamageMult or 1
		m.LastStandMult = math.max(m.LastStandMult, r.LastStandMult or 1)
		m.KillRefund += r.KillRefund or 0
		m.CriticalPopsDelta += r.CriticalPopsDelta or 0
		m.HeartOnCritical += r.HeartOnCritical or 0
		m.BountyMult *= r.BountyMult or 1
		m.MonsterHPMult *= r.MonsterHPMult or 1
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

local function roomName(cfg: any, room: string): string
	return cfg.Rooms[room] and cfg.Rooms[room].Name or "Boss Arena"
end

local function roomDescription(cfg: any, room: string): string
	return cfg.Rooms[room] and cfg.Rooms[room].Description or "A boss waits below. Prepare."
end

-- Everything the client needs: HUD numbers, the cards, and the modifiers so the preview matches the real rules.
function Expedition.View(run: Run, cfg: any)
	local relics = {}
	for _, id in run.Relics do
		table.insert(relics, { Name = cfg.Relics[id].Name, Family = cfg.Relics[id].Family, Description = cfg.Relics[id].Description })
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
			RelicFamily = relic and relic.Family or "",
			Room = card.Room,
			RoomName = roomName(cfg, card.Room),
			RoomDescription = roomDescription(cfg, card.Room),
		})
	end
	return {
		Floor = run.Floor,
		Floors = run.Floors,
		Charges = run.Charges,
		Haul = run.Haul,
		Phase = run.Phase,
		Hearts = run.Hearts,
		Room = run.Room,
		RoomName = roomName(cfg, run.Room),
		Chaos = run.Chaos and cfg.ChaosEvents[run.Chaos] and cfg.ChaosEvents[run.Chaos].Name or nil,
		Relics = relics,
		Choices = cards,
		BankNow = Expedition.Bank(run, cfg, false),
		SalvageNow = Expedition.Salvage(run, cfg),
		Modifiers = Expedition.Modifiers(run, cfg),
	}
end

return Expedition
