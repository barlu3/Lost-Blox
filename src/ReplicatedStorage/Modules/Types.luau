-- Shared type manifest. Both server and client require this module for type-checking.
-- Add new types here as systems are built; never put runtime logic in this file.

export type TargetType = "single" | "aoe" | "self"

export type SkillDef = {
	id: string,
	cooldown: number,
	range: number,
	damageMultiplier: number,
	resourceCost: number,
	targetType: TargetType,
	aoeRadius: number?,
}

export type ItemStack = {
	id: string,
	quantity: number,
	quality: number,
	iLvl: number,
}

export type EquippedItems = {
	weapon: ItemStack?,
	head: ItemStack?,
	chest: ItemStack?,
	legs: ItemStack?,
	accessory1: ItemStack?,
	accessory2: ItemStack?,
}

export type HoningState = {
	tier: number,
	level: number,
	pityCounter: number,
	pityBonus: number,
}

export type ActiveQuestData = {
	-- Values are either a count (kill/collect objectives) or a boolean (reach objectives).
	progress: { [string]: number | boolean },
	startedAt: number,
}

export type PlayerData = {
	characterSlot: number,
	inventory: { ItemStack },
	equippedItems: EquippedItems,
	honing: { [string]: HoningState },
	questProgress: { [string]: ActiveQuestData },
	completedQuests: { string },
	createdAt: number,
}

return {}
