--!strict
-- Third-party decor models from the Creator Store. Every id here was returned by the Creator Store API, had its
-- thumbnail viewed, and was re-checked (free, hash-approved, hasScripts == false); see docs/ASSET_REGISTRY.md.
-- Server/Props.luau strips everything except visual geometry at load time and falls back to procedural decor
-- if a model cannot be loaded, so a missing/removed asset never breaks the world.
export type PropDef = { Id: number, Name: string, Creator: string }

return {
	Defs = {
		CrystalA = { Id = 15618160671, Name = "Crystal Cluster", Creator = "kingOfcats9912828" },
		CrystalB = { Id = 12882247457, Name = "crystals6", Creator = "senya0079" },
		Lamp = { Id = 17451005959, Name = "lamp", Creator = "metrox1223" },
		MushroomA = { Id = 2986139359, Name = "Glowing Mushroom", Creator = "CaptainOwlin" },
		MushroomB = { Id = 1532334716, Name = "Glowing Mushroom", Creator = "Chooonky" },
		StalagmiteA = { Id = 9687949418, Name = "Stalagmite 1", Creator = "Jey_Jacule" },
		StalagmiteB = { Id = 10186366587, Name = "stalagmite 2", Creator = "Firesquirrel777" },
		Crate = { Id = 182451181, Name = "Wooden Crate", Creator = "Quenty" },
	} :: { [string]: PropDef },
}
