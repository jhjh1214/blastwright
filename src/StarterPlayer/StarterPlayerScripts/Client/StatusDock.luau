--!nonstrict
-- Bottom-right status tiles for things that are running right now: one tile per live event (its own icon and colour) and one
-- for the shared Server Goal (progress bar, or the frenzy countdown). Each tile shows a timer or progress and can be tapped
-- (fixed sizes only). Pure display: the server decides what is live; a 1-second loop only updates the countdown text.
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local StatusDock = {}

-- event id -> icon and colour (unknown ids fall back to a star)
local LOOK = {
	PrismaticWeekend = { Icon = "Gem", Color = Color3.fromRGB(58, 150, 255) },
	OverchargeWednesday = { Icon = "Bolt", Color = Color3.fromRGB(255, 186, 40) },
	HappyHour = { Icon = "Clock", Color = Color3.fromRGB(70, 198, 96) },
	LurkerSwarmFriday = { Icon = "Skull", Color = Color3.fromRGB(238, 62, 78) },
	CrystalStorm = { Icon = "Star", Color = Color3.fromRGB(170, 90, 255) },
	ExplosiveSunday = { Icon = "Bomb", Color = Color3.fromRGB(255, 120, 40) },
}
local FALLBACK = { Icon = "Star", Color = Theme.Colors.Boost }
local GOAL_COLOR = Theme.Colors.Codex
local MAX_EVENT_TILES = 3
local WIDTH = 184

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function commas(n)
	local s = tostring(math.floor(n + 0.5))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function StatusDock.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return ("%dh %02dm"):format(seconds // 3600, (seconds % 3600) // 60)
	end
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- One tile with a fixed size (no automatic sizing, nothing can grow): icon disc, name and a big value line; addBar adds a bar.
local function buildTile(parent, order, look, name)
	local root = make("Frame", { BackgroundColor3 = Theme.Shade(look.Color, 0.4), Size = UDim2.fromOffset(WIDTH, 44), LayoutOrder = order, BorderSizePixel = 0, ZIndex = Theme.Z.Hud }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, root)
	make("UIStroke", { Color = Theme.Colors.Outline, Thickness = Theme.Stroke.Small, LineJoinMode = Enum.LineJoinMode.Round }, root)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(look.Color, 0.1), Theme.Shade(look.Color, 0.35)), Rotation = 90 }, root)

	local row = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 5), Size = UDim2.new(1, -14, 0, 34), ZIndex = Theme.Z.Hud + 1 }, root)
	local disc = make("Frame", { BackgroundColor3 = look.Color, Size = UDim2.fromOffset(34, 34), ZIndex = Theme.Z.Hud + 1 }, row)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
	make("UIStroke", { Color = Theme.Colors.Outline, Thickness = Theme.Stroke.Small }, disc)
	Icons.Draw(look.Icon, disc, nil, 0.86)
	local title = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -40, 0, 14), Font = Theme.Font.Body, Text = name, TextSize = 13, TextColor3 = Theme.Tint(look.Color, 0.75), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = Theme.Z.Hud + 2 }, row)
	Kit.Outline(title, 2)
	local value = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 13), Size = UDim2.new(1, -40, 0, 21), Font = Theme.Font.Display, Text = "", TextSize = 18, TextColor3 = Theme.Colors.Ink, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = Theme.Z.Hud + 2 }, row)
	Kit.Outline(value, 2.5)

	local tile = { Root = root, Value = value, Title = title, Color = look.Color }

	return tile
end

local function addBar(tile)
	tile.Root.Size = UDim2.fromOffset(WIDTH, 60)
	local track = make("Frame", { BackgroundColor3 = Theme.Colors.Outline, Position = UDim2.fromOffset(6, 44), Size = UDim2.new(1, -14, 0, 9), BorderSizePixel = 0, ZIndex = Theme.Z.Hud + 1 }, tile.Root)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local fill = make("Frame", { BackgroundColor3 = Theme.Tint(tile.Color, 0.25), Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, ZIndex = Theme.Z.Hud + 2 }, track)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	tile.Track, tile.Fill = track, fill
end

