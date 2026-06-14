--!strict
-- Timed combat effects (e.g. Stormcaller's Arcane Surge). DamageCalculator reads
-- the resolved modifiers before resolving a hit. Pure and unit-testable; the
-- store is just a table of { [effectName]: expiresAt } keyed off os.clock().

local ActiveEffects = {}

ActiveEffects.ARCANE_SURGE_DAMAGE_MUL = 0.30
ActiveEffects.ARCANE_SURGE_COOLDOWN_MUL = -0.50

export type Store = { [string]: number }

function ActiveEffects.apply(store: Store, name: string, now: number, duration: number)
	store[name] = now + duration
end

function ActiveEffects.isActive(store: Store, name: string, now: number): boolean
	local expiresAt = store[name]
	return expiresAt ~= nil and now < expiresAt
end

-- Modifiers contributed by Arcane Surge when active: +30% damage, -50% cooldown.
function ActiveEffects.surgeModifiers(store: Store, now: number): { damageMul: number, cooldownMul: number }
	if ActiveEffects.isActive(store, "arcane_surge", now) then
		return {
			damageMul = ActiveEffects.ARCANE_SURGE_DAMAGE_MUL,
			cooldownMul = ActiveEffects.ARCANE_SURGE_COOLDOWN_MUL,
		}
	end
	return { damageMul = 0, cooldownMul = 0 }
end

return ActiveEffects
