-- TASK_Q2_04 acceptance: pity force-success timing, observed success rate vs.
-- theoretical with-pity rate, material checks, and non-mutation of input state.
require("../Harness.luau")
local HoningCalculator = require("../../src/ServerScriptService/Save/HoningCalculator.luau")

local function freshState()
	return { tier = 0, level = 9, pityCounter = 0, pityBonus = 0 }
end

return function()
	describe("HoningCalculator pity", function()
		it("forces success exactly at MAX_PITY, not before", function()
			-- roll 0.99 would normally fail at pbase 0.20.
			local atNine = { tier = 0, level = 9, pityCounter = 9, pityBonus = 0 }
			expect(HoningCalculator.attempt(atNine, 0.99, 0.20, 0.05, 10).success).to.equal(false)
			local atTen = { tier = 0, level = 9, pityCounter = 10, pityBonus = 0 }
			expect(HoningCalculator.attempt(atTen, 0.99, 0.20, 0.05, 10).success).to.equal(true)
		end)

		it("resets pity on success and increments on failure", function()
			local fail = HoningCalculator.attempt(freshState(), 0.99, 0.20, 0.05, 10)
			expect(fail.newState.pityCounter).to.equal(1)
			expect(fail.newState.pityBonus).to.be.near(0.05, 1e-9)

			local win = HoningCalculator.attempt({ tier = 0, level = 9, pityCounter = 3, pityBonus = 0.15 }, 0.01, 0.20, 0.05, 10)
			expect(win.newState.pityCounter).to.equal(0)
			expect(win.newState.pityBonus).to.be.near(0, 1e-9)
			expect(win.newState.level).to.equal(10)
		end)

		it("does not mutate the input state", function()
			local s = freshState()
			HoningCalculator.attempt(s, 0.99, 0.20, 0.05, 10)
			expect(s.pityCounter).to.equal(0)
			expect(s.level).to.equal(9)
		end)
	end)

	describe("HoningCalculator distribution", function()
		it("observed success rate is within 2% of the theoretical with-pity rate", function()
			local pbase, inc, maxPity = 0.20, 0.05, 10

			-- Theoretical expected attempts per success from the p_k sequence.
			local survive = 1.0
			local expectedAttempts = 0.0
			for k = 0, maxPity do
				expectedAttempts += survive -- probability we make a (k+1)-th attempt
				local pk = math.min(pbase + k * inc, 1.0)
				if k >= maxPity then
					pk = 1.0
				end
				survive *= (1 - pk)
			end
			local theoretical = 1.0 / expectedAttempts

			local rng = Random.new(987654)
			local state = { tier = 0, level = 1, pityCounter = 0, pityBonus = 0 }
			local successes, attempts = 0, 0
			for _ = 1, 10000 do
				attempts += 1
				local outcome = HoningCalculator.attempt(state, rng:NextNumber(), pbase, inc, maxPity)
				if outcome.success then
					successes += 1
					state = { tier = 0, level = 1, pityCounter = 0, pityBonus = 0 }
				else
					state = outcome.newState
				end
			end
			local observed = successes / attempts
			expect(math.abs(observed - theoretical) <= 0.02).to.equal(true)
		end)

		it("pity guarantees success within MAX_PITY + 1 attempts", function()
			local rng = Random.new(13)
			for _ = 1, 200 do
				local state = { tier = 1, level = 10, pityCounter = 0, pityBonus = 0 }
				local n = 0
				repeat
					n += 1
					local outcome = HoningCalculator.attempt(state, rng:NextNumber(), 0.10, 0.04, 10)
					state = outcome.newState
				until outcome.success
				expect(n <= 11).to.equal(true)
			end
		end)
	end)

	describe("HoningCalculator materials", function()
		it("affords only when every required material is owned", function()
			local owned = { mana_shard = 47, guardian_stone = 10 }
			expect(HoningCalculator.canAfford({ mana_shard = 20, guardian_stone = 5 }, owned)).to.equal(true)
			expect(HoningCalculator.canAfford({ mana_shard = 50 }, owned)).to.equal(false)
			expect(HoningCalculator.canAfford({ destruction_stone = 1 }, owned)).to.equal(false)
		end)
	end)

	describe("HoningCalculator item lookup", function()
		it("uses P_BASE for the item's tier and level", function()
			-- T0+1 = 0.80: a roll of 0.79 succeeds, 0.81 fails (no pity yet).
			local s = { tier = 0, level = 1, pityCounter = 0, pityBonus = 0 }
			expect(HoningCalculator.attemptForItem(s, 0.79).success).to.equal(true)
			expect(HoningCalculator.attemptForItem(s, 0.81).success).to.equal(false)
		end)
	end)
end
