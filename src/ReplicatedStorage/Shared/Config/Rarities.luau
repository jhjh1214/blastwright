--!strict
return {
	Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },
	Info = {
		Common = { Color = { 200, 205, 215 } },
		Uncommon = { Color = { 110, 220, 130 } },
		Rare = { Color = { 90, 160, 255 } },
		Epic = { Color = { 200, 110, 255 } },
		Legendary = { Color = { 255, 190, 60 } },
		Mythic = { Color = { 255, 90, 120 } },
	} :: { [string]: { Color: { number } } },
}
