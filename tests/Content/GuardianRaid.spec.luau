-- TASK_Q3_02 acceptance: HP scaling, wipe detection, solo + iLvl grouping.
-- See GuardianRaid NOTE re: the spec's 41250 example vs. the 0.875 formula.
require("../Harness.luau")
local GuardianRaid = require("../../src/ServerScriptService/Content/GuardianRaid.luau")

return function()
	describe("GuardianRaid HP scaling", function()
		it("solo (n=1) uses base HP", function()
			expect(GuardianRaid.scaledHp(10000, 1)).to.be.near(10000, 1e-6)
		end)

		it("scales by the 0.875 coefficient per extra player", function()
			-- 10000 * (1 + 0.875*3) = 36250 (the formula's correct result)
			expect(GuardianRaid.scaledHp(10000, 4)).to.be.near(36250, 1e-6)
			expect(GuardianRaid.scaledHp(10000, 2)).to.be.near(18750, 1e-6)
		end)
	end)

	describe("GuardianRaid wipe", function()
		it("is a wipe only when every player is dead", function()
			expect(GuardianRaid.isWipe({ { alive = false }, { alive = false } })).to.equal(true)
			expect(GuardianRaid.isWipe({ { alive = false }, { alive = true } })).to.equal(false)
		end)

		it("an empty roster is not a wipe", function()
			expect(GuardianRaid.isWipe({})).to.equal(false)
		end)
	end)

	describe("GuardianRaid grouping", function()
		it("a solo queuer forms a valid party of one", function()
			local parties = GuardianRaid.groupByILvl({ { userId = 1, iLvl = 600 } }, 4, 100)
			expect(#parties).to.equal(1)
			expect(#parties[1]).to.equal(1)
		end)

		it("groups close-iLvl players up to the party cap", function()
			local entries = {
				{ userId = 1, iLvl = 600 },
				{ userId = 2, iLvl = 620 },
				{ userId = 3, iLvl = 640 },
				{ userId = 4, iLvl = 660 },
				{ userId = 5, iLvl = 680 },
			}
			local parties = GuardianRaid.groupByILvl(entries, 4, 100)
			expect(#parties).to.equal(2) -- [4 players] + [1 leftover]
			expect(#parties[1]).to.equal(4)
			expect(#parties[2]).to.equal(1)
		end)

		it("splits players outside the iLvl range into separate parties", function()
			local entries = {
				{ userId = 1, iLvl = 300 },
				{ userId = 2, iLvl = 900 },
			}
			local parties = GuardianRaid.groupByILvl(entries, 4, 100)
			expect(#parties).to.equal(2)
		end)
	end)
end
