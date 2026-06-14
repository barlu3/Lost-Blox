-- Server-authoritative skill execution. The client fires CastSkill with
-- { skillId, targetId } and the server owns all resolution: validation, damage,
-- and health writes. CharacterStats is never replicated to the client.
--
-- The pure pieces live in CastValidator (ordering rules) and DamageCalculator
-- (formula); this module is the runtime integrator + RemoteEvent wiring.
local Players = game:GetService("Players")

local SkillRegistry = require(script.Parent.SkillRegistry)
local DamageCalculator = require(script.Parent.DamageCalculator)
local CastValidator = require(script.Parent.CastValidator)
local TripodResolver = require(script.Parent.TripodResolver)
local EngravingResolver = require(script.Parent.EngravingResolver)

local SkillExecutor = {}

-- Keyed by Player so entries clear naturally on PlayerRemoving. Never exposed.
local characterStats: { [Player]: any } = {}
local lastCast: { [Player]: { [string]: number } } = {}
local equippedTripods: { [Player]: { [string]: string } } = {}
local engravingBooks: { [Player]: { [string]: number } } = {}

-- Resolver supplied by combat content (boss/mob systems) so the executor doesn't
-- hard-code how a targetId maps to a damageable object. Returns a table with
-- { position: Vector3, alive: boolean, takeDamage: (number) -> () } or nil.
local resolveTarget: ((player: Player, targetId: any) -> any?)? = nil

function SkillExecutor.setStats(player: Player, stats: any)
	characterStats[player] = stats
end

function SkillExecutor.getStats(player: Player): any?
	return characterStats[player]
end

function SkillExecutor.setEquippedTripods(player: Player, tripods: { [string]: string })
	equippedTripods[player] = tripods
end

function SkillExecutor.setEngravings(player: Player, book: { [string]: number })
	engravingBooks[player] = book
end

function SkillExecutor.setTargetResolver(fn: (player: Player, targetId: any) -> any?)
	resolveTarget = fn
end

-- Resolves one cast. Returns a CastResult; on failure the reason is for server
-- logs only and is never relayed to the client.
function SkillExecutor.tryCast(player: Player, skillId: string, target: any): { ok: boolean, reason: string?, damage: number?, didCrit: boolean? }
	local baseSkill = SkillRegistry.get(skillId)
	local stats = characterStats[player]
	if stats == nil or baseSkill == nil then
		return { ok = false, reason = "no_stats" }
	end

	-- Apply the equipped tripod to a copy (tripods can shorten cooldown, so this
	-- must happen before the cooldown check).
	local tripodId = equippedTripods[player] and equippedTripods[player][skillId]
	local skill = TripodResolver.resolve(baseSkill :: any, tripodId)

	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local casterState = {
		position = hrp and hrp.Position or Vector3.new(),
		resource = stats.resource or 0,
		lastCast = lastCast[player] or {},
	}

	local reason = CastValidator.validate(skill, casterState, target, os.clock())
	if reason ~= "ok" then
		return { ok = false, reason = reason }
	end

	-- Commit cooldown + resource cost before dealing damage.
	lastCast[player] = lastCast[player] or {}
	lastCast[player][skillId] = os.clock()
	stats.resource = (stats.resource or 0) - skill.resourceCost

	-- Engravings resolve to damage modifiers before the hit is calculated.
	local mods = EngravingResolver.resolve(engravingBooks[player] or {}, skillId)
	local result = DamageCalculator.calculate(stats, skill, mods, nil)

	if skill.targetType ~= "self" and target and target.takeDamage then
		target.takeDamage(result.damage)
	end

	return { ok = true, damage = result.damage, didCrit = result.didCrit }
end

-- Connects the CastSkill RemoteEvent. Call once from a server entry script.
function SkillExecutor.start(castSkill: RemoteEvent)
	castSkill.OnServerEvent:Connect(function(player: Player, skillId: any, targetId: any)
		if type(skillId) ~= "string" then
			return
		end
		local target = if resolveTarget then resolveTarget(player, targetId) else nil
		-- Result intentionally discarded: failures are silent to the client.
		SkillExecutor.tryCast(player, skillId, target)
	end)

	Players.PlayerRemoving:Connect(function(player)
		characterStats[player] = nil
		lastCast[player] = nil
		equippedTripods[player] = nil
		engravingBooks[player] = nil
	end)
end

return SkillExecutor
