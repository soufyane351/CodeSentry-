--!strict
-- Formatting helpers shared by UI and tests.

local Formatter = {}

function Formatter.timestamp(unixTimestamp: number?): string
	if type(unixTimestamp) ~= "number" then
		return "Timestamp unavailable"
	end
	local ok, result = pcall(function()
		return DateTime.fromUnixTimestamp(unixTimestamp):FormatLocalTime("LLL", "en-us")
	end)
	if ok then
		return result
	end
	return "Timestamp unavailable"
end

function Formatter.formatLabel(format: string?): string
	if format == "three-word" then
		return "MODE 3 · THREE WORD"
	elseif format == "four-digit" then
		return "MODE 4 · FOUR DIGIT"
	end
	return "FORMAT UNKNOWN"
end

return Formatter
