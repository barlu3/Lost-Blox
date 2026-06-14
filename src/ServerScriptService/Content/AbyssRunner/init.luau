-- Runs a scripted Abyss Dungeon room. Watches the boss HP for trigger_hp
-- crossings (in descending order) and hands control to the mechanic module for
-- each. On a mechanic failure it wipes the room: boss HP resets to the value it
-- had on room entry (NOT global full HP) and the party respawns at the entrance.
--
-- Mechanics are resolved dynamically by type, so adding a new mechanic primitive
-- is a new file in Mechanics/ with zero changes here.
local AbyssRunner = {}
AbyssRunner.__index = AbyssRunner

local function defaultResolver(mechanicType: string): any
	return require(script.Mechanics:FindFirstChild(mechanicType))
end

-- world: { getBossHp, setBossHp, getBossHpFraction, respawnParty, getPlayers,
--          getPlayerTile, getSafeColor, applyLethal, getPillarsRemaining }
-- mechanicResolver(type) -> mechanic module (injected in tests).
function AbyssRunner.new(roomDef: any, world: any, mechanicResolver: ((string) -> any)?)
	return setmetatable({
		roomDef = roomDef,
		world = world,
		resolveMechanic = mechanicResolver or defaultResolver,
		roomStartHp = nil,
	}, AbyssRunner)
end

-- Records the boss HP at room entry; wipeRoom restores to exactly this.
function AbyssRunner:enterRoom()
	self.roomStartHp = self.world.getBossHp()
end

function AbyssRunner:wipeRoom()
	self.world.setBossHp(self.roomStartHp)
	self.world.respawnParty()
end

-- Runs one mechanic; on failure the room wipes. onComplete(success) is optional.
function AbyssRunner:runMechanic(mechanic: any, onComplete: ((boolean) -> ())?)
	local module = self.resolveMechanic(mechanic.type)
	module.run(self.world, mechanic, function(success: boolean)
		if not success then
			self:wipeRoom()
		end
		if onComplete then
			onComplete(success)
		end
	end)
end

return AbyssRunner
