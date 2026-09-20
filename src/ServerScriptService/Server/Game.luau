--!strict
-- Server-authoritative game loop: seams, volleys, rewards, purchases, state sync.
-- The client only ever sends intents (Detonate cells, Buy ids); everything else is decided here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChainSim = require(Shared.ChainSim)
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Remotes = require(Shared.Remotes)

local Data = require(script.Parent.Data)
local Seam = require(script.Parent.Seam)
local Validate = require(script.Parent.Validate)

local Tuning = Config.Tuning
local Crystals = Config.Crystals
local Upgrades = Config.Upgrades
local Charges = Config.Charges
local Strata = Config.Strata

local BUY_COOLDOWN = 0.2
local DETONATE_COOLDOWN = 0.15

type SeamState = {
	Id: number,
	Grid: ChainSim.Grid,
	Stratum: number,
	Charges: number,
	ChargesMax: number,
	Earned: number,
	Popped: number,
	Valuable: number,
	InFlight: boolean,
}

local Game = {}
local seams: { [Player]: SeamState } = {}
local slots: { [Player]: number } = {}
local lastAction: { [Player]: { Buy: number, Detonate: number } } = {}
local seamCounter = 0

local function upgradeLevel(data: any, id: string): number
	return data.Upgrades[id] or 0
end

local function notify(player: Player, text: string, kind: string)
	Remotes.Notify:FireClient(player, text, kind)
end

local function snapshot(player: Player): { [string]: any }?
	local data = Data.Get(player)
	if not data then
		return nil
	end
	local seam = seams[player]
	return {
		Shards = data.Shards,
		Upgrades = data.Upgrades,
		UnlockedCharges = data.UnlockedCharges,
		StrataUnlocked = data.Progress.StrataUnlocked,
		ActiveStratum = data.Progress.ActiveStratum,
		Codex = data.Codex,
		BestChain = data.Stats.BestChain,
		ChargesLeft = seam and seam.Charges or 0,
		ChargesMax = seam and seam.ChargesMax or 0,
	}
end

local function sync(player: Player)
	local snap = snapshot(player)
	if snap then
		Remotes.Sync:FireClient(player, snap)
	end
end

local function seamPayload(player: Player, seam: SeamState): { [string]: any }
	local cells = {}
	for key, cell in seam.Grid.Cells do
		table.insert(cells, { K = key, Kind = cell.Kind, M = cell.Mutated })
	end
	return {
		UserId = player.UserId,
		Slot = slots[player],
		Size = seam.Grid.Size,
		Stratum = seam.Stratum,
		Cells = cells,
	}
end

local function startSeam(player: Player)
	local data = Data.Get(player)
	if not data or not slots[player] then
		return
	end
	seamCounter += 1
	local stratum = data.Progress.ActiveStratum
	local grid = Seam.Generate(Crystals, Tuning, stratum, seamCounter * 7919 + player.UserId % 100003 + os.time())
	local max = Tuning.BaseCharges + upgradeLevel(data, "ExtraCharge") * Upgrades.Defs.ExtraCharge.PerLevel
	local seam: SeamState = {
		Id = seamCounter,
		Grid = grid,
		Stratum = stratum,
		Charges = max,
		ChargesMax = max,
		Earned = 0,
		Popped = 0,
		Valuable = Seam.CountValuable(grid, Crystals),
		InFlight = false,
	}
	seams[player] = seam
	Remotes.SeamStart:FireAllClients(seamPayload(player, seam))
	sync(player)
end

local function contextFor(data: any)
	local momentumLevel = upgradeLevel(data, "Momentum")
	return {
		Crystals = Config.Context.Crystals,
		Charges = Config.Context.Charges,
		Tuning = Tuning,
		RadiusBonus = upgradeLevel(data, "BlastRadius") * Upgrades.Defs.BlastRadius.PerLevel,
		MomentumPops = Tuning.MomentumPops - momentumLevel * Upgrades.Defs.Momentum.PerLevel,
	}
end

local function endSeam(player: Player, seam: SeamState)
	local data = Data.Get(player)
	if not data or seams[player] ~= seam then
		return
	end
	local fraction = seam.Valuable > 0 and seam.Popped / seam.Valuable or 1
	if fraction >= Tuning.ClearBonusMinFraction then
		local bonus = math.floor(seam.Earned * Tuning.ClearBonusRate * fraction)
		data.Shards += bonus
		data.Stats.TotalShards += bonus
		data.Stats.SeamsCleared += 1
		notify(player, ("Seam cleared! +%d bonus shards"):format(bonus), "Reward")
	else
		notify(player, "Seam spent. New seam incoming.", "Info")
	end
	sync(player)
	task.delay(Tuning.SeamRegenDelay, function()
		if seams[player] == seam and player.Parent then
			startSeam(player)
		end
	end)
end

