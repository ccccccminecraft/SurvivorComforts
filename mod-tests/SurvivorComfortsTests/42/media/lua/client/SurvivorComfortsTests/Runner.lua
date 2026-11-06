-- Survivor Comforts tests: registering and running tests (docs/testing.md).
--
--   local T = SurvivorComfortsTests
--   T.add("Search: parse splits on spaces", function(t)
--       t:equal(#SurvivorComforts.search.parse("saw  logs"), 2)
--   end)
--
-- Tests run one at a time, one per tick, in name order. A test passes when
-- it returns without failing a check. A failed check does not stop the test
-- (it returns false, so the test can return early): in debug mode the game
-- stops on every Lua error, even one caught by pcall, and shows its error
-- screen, so the checks never raise one. One that has to wait (for a server
-- answer, say) calls t:waitFor(check, timeoutMs, after): it passes once check
-- returns true and after (if any) runs without failing, and fails when the
-- time is up. Results go to the "Survivor Comforts" tab of the debug menu's
-- unit tests (Panel.lua) and to console.txt:
--   [SurvivorComfortsTests] PASS <name> (<ms> ms)
--   [SurvivorComfortsTests] FAIL <name>: <reason>
--   [SurvivorComfortsTests] SKIP <name>: <reason>
--   [SurvivorComfortsTests] done: <n> passed, <n> failed, <n> skipped
--
-- A test that cannot run in this kind of game (single player or
-- multiplayer) calls `return t:skip("single player only")`; it is neither
-- passed nor failed.
--
-- No Japanese in this file: the game's Lua breaks Japanese written straight
-- into the source (see Search.lua in the mod).

SurvivorComfortsTests = SurvivorComfortsTests or {}
local T = SurvivorComfortsTests

local LOG = "[SurvivorComfortsTests] "
local DEFAULT_TIMEOUT_MS = 5000

local tests = {}   -- [name] = fn(t)
T.results = {}     -- [name] = { status = "running" | "pass" | "fail" | "skip", message, ms }
T.listeners = {}   -- called after every change of a result

function T.add(name, fn)
    if tests[name] then
        print(LOG .. "a test is added twice: " .. name)
    end
    tests[name] = fn
end

function T.names()
    local names = {}
    for name in pairs(tests) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

local function notify()
    for _, fn in ipairs(T.listeners) do
        pcall(fn)
    end
end

---------------------------------------------------------------------------
-- Checks (t:equal, t:ok, t:fail, t:waitFor)
---------------------------------------------------------------------------
local Context = {}
Context.__index = Context

local function show(value)
    if type(value) == "string" then return "\"" .. value .. "\"" end
    return tostring(value)
end

-- The first failure is the one reported. Returns false, for `return t:fail(...)`.
function Context:fail(message)
    if not self.failure then
        self.failure = message or "failed"
    end
    return false
end

-- Each check returns whether it held: `if not t:ok(x, "...") then return end`.
function Context:ok(value, message)
    if not value then
        return self:fail(message or ("expected a true value, got " .. show(value)))
    end
    return true
end

function Context:equal(actual, expected, message)
    if actual ~= expected then
        local prefix = message and (message .. ": ") or ""
        return self:fail(prefix .. "expected " .. show(expected) .. ", got " .. show(actual))
    end
    return true
end

-- The test does not apply to this game (single player or multiplayer): it
-- ends as skipped, unless a check already failed. Returns false, for
-- `return t:skip(...)`.
function Context:skip(reason)
    self.skipped = reason or "skipped"
    return false
end

-- fn() runs when the test ends, passed or not (newest first): for putting
-- back options, items and data the test changed.
function Context:cleanup(fn)
    self.cleanups = self.cleanups or {}
    table.insert(self.cleanups, fn)
end

-- check() is called every tick until it returns true; then after(t) runs.
-- after may wait again. Past timeoutMs the test fails.
function Context:waitFor(check, timeoutMs, after)
    self.waiting = {
        check = check,
        deadline = getTimestampMs() + (timeoutMs or DEFAULT_TIMEOUT_MS),
        after = after,
    }
end

local function errorText(err)
    return tostring(err)
end

---------------------------------------------------------------------------
-- Running
---------------------------------------------------------------------------
local queue = nil    -- names still to run, or nil when nothing runs
local current = nil  -- { name, context, started }
local passed, failed, skipped = 0, 0, 0

local function finish(status, message)
    local cleanups = current.context.cleanups or {}
    for i = #cleanups, 1, -1 do
        local ok, err = pcall(cleanups[i])
        if not ok and status == "pass" then
            status, message = "fail", "cleanup failed: " .. errorText(err)
        end
    end
    local ms = getTimestampMs() - current.started
    T.results[current.name] = { status = status, message = message, ms = ms }
    if status == "pass" then
        passed = passed + 1
        print(LOG .. "PASS " .. current.name .. " (" .. ms .. " ms)")
    elseif status == "skip" then
        skipped = skipped + 1
        print(LOG .. "SKIP " .. current.name .. ": " .. tostring(message))
    else
        failed = failed + 1
        print(LOG .. "FAIL " .. current.name .. ": " .. tostring(message))
    end
    current = nil
    notify()
end

local function start(name)
    local context = setmetatable({ name = name }, Context)
    current = { name = name, context = context, started = getTimestampMs() }
    T.results[name] = { status = "running" }
    notify()
    local fn = tests[name]
    if not fn then
        finish("fail", "no such test")
        return
    end
    local ok, err = pcall(fn, context)
    if not ok then
        finish("fail", errorText(err))
    elseif context.failure then
        finish("fail", context.failure)
    elseif context.skipped then
        finish("skip", context.skipped)
    elseif not context.waiting then
        finish("pass")
    end
end

local function poll()
    local context = current.context
    local waiting = context.waiting
    local ok, done = pcall(waiting.check)
    if not ok then
        finish("fail", errorText(done))
    elseif done then
        context.waiting = nil
        if waiting.after then
            local afterOk, err = pcall(waiting.after, context)
            if not afterOk then
                finish("fail", errorText(err))
                return
            end
            if context.failure then
                finish("fail", context.failure)
                return
            end
            if context.skipped then
                finish("skip", context.skipped)
                return
            end
            if context.waiting then return end
        end
        finish("pass")
    elseif getTimestampMs() > waiting.deadline then
        finish("fail", "timed out")
    end
end

local onTick

local function done()
    queue = nil
    Events.OnTick.Remove(onTick)
    print(LOG .. "done: " .. passed .. " passed, " .. failed .. " failed, " .. skipped .. " skipped")
    notify()
end

onTick = function()
    if current then
        if current.context.waiting then poll() end
        return
    end
    if queue and #queue > 0 then
        start(table.remove(queue, 1))
    elseif queue then
        done()
    end
end

-- Starts the given tests; false when tests are already running.
function T.run(names)
    if queue then return false end
    queue = {}
    for _, name in ipairs(names) do
        table.insert(queue, name)
        T.results[name] = nil
    end
    passed, failed, skipped = 0, 0, 0
    print(LOG .. "running " .. #queue .. " test(s)")
    Events.OnTick.Add(onTick)
    notify()
    return true
end

function T.runAll()
    return T.run(T.names())
end

function T.runOne(name)
    return T.run({ name })
end

-- The test that is waiting fails; the rest are not run.
function T.stop()
    if not queue then return end
    queue = {}
    if current then finish("fail", "stopped") end
end

function T.isRunning()
    return queue ~= nil
end

-- passed, failed, skipped in the last run.
function T.counts()
    return passed, failed, skipped
end
