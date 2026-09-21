--!strict
-- Live events: recurring time windows (UTC) that change a rule for everyone on the server. No server restarts or
-- updates are needed; the calendar does the work. Weekdays are Monday = 0 to Sunday = 6. A window is
-- [StartHour, EndHour) within the day (EndHour 24 = midnight). Effects: MutationMult (multiplies the Prismatic spawn
-- chance), ShardMult (multiplies blast payouts), ChargeBonus (extra charges per seam). Add an event by adding a table.
export type Def = {
	Id: string,
	Name: string,
	Description: string,
	Weekdays: { number },
	StartHour: number,
	EndHour: number,
	Effects: { [string]: number },
}

return {
	Defs = {
		{
			Id = "PrismaticWeekend",
			Name = "Prismatic Weekend",
			Description = "Crystals are 3x as likely to be Prismatic.",
			Weekdays = { 5, 6 },
			StartHour = 0,
			EndHour = 24,
			Effects = { MutationMult = 3 },
		},
		{
			Id = "OverchargeWednesday",
			Name = "Overcharge Wednesday",
			Description = "+1 charge on every seam.",
			Weekdays = { 2 },
			StartHour = 0,
			EndHour = 24,
			Effects = { ChargeBonus = 1 },
		},
		{
			Id = "HappyHour",
			Name = "Happy Hour",
			Description = "Blast payouts are 1.5x.",
			Weekdays = { 0, 1, 2, 3, 4, 5, 6 },
			StartHour = 18,
			EndHour = 19,
			Effects = { ShardMult = 1.5 },
		},
	} :: { Def },
}
