--!strict
-- CodeSentry configuration. This module is safe to require on the client.

local Config = {}

Config.VERSION = "1.0.0"

Config.DEFAULTS = {
	defaultMode = "auto",
	requirePrefix = true,
	prefixes = {
		"new code:",
		"new codes:",
		"code:",
		"codes:",
		"redeem code:",
		"redeem:",
		"use code:",
	},
	maxInputLength = 12000,
	maxHistoryEntries = 200,
	theme = "dark",
}

local function copyArray(source: {any}): {any}
	local result = {}
	for index, value in ipairs(source) do
		result[index] = value
	end
	return result
end

function Config.copy(overrides: {[string]: any}?)
	local result = {}
	for key, value in pairs(Config.DEFAULTS) do
		if key == "prefixes" then
			result[key] = copyArray(value)
		else
			result[key] = value
		end
	end

	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			if key == "prefixes" and type(value) == "table" then
				result[key] = copyArray(value)
			else
				result[key] = value
			end
		end
	end
	return result
end

function Config.validate(config: any): (boolean, string?)
	if type(config) ~= "table" then
		return false, "configuration must be a table"
	end
	if config.defaultMode ~= nil and config.defaultMode ~= "3" and config.defaultMode ~= "4" and config.defaultMode ~= "auto" then
		return false, "defaultMode must be '3', '4' or 'auto'"
	end
	if config.requirePrefix ~= nil and type(config.requirePrefix) ~= "boolean" then
		return false, "requirePrefix must be a boolean"
	end
	if type(config.prefixes) ~= "table" then
		return false, "prefixes must be an array of strings"
	end
	if #config.prefixes == 0 and config.requirePrefix ~= false then
		return false, "at least one prefix is required when requirePrefix is enabled"
	end
	for index, prefix in ipairs(config.prefixes) do
		if type(prefix) ~= "string" or prefix:gsub("%s", "") == "" then
			return false, string.format("prefix %d must be a non-empty string", index)
		end
		if prefix:find("\n", 1, true) or prefix:find("\r", 1, true) then
			return false, string.format("prefix %d cannot contain a newline", index)
		end
	end
	if config.maxInputLength ~= nil then
		if type(config.maxInputLength) ~= "number" or config.maxInputLength < 1 or config.maxInputLength % 1 ~= 0 then
			return false, "maxInputLength must be a positive integer"
		end
	end
	if config.maxHistoryEntries ~= nil then
		if type(config.maxHistoryEntries) ~= "number" or config.maxHistoryEntries < 1 or config.maxHistoryEntries % 1 ~= 0 then
			return false, "maxHistoryEntries must be a positive integer"
		end
	end
	if config.theme ~= nil and config.theme ~= "dark" and config.theme ~= "light" then
		return false, "theme must be 'dark' or 'light'"
	end
	return true, nil
end

return Config
