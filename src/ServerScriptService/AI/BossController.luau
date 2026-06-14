--!strict
-- Server-side boss state machine. The boss cycles Idle → Approach → Telegraph →
-- Attack and back, stepping through a mechanic sequence. Enrage is a one-shot
-- modifier (HP < 30%); Stagger is an externally triggered damage-taken window.
--
-- All side effects go through an injected `world` interface, so the transition
-- logic is unit-testable with a mock world and the harness-controlled os.clock.
-- A real Roblox world is built by RobloxBossWorld at runtime.

local BossController = {}
BossController.__index = BossController

export type Mechanic = {
	name: string,
	telegraph: number,
	radius: number,
	shape: string,
	colorHint: boolean?,
	checkThreshold: number?,
}

export type Config = {
	aggroRadius: number,
	meleeRange: number,
	enrageThreshold: number,
	enrageMoveMult: number,
	enrageDamageMult: number,
	staggerDuration: number,
	attackDamage: number,
	mechanics: { Mechanic },
}

-- The world interface the controller drives. See RobloxBossWorld for the live impl.
export type World = {
	getPlayers: () -> { any },
	getBossPosition: () -> Vector3,
	moveBossTo: (Vector3) -> (),
	getHpFraction: () -> number,
	spawnDangerZone: (Mechanic, Vector3) -> any,
	playersInZone: (any) -> { any },
	applyDamage: (any, number) -> (),
	clearDangerZone: (any) -> (),
	applyEnrage: (number, number) -> (),
}

local DEFAULT_MECHANICS: { Mechanic } = {
	{ name = "AoE Sweep", telegraph = 1.2, radius = 10, shape = "circle" },
	{ name = "Color Match", telegraph = 1.8, radius = 5, shape = "square", colorHint = true },
	{ name = "DPS Burn", telegraph = 0.8, radius = 20, shape = "ring", checkThreshold = 0.15 },
}

function BossController.defaultConfig(): Config
	return {
		aggroRadius = 40,
		meleeRange = 6,
		enrageThreshold = 0.30,
		enrageMoveMult = 1.5,
		enrageDamageMult = 1.3,
		staggerDuration = 2,
		attackDamage = 100,
		mechanics = DEFAULT_MECHANICS,
	}
end

function BossController.new(config: Config, world: World)
	local self = setmetatable({}, BossController)
	self.config = config
	self.world = world
	self.state = "Idle"
	self.enraged = false
	self.mechanicIndex = 1
	self.telegraphStart = 0
	self.telegraphDuration = 0
	self.activeZone = nil
	self.staggerUntil = 0
	self.targetPosition = nil
	return self
end

function BossController:getState(): string
	return self.state
end

function BossController:isEnraged(): boolean
	return self.enraged
end

-- Returns the nearest living player within radius of the boss, or nil.
local function nearestPlayerInRadius(bossPos: Vector3, players: { any }, radius: number): any?
	local best, bestDist = nil, math.huge
	for _, p in players do
		if p.alive then
			local d = (p.position - bossPos).Magnitude
			if d <= radius and d < bestDist then
				best, bestDist = p, d
			end
		end
	end
	return best
end

-- Externally triggered when a stagger threshold is crossed: opens a 2s window.
function BossController:triggerStagger()
	self.staggerUntil = os.clock() + self.config.staggerDuration
	self.state = "Stagger"
end

-- Damage-taken multiplier; +50% while staggered (used by the damage pipeline).
function BossController:damageTakenMultiplier(): number
	return if self.state == "Stagger" then 1.5 else 1.0
end

local function enterTelegraph(self: any)
	local mechanic = self.config.mechanics[self.mechanicIndex]
	self.telegraphStart = os.clock()
	self.telegraphDuration = mechanic.telegraph
	self.activeZone = self.world.spawnDangerZone(mechanic, self.targetPosition or self.world.getBossPosition())
	self.state = "Telegraph"
end

-- Advances the machine one tick. `dt` is unused by the transition logic itself
-- (timing reads os.clock) but kept for parity with onTick(dt) heartbeats.
function BossController:step(_dt: number?)
	-- Enrage check runs every tick but applies its modifier exactly once.
	if not self.enraged and self.world.getHpFraction() < self.config.enrageThreshold then
		self.enraged = true
		self.world.applyEnrage(self.config.enrageMoveMult, self.config.enrageDamageMult)
	end

	local state = self.state
	if state == "Idle" then
		local target = nearestPlayerInRadius(self.world.getBossPosition(), self.world.getPlayers(), self.config.aggroRadius)
		if target then
			self.state = "Approach"
		end
	elseif state == "Approach" then
		local target = nearestPlayerInRadius(self.world.getBossPosition(), self.world.getPlayers(), self.config.aggroRadius)
		if not target then
			self.state = "Idle"
			return
		end
		self.targetPosition = target.position
		self.world.moveBossTo(target.position)
		local dist = (target.position - self.world.getBossPosition()).Magnitude
		if dist <= self.config.meleeRange then
			enterTelegraph(self)
		end
	elseif state == "Telegraph" then
		-- Cannot be interrupted once entered; resolves after the wind-up.
		if os.clock() - self.telegraphStart >= self.telegraphDuration then
			self.state = "Attack"
		end
	elseif state == "Attack" then
		-- Only players inside the danger zone take damage.
		for _, p in self.world.playersInZone(self.activeZone) do
			self.world.applyDamage(p, self.config.attackDamage)
		end
		self.world.clearDangerZone(self.activeZone)
		self.activeZone = nil
		self.mechanicIndex += 1
		if self.mechanicIndex > #self.config.mechanics then
			self.mechanicIndex = 1
		end
		self.state = "Approach"
	elseif state == "Stagger" then
		if os.clock() >= self.staggerUntil then
			self.state = "Approach"
		end
	end
end

return BossController
