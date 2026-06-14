--!strict
-- Class resource math for Stormcaller (Arcana) and Skystrike (Chi). The pure
-- helpers below hold all the accumulation/spend rules and are unit-testable;
-- the runtime layer tracks per-player resource (in CharacterStats, not the
-- profile — it resets on death/relog) and replicates each change to the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResourceManager = {}

-- Stormcaller — Arcana
ResourceManager.ARCANA_MAX = 100
ResourceManager.ARCANA_PER_BUILDER = 8
ResourceManager.ARCANE_SURGE_DURATION = 6

-- Skystrike — Chi
ResourceManager.CHI_MAX = 3
ResourceManager.CHI_PER_BUILDER = 1
ResourceManager.CHI_DAMAGE_PER_STACK = 0.25

-- ── Pure resource math ──────────────────────────────────────────────────────
function ResourceManager.addArcana(current: number, amount: number?): number
	return math.min(current + (amount or ResourceManager.ARCANA_PER_BUILDER), ResourceManager.ARCANA_MAX)
end

function ResourceManager.canSpend(current: number, cost: number): boolean
	return current >= cost
end

function ResourceManager.spend(current: number, cost: number): number
	return math.max(current - cost, 0)
end

function ResourceManager.canArcaneSurge(arcana: number): boolean
	return arcana >= ResourceManager.ARCANA_MAX
end

function ResourceManager.addChi(current: number, amount: number?): number
	return math.min(current + (amount or ResourceManager.CHI_PER_BUILDER), ResourceManager.CHI_MAX)
end

-- Spender damage scales base * (1 + 0.25 * chi). chi = 0 yields base, not a reject.
function ResourceManager.chiDamageMultiplier(chi: number): number
	return 1 + ResourceManager.CHI_DAMAGE_PER_STACK * chi
end

function ResourceManager.canTigersWrath(chi: number): boolean
	return chi >= ResourceManager.CHI_MAX
end

-- ── Runtime per-player resource + replication ───────────────────────────────
local resourceUpdated: RemoteEvent? = nil
local resourceByPlayer: { [Player]: number } = {}

function ResourceManager.get(player: Player): number
	return resourceByPlayer[player] or 0
end

function ResourceManager.set(player: Player, value: number)
	resourceByPlayer[player] = value
	if resourceUpdated then
		resourceUpdated:FireClient(player, value)
	end
end

function ResourceManager.reset(player: Player)
	ResourceManager.set(player, 0)
end

function ResourceManager.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("ResourceUpdated")
	if existing then
		resourceUpdated = existing :: RemoteEvent
	else
		local r = Instance.new("RemoteEvent")
		r.Name = "ResourceUpdated"
		r.Parent = remotes
		resourceUpdated = r
	end
end

return ResourceManager
