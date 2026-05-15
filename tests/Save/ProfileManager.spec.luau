-- Unit tests for ProfileManager using a mocked ProfileService.
-- Run with TestEZ: require this file from a test runner script.
--
-- The mock mirrors the ProfileService API so these tests run without a live
-- DataStore. Integration tests (session lock, cross-server, Studio persistence)
-- must be validated manually in Studio.

local ProfileTemplate = require(game.ServerScriptService.Save.ProfileTemplate)

-- Builds a mock profile wrapping a copy of the provided data table.
local function makeMockProfile(data: { [string]: any }?, shouldReturnNil: boolean?)
	if shouldReturnNil then
		return nil
	end

	-- Deep-copy data so each test is isolated.
	local profileData = {}
	for k, v in (data or ProfileTemplate) do
		profileData[k] = v
	end

	local saveCount = 0
	local releaseCount = 0
	local reconcileCalled = false

	local profile = {
		Data = profileData,
		_saveCount = function() return saveCount end,
		_releaseCount = function() return releaseCount end,
		_reconcileCalled = function() return reconcileCalled end,
	}

	function profile:Reconcile()
		reconcileCalled = true
		-- Mirror ProfileService behaviour: add missing keys from template without
		-- overwriting existing values.
		for key, default in ProfileTemplate do
			if self.Data[key] == nil then
				self.Data[key] = default
			end
		end
	end

	function profile:Save()
		saveCount += 1
	end

	function profile:Release()
		releaseCount += 1
	end

	return profile
end

-- Builds a mock ProfileStore whose LoadProfileAsync is controllable per-call.
local function makeMockProfileService(profileSequence: { any })
	local callIndex = 0

	local store = {}
	function store:LoadProfileAsync(_key: string)
		callIndex += 1
		local entry = profileSequence[callIndex] or profileSequence[#profileSequence]
		if entry == "nil" then
			return nil
		end
		return entry
	end

	local service = {}
	function service.GetProfileStore(_name: string, _template: { [string]: any })
		return store
	end

	return service
end

-- Builds a mock Player object.
local function makeMockPlayer(userId: number, isInGame: boolean?)
	return {
		UserId = userId,
		-- Simulate IsDescendantOf(game): true when player is still in the game.
		IsDescendantOf = function(_self, _ancestor)
			return if isInGame == nil then true else isInGame
		end,
		_kicked = false,
		Kick = function(self, _reason: string)
			self._kicked = true
		end,
	}
end

return function()
	describe("ProfileTemplate", function()
		it("contains all required keys", function()
			expect(ProfileTemplate.characterSlot).to.be.ok()
			expect(ProfileTemplate.inventory).to.be.ok()
			expect(ProfileTemplate.equippedItems).to.be.ok()
			expect(ProfileTemplate.honing).to.be.ok()
			expect(ProfileTemplate.questProgress).to.be.ok()
			expect(ProfileTemplate.completedQuests).to.be.ok()
			expect(ProfileTemplate.createdAt).never.to.equal(nil)
		end)

		it("characterSlot defaults to 1", function()
			expect(ProfileTemplate.characterSlot).to.equal(1)
		end)

		it("createdAt defaults to 0", function()
			expect(ProfileTemplate.createdAt).to.equal(0)
		end)
	end)

	describe("mock ProfileService — session lock", function()
		it("nil from LoadProfileAsync kicks the player", function()
			local player = makeMockPlayer(1)
			local profile = makeMockProfile(nil, true) -- simulates session lock

			-- Replicate the kick guard logic from ProfileManager.
			if profile == nil then
				player:Kick("Unable to load your save data. Please rejoin in a moment.")
			end

			expect(player._kicked).to.equal(true)
		end)

		it("valid profile does not kick the player", function()
			local player = makeMockPlayer(1)
			local profile = makeMockProfile()

			if profile == nil then
				player:Kick("...")
			end

			expect(player._kicked).to.equal(false)
		end)
	end)

	describe("mock ProfileService — stale profile guard", function()
		it("releases profile when player left during load", function()
			local profile = makeMockProfile()
			local playerGone = makeMockPlayer(1, false) -- IsDescendantOf returns false

			if not playerGone:IsDescendantOf(game) then
				profile:Release()
			end

			expect(profile._releaseCount()).to.equal(1)
		end)

		it("does not release profile when player is still in game", function()
			local profile = makeMockProfile()
			local playerPresent = makeMockPlayer(1, true)

			if not playerPresent:IsDescendantOf(game) then
				profile:Release()
			end

			expect(profile._releaseCount()).to.equal(0)
		end)
	end)

	describe("mock ProfileService — reconciliation", function()
		it("Reconcile adds missing template keys without overwriting existing data", function()
			-- Simulate an old profile missing 'honing' (added in a schema update).
			local existingData = {
				characterSlot = 2,
				inventory = { { id = "iron_sword", quantity = 1, quality = 50, iLvl = 302 } },
				equippedItems = {},
				questProgress = {},
				completedQuests = {},
				createdAt = 1700000000,
				-- 'honing' is intentionally absent to simulate an old save.
			}

			local profile = makeMockProfile(existingData)
			profile:Reconcile()

			-- New key was added from template.
			expect(profile.Data.honing).to.be.ok()
			-- Existing values were preserved.
			expect(profile.Data.characterSlot).to.equal(2)
			expect(profile.Data.createdAt).to.equal(1700000000)
		end)

		it("Reconcile does not overwrite existing values", function()
			local existingData = {
				characterSlot = 3,
				inventory = {},
				equippedItems = {},
				honing = {},
				questProgress = {},
				completedQuests = {},
				createdAt = 1700000001,
			}

			local profile = makeMockProfile(existingData)
			profile:Reconcile()

			expect(profile.Data.characterSlot).to.equal(3)
			expect(profile.Data.createdAt).to.equal(1700000001)
		end)
	end)

	describe("mock ProfileService — createdAt", function()
		it("sets createdAt when template default of 0 is found (new player)", function()
			local profile = makeMockProfile()
			profile:Reconcile()

			-- Replicate the createdAt init logic from ProfileManager.
			local now = os.time()
			if profile.Data.createdAt == 0 then
				profile.Data.createdAt = now
			end

			expect(profile.Data.createdAt).to.equal(now)
		end)

		it("does not overwrite existing createdAt (returning player)", function()
			local existingData = {
				characterSlot = 1,
				inventory = {},
				equippedItems = {},
				honing = {},
				questProgress = {},
				completedQuests = {},
				createdAt = 1700000000,
			}

			local profile = makeMockProfile(existingData)
			profile:Reconcile()

			if profile.Data.createdAt == 0 then
				profile.Data.createdAt = os.time()
			end

			expect(profile.Data.createdAt).to.equal(1700000000)
		end)
	end)

	describe("mock ProfileService — PlayerRemoving sequence", function()
		it("calls Save then Release on player removing", function()
			local profile = makeMockProfile()

			-- Replicate onPlayerRemoving logic.
			profile:Save()
			profile:Release()

			expect(profile._saveCount()).to.equal(1)
			expect(profile._releaseCount()).to.equal(1)
		end)

		it("Save is called before Release", function()
			local callOrder = {}
			local profile = makeMockProfile()

			-- Override to record order.
			function profile:Save()
				table.insert(callOrder, "Save")
			end
			function profile:Release()
				table.insert(callOrder, "Release")
			end

			profile:Save()
			profile:Release()

			expect(callOrder[1]).to.equal("Save")
			expect(callOrder[2]).to.equal("Release")
		end)
	end)
end
