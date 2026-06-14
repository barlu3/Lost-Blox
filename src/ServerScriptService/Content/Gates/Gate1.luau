-- Legion Raid "First Hollow Lord" — Gate 1 data. Gate scripts are pure data
-- tables; RaidController orchestrates execution (one-way dependency).
return {
	gate = 1,
	boss_id = "first_hollow_lord",
	hp_base = 2000000,
	mechanics = {
		{ type = "ColorMatch", trigger_hp = 0.85, detonation_time = 5 },
		{ type = "DPSCheck", trigger_hp = 0.50, threshold = 0.40, time_limit = 25 },
		{ type = "PillarPhase", trigger_hp = 0.15, pillar_count = 6, time_limit = 40 },
	},
}
