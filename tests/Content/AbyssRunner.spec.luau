-- TASK_Q4_01 acceptance: wipeRoom resets boss HP to room-start (not global),
-- and new mechanic types need zero AbyssRunner changes (dynamic resolver).
require("../Harness.luau")
local AbyssRunner = require("../../src/ServerScriptService/Content/AbyssRunner/init.luau")

local function mockWorld()
	local state = { bossHp = 250000, respawns = 0 }
	state.world = {
		getBossHp = function()
			return state.bossHp
		end,
		setBossHp = function(hp)
			state.bossHp = hp
		end,
		respawnParty = function()
			state.respawns += 1
		end,
	}
	return state
end

return function()
	describe("AbyssRunner wipe", function()
		it("resets boss HP to the room-start value, not global full HP", function()
			local w = mockWorld()
			local runner = AbyssRunner.new({ id = "room_1" }, w.world)
			runner:enterRoom() -- records 250000
			w.bossHp = 50000 -- party damaged the boss
			runner:wipeRoom()
			expect(w.bossHp).to.equal(250000)
			expect(w.respawns).to.equal(1)
		end)
	end)

	describe("AbyssRunner mechanic dispatch", function()
		it("wipes on a failed mechanic and not on success", function()
			local w = mockWorld()
			-- Inject mechanic modules so no Roblox instance lookup is needed; this
			-- is the same seam that lets new mechanic types be added with zero
			-- changes to AbyssRunner.
			local mechanics = {
				FailingThing = {
					run = function(_world, _config, onComplete)
						onComplete(false)
					end,
				},
				PassingThing = {
					run = function(_world, _config, onComplete)
						onComplete(true)
					end,
				},
			}
			local runner = AbyssRunner.new({ id = "room_1" }, w.world, function(t)
				return mechanics[t]
			end)
			runner:enterRoom()
			w.bossHp = 10000

			runner:runMechanic({ type = "PassingThing" })
			expect(w.respawns).to.equal(0) -- success: no wipe

			runner:runMechanic({ type = "FailingThing" })
			expect(w.respawns).to.equal(1) -- failure: wiped
			expect(w.bossHp).to.equal(250000)
		end)
	end)
end
