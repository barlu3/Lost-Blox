-- Server-side quest tracking. Quests are defined in JSON, tracked in the player
-- profile, and completed when all objectives are met. Event-driven: combat /
-- movement systems publish to a BindableEvent bus, which QuestManager subscribes
-- to — so CombatResolver never imports QuestManager directly.
--
-- The progress math lives in QuestLogic (pure); this module wires it to the
-- profile, rewards, and the QuestCompleted RemoteEvent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestLogic = require(script.Parent.QuestLogic)

local QuestManager = {}

local quests: { [string]: any } = {}
local ProfileManager: any = nil
local InventoryManager: any = nil
local questCompleted: RemoteEvent? = nil

function QuestManager.register(questDef: any)
	quests[questDef.id] = questDef
end

function QuestManager.loadAll()
	local configs = ReplicatedStorage:WaitForChild("Configs")
	local folder = configs:FindFirstChild("Quests")
	if not folder then
		return
	end
	for _, module in folder:GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, def = pcall(require, module)
			if ok and type(def) == "table" and def.id then
				QuestManager.register(def)
			end
		end
	end
end

function QuestManager.startQuest(player: Player, questId: string): boolean
	local data = ProfileManager.GetData(player)
	local def = quests[questId]
	if not data or not def then
		return false
	end
	if not QuestLogic.canStart(questId, data.questProgress, data.completedQuests) then
		return false
	end
	data.questProgress[questId] = {
		progress = QuestLogic.initProgress(def),
		startedAt = os.time(),
	}
	return true
end

-- Grants every reward in one pass; the caller's single profile write makes it
-- atomic, so a crash mid-grant cannot half-complete a quest.
local function grantRewards(player: Player, data: any, def: any)
	for _, reward in def.rewards do
		if reward.type == "item" then
			InventoryManager.AddItem(player, { id = reward.id, quantity = reward.quantity or 1, quality = 0, iLvl = 0, stackable = true })
		elseif reward.type == "exp" then
			data.exp = (data.exp or 0) + (reward.amount or 0)
		end
	end
end

local function checkCompletion(player: Player, data: any, questId: string)
	local def = quests[questId]
	local active = data.questProgress[questId]
	if not def or not active then
		return
	end
	if QuestLogic.isComplete(def, active.progress) then
		grantRewards(player, data, def)
		data.questProgress[questId] = nil
		table.insert(data.completedQuests, questId)
		if questCompleted then
			questCompleted:FireClient(player, questId)
		end
	end
end

function QuestManager.onMobKilled(player: Player, mobId: string)
	local data = ProfileManager.GetData(player)
	if not data then
		return
	end
	for questId, active in data.questProgress do
		local def = quests[questId]
		if def and QuestLogic.incrementKill(def, active.progress, mobId) then
			checkCompletion(player, data, questId)
		end
	end
end

function QuestManager.onZoneReached(player: Player, zoneId: string)
	local data = ProfileManager.GetData(player)
	if not data then
		return
	end
	for questId, active in data.questProgress do
		local def = quests[questId]
		if def and QuestLogic.markReach(def, active.progress, zoneId) then
			checkCompletion(player, data, questId)
		end
	end
end

-- bus: a BindableEvent-backed event table { MobKilled, ZoneReached } so combat
-- and movement publish without a hard dependency on QuestManager.
function QuestManager.start(profileManager: any, inventoryManager: any, bus: any)
	ProfileManager = profileManager
	InventoryManager = inventoryManager

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("QuestCompleted")
	if existing then
		questCompleted = existing :: RemoteEvent
	else
		local r = Instance.new("RemoteEvent")
		r.Name = "QuestCompleted"
		r.Parent = remotes
		questCompleted = r
	end

	QuestManager.loadAll()

	if bus then
		bus.MobKilled.Event:Connect(QuestManager.onMobKilled)
		bus.ZoneReached.Event:Connect(QuestManager.onZoneReached)
	end
end

return QuestManager
