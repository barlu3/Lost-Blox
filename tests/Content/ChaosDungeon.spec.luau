-- TASK_Q3_01 acceptance: kill-chain scoring, iLvl gate, phase completion.
-- Loot math is covered by LootTable (TASK_Q4_02).
require("../Harness.luau")
local ChaosDungeon = require("../../src/ServerScriptService/Content/ChaosDungeon.luau")

local T0 = { tier = 0, ilvl_min = 0, ilvl_max = 299 }

return function()
	describe("ChaosDungeon iLvl gate", function()
		it("admits a player within the tier band", function()
			expect(ChaosDungeon.canEnter(100, T0)).to.equal(true)
		end)
		it("rejects a player above the tier band", function()
			expect(ChaosDungeon.canEnter(300, T0)).to.equal(false)
		end)
	end)

	describe("ChaosDungeon phase", function()
		it("phase completes when no mobs remain", function()
			expect(ChaosDungeon.isPhaseComplete(0)).to.equal(true)
			expect(ChaosDungeon.isPhaseComplete(1)).to.equal(false)
		end)
	end)

	describe("ChaosDungeon kill chain", function()
		it("adds 50 per consecutive kill within 5 seconds", function()
			local s = ChaosDungeon.newScore(0)
			ChaosDungeon.registerKill(s, 1000) -- first kill, no chain bonus yet
			expect(s.chainBonus).to.equal(0)
			ChaosDungeon.registerKill(s, 1002) -- within window: +50
			expect(s.chainBonus).to.equal(50)
			ChaosDungeon.registerKill(s, 1004) -- within window: +50
			expect(s.chainBonus).to.equal(100)
			expect(s.score).to.equal(100)
		end)

		it("resets the chain to 0 after a gap longer than 5 seconds", function()
			local s = ChaosDungeon.newScore(0)
			ChaosDungeon.registerKill(s, 1000)
			ChaosDungeon.registerKill(s, 1002) -- +50
			expect(s.chainBonus).to.equal(50)
			ChaosDungeon.registerKill(s, 1010) -- gap > 5s: reset
			expect(s.chainBonus).to.equal(0)
		end)
	end)

	describe("ChaosDungeon time bonus", function()
		it("awards 10 points per remaining second", function()
			expect(ChaosDungeon.timeBonus(30)).to.equal(300)
		end)
		it("never goes negative when over time", function()
			expect(ChaosDungeon.timeBonus(-5)).to.equal(0)
		end)
	end)
end
