-- Default data shape for a new player profile.
-- Reconcile() adds any keys present here that are missing from saved data,
-- so adding a new key here is the schema migration path — no data wipe.
local ProfileTemplate = {
	characterSlot = 1,
	-- Each entry: { name: string, class: string, createdAt: number }
	slots = {},
	inventory = {},
	equippedItems = {},
	-- Engraving book: { [engravingId]: points 0–15 }
	engravings = {},
	-- One equipped tripod option id per skill: { [skillId]: tripodOptionId }
	equippedTripods = {},
	honing = {},
	questProgress = {},
	completedQuests = {},
	-- Weekly raid lockout keys: { ["<isoWeek>:<raidId>:<gate>"]: true }
	weeklyLockout = {},
	-- Set lazily on first Battle Pass interaction (see BattlePass module).
	battlePass = nil,
	exp = 0,
	createdAt = 0,
}

return ProfileTemplate
