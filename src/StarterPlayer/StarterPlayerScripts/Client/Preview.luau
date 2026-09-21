--!nonstrict
-- Planning overlay for blast mode. Drawn with BoxHandleAdornments that render ON TOP of the world, so rocks and
-- crystals can never hide it:
--   * a bright outline around the whole grid and faint lines between cells
--   * hovering (or, on touch, the last tapped cell): the cell is outlined in gold and the exact cells a charge
--     there would blast are tinted, so you can see what you are about to plant
--   * planted charges: cell filled orange, blast cells tinted
--   * the predicted chain: white = hit directly by a charge, gold = chain reaction, cyan = prism beam,
--     with lines from whatever sets each crystal off
-- Without the Seismograph upgrade only direct hits are shown (reading crystal types matters early on); with it the
-- whole chain, estimated shards, tier bonus and momentum refund are shown.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChainSim = require(Shared.ChainSim)
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Lurker = require(Shared.Lurker)
local Boss = require(Shared.Boss)
local BossRT = require(Shared.BossRT)
local Power = require(Shared.Power)

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
	Border = Color3.fromRGB(150, 200, 255),
	Lattice = Color3.fromRGB(170, 195, 235),
}

local BASE_PLANTED = COLORS.Planted

-- The player's equipped blast color (cosmetic), used for planted charges and blast areas.
local function activeColor()
	for _, style in (State.Data and State.Data.Styles) or {} do
		if style.Equipped then
			return Color3.fromRGB(style.Color[1], style.Color[2], style.Color[3])
		end
	end
	return BASE_PLANTED
end

-- Draw order among always-on-top adornments (higher = on top).
local Z_LATTICE, Z_AREA, Z_MARK, Z_LINK, Z_HOVER, Z_PLANT = 1, 2, 3, 4, 5, 6
local Y = 0.6 -- height of the overlay above the floor (only matters for the perspective of thin boxes)

local folder = Instance.new("Folder")
folder.Name = "PreviewOverlay"
folder.Parent = workspace

-- Every adornment is anchored to one invisible, unrotated part sitting at the pad's center.
local anchor = Instance.new("Part")
anchor.Name = "OverlayAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.CastShadow = false
anchor.Transparency = 1
anchor.Size = Vector3.one
anchor.Parent = folder

local used, free = {}, {}
local hoverCell = nil -- { X, Z }
local origin = Vector3.zero

local function acquire()
	local a = table.remove(free)
	if not a then
		a = Instance.new("BoxHandleAdornment")
		a.Adornee = anchor
		a.AlwaysOnTop = true
		a.Parent = folder
	end
	a.Visible = true
	table.insert(used, a)
	return a
end

local function clear()
	for _, a in used do
		a.Visible = false
		table.insert(free, a)
	end
	table.clear(used)
end

-- A flat filled square centered on a world position (x, z).
local function fill(cx, cz, width, depth, color, transparency, zindex)
	local a = acquire()
	a.Size = Vector3.new(width, 0.1, depth)
	a.CFrame = CFrame.new(cx - origin.X, Y - origin.Y, cz - origin.Z)
	a.Color3 = color
	a.Transparency = transparency
	a.ZIndex = zindex
end

-- A flat straight line between two world positions (x, z).
local function line(ax, az, bx, bz, thickness, color, transparency, zindex)
	local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	if length < 0.05 then
		return
	end
	local a = acquire()
	a.Size = Vector3.new(thickness, 0.1, length)
	local mid = Vector3.new((ax + bx) / 2 - origin.X, Y - origin.Y, (az + bz) / 2 - origin.Z)
	a.CFrame = CFrame.lookAt(mid, mid + Vector3.new(bx - ax, 0, bz - az))
	a.Color3 = color
	a.Transparency = transparency
	a.ZIndex = zindex
end

local function cellCenter(view, x, z)
	local p = Geometry.CellPosition(view.Origin, x, z)
	return p.X, p.Z
end

-- Square outline of a cell.
local function outline(view, x, z, thickness, color, transparency, zindex)
	local cx, cz = cellCenter(view, x, z)
	local h = CELL / 2 * 0.96
	line(cx - h, cz - h, cx + h, cz - h, thickness, color, transparency, zindex)
	line(cx + h, cz - h, cx + h, cz + h, thickness, color, transparency, zindex)
	line(cx + h, cz + h, cx - h, cz + h, thickness, color, transparency, zindex)
	line(cx - h, cz + h, cx - h, cz - h, thickness, color, transparency, zindex)
end

local function tintCell(view, x, z, color, transparency, zindex)
	local cx, cz = cellCenter(view, x, z)
	fill(cx, cz, CELL * 0.94, CELL * 0.94, color, transparency, zindex)
end

