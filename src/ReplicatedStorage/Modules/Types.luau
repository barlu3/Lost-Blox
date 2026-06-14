-- Shared type manifest. Both server and client require this module for type-checking.
-- Add new types here as systems are built; never put runtime logic in this file.
--
-- NOTE: pure-logic modules (DamageCalculator, EngravingResolver, HoningCalculator,
-- LootTable, TripodResolver, …) intentionally redeclare the shapes they need
-- locally so they stay free of any require() and remain unit-testable outside
-- Roblox. This manifest is the contract for cross-boundary (server↔client) data.

export type TargetType = "single" | "aoe" | "self"

export type SkillDef = {
	id: string,
	cooldown: number,
	range: number,
	damageMultiplier: number,
	resourceCost: number,
	targetType: TargetType,
	aoeRadius: number?,
	key: string?,
}

-- Accumulated passive modifiers from engravings + tripods, consumed by DamageCalculator.
export type ModifierTable = {
	damageAdd: number,
	damageMul: number,
	critRate: number,
	critDamage: number,
}

export type CharacterStats = {
	baseAttack: number,
	critChance: number,
	critDamage: number,
	iLvl: number,
	maxHealth: number,
	resource: number,
	resourceType: string,
}

export type CastResult = {
	ok: boolean,
	damage: number?,
	didCrit: boolean?,
	reason: string?,
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

export type HoningResult = {
	success: boolean,
	newLevel: number?,
	pityCounter: number?,
	reason: string?,
}

export type EngravingTier = {
	threshold: number,
	type: string,
	value: number,
}

export type EngravingDef = {
	id: string,
	tiers: { EngravingTier },
	filter: string?,
}

export type TripodOption = {
	id: string,
	type: "damage" | "cooldown" | "aoe_radius",
	value: number,
}

export type QuestObjective = {
	id: string,
	type: "kill" | "reach" | "collect",
	target: string,
	count: number?,
}

export type QuestReward = {
	type: "item" | "exp",
	id: string?,
	quantity: number?,
	amount: number?,
}

export type QuestDef = {
	id: string,
	name: string,
	objectives: { QuestObjective },
	rewards: { QuestReward },
}

export type ActiveQuestData = {
	-- Values are either a count (kill/collect objectives) or a boolean (reach objectives).
	progress: { [string]: number | boolean },
	startedAt: number,
}

export type LootEntry = {
	id: string,
	weight: number,
	min_ilvl: number,
}

export type LootResult = {
	id: string,
	quality: number,
}

export type MechanicDef = {
	name: string,
	telegraph: number,
	radius: number,
	shape: "circle" | "square" | "ring",
	colorHint: boolean?,
	checkThreshold: number?,
}

export type BattlePassData = {
	season: string,
	xp: number,
	tier: number,
	premiumUnlocked: boolean,
	claimedTiers: { number },
}

export type PlayerData = {
	characterSlot: number,
	slots: { any },
	inventory: { ItemStack },
	equippedItems: EquippedItems,
	equippedTripods: { [string]: string },
	engravings: { [string]: number },
	honing: { [string]: HoningState },
	questProgress: { [string]: ActiveQuestData },
	completedQuests: { string },
	weeklyLockout: { [string]: boolean },
	battlePass: BattlePassData?,
	exp: number,
	createdAt: number,
}

return {}
