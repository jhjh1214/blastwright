--!nonstrict
-- Planning aids for blast mode. Everything here is drawn flat on the floor with non-glowing parts:
--   * a faint dot at every cell, so it is obvious where charges can go
--   * a hover ghost showing where you would plant and the blast area it would cover
--   * planted charges, each with its blast area
--   * the predicted chain: colored rings on crystals and lines showing what sets off what
--       white = hit directly by a charge, gold = chain reaction, cyan = prism beam
-- Without the Seismograph upgrade only the direct hits are shown (reading crystal types matters early on);
-- with it the whole chain, estimated shards, tier bonus and momentum refund are shown.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChainSim = require(Shared.ChainSim)
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)

local CavernView = require(script.Parent.CavernView)
local State = require(script.Parent.State)

local Preview = {}
Preview.OnText = nil -- callback(text): main line
Preview.OnInfo = nil -- callback(text): second line (crystal info, legend)

local CELL = Config.Tuning.CellSize

local COLORS = {
	Charge = Color3.fromRGB(255, 255, 255),
	Chain = Color3.fromRGB(255, 205, 80),
	Beam = Color3.fromRGB(110, 220, 255),
	Planted = Color3.fromRGB(255, 120, 50),
	Hover = Color3.fromRGB(255, 225, 140),
	Blocked = Color3.fromRGB(255, 90, 100),
	Dot = Color3.fromRGB(170, 190, 230),
}

-- Heights above the floor, so overlapping layers never z-fight.
local Y_AREA, Y_DOT, Y_HOVER, Y_PLANT, Y_MARK, Y_LINE = 0.30, 0.34, 0.42, 0.44, 0.50, 0.90

local folder = Instance.new("Folder")
folder.Name = "PreviewMarkers"
folder.Parent = workspace

local pools = { Disc = { used = {}, free = {} }, Bar = { used = {}, free = {} } }
local hoverCell = nil -- { X, Z }

local function acquire(kind)
	local pool = pools[kind]
	local p = table.remove(pool.free)
	if not p then
		p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		if kind == "Disc" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	table.insert(pool.used, p)
	return p
end

local function disc(position, diameter, color, transparency)
	local p = acquire("Disc")
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(0.06, diameter, diameter)
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = folder
end

local function bar(a, b, width, color, transparency)
	local dist = (b - a).Magnitude
	if dist < 0.05 then
		return
	end
	local p = acquire("Bar")
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(width, 0.12, dist)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = folder
end

local function clear()
	for _, pool in pools do
		for _, p in pool.used do
			p.Parent = nil
			table.insert(pool.free, p)
		end
		table.clear(pool.used)
	end
end

local function setText(text)
	if Preview.OnText then
		Preview.OnText(text)
	end
end

local function setInfo(text)
	if Preview.OnInfo then
		Preview.OnInfo(text)
	end
end

local function cellPos(view, x, z, y)
	return Geometry.CellPosition(view.Origin, x, z) + Vector3.new(0, y, 0)
end

-- The area a charge would blast, as a flat translucent shape.
local function drawArea(view, x, z, kind, transparency)
	local def = Config.Charges.Defs[kind]
	if not def then
		return
	end
	if def.Shape == "Radius" then
		local radius = (def.Radius or 0) + State.UpgradeLevel("BlastRadius") * Config.Upgrades.Defs.BlastRadius.PerLevel
		disc(cellPos(view, x, z, Y_AREA), (radius + 0.45) * 2 * CELL, COLORS.Planted, transparency)
	elseif def.Shape == "Column" then
		local range = def.Range or 0
		local z1, z2 = math.max(1, z - range), math.min(view.Size, z + range)
		local overhang = Vector3.new(0, 0, CELL * 0.45)
		bar(cellPos(view, x, z1, Y_AREA) - overhang, cellPos(view, x, z2, Y_AREA) + overhang, CELL * 0.9, COLORS.Planted, transparency)
	end
end

