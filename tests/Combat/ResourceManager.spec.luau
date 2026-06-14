-- TASK_Q2_02 acceptance: Arcana accumulation/cap, spender gating, Chi stacks
-- and damage scaling, identity thresholds.
require("../Harness.luau")
local ResourceManager = require("../../src/ServerScriptService/Combat/ResourceManager.luau")

return function()
	describe("Stormcaller Arcana", function()
		it("13 builders accumulate to exactly 100 (capped from 104)", function()
			local arcana = 0
			for _ = 1, 13 do
				arcana = ResourceManager.addArcana(arcana)
			end
			expect(arcana).to.equal(100)
		end)

		it("cannot spend a 40-cost spender with 30 Arcana", function()
			expect(ResourceManager.canSpend(30, 40)).to.equal(false)
			expect(ResourceManager.canSpend(40, 40)).to.equal(true)
		end)

		it("spending subtracts and never goes negative", function()
			expect(ResourceManager.spend(100, 40)).to.equal(60)
			expect(ResourceManager.spend(10, 40)).to.equal(0)
		end)

		it("Arcane Surge requires a full 100 Arcana", function()
			expect(ResourceManager.canArcaneSurge(100)).to.equal(true)
			expect(ResourceManager.canArcaneSurge(99)).to.equal(false)
		end)
	end)

	describe("Skystrike Chi", function()
		it("caps Chi stacks at 3", function()
			local chi = 0
			for _ = 1, 5 do
				chi = ResourceManager.addChi(chi)
			end
			expect(chi).to.equal(3)
		end)

		it("spender at 3 Chi deals base * 1.75", function()
			expect(ResourceManager.chiDamageMultiplier(3)).to.be.near(1.75, 1e-9)
		end)

		it("spender at 0 Chi deals base damage (multiplier 1.0)", function()
			expect(ResourceManager.chiDamageMultiplier(0)).to.be.near(1.0, 1e-9)
		end)

		it("Tiger's Wrath requires 3 Chi", function()
			expect(ResourceManager.canTigersWrath(3)).to.equal(true)
			expect(ResourceManager.canTigersWrath(2)).to.equal(false)
		end)
	end)
end
