-- Orchestrates a Legion Raid gate on its private server. Reads TeleportData to
-- know which raid/gate, loads the gate data table, scales boss HP for the entered
-- party, runs mechanics via the Abyss mechanic primitives, and enforces the
-- weekly lockout (locked players enter but receive no loot).
--
-- Pure logic (lockout, entry, drift) lives in LegionRaid; HP scaling reuses
-- GuardianRaid.scaledHp.
local LegionRaid = require(script.Parent.LegionRaid)
local GuardianRaid = require(script.Parent.GuardianRaid)

local RaidController = {}
RaidController.__index = RaidController

-- gates: { [gateNumber]: gateDataTable }. world: { getBossHp, setBossHp,
-- respawnParty, grantLoot, getPlayers, now } injected at runtime.
function RaidController.new(raidId: string, gates: { [number]: any }, world: any, playerCount: number)
	return setmetatable({
		raidId = raidId,
		gates = gates,
		world = world,
		playerCount = playerCount,
		currentGate = 1,
	}, RaidController)
end

function RaidController:scaledGateHp(gateNumber: number): number
	local gate = self.gates[gateNumber]
	return GuardianRaid.scaledHp(gate.hp_base, self.playerCount)
end

-- On a clear: record the weekly lockout and grant loot only if the player was
-- not already locked for this gate this week.
function RaidController:onGateCleared(player: any, weeklyLockout: { [string]: boolean })
	local week = LegionRaid.weekIndex(os.time())
	local alreadyLocked = LegionRaid.isLocked(weeklyLockout, week, self.raidId, self.currentGate)
	if not alreadyLocked then
		self.world.grantLoot(player, self.raidId, self.currentGate)
		LegionRaid.recordClear(weeklyLockout, week, self.raidId, self.currentGate)
	end
	self.currentGate += 1
end

-- Wipe retains boss HP (no reset to full); the runtime simply respawns the party.
function RaidController:onWipe()
	self.world.respawnParty()
end

return RaidController
