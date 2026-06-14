-- TASK_Q5_01 acceptance: solo entry, weekly lockout, timer drift, 8-player HP.
require("../Harness.luau")
local LegionRaid = require("../../src/ServerScriptService/Content/LegionRaid.luau")
local GuardianRaid = require("../../src/ServerScriptService/Content/GuardianRaid.luau")

return function()
	describe("LegionRaid entry", function()
		it("allows a solo party (no forced 8 players)", function()
			expect(LegionRaid.canEnter(1)).to.equal(true)
			expect(LegionRaid.canEnter(8)).to.equal(true)
		end)
		it("rejects an empty or oversized party", function()
			expect(LegionRaid.canEnter(0)).to.equal(false)
			expect(LegionRaid.canEnter(9)).to.equal(false)
		end)
	end)

	describe("LegionRaid weekly lockout", function()
		it("records a gate clear and reports it locked the same week", function()
			local lockout = {}
			local week = LegionRaid.weekIndex(1761955200)
			LegionRaid.recordClear(lockout, week, "first_hollow", 2)
			expect(LegionRaid.isLocked(lockout, week, "first_hollow", 2)).to.equal(true)
		end)

		it("does not lock other gates or other weeks", function()
			local lockout = {}
			local week = LegionRaid.weekIndex(1761955200)
			LegionRaid.recordClear(lockout, week, "first_hollow", 2)
			expect(LegionRaid.isLocked(lockout, week, "first_hollow", 3)).to.equal(false)
			expect(LegionRaid.isLocked(lockout, week + 1, "first_hollow", 2)).to.equal(false)
		end)

		it("rolls to a new lockout bucket after a week", function()
			local a = LegionRaid.weekIndex(1761955200)
			local b = LegionRaid.weekIndex(1761955200 + LegionRaid.SECONDS_PER_WEEK)
			expect(b).to.equal(a + 1)
		end)
	end)

	describe("LegionRaid timer drift", function()
		it("computes drift and flags only beyond 50ms", function()
			expect(LegionRaid.timerDrift(6.0, 6.03)).to.be.near(0.03, 1e-9)
			expect(LegionRaid.isDriftHigh(0.03)).to.equal(false)
			expect(LegionRaid.isDriftHigh(0.06)).to.equal(true)
		end)
	end)

	describe("LegionRaid HP scaling (Guardian formula extended to 8)", function()
		it("scales boss HP for an 8-player party", function()
			-- 2,000,000 * (1 + 0.875*7) = 2,000,000 * 7.125 = 14,250,000
			expect(GuardianRaid.scaledHp(2000000, 8)).to.be.near(14250000, 1)
		end)
	end)
end
