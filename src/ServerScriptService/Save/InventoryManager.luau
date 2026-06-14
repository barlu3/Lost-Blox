-- Player item storage and equipped loadout. All mutations happen server-side;
-- the client receives a sanitized replicated snapshot after each change.
--
-- The mutation cores (addToInventory, applyEquip) are pure and operate on the
-- profile's inventory/equipped tables directly, so they are unit-testable. The
-- player-facing API binds them to ProfileManager + StatRecomputer + replication.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryManager = {}

InventoryManager.MAX_SLOTS = 120
InventoryManager.VALID_SLOTS = {
	weapon = true,
	head = true,
	chest = true,
	legs = true,
	accessory1 = true,
	accessory2 = true,
}

export type Item = { id: string, quantity: number?, quality: number, iLvl: number, stackable: boolean? }

-- Adds an item to the inventory array, stacking when possible. Returns false if
-- the inventory is full (cap reached and no existing stack to grow).
function InventoryManager.addToInventory(inventory: { any }, itemDef: Item, maxSlots: number?): boolean
	local cap = maxSlots or InventoryManager.MAX_SLOTS
	local amount = itemDef.quantity or 1

	if itemDef.stackable then
		for _, entry in inventory do
			if entry.id == itemDef.id and entry.quality == itemDef.quality then
				entry.quantity += amount
				return true
			end
		end
	end

	if #inventory >= cap then
		return false
	end

	table.insert(inventory, {
		id = itemDef.id,
		quantity = amount,
		quality = itemDef.quality,
		iLvl = itemDef.iLvl,
	})
	return true
end

-- Moves inventory[index] into equipped[slot], swapping any occupant back into
-- the inventory. recomputeFn is invoked exactly once on a successful equip.
-- Returns { ok, reason? }. Atomic from the caller's view: both tables change
-- together before recompute runs.
function InventoryManager.applyEquip(
	data: any,
	index: number,
	slot: string,
	recomputeFn: (() -> ())?
): { ok: boolean, reason: string? }
	if not InventoryManager.VALID_SLOTS[slot] then
		return { ok = false, reason = "invalid_slot" }
	end

	local inventory = data.inventory
	local equipped = data.equippedItems
	local item = inventory[index]
	if item == nil then
		return { ok = false, reason = "no_such_item" } -- ownership check
	end

	local previous = equipped[slot]
	table.remove(inventory, index)
	if previous ~= nil then
		-- A slot just freed up, so the swapped-out item always fits.
		table.insert(inventory, previous)
	end
	equipped[slot] = item

	if recomputeFn then
		recomputeFn()
	end
	return { ok = true }
end

-- Strips internal layout from the inventory before sending to the client.
function InventoryManager.snapshot(data: any): { inventory: { any }, equipped: any }
	local inv = {}
	for _, entry in data.inventory do
		table.insert(inv, { id = entry.id, quantity = entry.quantity, quality = entry.quality, iLvl = entry.iLvl })
	end
	return { inventory = inv, equipped = data.equippedItems }
end

-- ── Player-facing runtime API ───────────────────────────────────────────────
-- Wired in start(); kept thin so the testable logic stays in the pure cores.
local ProfileManager: any = nil
local StatRecomputer: any = nil
local inventoryUpdated: RemoteEvent? = nil
local statsByPlayer: { [Player]: any } = {}

function InventoryManager.setStats(player: Player, stats: any)
	statsByPlayer[player] = stats
end

function InventoryManager.AddItem(player: Player, itemDef: Item): boolean
	local data = ProfileManager.GetData(player)
	if not data then
		return false
	end
	return InventoryManager.addToInventory(data.inventory, itemDef)
end

function InventoryManager.EquipItem(player: Player, index: number, slot: string): boolean
	local data = ProfileManager.GetData(player)
	if not data then
		return false
	end
	local result = InventoryManager.applyEquip(data, index, slot, function()
		local base = statsByPlayer[player]
		if base then
			statsByPlayer[player] = StatRecomputer.recompute(base, data.equippedItems)
		end
	end)
	if result.ok and inventoryUpdated then
		inventoryUpdated:FireClient(player, InventoryManager.snapshot(data))
	end
	return result.ok
end

function InventoryManager.start(profileManager: any, statRecomputer: any)
	ProfileManager = profileManager
	StatRecomputer = statRecomputer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("InventoryUpdated")
	if existing then
		inventoryUpdated = existing :: RemoteEvent
	else
		local r = Instance.new("RemoteEvent")
		r.Name = "InventoryUpdated"
		r.Parent = remotes
		inventoryUpdated = r
	end
end

return InventoryManager
