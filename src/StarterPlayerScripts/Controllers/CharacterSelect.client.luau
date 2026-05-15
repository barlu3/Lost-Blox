-- Character / file-select screen.
-- Shows on join; hides when the player clicks Play.  Arcane Odyssey-style slots.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- ── Remotes ───────────────────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local getSlotDataFn: RemoteFunction = Remotes:WaitForChild("GetSlotData") :: any
local createCharEv: RemoteEvent = Remotes:WaitForChild("CreateCharacter") :: any
local deleteCharEv: RemoteEvent = Remotes:WaitForChild("DeleteCharacter") :: any
local selectCharEv: RemoteEvent = Remotes:WaitForChild("SelectCharacter") :: any
local charUpdatedEv: RemoteEvent = Remotes:WaitForChild("CharacterUpdated") :: any
local charReadyEv: RemoteEvent = Remotes:WaitForChild("CharacterReady") :: any

-- ── Constants ─────────────────────────────────────────────────────────────────
local SLOT_COUNT = 3
local NAME_MIN, NAME_MAX = 3, 20
local TW_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TW_MED = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local C = {
	bg        = Color3.fromRGB(10, 12, 20),
	card      = Color3.fromRGB(18, 22, 34),
	cardHov   = Color3.fromRGB(26, 32, 50),
	cardSel   = Color3.fromRGB(30, 38, 62),
	border    = Color3.fromRGB(45, 55, 80),
	borderSel = Color3.fromRGB(220, 170, 60),
	gold      = Color3.fromRGB(220, 170, 60),
	white     = Color3.fromRGB(215, 215, 228),
	dim       = Color3.fromRGB(120, 128, 152),
	play      = Color3.fromRGB(50, 148, 78),
	del       = Color3.fromRGB(148, 50, 50),
	disabled  = Color3.fromRGB(42, 48, 68),
	ironclad  = Color3.fromRGB(200, 118, 45),
	storm     = Color3.fromRGB(68, 118, 222),
	sky       = Color3.fromRGB(200, 58, 90),
}

local CLASSES = {
	{ id = "Ironclad",    label = "IRONCLAD",    sub = "Warrior",        color = C.ironclad, available = true  },
	{ id = "Stormcaller", label = "STORMCALLER", sub = "Mage",           color = C.storm,    available = false },
	{ id = "Skystrike",   label = "SKYSTRIKE",   sub = "Martial Artist", color = C.sky,      available = false },
}

local CLASS_COLOR = {
	Ironclad = C.ironclad, Stormcaller = C.storm, Skystrike = C.sky,
}

-- ── State ─────────────────────────────────────────────────────────────────────
local slots      = {}        -- array of slot info tables, length = SLOT_COUNT
local selSlot: number?  = nil
local createFor: number? = nil
local pickedClass: string? = nil

-- Forward-declared callback table so card hit-box closures can call functions
-- defined later in the script.
local cb = {}

-- ── Utility ───────────────────────────────────────────────────────────────────
local function make(cls: string, parent: Instance?, props: { [string]: any }?): any
	local obj = Instance.new(cls) :: any
	for k, v in (props or {}) do obj[k] = v end
	if parent then obj.Parent = parent end
	return obj
end

local function addCorner(obj: GuiObject, px: number)
	make("UICorner", obj, { CornerRadius = UDim.new(0, px) })
end

local function addStroke(obj: GuiObject, color: Color3, thickness: number): UIStroke
	return make("UIStroke", obj, { Color = color, Thickness = thickness })
end

local function addPad(obj: GuiObject, px: number)
	make("UIPadding", obj, {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px), PaddingRight  = UDim.new(0, px),
	})
end

local function hoverColor(btn: TextButton, base: Color3)
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TW_FAST, { BackgroundColor3 = base:Lerp(Color3.new(1,1,1), 0.15) }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TW_FAST, { BackgroundColor3 = base }):Play()
	end)
end

