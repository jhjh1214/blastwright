--!strict
-- Boss finishers: the FINAL BLAST look when a boss falls (colors of the bursts and rings). Cosmetic only. The default is
-- free; the rest are shop items (see Config/Products.luau Offers). Other players near you see yours.
export type Def = { Id: string, Name: string, Color: { number }, Shop: boolean? }

return {
	DefaultId = "Gold",
	Defs = {
		{ Id = "Gold", Name = "Golden Finish", Color = { 255, 205, 90 } },
		{ Id = "Celestial", Name = "Celestial Finish", Color = { 170, 215, 255 }, Shop = true },
		{ Id = "Inferno", Name = "Inferno Finish", Color = { 255, 90, 40 }, Shop = true },
		{ Id = "Void", Name = "Void Finish", Color = { 175, 90, 255 }, Shop = true },
	} :: { Def },
}