-- Outline of the whole grid plus faint lines between cells.
local function drawLattice(view)
	local n = view.Size
	local half = n * CELL / 2
	local ox, oz = view.Origin.X, view.Origin.Z
	for i = 0, n do
		local c = (i - n / 2) * CELL
		local edge = i == 0 or i == n
		local thickness = edge and 0.55 or 0.14
		local transparency = edge and 0.25 or 0.72
		local color = edge and COLORS.Border or COLORS.Lattice
		line(ox + c, oz - half, ox + c, oz + half, thickness, color, transparency, Z_LATTICE)
		line(ox - half, oz + c, ox + half, oz + c, thickness, color, transparency, Z_LATTICE)
	end
end

-- The exact cells a charge of this kind would blast from (x, z).
local function areaCells(view, x, z, kind)
	local def = State.Charges(State.Data and State.Data.Puzzle and State.Data.Puzzle.Active)[kind]
	if not def then
		return {}
	end
	return ChainSim.BlastCells(def.Shape, x, z, def.Radius or 0, def.Range or 0, view.Size, def)
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

-- The combat read (Lurker / boss / attacks) has its own label at the bottom centre so it never fights the boss bar.
local function setCombat(text)
	if Preview.OnCombat then
		Preview.OnCombat(text)
	end
end

