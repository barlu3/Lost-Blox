--!nocheck
-- Offline test harness for running Luau unit tests under lune (outside Roblox).
--
-- Requiring this module installs minimal Roblox global shims (Vector3, Random,
-- task, Enum, a controllable os.clock) so that pure-logic game modules — which
-- have no Roblox-instance requires — can be required and exercised for real.
--
-- Spec files follow the repo's TestEZ shape: `return function() describe(...) end`.
-- The runner (tests/run.luau) requires every spec and invokes the returned
-- function, then calls Harness.run() to print results and set the exit code.

local T = {}

-- ── Controllable clock ──────────────────────────────────────────────────────
-- Modules read os.clock() for cooldowns/timestamps; tests drive it explicitly.
-- lune's os table is readonly, so shadow the global os with a thin wrapper.
local clockTime = 1000.0
local realOs = os
os = setmetatable({
	clock = function()
		return clockTime
	end,
}, { __index = realOs })
function T.setTime(t: number)
	clockTime = t
end
function T.advance(dt: number)
	clockTime += dt
end

-- ── Vector3 shim ────────────────────────────────────────────────────────────
local Vec = {}
Vec.__index = function(t, k)
	if k == "Magnitude" then
		return (t.X * t.X + t.Y * t.Y + t.Z * t.Z) ^ 0.5
	end
	return nil
end
Vec.__sub = function(a, b)
	return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, Vec)
end
Vec.__add = function(a, b)
	return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, Vec)
end
Vec.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3 = {
	new = function(x: number?, y: number?, z: number?)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vec)
	end,
}

-- ── Random shim (deterministic xorshift32) ──────────────────────────────────
-- Not bit-identical to Roblox's Random, but deterministic per-seed and uniform
-- enough for distribution assertions. Production uses the real Roblox Random.
local Rng = {}
Rng.__index = Rng
function Rng:_next(): number
	local x = self._s
	x = bit32.bxor(x, bit32.band(bit32.lshift(x, 13), 0xFFFFFFFF))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.band(bit32.lshift(x, 5), 0xFFFFFFFF))
	x = bit32.band(x, 0xFFFFFFFF)
	self._s = x
	return x
end
function Rng:NextNumber(a: number?, b: number?): number
	local r = self:_next() / 4294967296
	if a ~= nil and b ~= nil then
		return a + (b - a) * r
	end
	return r
end
function Rng:NextInteger(a: number, b: number): number
	return a + (self:_next() % (b - a + 1))
end
Random = {
	new = function(seed: number?)
		local s = bit32.band(math.floor(seed or (clockTime * 1e6)), 0xFFFFFFFF)
		if s == 0 then
			s = 0x9E3779B9
		end
		return setmetatable({ _s = s }, Rng)
	end,
}

-- ── task shim ───────────────────────────────────────────────────────────────
-- delay() records scheduled callbacks for inspection; spawn/defer run inline.
local scheduled: { { t: number, fn: (...any) -> (), args: { any } } } = {}
T.scheduled = scheduled
task = {
	delay = function(t: number, fn: (...any) -> (), ...): any
		table.insert(scheduled, { t = t, fn = fn, args = { ... } })
		return {}
	end,
	spawn = function(fn: (...any) -> (), ...): any
		fn(...)
		return {}
	end,
	defer = function(fn: (...any) -> (), ...): any
		fn(...)
		return {}
	end,
	wait = function(t: number?): number
		return t or 0
	end,
	cancel = function(_: any) end,
}
function T.flushDelays()
	local pending = scheduled
	scheduled = {}
	T.scheduled = scheduled
	task.delay = function(t: number, fn: (...any) -> (), ...): any
		table.insert(scheduled, { t = t, fn = fn, args = { ... } })
		return {}
	end
	for _, c in pending do
		c.fn(table.unpack(c.args))
	end
end
function T.clearDelays()
	for i = #scheduled, 1, -1 do
		scheduled[i] = nil
	end
end