-- ── Root GUI ──────────────────────────────────────────────────────────────────
local gui = make("ScreenGui", playerGui, {
	Name           = "CharacterSelectGui",
	ResetOnSpawn   = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder   = 10,
})

-- ════════════════════════════════════════════════════════════════════════════
-- FILE SELECT SCREEN
-- ════════════════════════════════════════════════════════════════════════════
local fsScreen = make("Frame", gui, {
	Name             = "FileSelect",
	Size             = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.bg,
	BorderSizePixel  = 0,
})

make("TextLabel", fsScreen, {
	Text = "LOST BLOX", Size = UDim2.new(1, 0, 0, 60),
	Position = UDim2.new(0, 0, 0, 36),
	Font = Enum.Font.GothamBlack, TextSize = 42,
	TextColor3 = C.gold, BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Center,
})
make("TextLabel", fsScreen, {
	Text = "Select File", Size = UDim2.new(1, 0, 0, 28),
	Position = UDim2.new(0, 0, 0, 92),
	Font = Enum.Font.Gotham, TextSize = 17,
	TextColor3 = C.dim, BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Center,
})

-- cards holder
local cardsHolder = make("Frame", fsScreen, {
	Size = UDim2.new(0.80, 0, 0, 420),
	Position = UDim2.new(0.10, 0, 0.5, -210),
	BackgroundTransparency = 1,
})
make("UIListLayout", cardsHolder, {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 20),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
})

-- action bar
local actionBar = make("Frame", fsScreen, {
	Size = UDim2.new(0, 264, 0, 54),
	Position = UDim2.new(0.5, -132, 1, -88),
	BackgroundTransparency = 1,
})
make("UIListLayout", actionBar, {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 14),
	VerticalAlignment = Enum.VerticalAlignment.Center,
})

local playBtn = make("TextButton", actionBar, {
	Text = "PLAY", Size = UDim2.new(0, 124, 0, 50),
	Font = Enum.Font.GothamBold, TextSize = 17,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = C.disabled,
	AutoButtonColor = false, LayoutOrder = 1,
})
addCorner(playBtn, 10)

local deleteBtn = make("TextButton", actionBar, {
	Text = "DELETE", Size = UDim2.new(0, 114, 0, 50),
	Font = Enum.Font.GothamBold, TextSize = 15,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = C.disabled,
	AutoButtonColor = false, LayoutOrder = 2,
})
addCorner(deleteBtn, 10)

-- ── Slot card builder ─────────────────────────────────────────────────────────
type CardRefs = {
	frame: Frame, stroke: UIStroke,
	emptyGroup: Frame, filledGroup: Frame,
	nameLabel: TextLabel, classLabel: TextLabel,
	colorBar: Frame, colorBarCover: Frame,
	dateLabel: TextLabel,
}

local cardRefs: { CardRefs } = {}

