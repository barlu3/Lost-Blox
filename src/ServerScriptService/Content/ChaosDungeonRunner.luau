-- Runs a 3-phase Chaos Dungeon instance on the server. Phase 1 clears mobs,
-- Phase 2 an elite, Phase 3 the boss; loot rolls once per phase completion.
-- Score/phase/iLvl rules come from ChaosDungeon (pure); spawning and loot I/O
-- are here. The client UI only receives score/phase updates via RemoteEvent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChaosDungeon = require(script.Parent.ChaosDungeon)
local GuardianRaid = require(script.Parent.GuardianRaid)
local LootTable = require(script.Parent.Parent.Loot.LootTable)

local ChaosDungeonRunner = {}
ChaosDungeonRunner.__index = ChaosDungeonRunner

-- config: decoded ChaosTiers/T<n>.json. world: { spawnMobs, spawnElite,
-- spawnBoss, onPhaseUpdate, grantLoot } supplied by the runtime.
function ChaosDungeonRunner.new(config: any, world: any, playerCount: number)
	local self = setmetatable({}, ChaosDungeonRunner)
	self.config = config
	self.world = world
	self.playerCount = playerCount
	self.score = ChaosDungeon.newScore(0)
	self.phase = 0
	self.deadline = os.clock() + config.time_limit_seconds
	return self
end

function ChaosDungeonRunner:remainingSeconds(): number
	return math.max(0, self.deadline - os.clock())
end

function ChaosDungeonRunner:onMobKilled()
	ChaosDungeon.registerKill(self.score, os.clock())
end

-- Called by the runtime when a phase's clear condition is met (mob count 0,
-- elite dead, or boss dead). Awards the time bonus and rolls loot once.
function ChaosDungeonRunner:completePhase(lootTier: number)
	ChaosDungeon.addTimeBonus(self.score, self:remainingSeconds())
	local roll = LootTable.roll(self.config.loot_table_id, self.world.playerILvl())
	self.world.grantLoot(roll)
	self.phase += 1
	self.world.onPhaseUpdate(self.phase, self.score.score)
end

return ChaosDungeonRunner