-- ── Enum shim (returns a named stub for any Enum.Type.Member access) ─────────
local function enumType()
	return setmetatable({}, {
		__index = function(_, member: string)
			return { Name = member, Value = 0 }
		end,
	})
end
Enum = setmetatable({}, { __index = function()
	return enumType()
end })

-- ── game / services shim ────────────────────────────────────────────────────
local serde = require("@lune/serde")

T.isStudio = true
T.httpPosts = {} :: { { url: string, body: string } }

local function makeSignal()
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_, fn: (...any) -> ())
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end
T.makeSignal = makeSignal

local HttpService = {
	JSONEncode = function(_, value: any): string
		return serde.encode("json", value)
	end,
	JSONDecode = function(_, s: string): any
		return serde.decode("json", s)
	end,
	PostAsync = function(_, url: string, body: string): string
		table.insert(T.httpPosts, { url = url, body = body })
		return ""
	end,
	GenerateGUID = function(_, _wrap: boolean?): string
		return "00000000-0000-0000-0000-000000000000"
	end,
}

local RunService = {
	IsStudio = function()
		return T.isStudio
	end,
	IsServer = function()
		return true
	end,
	Heartbeat = makeSignal(),
	RenderStepped = makeSignal(),
}

local services: { [string]: any } = {
	HttpService = HttpService,
	RunService = RunService,
}

game = {
	GetService = function(_, name: string): any
		return services[name]
	end,
}
T.services = services

-- ── Matchers ────────────────────────────────────────────────────────────────
local function buildMatchers(value: any, negated: boolean)
	local function assert_(cond: boolean, message: string)
		if negated then
			cond = not cond
		end
		if not cond then
			error(message, 4)
		end
	end
	local be = {
		ok = function()
			assert_(value ~= nil, ("expected %s to be non-nil"):format(tostring(value)))
		end,
		near = function(x: number, eps: number?)
			local e = eps or 1e-6
			assert_(
				type(value) == "number" and math.abs(value - x) <= e,
				("expected %s to be near %s (±%s)"):format(tostring(value), tostring(x), tostring(e))
			)
		end,
		a = function(ty: string)
			assert_(type(value) == ty, ("expected type %s, got %s"):format(ty, type(value)))
		end,
	}
	return {
		be = be,
		equal = function(x: any)
			assert_(value == x, ("expected %s to equal %s"):format(tostring(value), tostring(x)))
		end,
		throw = function()
			assert_(type(value) == "function", "expect(fn).to.throw expects a function")
			local ok = pcall(value :: any)
			assert_(not ok, "expected function to throw")
		end,
	}
end

function T.expect(value: any)
	return {
		to = buildMatchers(value, false),
		never = { to = buildMatchers(value, true) },
	}
end

-- ── describe / it registry ──────────────────────────────────────────────────
local results = { pass = 0, fail = 0, failures = {} :: { { label: string, err: string } } }
local stack: { string } = {}

function T.describe(name: string, fn: () -> ())
	table.insert(stack, name)
	local ok, err = pcall(fn)
	table.remove(stack)
	if not ok then
		results.fail += 1
		table.insert(results.failures, { label = name .. " (describe body)", err = tostring(err) })
	end
end

function T.it(name: string, fn: () -> ())
	local label = (#stack > 0 and (table.concat(stack, " › ") .. " › ") or "") .. name
	-- Reset transient scheduler state between tests for isolation.
	T.clearDelays()
	local ok, err = pcall(fn)
	if ok then
		results.pass += 1
	else
		results.fail += 1
		table.insert(results.failures, { label = label, err = tostring(err) })
	end
end

-- Expose the TestEZ-style API as globals so spec bodies read naturally.
expect = T.expect
describe = T.describe
it = T.it

function T.run(): number
	print(string.format("\n%d passed, %d failed", results.pass, results.fail))
	if results.fail > 0 then
		print("\nFAILURES:")
		for _, f in results.failures do
			print("  ✗ " .. f.label)
			print("    " .. f.err)
		end
		return 1
	end
	print("All tests passed.")
	return 0
end

return T