-- What the planned volley would do to the Lurker and the boss (and to the boss's wound-up attacks), using the exact same
-- pure rules the server uses. `res` = the chain result to judge by (the full chain with the Seismograph, direct hits only without).
local function combatLines(res, full)
	local data = State.Data
	local lines = {}
	local mctx = { Crystals = Config.Context.Crystals, Charges = State.Charges(data.Puzzle and data.Puzzle.Active), BlastCells = ChainSim.BlastCells, Size = Config.Tuning.GridSize }
	local mods = State.Run and State.Run.Modifiers
	local power = Power.Multiplier(res.Pops, data.Critical or 0, Config.Bosses.Power)
	if not (data.Puzzle and data.Puzzle.Active) then
		power *= 1 + State.UpgradeLevel("Scope") * Config.Upgrades.Defs.Scope.PerLevel
	end
	if mods then
		power *= mods.DamageMult
		if (data.Hearts or 0) == 1 then
			power *= mods.LastStandMult
		end
	end
	if data.Monster then
		local m = data.Monster
		local dmg = Lurker.Damage({ Kind = m.Kind, X = m.X, Z = m.Z, HP = m.HP, MaxHP = m.MaxHP, Turn = 0 }, State.Placed, res, mctx, Config.Lurkers)
		if dmg > 0 then
			dmg = math.max(1, math.floor(dmg * power))
		end
		if dmg >= m.HP then
			table.insert(lines, ("%s: ~%d damage, KILLS IT"):format(m.Name, dmg))
		elseif dmg > 0 then
			table.insert(lines, ("%s: ~%d damage (HP %d -> %d)"):format(m.Name, dmg, m.HP, m.HP - dmg))
		else
			table.insert(lines, ("%s: this volley does not reach it"):format(m.Name))
		end
	end
	local boss = data.Boss
	if boss then
		local est = Boss.Estimate(boss, State.Placed, res, mctx, Config.Bosses, power)
		if boss.Phase == "Armor" then
			table.insert(lines, ("Armor: breaks %d node%s, %d left"):format(est.NodesBroken, est.NodesBroken == 1 and "" or "s", est.NodesLeft))
		elseif boss.Phase == "Weak" then
			table.insert(lines, ("Weak points hit: %d/2 -> ~%d damage%s"):format(est.WeakHit, est.Damage, est.WeakHit == 2 and "  MASSIVE" or ""))
		elseif boss.Phase == "Finisher" then
			table.insert(lines, est.Killed and "FINISHER: this volley kills it!" or ("Finisher needs %d+ pops (this is %d)"):format(Config.Bosses.Defs[boss.Kind].Finisher.Pops, res.Pops))
		else
			table.insert(lines, est.Killed and "This volley kills the boss!" or ("Core hit ~%d (HP %d -> %d)"):format(est.Damage, boss.HP, boss.HP - est.Damage))
		end
		if boss.RT and #boss.RT.Threats > 0 then
			local sim = BossRT.Simulate(boss.RT.Threats, res.Events, { Crystals = Config.Context.Crystals }, boss.Kind, Config.Bosses)
			for _, o in sim.Outcomes do
				if o.Type == "Slam" then
					table.insert(lines, o.Fully and "SLAM: cut" or "SLAM: not cut (pop 3+ crystals on the line, or Dodge)")
				elseif o.Type == "Meteor" then
					table.insert(lines, o.Fully and "METEORS: all deflected" or ("METEORS: %d/%d deflected (pop Lensglass)"):format(o.Stopped, o.Total))
				else
					table.insert(lines, o.Fully and "CORRUPTION: purified" or ("CORRUPTION: %d/%d marked crystals purified"):format(o.Stopped, o.Total))
				end
			end
		end
	end
	if #lines > 0 and not full then
		table.insert(lines, "(direct hits only: the Seismograph shows chain effects)")
	end
	return table.concat(lines, "\n")
end

local function refresh()
	clear()
	local view = CavernView.Get(State.UserId)
	if not view or not State.Data or not State.Engaged or State.Busy then
		setText("")
		setInfo("")
		setCombat("")
		return
	end
	origin = view.Origin
	anchor.CFrame = CFrame.new(origin)
	COLORS.Planted = activeColor()

	local available = State.Data.ChargesLeft or 0
	local maxCharges = State.Data.ChargesMax or available
	local canPlant = #State.Placed < math.min(available, Config.Tuning.MaxVolleyCharges)
	local planted = {}
	for _, c in State.Placed do
		planted[c.Z * 100 + c.X] = true
	end

	drawLattice(view)

	-- Hover: where you would plant, and the exact cells it would blast.
	if hoverCell then
		local hx, hz = hoverCell.X, hoverCell.Z
		if planted[hz * 100 + hx] then
			tintCell(view, hx, hz, COLORS.Hover, 0.55, Z_HOVER)
			outline(view, hx, hz, 0.45, COLORS.Hover, 0.05, Z_HOVER) -- tap again to remove
		elseif canPlant then
			for _, c in areaCells(view, hx, hz, State.SelectedCharge) do
				tintCell(view, c.X, c.Z, COLORS.Planted, 0.86, Z_AREA)
			end
			tintCell(view, hx, hz, COLORS.Hover, 0.6, Z_HOVER)
			outline(view, hx, hz, 0.45, COLORS.Hover, 0.05, Z_HOVER)
		else
			tintCell(view, hx, hz, COLORS.Blocked, 0.55, Z_HOVER) -- no charges left
			outline(view, hx, hz, 0.45, COLORS.Blocked, 0.05, Z_HOVER)
		end
	end

	-- Planted charges, each with the cells it blasts.
	for _, c in State.Placed do
		for _, cell in areaCells(view, c.X, c.Z, c.Kind) do
			tintCell(view, cell.X, cell.Z, COLORS.Planted, 0.8, Z_AREA)
		end
		tintCell(view, c.X, c.Z, COLORS.Planted, 0.3, Z_PLANT)
		outline(view, c.X, c.Z, 0.5, Color3.fromRGB(255, 240, 210), 0.05, Z_PLANT)
		local cx, cz = cellCenter(view, c.X, c.Z)
		fill(cx, cz, CELL * 0.28, CELL * 0.28, Color3.fromRGB(255, 245, 220), 0, Z_PLANT)
	end

	local crystalText = crystalInfo(view)
	if #State.Placed == 0 then
		setCombat("")
		setText(("Tap a spot to plant a charge  |  Charges %d/%d"):format(available, maxCharges))
		setInfo(crystalText or "Tap a planted charge again to remove it.")
		return
	end

	local upgrades = Config.Upgrades.Defs
	local puzzle = State.Data.Puzzle and State.Data.Puzzle.Active -- the puzzle ignores upgrades
	local ctx = {
		Crystals = Config.Context.Crystals,
		Charges = State.Charges(puzzle),
		Tuning = Config.Tuning,
		RadiusBonus = 0, -- Fat Fuse is already inside State.Charges
		MomentumPops = puzzle and Config.Tuning.MomentumPops or math.max(3, Config.Tuning.MomentumPops - State.UpgradeLevel("Momentum") * upgrades.Momentum.PerLevel + (State.Run and State.Run.Modifiers.MomentumPopsDelta or 0)),
		Modifiers = State.Run and State.Run.Modifiers or nil, -- relics change the real rules, so the preview must too
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
			tintCell(view, ev.X, ev.Z, color, 0.5, Z_MARK)
			local sx, sz = cellCenter(view, ev.SX, ev.SZ)
			local tx, tz = cellCenter(view, ev.X, ev.Z)
			line(sx, sz, tx, tz, 0.35, color, 0.1, Z_LINK)
		end
	end

	local left = available - #State.Placed
	if seismograph then
		setText(("Charges %d/%d  |  Chain %d  |  ~%d shards"):format(left, maxCharges, result.Pops, result.Total))
		local parts = {}
		if result.Tier then
			table.insert(parts, ("%s +%d%%"):format(result.Tier, math.floor(result.Bonus * 100 + 0.5)))
		end
		if result.Momentum then
			table.insert(parts, "refunds a charge")
		end
		table.insert(parts, "white = direct, gold = chain, cyan = beam")
		local combat = combatLines(result, true)
		setInfo((crystalText and (crystalText .. "\n") or "") .. table.concat(parts, "  |  "))
		setCombat(combat)
	else
		setText(("Charges %d/%d  |  Direct hits: %d"):format(left, maxCharges, direct))
		-- without the Seismograph the combat read uses only the crystals the charges hit directly
		local directEvents = {}
		for _, ev in result.Events do
			if ev.Cause == "Charge" then
				table.insert(directEvents, ev)
			end
		end
		local combat = combatLines({ Pops = #directEvents, Events = directEvents }, false)
		setInfo(crystalText or "Get the Seismograph in the Forge to preview whole chains.")
		setCombat(combat)
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
