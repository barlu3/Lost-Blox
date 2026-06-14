--!strict
-- Parses every .luau file under the given roots with load() and reports syntax
-- errors. This is the offline safety net: Roblox-instance requires can't resolve
-- outside Studio, but load() still catches every parse/compile error.
--
-- Run: lune run tools/dev/syntax_check.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOTS = { "src", "tests", "tools/dev" }

local failures: { { path: string, err: string } } = {}
local checked = 0

local function walk(dir: string)
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			walk(path)
		elseif entry:match("%.luau$") then
			checked += 1
			local source = fs.readFile(path)
			local ok, err = pcall(luau.compile, source)
			if not ok then
				table.insert(failures, { path = path, err = tostring(err) })
			end
		end
	end
end

for _, root in ROOTS do
	if fs.isDir(root) then
		walk(root)
	end
end

print(string.format("Syntax-checked %d Luau files.", checked))

if #failures > 0 then
	print(string.format("\n%d FILE(S) FAILED TO PARSE:", #failures))
	for _, f in failures do
		print("  ✗ " .. f.path)
		print("    " .. f.err)
	end
	process.exit(1)
end

print("All files parsed cleanly.")
