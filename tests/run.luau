--!nocheck
-- Runs every *.spec.luau under tests/ with lune. Specs follow the TestEZ shape
-- (`return function() describe(...) end`); the harness must be required first so
-- its Roblox shims and describe/it/expect globals are installed.
--
-- Run: lune run tests/run.luau

local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("./Harness.luau")

-- Specs that require a live Roblox DataModel (TestEZ-in-Studio only).
local SKIP = {
	["ProfileManager.spec.luau"] = true,
}

local specPaths: { string } = {}

local function walk(dir: string)
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			walk(path)
		elseif entry:match("%.spec%.luau$") and not SKIP[entry] then
			table.insert(specPaths, path)
		end
	end
end

walk("tests")
table.sort(specPaths)

for _, path in specPaths do
	-- require() resolves relative to this file (tests/run.luau); strip the
	-- leading "tests/" and prefix "./" to match.
	local rel = "./" .. path:gsub("^tests/", "")
	local spec = require(rel)
	if type(spec) == "function" then
		spec()
	end
end

process.exit(Harness.run())
