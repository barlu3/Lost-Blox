-- TASK_Q4_02 acceptance: deterministic seeded rolls, iLvl filtering, weight
-- renormalization, and ~1% legendary quality.
require("../Harness.luau")
local LootTable = require("../../src/ServerScriptService/Loot/LootTable.luau")

local CHAOS_T1 = {
	id = "chaos_t1",
	entries = {
		{ id = "void_necklace", weight = 10, min_ilvl = 600 },
		{ id = "storm_earring", weight = 15, min_ilvl = 600 },
		{ id = "shadow_ring", weight = 20, min_ilvl = 600 },
		{ id = "honing_shard_t1", weight = 55, min_ilvl = 0 },
	},
}

return function()
	describe("LootTable determinism", function()
		it("the same seed produces the same roll", function()
			local a = LootTable.new(12345):rollTable(CHAOS_T1, 700)
			local b = LootTable.new(12345):rollTable(CHAOS_T1, 700)
			expect(a.id).to.equal(b.id)
			expect(a.quality).to.equal(b.quality)
		end)
	end)

	describe("LootTable iLvl filter", function()
		it("excludes entries above the player's iLvl", function()
			-- At iLvl 400 only honing_shard_t1 (min 0) is eligible.
			local roller = LootTable.new(42)
			for _ = 1, 200 do
				local result = roller:rollTable(CHAOS_T1, 400)
				expect(result.id).to.equal("honing_shard_t1")
			end
		end)
	end)

	describe("LootTable renormalization", function()
		it("a weight-55 of 100 entry lands ~55% of the time at full iLvl", function()
			local roller = LootTable.new(2024)
			local hits = 0
			local N = 20000
			for _ = 1, N do
				if roller:rollTable(CHAOS_T1, 700).id == "honing_shard_t1" then
					hits += 1
				end
			end
			expect(math.abs(hits / N - 0.55) <= 0.03).to.equal(true)
		end)

		it("renormalizes when high-iLvl entries are filtered out", function()
			-- Only honing_shard_t1 remains at iLvl 0, so it is certain (55/55).
			local roller = LootTable.new(7)
			expect(roller:rollTable(CHAOS_T1, 0).id).to.equal("honing_shard_t1")
		end)
	end)

	describe("LootTable quality", function()
		it("produces legendary quality ~1% of the time over 100k rolls", function()
			local roller = LootTable.new(555)
			local legendary = 0
			local N = 100000
			for _ = 1, N do
				if LootTable.qualityBucket(roller:rollTable(CHAOS_T1, 700).quality) == "legendary" then
					legendary += 1
				end
			end
			local rate = legendary / N
			expect(math.abs(rate - 0.01) <= 0.002).to.equal(true)
		end)

		it("classifies quality buckets at the boundaries", function()
			expect(LootTable.qualityBucket(0)).to.equal("common")
			expect(LootTable.qualityBucket(30)).to.equal("common")
			expect(LootTable.qualityBucket(31)).to.equal("uncommon")
			expect(LootTable.qualityBucket(60)).to.equal("uncommon")
			expect(LootTable.qualityBucket(61)).to.equal("rare")
			expect(LootTable.qualityBucket(85)).to.equal("rare")
			expect(LootTable.qualityBucket(86)).to.equal("epic")
			expect(LootTable.qualityBucket(99)).to.equal("epic")
			expect(LootTable.qualityBucket(100)).to.equal("legendary")
		end)
	end)
end
