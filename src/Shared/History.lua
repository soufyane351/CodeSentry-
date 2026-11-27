--!strict
-- In-memory, session-only history. No filesystem or DataStore access.

local History = {}
History.__index = History

export type Entry = {
	code: string,
	format: string,
	timestamp: number,
	lastSeenTimestamp: number,
	lastStatus: string,
	duplicateCount: number,
}

export type HistoryStore = {
	_entries: {Entry},
	_index: {[string]: Entry},
	_limit: number,
}

local VALID_FORMATS = {
	["three-word"] = true,
	["four-digit"] = true,
}

local function makeKey(code: string, format: string): string
	return format .. "\0" .. code
end

local function copyEntry(entry: Entry): Entry
	return {
		code = entry.code,
		format = entry.format,
		timestamp = entry.timestamp,
		lastSeenTimestamp = entry.lastSeenTimestamp,
		lastStatus = entry.lastStatus,
		duplicateCount = entry.duplicateCount,
	}
end

function History.new(maxEntries: number?)
	local limit = maxEntries or 200
	if type(limit) ~= "number" or limit < 1 or limit % 1 ~= 0 or limit == math.huge then
		return nil, "history limit must be a positive integer"
	end
	return setmetatable({
		_entries = {},
		_index = {},
		_limit = limit,
	}, History)
end

function History.add(self: HistoryStore, code: any, format: any, timestamp: number?): (string?, Entry | string)
	if type(code) ~= "string" or not code:match("%S") or code:match("%c") then
		return nil, "code must be a non-empty string without control characters"
	end
	if type(format) ~= "string" or not VALID_FORMATS[format] then
		return nil, "format must be 'three-word' or 'four-digit'"
	end
	if timestamp ~= nil and type(timestamp) ~= "number" then
		return nil, "timestamp must be a number"
	end
	local time = timestamp or DateTime.now().UnixTimestamp
	if time ~= time or time == math.huge or time == -math.huge then
		return nil, "timestamp must be a finite number"
	end
	local key = makeKey(code, format)
	local existing = self._index[key]
	if existing then
		existing.lastSeenTimestamp = time
		existing.lastStatus = "DUPLICATE"
		existing.duplicateCount += 1
		for index, entry in ipairs(self._entries) do
			if entry == existing then
				table.remove(self._entries, index)
				break
			end
		end
		table.insert(self._entries, 1, existing)
		return "duplicate", copyEntry(existing)
	end

	local entry: Entry = {
		code = code,
		format = format,
		timestamp = time,
		lastSeenTimestamp = time,
		lastStatus = "NEW",
		duplicateCount = 0,
	}
	table.insert(self._entries, 1, entry)
	self._index[key] = entry

	while #self._entries > self._limit do
		local removed = table.remove(self._entries)
		self._index[makeKey(removed.code, removed.format)] = nil
	end
	return "added", copyEntry(entry)
end

function History.has(self: HistoryStore, code: string, format: string): boolean
	if type(code) ~= "string" or type(format) ~= "string" then
		return false
	end
	return self._index[makeKey(code, format)] ~= nil
end

function History.count(self: HistoryStore): number
	return #self._entries
end

function History.list(self: HistoryStore): {Entry}
	local result = {}
	for index, entry in ipairs(self._entries) do
		result[index] = copyEntry(entry)
	end
	return result
end

function History.search(self: HistoryStore, query: string?, formatFilter: string?): {Entry}
	local normalizedQuery = type(query) == "string" and string.lower(query) or ""
	if type(formatFilter) ~= "string" then
		formatFilter = "all"
	end
	local results = {}
	for _, entry in ipairs(self._entries) do
		local matchesFormat = formatFilter == nil or formatFilter == "all" or entry.format == formatFilter
		local matchesQuery = normalizedQuery == "" or string.find(string.lower(entry.code), normalizedQuery, 1, true) ~= nil
		if matchesFormat and matchesQuery then
			table.insert(results, copyEntry(entry))
		end
	end
	return results
end

function History.clear(self: HistoryStore)
	self._entries = {}
	self._index = {}
	return true
end

return History
