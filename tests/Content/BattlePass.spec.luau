-- TASK_Q5_02 acceptance: tier bisect, premium gating, claim tracking, rollover.
require("../Harness.luau")
local BattlePass = require("../../src/ServerScriptService/Content/BattlePass.luau")

local THRESHOLDS = { 500, 1200, 2100, 3200, 5000 }

return function()
	describe("BattlePass tier math", function()
		it("4200 XP against the thresholds is tier 4", function()
			expect(BattlePass.tierForXp(THRESHOLDS, 4200)).to.equal(4)
		end)
		it("below the first threshold is tier 0", function()
			expect(BattlePass.tierForXp(THRESHOLDS, 400)).to.equal(0)
		end)
		it("exactly on a threshold counts that tier", function()
			expect(BattlePass.tierForXp(THRESHOLDS, 500)).to.equal(1)
		end)
		it("addXp accumulates and recomputes tier", function()
			local data = BattlePass.newData("S0")
			BattlePass.addXp(data, 2200, THRESHOLDS) -- clears 500/1200/2100
			expect(data.tier).to.equal(3)
			BattlePass.addXp(data, 2000, THRESHOLDS) -- total 4200, clears 3200
			expect(data.tier).to.equal(4)
		end)
	end)

	describe("BattlePass premium gating", function()
		it("a free-track player cannot get a premium-track reward", function()
			local data = BattlePass.newData("S0")
			data.premiumUnlocked = false
			expect(BattlePass.canGrant({ track = "premium" }, data)).to.equal(false)
			expect(BattlePass.canGrant({ track = "free" }, data)).to.equal(true)
		end)
		it("a premium player can get premium-track rewards", function()
			local data = BattlePass.newData("S0")
			data.premiumUnlocked = true
			expect(BattlePass.canGrant({ track = "premium" }, data)).to.equal(true)
		end)
	end)

	describe("BattlePass claim tracking", function()
		it("does not re-grant a claimed tier after reload", function()
			local data = BattlePass.newData("S0")
			BattlePass.addXp(data, 4200, THRESHOLDS) -- tier 4
			local first = BattlePass.unclaimedTiers(data)
			expect(#first).to.equal(4)
			for _, tier in first do
				BattlePass.claimTier(data, tier)
			end
			-- Simulate a reload: unclaimed should now be empty.
			expect(#BattlePass.unclaimedTiers(data)).to.equal(0)
		end)
	end)

	describe("BattlePass rollover", function()
		it("archives the season and resets xp/tier to 0", function()
			local data = BattlePass.newData("S0")
			BattlePass.addXp(data, 4200, THRESHOLDS)
			data.premiumUnlocked = true
			local result = BattlePass.rollover(data, "S1")
			expect(result.archive.season).to.equal("S0")
			expect(result.archive.tier).to.equal(4)
			expect(result.newData.season).to.equal("S1")
			expect(result.newData.xp).to.equal(0)
			expect(result.newData.tier).to.equal(0)
			expect(#result.newData.claimedTiers).to.equal(0)
		end)
	end)
end
