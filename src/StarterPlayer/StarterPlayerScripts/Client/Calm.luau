--!nonstrict
-- "Calm" mode: while a boss is on the grid or an Expedition is running the player must be able to read the field (where to
-- hit, when to dodge), so the loud effects are turned down: fewer/fainter particles, thin rings instead of big discs,
-- weaker camera shake and punch, and only important banners. Set by UI when the boss/run state changes; read by VFX,
-- CameraFeedback and Feed. Cosmetic only.
local Calm = { On = false }

function Calm.Set(on)
	Calm.On = on == true
end

return Calm