local function onDetonate(player: Player, payload: any)
	local data = Data.Get(player)
	local seam = seams[player]
	if not data or not seam or seam.InFlight then
		return
	end
	local now = os.clock()
	local last = lastAction[player]
	if last and now - last.Detonate < DETONATE_COOLDOWN then
		return
	end
	if last then
		last.Detonate = now
	end

	local volley, reason = Validate.Volley(payload, seam.Charges, data.UnlockedCharges, seam.Grid.Size, Tuning.MaxVolleyCharges)
	if not volley then
		warn(("[Game] Rejected Detonate from %s: %s"):format(player.Name, tostring(reason)))
		return
	end

	seam.InFlight = true
	seam.Charges -= #volley
	local result = ChainSim.Run(seam.Grid, volley, contextFor(data))

	-- Apply the result to authoritative state.
	local valuablePops = 0
	for _, ev in result.Events do
		seam.Grid.Cells[ChainSim.Key(seam.Grid.Size, ev.X, ev.Z)] = nil
		if Crystals.Defs[ev.Kind].Value > 0 then
			valuablePops += 1
		end
		data.Codex.Discovered[ev.Kind] = true
		if ev.Mutated then
			data.Codex.Mutated[ev.Kind] = true
		end
	end
	seam.Popped += valuablePops
	seam.Earned += result.Total
	data.Shards += result.Total
	data.Stats.TotalShards += result.Total
	data.Stats.TotalPops += result.Pops
	data.Stats.BestChain = math.max(data.Stats.BestChain, result.Pops)
	if result.Momentum then
		seam.Charges = math.min(seam.Charges + 1, seam.ChargesMax)
	end

	Remotes.VolleyResult:FireAllClients({
		UserId = player.UserId,
		Charges = volley,
		Events = result.Events,
		Pops = result.Pops,
		Raw = result.Raw,
		Bonus = result.Bonus,
		Total = result.Total,
		PeakMult = result.PeakMult,
		Tier = result.Tier,
		Duration = result.Duration,
		Momentum = result.Momentum,
	})
	sync(player)

	task.delay(result.Duration + 0.3, function()
		if seams[player] ~= seam then
			return
		end
		seam.InFlight = false
		local remaining = Seam.CountValuable(seam.Grid, Crystals)
		if seam.Charges <= 0 or remaining == 0 then
			endSeam(player, seam)
		end
	end)
end

local function onBuy(player: Player, kind: any, id: any)
	local data = Data.Get(player)
	if not data or type(kind) ~= "string" or type(id) ~= "string" then
		return
	end
	local now = os.clock()
	local last = lastAction[player]
	if last and now - last.Buy < BUY_COOLDOWN then
		return
	end
	if last then
		last.Buy = now
	end

	if kind == "Upgrade" then
		local def = Upgrades.Defs[id]
		if not def then
			return
		end
		local level = upgradeLevel(data, id)
		local cost = def.Costs[level + 1]
		if not cost then
			return notify(player, "Already maxed.", "Info")
		end
		if data.Shards < cost then
			return notify(player, "Not enough shards.", "Error")
		end
		data.Shards -= cost
		data.Upgrades[id] = level + 1
		notify(player, def.Name .. " upgraded" .. (id == "ExtraCharge" and " (next seam)" or ""), "Reward")
	elseif kind == "Charge" then
		local def = Charges.Defs[id]
		if not def or def.UnlockCost == nil or data.UnlockedCharges[id] then
			return
		end
		if data.Shards < def.UnlockCost then
			return notify(player, "Not enough shards.", "Error")
		end
		data.Shards -= def.UnlockCost
		data.UnlockedCharges[id] = true
		notify(player, def.Name .. " unlocked!", "Reward")
	elseif kind == "Stratum" then
		local n = tonumber(id)
		if not n or n % 1 ~= 0 or Strata[n] == nil then
			return
		end
		if n <= data.Progress.StrataUnlocked then
			data.Progress.ActiveStratum = n
			notify(player, Strata[n].Name .. " selected (next seam)", "Info")
		elseif n == data.Progress.StrataUnlocked + 1 then
			local cost = Strata[n].Cost
			if data.Shards < cost then
				return notify(player, "Not enough shards.", "Error")
			end
			data.Shards -= cost
			data.Progress.StrataUnlocked = n
			data.Progress.ActiveStratum = n
			notify(player, Strata[n].Name .. " unlocked!", "Reward")
		else
			return
		end
	else
		return
	end
	sync(player)
end

local function placeCharacter(player: Player)
	local slot = slots[player]
	local character = player.Character
	if slot and character then
		local origin = Geometry.Origin(slot)
		character:PivotTo(CFrame.new(origin + Vector3.new(0, 5, -(Geometry.Extent() / 2) - 14)))
	end
end

local function lowestFreeSlot(): number
	local used: { [number]: boolean } = {}
	for _, s in slots do
		used[s] = true
	end
	local n = 0
	while used[n] do
		n += 1
	end
	return n
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(placeCharacter, player)
	end)

	local session = Data.Load(player)
	if not session then
		player:Kick("Your data could not be loaded safely. Please rejoin in a minute.")
		return
	end
	if player.Parent == nil then
		Data.Release(player) -- left mid-load: free the session lock
		return
	end

	slots[player] = lowestFreeSlot()
	lastAction[player] = { Buy = 0, Detonate = 0 }
	placeCharacter(player)
	startSeam(player)

	-- Show existing caverns to the new player.
	for other, seam in seams do
		if other ~= player then
			Remotes.SeamStart:FireClient(player, seamPayload(other, seam))
		end
	end
end

local function onPlayerRemoving(player: Player)
	local seam = seams[player]
	if seam then
		Remotes.SeamRemove:FireAllClients(player.UserId)
	end
	seams[player] = nil
	slots[player] = nil
	lastAction[player] = nil
end

function Game.Init()
	Remotes.Detonate.OnServerEvent:Connect(onDetonate)
	Remotes.Buy.OnServerEvent:Connect(onBuy)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return Game
