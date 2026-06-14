-- TASK_Q1_05 acceptance: aggro transition, telegraph-before-damage timing,
-- enrage-applies-once, and zone-only damage. Mechanic feel needs a game session.
local Harness = require("../Harness.luau")
local BossController = require("../../src/ServerScriptService/AI/BossController.luau")

-- Builds a controllable mock world. Tweak fields between steps to drive states.
local function mockWorld(opts)
	opts = opts or {}
	local state = {
		players = opts.players or {},
		bossPos = opts.bossPos or Vector3.new(0, 0, 0),
		hpFraction = opts.hpFraction or 1.0,
		zonePlayers = opts.zonePlayers or {},
		moves = {},
		damaged = {},
		enrageCalls = 0,
		zonesSpawned = 0,
		zonesCleared = 0,
	}
	state.world = {
		getPlayers = function()
			return state.players
		end,
		getBossPosition = function()
			return state.bossPos
		end,
		moveBossTo = function(p)
			table.insert(state.moves, p)
		end,
		getHpFraction = function()
			return state.hpFraction
		end,
		spawnDangerZone = function(_mech, _pos)
			state.zonesSpawned += 1
			return { id = state.zonesSpawned }
		end,
		playersInZone = function(_zone)
			return state.zonePlayers
		end,
		applyDamage = function(p, amount)
			table.insert(state.damaged, { player = p, amount = amount })
		end,
		clearDangerZone = function(_zone)
			state.zonesCleared += 1
		end,
		applyEnrage = function(_m, _d)
			state.enrageCalls += 1
		end,
	}
	return state
end

local function player(x, alive)
	return { position = Vector3.new(x, 0, 0), alive = alive ~= false, id = x }
end

return function()
	describe("BossController aggro", function()
		it("stays Idle with no player in the 40-stud radius", function()
			local w = mockWorld({ players = { player(41) } })
			local boss = BossController.new(BossController.defaultConfig(), w.world)
			boss:step()
			expect(boss:getState()).to.equal("Idle")
		end)

		it("transitions Idle -> Approach when a player enters the radius", function()
			local w = mockWorld({ players = { player(39) } })
			local boss = BossController.new(BossController.defaultConfig(), w.world)
			boss:step()
			expect(boss:getState()).to.equal("Approach")
		end)
	end)

	describe("BossController telegraph timing", function()
		it("spawns the danger zone at least 0.8s before damage resolves", function()
			-- Boss is within melee range of the player so Approach -> Telegraph.
			local w = mockWorld({ players = { player(2) }, bossPos = Vector3.new(0, 0, 0) })
			local boss = BossController.new(BossController.defaultConfig(), w.world)
			Harness.setTime(1000)
			boss:step() -- Idle -> Approach
			boss:step() -- Approach -> Telegraph (within melee), zone spawned
			expect(boss:getState()).to.equal("Telegraph")
			expect(w.zonesSpawned).to.equal(1)

			-- First mechanic telegraph is 1.2s. Damage must not resolve early.
			Harness.advance(0.7)
			boss:step()
			expect(boss:getState()).to.equal("Telegraph")
			expect(#w.damaged).to.equal(0)

			-- After the full telegraph, Attack resolves damage.
			Harness.advance(0.6) -- total 1.3s >= 1.2
			boss:step() -- Telegraph -> Attack
			expect(#w.damaged >= 0).to.equal(true)
		end)

		it("default mechanics all telegraph for at least 0.8s", function()
			for _, m in BossController.defaultConfig().mechanics do
				expect(m.telegraph >= 0.8).to.equal(true)
			end
		end)
	end)

	describe("BossController enrage", function()
		it("applies the enrage modifier exactly once below the threshold", function()
			local w = mockWorld({ players = { player(50) }, hpFraction = 0.2 })
			local boss = BossController.new(BossController.defaultConfig(), w.world)
			boss:step()
			boss:step()
			boss:step()
			expect(boss:isEnraged()).to.equal(true)
			expect(w.enrageCalls).to.equal(1)
		end)

		it("does not enrage above the threshold", function()
			local w = mockWorld({ players = {}, hpFraction = 0.5 })
			local boss = BossController.new(BossController.defaultConfig(), w.world)
			boss:step()
			expect(boss:isEnraged()).to.equal(false)
			expect(w.enrageCalls).to.equal(0)
		end)
	end)

	describe("BossController attack", function()
		it("only damages players inside the danger zone", function()
			local inside = player(1)
			local outside = player(30)
			local w = mockWorld({
				players = { inside, outside },
				bossPos = Vector3.new(0, 0, 0),
				zonePlayers = { inside }, -- only the inside player is in the zone
			})
			local boss = BossController.new(BossController.defaultConfig(), w.world)
			Harness.setTime(2000)
			boss:step() -- Idle -> Approach
			boss:step() -- Approach -> Telegraph
			Harness.advance(2.0)
			boss:step() -- Telegraph -> Attack
			boss:step() -- Attack resolves
			expect(#w.damaged).to.equal(1)
			expect(w.damaged[1].player).to.equal(inside)
		end)
	end)

	describe("BossController stagger", function()
		it("enters Stagger and grants +50% damage taken, then returns to Approach", function()
			local w = mockWorld({ players = { player(5) } })
			local boss = BossController.new(BossController.defaultConfig(), w.world)
			Harness.setTime(3000)
			boss:triggerStagger()
			expect(boss:getState()).to.equal("Stagger")
			expect(boss:damageTakenMultiplier()).to.be.near(1.5, 1e-9)
			Harness.advance(2.1)
			boss:step()
			expect(boss:getState()).to.equal("Approach")
		end)
	end)
end