-- One-line description of the crystal at the hovered (or last planted) cell.
local function crystalInfo(view)
	local cell = hoverCell
	if not cell and #State.Placed > 0 then
		local last = State.Placed[#State.Placed]
		cell = { X = last.X, Z = last.Z }
	end
	if not cell then
		return nil
	end
	local crystal = view.Grid.Cells[ChainSim.Key(view.Size, cell.X, cell.Z)]
	if not crystal then
		return "Empty spot. A charge here still hits nearby crystals."
	end
	local def = Config.Crystals.Defs[crystal.Kind]
	return ("%s%s: %s"):format(def.Name, crystal.Mutated and " (Prismatic, worth 3x)" or "", def.Description)
end

local function refresh()
	clear()
	local view = CavernView.Get(State.UserId)
	if not view or not State.Data or not State.Engaged or State.Busy then
		setText("")
		setInfo("")
		return
	end

	local available = State.Data.ChargesLeft or 0
	local canPlant = #State.Placed < math.min(available, Config.Tuning.MaxVolleyCharges)

	-- A faint dot at every cell.
	for z = 1, view.Size do
		for x = 1, view.Size do
			disc(cellPos(view, x, z, Y_DOT), 0.9, COLORS.Dot, 0.78)
		end
	end

	local planted = {}
	for _, c in State.Placed do
		planted[c.Z * 100 + c.X] = true
	end

	-- Hover ghost: where you would plant, and what it would cover.
	if hoverCell then
		local hx, hz = hoverCell.X, hoverCell.Z
		if planted[hz * 100 + hx] then
			disc(cellPos(view, hx, hz, Y_HOVER), 4.8, COLORS.Hover, 0.3) -- tap again to remove
		elseif canPlant then
			drawArea(view, hx, hz, State.SelectedCharge, 0.9)
			disc(cellPos(view, hx, hz, Y_HOVER), 4.2, COLORS.Hover, 0.5)
		else
			disc(cellPos(view, hx, hz, Y_HOVER), 4.2, COLORS.Blocked, 0.5) -- no charges left
		end
	end

	-- Planted charges, each with its own blast area.
	for _, c in State.Placed do
		drawArea(view, c.X, c.Z, c.Kind, 0.82)
		disc(cellPos(view, c.X, c.Z, Y_PLANT), 4.6, COLORS.Planted, 0.1)
		disc(cellPos(view, c.X, c.Z, Y_PLANT + 0.02), 2.2, Color3.fromRGB(255, 235, 200), 0.05)
	end

	local crystalText = crystalInfo(view)
	if #State.Placed == 0 then
		setText(("Tap a spot to plant a charge (%d available)"):format(available))
		setInfo(crystalText or "Tap a planted charge again to remove it.")
		return
	end

	local upgrades = Config.Upgrades.Defs
	local ctx = {
		Crystals = Config.Context.Crystals,
		Charges = Config.Context.Charges,
		Tuning = Config.Tuning,
		RadiusBonus = State.UpgradeLevel("BlastRadius") * upgrades.BlastRadius.PerLevel,
		MomentumPops = Config.Tuning.MomentumPops - State.UpgradeLevel("Momentum") * upgrades.Momentum.PerLevel,
	}
	local result = ChainSim.Run(view.Grid, State.Placed, ctx)
	local seismograph = State.UpgradeLevel("Seismograph") > 0

	local direct = 0
	for _, ev in result.Events do
		local isDirect = ev.Cause == "Charge"
		if isDirect then
			direct += 1
		end
		if seismograph or isDirect then
			local color = COLORS[ev.Cause] or COLORS.Chain
			disc(cellPos(view, ev.X, ev.Z, Y_MARK), 3.4, color, 0.3)
			bar(cellPos(view, ev.SX, ev.SZ, Y_LINE), cellPos(view, ev.X, ev.Z, Y_LINE), 0.28, color, 0.25)
		end
	end

	local plantedText = ("Planted %d/%d"):format(#State.Placed, available)
	if seismograph then
		setText(("%s | Chain %d | ~%d shards"):format(plantedText, result.Pops, result.Total))
		local parts = {}
		if result.Tier then
			table.insert(parts, ("%s +%d%%"):format(result.Tier, math.floor(result.Bonus * 100 + 0.5)))
		end
		if result.Momentum then
			table.insert(parts, "refunds a charge")
		end
		table.insert(parts, "white = direct, gold = chain, cyan = beam")
		setInfo((crystalText and (crystalText .. "\n") or "") .. table.concat(parts, "  |  "))
	else
		setText(("%s | Direct hits: %d"):format(plantedText, direct))
		setInfo(crystalText or "Get the Seismograph in the Forge to preview whole chains.")
	end
end

function Preview.Refresh()
	local ok, err = pcall(refresh)
	if not ok then
		warn("[Preview] " .. tostring(err))
	end
end

-- x, z = the cell under the cursor / last tapped, or nil for none. silent = do not redraw now.
function Preview.SetHover(x, z, silent)
	local changed
	if x == nil then
		changed = hoverCell ~= nil
		hoverCell = nil
	else
		changed = hoverCell == nil or hoverCell.X ~= x or hoverCell.Z ~= z
		hoverCell = { X = x, Z = z }
	end
	if changed and not silent then
		Preview.Refresh()
	end
end

return Preview