function StatusDock.Build(parent)
	local holder = make("Frame", { Name = "StatusDock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(WIDTH, 200), ZIndex = Theme.Z.Hud }, parent)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right }, holder)

	local dock = {}
	local eventTiles = {} -- { { Tile, EndsAt } } in display order
	local goalTile, goalView, goalAt = nil, nil, 0
	local bossTile, bossView, bossAt = nil, nil, 0
	local eventSignature = ""

	local function refresh()
		local now = os.clock()
		for _, e in eventTiles do
			e.Tile.Value.Text = StatusDock.FormatTime(e.EndsAt - now)
		end
		if bossTile and bossView then
			local v = bossView
			if v.Defeated then
				bossTile.Title.Text = "WORLD BOSS"
				bossTile.Value.Text = "DEFEATED!"
				bossTile.Fill.Size = UDim2.fromScale(0, 1)
			else
				local left = math.max(0, (v.EndsIn or 0) - (now - bossAt))
				bossTile.Title.Text = string.upper(v.Name or "World boss") .. "  " .. StatusDock.FormatTime(left)
				bossTile.Value.Text = ("%s / %s"):format(commas(v.HP or 0), commas(v.MaxHP or 0))
				bossTile.Fill.Size = UDim2.fromScale(math.clamp((v.HP or 0) / math.max(1, v.MaxHP or 1), 0, 1), 1)
			end
		end
		if goalTile and goalView then
			local v = goalView
			local frenzy = math.max(0, v.FrenzyLeft - (now - goalAt))
			if frenzy > 0 then
				goalTile.Title.Text = "SERVER FRENZY"
				goalTile.Value.Text = StatusDock.FormatTime(frenzy) .. " left"
				goalTile.Fill.Size = UDim2.fromScale(1, 1)
			elseif v.Done then
				goalTile.Title.Text = "SERVER GOAL"
				goalTile.Value.Text = "Reached!"
				goalTile.Fill.Size = UDim2.fromScale(1, 1)
			else
				goalTile.Title.Text = "SERVER GOAL"
				goalTile.Value.Text = ("%s / %s"):format(commas(v.Progress), commas(v.Target))
				goalTile.Fill.Size = UDim2.fromScale(math.clamp(v.Progress / math.max(1, v.Target), 0, 1), 1)
			end
		end
	end

	-- list: the snapshot's Events ({ Id, Name, Description, EndsIn }), receivedAt: os.clock() when it arrived
	function dock.SetEvents(list, receivedAt)
		list = list or {}
		-- snapshots arrive after every volley: same events -> only refresh the end times (keeps tiles and open descriptions)
		local ids = {}
		for i, ev in list do
			if i <= MAX_EVENT_TILES then
				table.insert(ids, tostring(ev.Id or ev.Name))
			end
		end
		local signature = table.concat(ids, "|")
		if signature == eventSignature then
			for i, e in eventTiles do
				e.EndsAt = (receivedAt or os.clock()) + list[i].EndsIn
			end
			refresh()
			return
		end
		eventSignature = signature
		for _, e in eventTiles do
			e.Tile.Root:Destroy()
		end
		table.clear(eventTiles)
		for i, ev in list or {} do
			if i > MAX_EVENT_TILES then
				break
			end
			local look = LOOK[ev.Id] or FALLBACK
			local tile = buildTile(holder, i, look, ev.Name)
			table.insert(eventTiles, { Tile = tile, EndsAt = (receivedAt or os.clock()) + ev.EndsIn })
		end
		refresh()
	end

	-- view: WorldBoss.View (Active, Name, HP, MaxHP, EndsIn) or nil/inactive to hide the tile
	function dock.SetWorldBoss(view, receivedAt)
		local show = view ~= nil and (view.Active or view.Defeated)
		bossView, bossAt = view, receivedAt or os.clock()
		if not show then
			if bossTile then
				bossTile.Root:Destroy()
				bossTile = nil
			end
			return
		end
		if not bossTile then
			bossTile = buildTile(holder, 50, { Icon = "Skull", Color = Theme.Colors.Danger }, "WORLD BOSS")
			addBar(bossTile)
		end
		refresh()
	end

	-- view: Community.View or nil
	function dock.SetGoal(view, receivedAt)
		goalView, goalAt = view, receivedAt or os.clock()
		if not view then
			if goalTile then
				goalTile.Root:Destroy()
				goalTile = nil
			end
			return
		end
		if not goalTile then
			goalTile = buildTile(holder, 100, { Icon = "Goals", Color = GOAL_COLOR }, "SERVER GOAL")
			addBar(goalTile)
		end
		refresh()
	end

	task.spawn(function()
		while holder.Parent do
			task.wait(1)
			refresh()
		end
	end)
	return dock
end

return StatusDock
