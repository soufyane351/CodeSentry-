--!strict
-- Pure announcement parser. It never interacts with Roblox game state.

local Detector = {}

export type DetectionResult = {
	ok: boolean,
	code: string?,
	mode: string?,
	format: string?,
	reason: string?,
	message: string?,
}

local FORMATS = {
	["3"] = "three-word",
	["4"] = "four-digit",
}

local VALID_MODES = {
	["3"] = true,
	["4"] = true,
	auto = true,
}

local MESSAGES = {
	invalid_input = "input must be a string",
	empty_input = "input is empty",
	input_too_large = "input exceeds the configured size limit",
	invalid_config = "configuration is invalid",
	invalid_mode = "mode must be 3, 4 or auto",
	no_prefix = "no recognized announcement prefix found",
	no_code = "no code was found after the prefix",
	ambiguous_announcement = "multiple code announcements were found; process them separately",
	invalid_word_count = "a three-word code must contain exactly three words",
	invalid_words = "code words may contain ASCII letters, internal apostrophes or internal hyphens only",
	no_digits = "no four-digit code candidate was found after the prefix",
	invalid_digit_count = "a numeric code candidate must contain exactly four digits",
	invalid_digits = "a numeric code candidate cannot contain letters or other characters",
}

local function fail(reason: string, detail: string?): DetectionResult
	local message = MESSAGES[reason] or reason
	if detail and detail ~= "" then
		message ..= " (" .. detail .. ")"
	end
	return {
		ok = false,
		reason = reason,
		message = message,
	}
end

local function succeed(code: string, mode: string): DetectionResult
	return {
		ok = true,
		code = code,
		mode = mode,
		format = FORMATS[mode],
	}
end

function Detector.isValidMode(mode: any): boolean
	if type(mode) ~= "string" and type(mode) ~= "number" then
		return false
	end
	return VALID_MODES[string.lower(tostring(mode))] == true
end

local function normalizeText(text: string): string
	local normalized = text:gsub("\r\n", "\n"):gsub("\r", "\n")
	normalized = normalized:gsub("\194\160", " ")
	normalized = normalized:gsub("[ \t\f\v]+", " ")
	return normalized
end

local function normalizePrefix(prefix: string): string
	return string.lower(prefix):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function compilePrefixes(config: any): ({any}?, string?)
	if type(config) ~= "table" then
		return nil, "configuration must be a table"
	end
	if config.requirePrefix ~= nil and type(config.requirePrefix) ~= "boolean" then
		return nil, "requirePrefix must be a boolean"
	end
	if type(config.prefixes) ~= "table" then
		return nil, "prefixes must be an array of strings"
	end

	local compiled = {}
	for index, rawPrefix in ipairs(config.prefixes) do
		if type(rawPrefix) ~= "string" then
			return nil, string.format("prefix %d is not a string", index)
		end
		if rawPrefix:find("[\r\n]") then
			return nil, string.format("prefix %d contains a newline", index)
		end
		local prefix = normalizePrefix(rawPrefix)
		if prefix == "" then
			return nil, string.format("prefix %d is empty", index)
		end
		table.insert(compiled, prefix)
	end
	if #compiled == 0 and config.requirePrefix ~= false then
		return nil, "at least one prefix is required"
	end
	table.sort(compiled, function(left, right)
		return #left > #right
	end)
	return compiled, nil
end

local function isWordCharacter(character: string): boolean
	return character ~= "" and character:match("^[%w_]$") ~= nil
end

type PrefixMatch = {
	startIndex: number,
	endIndex: number,
	prefix: string,
}

local function findPrefixMatches(text: string, prefixes: {any}): {PrefixMatch}
	local lowerText = string.lower(text)
	local matches: {PrefixMatch} = {}
	local seen = {}

	for _, prefix in ipairs(prefixes) do
		local fromIndex = 1
		while true do
			local startIndex, endIndex = lowerText:find(prefix, fromIndex, true)
			if not startIndex then
				break
			end
			local previous = startIndex > 1 and lowerText:sub(startIndex - 1, startIndex - 1) or ""
			local following = lowerText:sub(endIndex + 1, endIndex + 1)
			local validBoundary = not isWordCharacter(previous)
			if validBoundary and isWordCharacter(prefix:sub(-1)) and isWordCharacter(following) then
				validBoundary = false
			end
			local key = tostring(startIndex) .. ":" .. tostring(endIndex)
			local coveredByLongerPrefix = false
			for _, existing in ipairs(matches) do
				if existing.startIndex <= startIndex and existing.endIndex >= endIndex then
					coveredByLongerPrefix = true
					break
				end
			end
			if validBoundary and not seen[key] and not coveredByLongerPrefix then
				seen[key] = true
				table.insert(matches, {
					startIndex = startIndex,
					endIndex = endIndex,
					prefix = prefix,
				})
			end
			fromIndex = startIndex + 1
		end
	end

	table.sort(matches, function(left, right)
		if left.startIndex == right.startIndex then
			return left.endIndex > right.endIndex
		end
		return left.startIndex < right.startIndex
	end)
	return matches
end

local function segmentAfterPrefix(text: string, endIndex: number): string
	local remainder = text:sub(endIndex + 1)
	local line = remainder:match("^[^\n]*") or ""
	return line:match("^[^%.!%?;,]*") or line
end

local function cleanToken(token: string): string
	-- Markdown emphasis/backtick wrappers are formatting, not code characters.
	while token:sub(1, 1) == "*" or token:sub(1, 1) == "_" or token:sub(1, 1) == "`" do
		token = token:sub(2)
	end
	while token:sub(-1) == "*" or token:sub(-1) == "_" or token:sub(-1) == "`" do
		token = token:sub(1, -2)
	end
	return token
