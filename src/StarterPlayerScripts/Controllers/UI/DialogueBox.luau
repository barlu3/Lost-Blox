-- Typewriter dialogue UI with Undertale-style voice blips. Plays a sequence of
-- { speaker, text, portrait } entries; text reveals one character at a time and
-- a per-NPC Sound blips on letters. Any input skips the reveal, then advances.
-- Pure timing/blip rules live in DialogueLogic.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueLogic = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DialogueLogic"))

local DialogueBox = {}

local localPlayer = Players.LocalPlayer
local gui: ScreenGui? = nil
local activeLabel: TextLabel? = nil
local historyFrame: ScrollingFrame? = nil
local revealing = false
local fullText = ""
local advanceRequested = false

local function buildGui()
	local g = Instance.new("ScreenGui")
	g.Name = "DialogueGui"
	g.ResetOnSpawn = false
	g.DisplayOrder = 20
	g.Enabled = false
	g.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0.7, 0, 0, 160)
	panel.Position = UDim2.new(0.15, 0, 1, -190)
	panel.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	panel.BackgroundTransparency = 0.1
	panel.Parent = g
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

	local history = Instance.new("ScrollingFrame")
	history.Name = "History"
	history.Size = UDim2.new(1, -24, 0, 70)
	history.Position = UDim2.new(0, 12, 0, 10)
	history.BackgroundTransparency = 1
	history.ScrollBarThickness = 4
	history.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = history

	local label = Instance.new("TextLabel")
	label.Name = "Active"
	label.Size = UDim2.new(1, -24, 0, 60)
	label.Position = UDim2.new(0, 12, 1, -72)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(230, 230, 240)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Text = ""
	label.Parent = panel

	gui, activeLabel, historyFrame = g, label, history
end

local function appendHistory(speaker: string, text: string)
	if not historyFrame then
		return
	end
	local entry = Instance.new("TextLabel")
	entry.Size = UDim2.new(1, 0, 0, 18)
	entry.BackgroundTransparency = 1
	entry.Font = Enum.Font.Gotham
	entry.TextSize = 13
	entry.TextColor3 = Color3.fromRGB(150, 155, 170)
	entry.TextXAlignment = Enum.TextXAlignment.Left
	entry.Text = ("%s: %s"):format(speaker, text)
	entry.LayoutOrder = #historyFrame:GetChildren()
	entry.Parent = historyFrame
end

-- Reveals one line character-by-character, blipping the NPC voice on letters.
local function revealLine(entry: { speaker: string, text: string }, voice: Sound?, pitch: number)
	fullText = entry.text
	revealing = true
	if activeLabel then
		activeLabel.Text = ""
	end

	for i = 1, #fullText do
		if not revealing then
			break -- skipped
		end
		local char = fullText:sub(i, i)
		if activeLabel then
			activeLabel.Text = fullText:sub(1, i)
		end
		local blip = DialogueLogic.blipFor(char, pitch)
		if blip and voice then
			voice.Volume = blip.volume
			voice.PlaybackSpeed = blip.playbackSpeed
			voice:Play()
		end
		task.wait(DialogueLogic.CHAR_DELAY)
	end

	if activeLabel then
		activeLabel.Text = fullText -- ensure full text shown after skip
	end
	revealing = false
	appendHistory(entry.speaker, entry.text)
end

-- Plays an ordered sequence of dialogue entries. voicePitch comes from the NPC
-- config (replicated on dialogue start) so the box never queries mid-playback.
function DialogueBox.playSequence(entries: { any }, voice: Sound?, voicePitch: number?)
	if not gui then
		buildGui()
	end
	local g = gui :: ScreenGui
	g.Enabled = true
	local pitch = voicePitch or 1.0

	for _, entry in entries do
		advanceRequested = false
		revealLine(entry, voice, pitch)
		-- Wait for the player to advance past the completed line.
		repeat
			task.wait()
		until advanceRequested
	end

	g.Enabled = false
	if historyFrame then
		for _, child in historyFrame:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy() -- history clears on dialogue end
			end
		end
	end
end

function DialogueBox.start()
	UserInputService.InputBegan:Connect(function(_, processed)
		if processed or not (gui and gui.Enabled) then
			return
		end
		if revealing then
			revealing = false -- first press: skip to full text
		else
			advanceRequested = true -- second press: advance
		end
	end)
end

return DialogueBox
