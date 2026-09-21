--!strict
-- Blast colors: cosmetic styles for your charges, detonation rings and planting markers. No gameplay effect.
-- Ownership is derived: the first entry is free; UnlockGoal styles are owned once that goal is claimed
-- (Config/Achievements.luau); Shop styles are owned only after a purchase (none can be bought until the developer
-- creates the product, see docs/MONETIZATION.md). Other players see your equipped color on your blasts.
export type Def = { Id: string, Name: string, Color: { number }, UnlockGoal: string?, Shop: boolean? }

return {
	DefaultId = "Classic",
	Defs = {
		{ Id = "Classic", Name = "Classic", Color = { 255, 170, 60 } },
		{ Id = "Frostfire", Name = "Frostfire", Color = { 140, 225, 255 }, UnlockGoal = "Chain1" },
		{ Id = "Rosegold", Name = "Rose Gold", Color = { 255, 150, 170 }, UnlockGoal = "Seams1" },
		{ Id = "Verdant", Name = "Verdant", Color = { 120, 235, 140 }, UnlockGoal = "Cache1" },
		{ Id = "Royal", Name = "Royal", Color = { 190, 130, 255 }, UnlockGoal = "Chain2" },
		{ Id = "Solar", Name = "Solar", Color = { 255, 230, 120 }, UnlockGoal = "Earn2" },
		{ Id = "NeonPink", Name = "Neon Pink", Color = { 255, 80, 200 }, Shop = true },
		{ Id = "Void", Name = "Void", Color = { 150, 80, 255 }, Shop = true },
		{ Id = "Toxic", Name = "Toxic", Color = { 140, 255, 60 }, Shop = true },
		{ Id = "Golden", Name = "Golden", Color = { 255, 215, 0 }, Shop = true },
	} :: { Def },
}
