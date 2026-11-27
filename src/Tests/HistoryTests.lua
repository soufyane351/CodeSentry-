--!strict
-- History unit tests.

local Shared = script.Parent.Parent:WaitForChild("Shared")
local History = require(Shared:WaitForChild("History"))

return function(test: (string, string, () -> string?) -> ())
	test("history duplicate protection", "a second matching entry returns duplicate", function()
		local history = assert(History.new())
		local state = history:add("ALPHA BETA GAMMA", "three-word", 100)
		local duplicate, existing = history:add("ALPHA BETA GAMMA", "three-word", 101)
		assert(state == "added" and duplicate == "duplicate")
		assert(existing.lastStatus == "DUPLICATE" and existing.duplicateCount == 1)
		assert(history:count() == 1 and history:list()[1].lastSeenTimestamp == 101)
		return tostring(state) .. " / " .. tostring(duplicate) .. " / duplicate count " .. tostring(existing.duplicateCount)
	end)

	test("history stores format and timestamp", "entry retains its type and timestamp", function()
		local history = assert(History.new())
		history:add("0042", "four-digit", 123456)
		local entry = history:list()[1]
		assert(entry.code == "0042" and entry.format == "four-digit" and entry.timestamp == 123456)
		return entry.format .. " @ " .. tostring(entry.timestamp)
	end)

	test("history newest first", "newest detection is the first list entry", function()
		local history = assert(History.new())
		history:add("0001", "four-digit", 1)
		history:add("0002", "four-digit", 2)
		assert(history:list()[1].code == "0002")
		return history:list()[1].code
	end)

	test("history search", "search returns only matching codes", function()
		local history = assert(History.new())
		history:add("ALPHA BETA GAMMA", "three-word", 1)
		history:add("0042", "four-digit", 2)
		local results = history:search("alpha", "all")
		assert(#results == 1 and results[1].code == "ALPHA BETA GAMMA")
		return tostring(#results) .. " match"
	end)

	test("history format filter", "mode filter returns only matching format", function()
		local history = assert(History.new())
		history:add("ALPHA BETA GAMMA", "three-word", 1)
		history:add("0042", "four-digit", 2)
		local results = history:search("", "four-digit")
		assert(#results == 1 and results[1].code == "0042")
		return results[1].format
	end)

	test("different formats are separate keys", "same literal value can be stored under different formats", function()
		local history = assert(History.new())
		local first = history:add("ALPHA BETA GAMMA", "three-word", 1)
		local second = history:add("0042", "four-digit", 2)
		assert(first == "added" and second == "added" and history:count() == 2)
		assert(history:has("ALPHA BETA GAMMA", "three-word") and history:has("0042", "four-digit"))
		return tostring(history:count()) .. " entries across both formats"
	end)

	test("history clear", "clear removes all entries and duplicate keys", function()
		local history = assert(History.new())
		history:add("0042", "four-digit", 1)
		assert(history:clear() and history:count() == 0)
		assert(history:add("0042", "four-digit", 2) == "added")
		return "cleared and reusable"
	end)

	test("history input validation", "nil, blank and control-character codes are rejected", function()
		local history = assert(History.new())
		local a = history:add(nil, "four-digit")
		local b = history:add("", "four-digit")
		local c = history:add("A\nB", "three-word")
		assert(a == nil and b == nil and c == nil and history:count() == 0)
		return "invalid entries rejected"
	end)

	test("history format validation", "unknown format cannot be recorded", function()
		local history = assert(History.new())
		local state = history:add("CODE", "unknown")
		assert(state == nil and history:count() == 0)
		return "invalid format rejected"
	end)

	test("history capacity", "oldest entries are removed when the configured cap is reached", function()
		local history = assert(History.new(2))
		history:add("0001", "four-digit", 1)
		history:add("0002", "four-digit", 2)
		history:add("0003", "four-digit", 3)
		assert(history:count() == 2 and not history:has("0001", "four-digit"))
		return table.concat({ history:list()[1].code, history:list()[2].code }, ", ")
	end)

	test("history returns defensive copies", "mutating a returned entry does not change stored history", function()
		local history = assert(History.new())
		history:add("0042", "four-digit", 1)
		local list = history:list()
		list[1].code = "changed"
		assert(history:list()[1].code == "0042")
		assert(history:list()[1].lastStatus == "NEW")
		return history:list()[1].code
	end)
end
