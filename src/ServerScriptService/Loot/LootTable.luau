--!strict
-- Pure weighted-drop roller with quality scaling. All randomness flows through an
-- injected Random instance (LootTable.new(seed)) so rolls are deterministic and
-- unit-testable. No profile reads, no RemoteEvents — callers pass the result to
-- InventoryManager.AddItem.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootTable = {}
LootTable.__index = LootTable

export type Entry = { id: string, weight: number, min_ilvl: number }
export type TableDef = { id: string, entries: { Entry } }
export type Result = { id: string, quality: number }

-- Quality buckets. NOTE(barlu3): the timeline's floor(rng*100) yields 0–99 and
-- can never reach the Legendary bucket (100); we roll an integer over [0,100]
-- instead so all buckets — including ~1% Legendary — are reachable.
function LootTable.qualityBucket(quality: number): string
	if quality >= 100 then
		return "legendary"
	elseif quality >= 86 then
		return "epic"
	elseif quality >= 61 then
		return "rare"
	elseif quality >= 31 then
		return "uncommon"
	end
	return "common"
end

function LootTable.new(seed: number)
	return setmetatable({ rng = Random.new(seed) }, LootTable)
end

-- Filters by iLvl gate, normalizes the remaining weights, and walks the
-- cumulative distribution. Quality is an independent roll over [0, 100].
function LootTable.rollTable(self: any, def: TableDef, playerILvl: number): Result?
	local filtered: { Entry } = {}
	local total = 0
	for _, entry in def.entries do
		if entry.min_ilvl <= playerILvl then
			table.insert(filtered, entry)
			total += entry.weight
		end
	end
	if #filtered == 0 or total <= 0 then
		return nil
	end

	local target = self.rng:NextNumber() * total
	local acc = 0
	local chosen = filtered[#filtered]
	for _, entry in filtered do
		acc += entry.weight
		if target <= acc then
			chosen = entry
			break
		end
	end

	return {
		id = chosen.id,
		quality = self.rng:NextInteger(0, 100),
	}
end

-- ── Registry + module-level convenience ─────────────────────────────────────
local tables: { [string]: TableDef } = {}

function LootTable.setTables(defs: { [string]: TableDef })
	tables = defs
end

function LootTable.loadAll()
	local configs = ReplicatedStorage:WaitForChild("Configs")
	local folder = configs:FindFirstChild("Loot")
	if not folder then
		return
	end
	for _, module in folder:GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, def = pcall(require, module)
			if ok and type(def) == "table" and def.id then
				tables[def.id] = def
			end
		end
	end
end

-- Convenience used by dungeon/raid runners: looks up a table by id and rolls
-- with a fresh seed (live play). Pass an explicit seed for replay testing.
function LootTable.roll(tableId: string, playerILvl: number, seed: number?): Result?
	local def = tables[tableId]
	if not def then
		return nil
	end
	local instance = LootTable.new(seed or (os.time() + math.random(1, 1e6)))
	return LootTable.rollTable(instance, def, playerILvl)
end

return LootTable
