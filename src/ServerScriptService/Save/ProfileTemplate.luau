-- Default data shape for a new player profile.
-- Reconcile() adds any keys present here that are missing from saved data,
-- so adding a new key here is the schema migration path — no data wipe.
local ProfileTemplate = {
	characterSlot = 1,
	-- Each entry: { name: string, class: string, createdAt: number }
	slots = {},
	inventory = {},
	equippedItems = {},
	honing = {},
	questProgress = {},
	completedQuests = {},
	createdAt = 0,
}

return ProfileTemplate
