--!strict
-- Server Goal: every player on a server pools their pops toward one shared target. When it is reached, everyone who
-- contributed gets RewardShards and the whole server gets a short Frenzy (payouts x FrenzyShardMult). Then a new round
-- starts, retargeted for how many players are online. Targets scale with players so a lone player and a full server
-- both get a goal that takes a few minutes.
return {
	BasePops = 250, -- pops needed with one player
	PopsPerPlayer = 150, -- added per extra player online at the start of the round
	MaxTarget = 2500,
	RewardShards = 1500, -- per contributing player when the goal is reached
	FrenzySeconds = 180,
	FrenzyShardMult = 1.25,
	NewRoundDelay = 20, -- seconds between finishing a goal and the next round starting
}