local function buildSlotCard(index: number): CardRefs
	local cardFrame = make("Frame", cardsHolder, {
		Name = "Card" .. index,
		Size = UDim2.new(0.333, -14, 1, 0),
		BackgroundColor3 = C.card,
		LayoutOrder = index,
	})
	addCorner(cardFrame, 14)
	local stroke = addStroke(cardFrame, C.border, 2)

	make("TextLabel", cardFrame, {
		Text = "FILE " .. index, Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 0, 20),
		Font = Enum.Font.Gotham, TextSize = 13,
		TextColor3 = C.dim, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- ── Empty state ──────────────────────────────────────────────────────────
	local emptyGroup = make("Frame", cardFrame, {
		Size = UDim2.new(1, 0, 1, -58),
		Position = UDim2.new(0, 0, 0, 58),
		BackgroundTransparency = 1,
	})
	make("TextLabel", emptyGroup, {
		Text = "+", Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.new(0, 0, 0.38, -35),
		Font = Enum.Font.GothamBold, TextSize = 56,
		TextColor3 = C.border, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	make("TextLabel", emptyGroup, {
		Text = "NEW GAME", Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0.38, 46),
		Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = C.dim, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- ── Filled state ─────────────────────────────────────────────────────────
	local filledGroup = make("Frame", cardFrame, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	})

	-- class color accent bar (top of card)
	local colorBar = make("Frame", filledGroup, {
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = C.ironclad,
		BorderSizePixel = 0,
	})
	addCorner(colorBar, 14)
	-- cover the bottom-rounded corners so bar looks flat on the bottom edge
	local colorBarCover = make("Frame", colorBar, {
		Size = UDim2.new(1, 0, 0.55, 0),
		Position = UDim2.new(0, 0, 0.45, 0),
		BackgroundColor3 = C.ironclad,
		BorderSizePixel = 0,
	})

	local nameLabel = make("TextLabel", filledGroup, {
		Text = "", Size = UDim2.new(1, -20, 0, 48),
		Position = UDim2.new(0, 10, 0, 50),
		Font = Enum.Font.GothamBold, TextSize = 26,
		TextColor3 = C.white, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local classLabel = make("TextLabel", filledGroup, {
		Text = "", Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.new(0, 10, 0, 100),
		Font = Enum.Font.Gotham, TextSize = 13,
		TextColor3 = C.ironclad, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local dateLabel = make("TextLabel", filledGroup, {
		Text = "", Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.new(0, 10, 1, -34),
		Font = Enum.Font.Gotham, TextSize = 11,
		TextColor3 = C.dim, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- ── Hit-box button over whole card ───────────────────────────────────────
	local hitBox = make("TextButton", cardFrame, {
		Text = "", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, ZIndex = 5,
	})
	hitBox.MouseEnter:Connect(function()
		if selSlot ~= index then
			TweenService:Create(cardFrame, TW_FAST, { BackgroundColor3 = C.cardHov }):Play()
		end
	end)
	hitBox.MouseLeave:Connect(function()
		if selSlot ~= index then
			TweenService:Create(cardFrame, TW_FAST, { BackgroundColor3 = C.card }):Play()
		end
	end)
	hitBox.MouseButton1Click:Connect(function()
		local s = slots[index]
		if not s then return end
		if s.isEmpty then
			cb.openCreate(index)
		else
			cb.selectCard(index)
		end
	end)

	return {
		frame = cardFrame, stroke = stroke,
		emptyGroup = emptyGroup, filledGroup = filledGroup,
		nameLabel = nameLabel, classLabel = classLabel,
		colorBar = colorBar, colorBarCover = colorBarCover,
		dateLabel = dateLabel,
	}
end

for i = 1, SLOT_COUNT do
	cardRefs[i] = buildSlotCard(i)
end

-- ════════════════════════════════════════════════════════════════════════════
-- CHARACTER CREATE SCREEN
-- ════════════════════════════════════════════════════════════════════════════
local createScreen = make("Frame", gui, {
	Name = "CharacterCreate",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.bg,
	BorderSizePixel = 0,
	Visible = false,
})

local backBtn = make("TextButton", createScreen, {
	Text = "← Back", Size = UDim2.new(0, 110, 0, 40),
	Position = UDim2.new(0, 28, 0, 28),
	Font = Enum.Font.Gotham, TextSize = 15,
	TextColor3 = C.dim, BackgroundColor3 = C.card,
	AutoButtonColor = false,
})
addCorner(backBtn, 8)
hoverColor(backBtn, C.card)

make("TextLabel", createScreen, {
	Text = "CREATE CHARACTER", Size = UDim2.new(1, 0, 0, 48),
	Position = UDim2.new(0, 0, 0, 34),
	Font = Enum.Font.GothamBlack, TextSize = 30,
	TextColor3 = C.gold, BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Center,
})

-- ── Name input ────────────────────────────────────────────────────────────────
local nameSection = make("Frame", createScreen, {
	Size = UDim2.new(0.42, 0, 0, 90),
	Position = UDim2.new(0.29, 0, 0, 112),
	BackgroundTransparency = 1,
})
make("TextLabel", nameSection, {
	Text = "Character Name", Size = UDim2.new(1, 0, 0, 20),
	Font = Enum.Font.GothamBold, TextSize = 13,
	TextColor3 = C.dim, BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local nameBox = make("TextBox", nameSection, {
	PlaceholderText = "Enter a name…",
	Text = "", Size = UDim2.new(1, 0, 0, 52),
	Position = UDim2.new(0, 0, 0, 24),
	Font = Enum.Font.GothamBold, TextSize = 20,
	TextColor3 = C.white, PlaceholderColor3 = C.dim,
	BackgroundColor3 = C.card, ClearTextOnFocus = false,
})
addCorner(nameBox, 10)
addStroke(nameBox, C.border, 2)
addPad(nameBox, 12)

local nameCountLbl = make("TextLabel", nameSection, {
	Text = "0 / " .. NAME_MAX, Size = UDim2.new(1, 0, 0, 16),
	Position = UDim2.new(0, 0, 0, 80),
	Font = Enum.Font.Gotham, TextSize = 11,
	TextColor3 = C.dim, BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Right,
})

-- ── Class select ──────────────────────────────────────────────────────────────
make("TextLabel", createScreen, {
	Text = "Choose Class", Size = UDim2.new(1, 0, 0, 24),
	Position = UDim2.new(0, 0, 0, 222),
	Font = Enum.Font.GothamBold, TextSize = 14,
	TextColor3 = C.dim, BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Center,
})

local classHolder = make("Frame", createScreen, {
	Size = UDim2.new(0.74, 0, 0, 230),
	Position = UDim2.new(0.13, 0, 0, 252),
	BackgroundTransparency = 1,
})
make("UIListLayout", classHolder, {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 16),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
})

type ClassRefs = { frame: Frame, stroke: UIStroke }
local classRefs: { ClassRefs } = {}

local function buildClassCard(i: number, def: { id: string, label: string, sub: string, color: Color3, available: boolean }): ClassRefs
	local fr = make("Frame", classHolder, {
		Name = "Class_" .. def.id,
		Size = UDim2.new(0.333, -12, 1, 0),
		BackgroundColor3 = if def.available then C.card else Color3.fromRGB(14, 17, 26),
		LayoutOrder = i,
	})
	addCorner(fr, 12)
	local st = addStroke(fr, C.border, 2)

	-- color accent bar
	local bar = make("Frame", fr, {
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = def.color, BorderSizePixel = 0,
	})
	addCorner(bar, 12)
	make("Frame", bar, {
		Size = UDim2.new(1, 0, 0.55, 0),
		Position = UDim2.new(0, 0, 0.45, 0),
		BackgroundColor3 = def.color, BorderSizePixel = 0,
	})

	make("TextLabel", fr, {
		Text = def.label, Size = UDim2.new(1, -12, 0, 46),
		Position = UDim2.new(0, 6, 0, 24),
		Font = Enum.Font.GothamBlack, TextSize = 17,
		TextColor3 = if def.available then C.white else C.dim,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
	})
	make("TextLabel", fr, {
		Text = def.sub:upper(), Size = UDim2.new(1, -12, 0, 18),
		Position = UDim2.new(0, 6, 0, 72),
		Font = Enum.Font.Gotham, TextSize = 11,
		TextColor3 = def.color, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	if def.available then
		local hit = make("TextButton", fr, {
			Text = "", Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, ZIndex = 4,
		})
		hit.MouseEnter:Connect(function()
			if pickedClass ~= def.id then
				TweenService:Create(fr, TW_FAST, { BackgroundColor3 = C.cardHov }):Play()
			end
		end)
		hit.MouseLeave:Connect(function()
			if pickedClass ~= def.id then
				TweenService:Create(fr, TW_FAST, { BackgroundColor3 = C.card }):Play()
			end
		end)
		hit.MouseButton1Click:Connect(function()
			cb.pickClass(def.id)
		end)
	else
		-- locked overlay
		local overlay = make("Frame", fr, {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(6, 8, 14),
			BackgroundTransparency = 0.30,
		})
		addCorner(overlay, 12)
		make("TextLabel", overlay, {
			Text = "COMING\nSOON", Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold, TextSize = 14,
			TextColor3 = C.dim, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
	end

	return { frame = fr, stroke = st }
end

for i, def in CLASSES do
	classRefs[i] = buildClassCard(i, def)
end

-- Create button
local createBtn = make("TextButton", createScreen, {
	Text = "CREATE", Size = UDim2.new(0, 180, 0, 52),
	Position = UDim2.new(0.5, -90, 1, -90),
	Font = Enum.Font.GothamBold, TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = C.disabled,
	AutoButtonColor = false,
})
addCorner(createBtn, 12)

-- ════════════════════════════════════════════════════════════════════════════
-- UPDATE / REFRESH FUNCTIONS
-- ════════════════════════════════════════════════════════════════════════════
local function formatDate(ts: number): string
	local ok, r = pcall(os.date, "%m/%d/%Y", ts)
	return "Created " .. (if ok and typeof(r) == "string" then r else "—")
end

local function refreshFileSelect()
	for i = 1, SLOT_COUNT do
		local refs = cardRefs[i]
		local s = slots[i] or { isEmpty = true }
		if s.isEmpty then
			refs.emptyGroup.Visible  = true
			refs.filledGroup.Visible = false
		else
			refs.emptyGroup.Visible  = false
			refs.filledGroup.Visible = true
			refs.nameLabel.Text      = s.name or "?"
			local col = CLASS_COLOR[s.class] or C.dim
			refs.classLabel.Text          = ((s.class or "Unknown")):upper()
			refs.classLabel.TextColor3    = col
			refs.colorBar.BackgroundColor3      = col
			refs.colorBarCover.BackgroundColor3 = col
			refs.dateLabel.Text = formatDate(s.createdAt or 0)
		end
	end
end

local function applySlotSelection(index: number?)
	selSlot = index
	for i = 1, SLOT_COUNT do
		local refs = cardRefs[i]
		local isSel = i == index
		TweenService:Create(refs.frame, TW_FAST, {
			BackgroundColor3 = if isSel then C.cardSel else C.card,
		}):Play()
		TweenService:Create(refs.stroke, TW_FAST, {
			Color = if isSel then C.borderSel else C.border,
		}):Play()
	end
	-- action buttons
	local hasFilled = index ~= nil and slots[index] and not slots[index].isEmpty
	local pCol = if hasFilled then C.play else C.disabled
	local dCol = if hasFilled then C.del  else C.disabled
	TweenService:Create(playBtn, TW_FAST, { BackgroundColor3 = pCol }):Play()
	TweenService:Create(deleteBtn, TW_FAST, { BackgroundColor3 = dCol }):Play()
	deleteBtn.Text = "DELETE" -- reset confirm state on selection change
end

local function validateCreate(): boolean
	local name = nameBox.Text:match("^%s*(.-)%s*$") or ""
	return #name >= NAME_MIN
		and #name <= NAME_MAX
		and name:match("^[%a%d ]+$") ~= nil
		and pickedClass ~= nil
end

local function refreshCreateBtn()
	local col = if validateCreate() then C.play else C.disabled
	TweenService:Create(createBtn, TW_MED, { BackgroundColor3 = col }):Play()
end

local function refreshClassCards()
	for i, def in CLASSES do
		if not def.available then continue end
		local refs = classRefs[i]
		local isSel = pickedClass == def.id
		TweenService:Create(refs.frame, TW_FAST, {
			BackgroundColor3 = if isSel then C.cardSel else C.card,
		}):Play()
		TweenService:Create(refs.stroke, TW_FAST, {
			Color = if isSel then C.borderSel else C.border,
		}):Play()
	end
end

local function showFileSelect()
	fsScreen.Visible     = true
	createScreen.Visible = false
end

local function showCreate(forSlot: number)
	createFor   = forSlot
	pickedClass = nil
	nameBox.Text = ""
	nameCountLbl.Text = "0 / " .. NAME_MAX
	refreshClassCards()
	refreshCreateBtn()
	fsScreen.Visible     = false
	createScreen.Visible = true
end

-- ── Populate forward-declared callbacks ───────────────────────────────────────
cb.selectCard = applySlotSelection
cb.openCreate = showCreate
cb.pickClass  = function(classId: string)
	pickedClass = classId
	refreshClassCards()
	refreshCreateBtn()
end

-- ════════════════════════════════════════════════════════════════════════════
-- BUTTON WIRING
-- ════════════════════════════════════════════════════════════════════════════

-- File select
local playPending = false
playBtn.MouseButton1Click:Connect(function()
	if playPending then return end
	if not selSlot then return end
	local s = slots[selSlot]
	if not s or s.isEmpty then return end

	-- Enter a loading state while we wait for the server to confirm.
	playPending = true
	playBtn.Text = "Loading…"
	TweenService:Create(playBtn, TW_FAST, { BackgroundColor3 = C.disabled }):Play()

	selectCharEv:FireServer(selSlot)

	-- Safety fallback: if CharacterReady never arrives (server error / timeout),
	-- restore the button so the player can retry.
	task.delay(10, function()
		if playPending then
			playPending = false
			playBtn.Text = "PLAY"
			TweenService:Create(playBtn, TW_FAST, { BackgroundColor3 = C.play }):Play()
		end
	end)
end)

deleteBtn.MouseButton1Click:Connect(function()
	if not selSlot then return end
	local s = slots[selSlot]
	if not s or s.isEmpty then return end
	if deleteBtn.Text == "DELETE" then
		-- First click: ask for confirmation.
		deleteBtn.Text = "CONFIRM?"
		task.delay(2.5, function()
			if deleteBtn.Text == "CONFIRM?" then
				deleteBtn.Text = "DELETE"
			end
		end)
	else
		-- Second click: execute delete.
		deleteBtn.Text = "DELETE"
		deleteCharEv:FireServer(selSlot)
		applySlotSelection(nil)
	end
end)

-- Character create
backBtn.MouseButton1Click:Connect(function()
	showFileSelect()
end)

nameBox:GetPropertyChangedSignal("Text"):Connect(function()
	local txt = nameBox.Text
	if #txt > NAME_MAX then
		nameBox.Text = txt:sub(1, NAME_MAX)
		return
	end
	nameCountLbl.Text = #txt .. " / " .. NAME_MAX
	refreshCreateBtn()
end)

createBtn.MouseButton1Click:Connect(function()
	if not validateCreate() then return end
	local name = nameBox.Text:match("^%s*(.-)%s*$") or ""
	createCharEv:FireServer(createFor, name, pickedClass)
	showFileSelect() -- optimistic: server will fire CharacterUpdated to confirm
end)

-- ── Server → Client: slot data updated ───────────────────────────────────────
charUpdatedEv.OnClientEvent:Connect(function(newSlots: { any })
	slots = newSlots
	refreshFileSelect()
	applySlotSelection(nil)
end)

-- ── Server → Client: slot accepted, dismiss menu and enter the game ───────────
charReadyEv.OnClientEvent:Connect(function()
	playPending = false
	gui.Enabled = false
end)

-- ════════════════════════════════════════════════════════════════════════════
-- INIT
-- ════════════════════════════════════════════════════════════════════════════
local function init()
	-- Show empty placeholders immediately while the server loads the profile.
	for i = 1, SLOT_COUNT do
		slots[i] = { isEmpty = true }
	end
	refreshFileSelect()
	applySlotSelection(nil)
	showFileSelect()

	-- Fetch real slot data from server (yields until ProfileManager loads).
	local ok, result = pcall(function()
		return getSlotDataFn:InvokeServer()
	end)
	if ok and result then
		slots = result
		refreshFileSelect()
	end
end

init()
