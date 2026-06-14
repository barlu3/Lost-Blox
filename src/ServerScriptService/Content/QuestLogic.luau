--!strict
-- Pure quest-progress logic, factored out of QuestManager so objective tracking,
-- completion, and start-gating are unit-testable with plain tables. No profile,
-- no RemoteEvents, no event bus.

local QuestLogic = {}

export type Objective = { id: string, type: string, target: string, count: number? }
export type QuestDef = { id: string, name: string, objectives: { Objective }, rewards: { any } }

-- Fresh progress for a quest: counts start at 0, reach flags at false.
function QuestLogic.initProgress(questDef: QuestDef): { [string]: number | boolean }
	local progress: { [string]: number | boolean } = {}
	for _, obj in questDef.objectives do
		progress[obj.id] = if obj.type == "reach" then false else 0
	end
	return progress
end

function QuestLogic.isObjectiveMet(obj: Objective, value: (number | boolean)?): boolean
	if obj.type == "reach" then
		return value == true
	end
	return type(value) == "number" and (value :: number) >= (obj.count or 1)
end

function QuestLogic.isComplete(questDef: QuestDef, progress: { [string]: number | boolean }): boolean
	for _, obj in questDef.objectives do
		if not QuestLogic.isObjectiveMet(obj, progress[obj.id]) then
			return false
		end
	end
	return true
end

-- Increments matching kill objectives, capped at count so a rapid double-kill
-- past the requirement can't overshoot. Returns true if anything changed.
function QuestLogic.incrementKill(questDef: QuestDef, progress: { [string]: number | boolean }, mobId: string): boolean
	local changed = false
	for _, obj in questDef.objectives do
		if obj.type == "kill" and obj.target == mobId then
			local current = (progress[obj.id] :: number) or 0
			if current < (obj.count or 1) then
				progress[obj.id] = current + 1
				changed = true
			end
		end
	end
	return changed
end

function QuestLogic.markReach(questDef: QuestDef, progress: { [string]: number | boolean }, zoneId: string): boolean
	local changed = false
	for _, obj in questDef.objectives do
		if obj.type == "reach" and obj.target == zoneId and progress[obj.id] ~= true then
			progress[obj.id] = true
			changed = true
		end
	end
	return changed
end

-- A quest can start only if it is neither active nor already completed.
function QuestLogic.canStart(questId: string, activeQuests: { [string]: any }, completedQuests: { string }): boolean
	if activeQuests[questId] ~= nil then
		return false
	end
	for _, id in completedQuests do
		if id == questId then
			return false
		end
	end
	return true
end

return QuestLogic
