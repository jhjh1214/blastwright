def edit(p, pairs):
    s = open(p, encoding='utf-8', newline='').read()
    crlf = '\r\n' in s
    s = s.replace('\r\n', '\n')
    for a, b in pairs:
        assert s.count(a) == 1, (p, s.count(a), a[:80])
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if crlf else s)

C = 'src/StarterPlayer/StarterPlayerScripts/Client/'
edit('src/ServerScriptService/Server/Game.luau', [
    ('		notify(player, warning[threat.Type], "Error")', '		notify(player, warning[threat.Type], "Threat") -- the boss panel shows it; this only plays the warning sound'),
])
edit(C + 'BossHud.luau', [
    ('-- parent: the blast HUD group. config: Config.Bosses.', 'BossHud.Objective = objective\n\n-- parent: the blast HUD group. config: Config.Bosses.'),
])
edit(C + 'UI.luau', [
    ('-- Big moments (chain tiers, Critical Mass, boss phases) use the banner', '''-- The boss appears / changes phase: a banner with the name (or the new phase) and what to do now.
function UI.ShowBossIntro(boss)
	AudioManager.Play("Tier")
	local def = Config.Bosses.Defs[boss.Kind]
	Feed.Banner(string.upper(boss.Name), def and def.Description or nil, Color3.fromRGB(214, 70, 78), 3.2)
end

function UI.ShowPhase(phase, boss)
	AudioManager.Play("Tier")
	Feed.Banner(string.upper(phase) .. " PHASE", boss and BossHud.Objective(boss, Config.Bosses) or nil, BossHud.PhaseColor[phase] or THEME.Gold, 2.2)
end

-- Big moments (chain tiers, Critical Mass, boss phases) use the banner'''),
])
edit(C + 'CavernView.luau', [
    # kick + arena
    ('				boss:PivotTo(view.BossBase * CFrame.new(0, math.sin(t * 1.4) * 0.35, 0) * CFrame.Angles(0, math.sin(t * 0.7) * 0.06, 0))', '''				local kick = view.BossKick and math.max(0, 1 - (t - view.BossKick) / 0.4) or 0 -- recoil when hit
				boss:PivotTo(view.BossBase * CFrame.new(0, math.sin(t * 1.4) * 0.35, kick * 1.6) * CFrame.Angles(kick * 0.05, math.sin(t * 0.7) * 0.06, 0))'''),
    ('	Creatures.SetPhase(model, boss.Phase)\n', '''	Creatures.SetPhase(model, boss.Phase)
	-- the arena: a coloured border around the grid and a sigil under the boss, both in the phase colour
	local phaseColor = ({ Armor = Color3.fromRGB(240, 190, 60), Attack = Color3.fromRGB(232, 92, 84), Weak = Color3.fromRGB(226, 90, 200), Enrage = Color3.fromRGB(236, 56, 56), Finisher = Color3.fromRGB(96, 214, 230) })[boss.Phase] or Color3.fromRGB(232, 92, 84)
	local mid = (view.Size + 1) / 2
	local centre = Geometry.CellPosition(view.Origin, mid, mid)
	local half = view.Extent / 2 + 1
	for _, side in { { 0, -half, view.Extent + 3, 1.4 }, { 0, half, view.Extent + 3, 1.4 }, { -half, 0, 1.4, view.Extent + 3 }, { half, 0, 1.4, view.Extent + 3 } } do
		local strip = Instance.new("Part")
		strip.Anchored, strip.CanCollide, strip.CanQuery, strip.CastShadow = true, false, false, false
		strip.Material = Enum.Material.Neon
		strip.Color = phaseColor
		strip.Transparency = 0.45
		strip.Size = Vector3.new(side[3], 0.3, side[4])
		strip.Position = centre + Vector3.new(side[1], 0.25, side[2])
		strip.Parent = view.BossFx
	end
	local sigil = Instance.new("Part")
	sigil.Anchored, sigil.CanCollide, sigil.CanQuery, sigil.CastShadow = true, false, false, false
	sigil.Shape = Enum.PartType.Cylinder
	sigil.Material = Enum.Material.Neon
	sigil.Color = phaseColor
	sigil.Transparency = 0.7
	sigil.Size = Vector3.new(0.2, CellSize * 3.6, CellSize * 3.6)
	sigil.CFrame = CFrame.new(centre + Vector3.new(0, 0.22, 0)) * CFrame.Angles(0, 0, math.rad(90))
	sigil.Parent = view.BossFx
'''),
    ('function CavernView.BossPosition(view)', '''function CavernView.BossHit(view)
	view.BossKick = os.clock()
end

function CavernView.BossPosition(view)'''),
])
edit(C + 'init.client.luau', [
    ('		UI.ShowTier("Boss defeated")\n', '		UI.ShowTier("Boss defeated")\n		UI.Flash(Color3.fromRGB(255, 240, 200), 0.6)\n'),
    ('	elseif turn.PhaseChanged then\n		UI.ShowTier(turn.PhaseChanged .. " phase")\n		CameraFeedback.Punch(5)\n', '''	elseif turn.PhaseChanged then
		UI.ShowPhase(turn.PhaseChanged, turn.Boss)
		CameraFeedback.Punch(6)
		CameraFeedback.Shake(1.2)
		VFX.Ring(view.Origin + Vector3.new(0, 0.4, 0), Color3.fromRGB(255, 220, 160), view.Extent * 1.6, 0.8)
		UI.Flash(Color3.fromRGB(255, 255, 255), 0.25)
'''),
    ('	if hitPos and hitAmount then\n', '''	if turn.BossDamage and turn.BossDamage > 0 then
		CavernView.BossHit(view)
	end
	-- an attack landed: fire where the crystals were destroyed
	if #turn.Eaten > 0 and turn.Boss then
		for i = 1, math.min(#turn.Eaten, 10) do
			local at = Geometry.CellPosition(view.Origin, turn.Eaten[i].X, turn.Eaten[i].Z) + Vector3.new(0, 2, 0)
			VFX.Burst(at, Color3.fromRGB(255, 130, 60), 10, 24)
		end
		CameraFeedback.Shake(1)
	end
	if hitPos and hitAmount then
'''),
    ('	-- The boss markers (armor nodes, weak points, marked attack cells) follow the server\'s snapshot.\n	local view = CavernView.Get(localPlayer.UserId)\n	if view then\n', '''	-- The boss markers (armor nodes, weak points, marked attack cells) follow the server's snapshot.
	local view = CavernView.Get(localPlayer.UserId)
	if snapshot.Boss and not State.LastBoss and State.Engaged then
		UI.ShowBossIntro(snapshot.Boss) -- the boss just appeared
		CameraFeedback.Punch(7)
	end
	State.LastBoss = snapshot.Boss ~= nil
	if view then
'''),
])
print('boss fx ok')
