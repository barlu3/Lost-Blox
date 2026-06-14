-- TASK_Q2_05 acceptance: stacking, equip swap without loss, single recompute,
-- ownership, and slot validation.
require("../Harness.luau")
local InventoryManager = require("../../src/ServerScriptService/Save/InventoryManager.luau")

return function()
	describe("InventoryManager.addToInventory", function()
		it("stacks 50 of the same stackable item into one entry", function()
			local inv = {}
			for _ = 1, 50 do
				InventoryManager.addToInventory(inv, { id = "mana_shard", quality = 0, iLvl = 0, stackable = true })
			end
			expect(#inv).to.equal(1)
			expect(inv[1].quantity).to.equal(50)
		end)

		it("keeps non-stackable items as separate entries", function()
			local inv = {}
			InventoryManager.addToInventory(inv, { id = "iron_sword", quality = 72, iLvl = 302 })
			InventoryManager.addToInventory(inv, { id = "iron_sword", quality = 72, iLvl = 302 })
			expect(#inv).to.equal(2)
		end)

		it("does not stack the same id at a different quality", function()
			local inv = {}
			InventoryManager.addToInventory(inv, { id = "shard", quality = 0, iLvl = 0, stackable = true })
			InventoryManager.addToInventory(inv, { id = "shard", quality = 5, iLvl = 0, stackable = true })
			expect(#inv).to.equal(2)
		end)

		it("returns false when the inventory is full", function()
			local inv = {}
			local ok1 = InventoryManager.addToInventory(inv, { id = "a", quality = 0, iLvl = 0 }, 1)
			local ok2 = InventoryManager.addToInventory(inv, { id = "b", quality = 0, iLvl = 0 }, 1)
			expect(ok1).to.equal(true)
			expect(ok2).to.equal(false)
			expect(#inv).to.equal(1)
		end)
	end)

	describe("InventoryManager.applyEquip", function()
		it("equips an item into an empty slot and recomputes once", function()
			local data = {
				inventory = { { id = "iron_sword", quantity = 1, quality = 72, iLvl = 302 } },
				equippedItems = {},
			}
			local recomputes = 0
			local result = InventoryManager.applyEquip(data, 1, "weapon", function()
				recomputes += 1
			end)
			expect(result.ok).to.equal(true)
			expect(data.equippedItems.weapon.id).to.equal("iron_sword")
			expect(#data.inventory).to.equal(0)
			expect(recomputes).to.equal(1)
		end)

		it("swaps an occupied slot back into inventory without item loss", function()
			local data = {
				inventory = { { id = "new_sword", quantity = 1, quality = 80, iLvl = 400 } },
				equippedItems = { weapon = { id = "old_sword", quantity = 1, quality = 50, iLvl = 300 } },
			}
			local result = InventoryManager.applyEquip(data, 1, "weapon")
			expect(result.ok).to.equal(true)
			expect(data.equippedItems.weapon.id).to.equal("new_sword")
			-- old sword preserved
			expect(#data.inventory).to.equal(1)
			expect(data.inventory[1].id).to.equal("old_sword")
		end)

		it("rejects an invalid slot and does not recompute", function()
			local data = { inventory = { { id = "x", quantity = 1, quality = 0, iLvl = 1 } }, equippedItems = {} }
			local recomputes = 0
			local result = InventoryManager.applyEquip(data, 1, "hat", function()
				recomputes += 1
			end)
			expect(result.ok).to.equal(false)
			expect(result.reason).to.equal("invalid_slot")
			expect(recomputes).to.equal(0)
		end)

		it("rejects equipping an item the player does not own (bad index)", function()
			local data = { inventory = {}, equippedItems = {} }
			local result = InventoryManager.applyEquip(data, 5, "weapon")
			expect(result.ok).to.equal(false)
			expect(result.reason).to.equal("no_such_item")
		end)
	end)
end