end

local function tokenize(segment: string): {string}
	-- In Markdown such as **Code:** ALPHA BETA GAMMA, the closing bold
	-- marker belongs to the prefix label and appears immediately before the code.
	segment = segment:gsub("^%s*%*%*%s+", "")
	local tokens = {}
	for rawToken in segment:gmatch("%S+") do
		-- Keep an empty cleaned token: a standalone decoration token is malformed,
		-- not something that should silently disappear from the word count.
		table.insert(tokens, cleanToken(rawToken))
	end
	return tokens
end

local function isValidWord(word: string): boolean
	local length = #word
	if length == 0 or not word:sub(1, 1):match("^[A-Za-z]$") or not word:sub(-1):match("^[A-Za-z]$") then
		return false
	end
	local previousWasSeparator = false
	for index = 1, length do
		local character = word:sub(index, index)
		local isLetter = character:match("^[A-Za-z]$") ~= nil
		local isSeparator = character == "'" or character == "-"
		if not isLetter and not isSeparator then
			return false
		end
		if isSeparator then
			if index == 1 or index == length or previousWasSeparator then
				return false
			end
		end
		previousWasSeparator = isSeparator
	end
	return true
end

local function parseThree(tokens: {string}): DetectionResult
	if #tokens ~= 3 then
		return fail("invalid_word_count", string.format("found %d", #tokens))
	end
	local normalized = {}
	for index, token in ipairs(tokens) do
		if not isValidWord(token) then
			return fail("invalid_words", string.format("token %d: %s", index, token))
		end
		normalized[index] = string.upper(token)
	end
	return succeed(table.concat(normalized, " "), "3")
end

local function parseFour(tokens: {string}): DetectionResult
	if #tokens == 0 then
		return fail("no_digits")
	end
	local candidate = tokens[1]
	if candidate:match("^%d+$") then
		if #candidate ~= 4 then
			return fail("invalid_digit_count", string.format("found %d digits", #candidate))
		end
		return succeed(candidate, "4")
	end
	if candidate:find("%d") then
		return fail("invalid_digits", candidate)
	end
	return fail("no_digits")
end

local function parseAuto(tokens: {string}): DetectionResult
	-- Both parsers are attempted. A successful four-digit result takes priority;
	-- otherwise a valid three-word result wins, then the most specific failure.
	local fourDigitResult = parseFour(tokens)
	if fourDigitResult.ok then
		return fourDigitResult
	end
	local threeWordResult = parseThree(tokens)
	if threeWordResult.ok then
		return threeWordResult
	end
	if fourDigitResult.reason == "invalid_digit_count" or fourDigitResult.reason == "invalid_digits" then
		return fourDigitResult
	end
	return threeWordResult
end

local function parseBare(text: string, mode: string): DetectionResult
	local tokens = tokenize(text)
	if mode == "3" then
		return parseThree(tokens)
	elseif mode == "4" then
		return parseFour(tokens)
	end
	return parseAuto(tokens)
end

local function parseWithPrefix(text: string, mode: string): DetectionResult
	local tokens = tokenize(text)
	if mode == "3" then
		return parseThree(tokens)
	elseif mode == "4" then
		return parseFour(tokens)
	end
	return parseAuto(tokens)
end

function Detector.detect(text: any, mode: any?, config: any?): DetectionResult
	if type(text) ~= "string" then
		return fail("invalid_input", "received " .. typeof(text))
	end
	if text == "" or text:match("^%s*$") then
		return fail("empty_input")
	end

	local activeConfig = config
	if activeConfig == nil then
		activeConfig = require(script.Parent.Config).copy()
	end
	local prefixes, configError = compilePrefixes(activeConfig)
	if not prefixes then
		return fail("invalid_config", configError)
	end

	local maxLength = activeConfig.maxInputLength
	if maxLength == nil then
		maxLength = 12000
	end
	if type(maxLength) ~= "number" or maxLength < 1 or maxLength % 1 ~= 0 then
		return fail("invalid_config", "maxInputLength must be a positive integer")
	end
	if #text > maxLength then
		return fail("input_too_large", string.format("limit %d characters", maxLength))
	end

	local selectedMode = mode
	if selectedMode == nil then
		selectedMode = activeConfig.defaultMode or "auto"
	end
	if type(selectedMode) ~= "string" and type(selectedMode) ~= "number" then
		return fail("invalid_mode")
	end
	selectedMode = string.lower(tostring(selectedMode))
	if not VALID_MODES[selectedMode] then
		return fail("invalid_mode", tostring(selectedMode))
	end

	local normalized = normalizeText(text)
	local matches = findPrefixMatches(normalized, prefixes)
	if #matches > 1 then
		return fail("ambiguous_announcement", string.format("found %d prefixes", #matches))
	end
	if #matches == 0 then
		if activeConfig.requirePrefix ~= false then
			return fail("no_prefix")
		end
		if selectedMode == "auto" then
			return parseBare(normalized, "auto")
		end
		return parseBare(normalized, selectedMode)
	end

	local candidateText = segmentAfterPrefix(normalized, matches[1].endIndex)
	if candidateText:match("^%s*$") then
		if selectedMode == "3" then
			return fail("invalid_word_count", "found 0")
		end
		return fail("no_digits")
	end

	if selectedMode == "3" then
		return parseWithPrefix(candidateText, "3")
	elseif selectedMode == "4" then
		return parseWithPrefix(candidateText, "4")
	end

	local tokens = tokenize(candidateText)
	if #tokens == 0 then
		return fail("no_code")
	end
	return parseAuto(tokens)
end

return Detector
