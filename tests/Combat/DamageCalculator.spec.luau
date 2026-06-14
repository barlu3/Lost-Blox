-- TASK_Q1_02 acceptance: damage formula correctness and crit-rate distribution.
require("../Harness.luau")
local DamageCalculator = require("../../src/ServerScriptService/Combat/DamageCalculator.luau")

local function neverCrit(): number
	return 1 -- 1 < crit_chance is false for any chance <= 1
end
local function alwaysCrit(): number
	return 0 -- 0 < crit_chance is true for any positive chance
end

return function()
	describe("DamageCalculator formula", function()
		it("non-crit damage is base_attack * multiplier", function()
			local stats = { baseAttack = 100, critChance = 0.5, critDamage = 1.0 }
			local result = DamageCalculator.calculate(stats, { damageMultiplier = 1.8 }, nil, neverCrit)
			expect(result.didCrit).to.equal(false)
			expect(result.damage).to.be.near(180, 1e-3)
		end)

		it("crit damage applies (1 + crit_damage)", function()
			local stats = { baseAttack = 100, critChance = 0.5, critDamage = 1.0 }
			local result = DamageCalculator.calculate(stats, { damageMultiplier = 1.8 }, nil, alwaysCrit)
			expect(result.didCrit).to.equal(true)
			expect(result.damage).to.be.near(360, 1e-3) -- 180 * (1 + 1.0)
		end)

		it("damageMul is multiplicative and damageAdd is flat", function()
			local stats = { baseAttack = 100, critChance = 0, critDamage = 0 }
			local mods = { damageAdd = 50, damageMul = 0.2, critRate = 0, critDamage = 0 }
			local result = DamageCalculator.calculate(stats, { damageMultiplier = 1.0 }, mods, neverCrit)
			-- 100 * 1.0 * 1.2 + 50 = 170
			expect(result.damage).to.be.near(170, 1e-3)
		end)

		it("modifier crit_rate adds to base crit chance", function()
			local stats = { baseAttack = 10, critChance = 0, critDamage = 0.5 }
			local mods = { damageAdd = 0, damageMul = 0, critRate = 1.0, critDamage = 0 }
			-- roll 0.9 < (0 + 1.0) -> crit
			local result = DamageCalculator.calculate(stats, { damageMultiplier = 1 }, mods, function()
				return 0.9
			end)
			expect(result.didCrit).to.equal(true)
		end)
	end)

	describe("DamageCalculator crit rate", function()
		it("observed crit rate is within 5% of crit_chance over 1000 casts", function()
			local stats = { baseAttack = 100, critChance = 0.3, critDamage = 0.5 }
			local rng = Random.new(20240612)
			local rollFn = function()
				return rng:NextNumber()
			end
			local crits = 0
			local N = 1000
			for _ = 1, N do
				if DamageCalculator.calculate(stats, { damageMultiplier = 1 }, nil, rollFn).didCrit then
					crits += 1
				end
			end
			local rate = crits / N
			expect(math.abs(rate - 0.3) <= 0.05).to.equal(true)
		end)
	end)
end
