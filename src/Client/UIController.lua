--!strict
-- Responsive Roblox UI for CodeSentry. All detection is local text processing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local packageFolder = ReplicatedStorage:WaitForChild("CodeSentry")
local shared = packageFolder:WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local History = require(shared:WaitForChild("History"))
local Processor = require(shared:WaitForChild("Processor"))
local Formatter = require(shared:WaitForChild("Formatter"))
local ThemeController = require(script.Parent.ThemeController)
local NotificationController = require(script.Parent.NotificationController)

local UIController = {}
UIController.__index = UIController

local function make(className: string, parent: Instance, properties: {[string]: any}?, themeRole: string?, textRole: string?): Instance
	local instance = Instance.new(className)
	if properties then
		for property, value in pairs(properties) do
			(instance :: any)[property] = value
		end
	end
	if themeRole then
		instance:SetAttribute("ThemeRole", themeRole)
	end
	if textRole then
		instance:SetAttribute("TextRole", textRole)
	end
	instance.Parent = parent
	return instance
end

local function addCorner(parent: Instance, radius: number)
	make("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function addStroke(parent: Instance, themeRole: string?)
	local stroke = make("UIStroke", parent, { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, themeRole or "Border")
	return stroke
end

local function addPadding(parent: Instance, left: number, right: number, top: number, bottom: number)
	make("UIPadding", parent, {
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right),
		PaddingTop = UDim.new(0, top),
		PaddingBottom = UDim.new(0, bottom),
	})
end

local function makeLabel(parent: Instance, text: string, size: number, textRole: string?, properties: {[string]: any}?): TextLabel
	local defaults: {[string]: any} = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = text,
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
		Size = UDim2.new(1, 0, 0, 24),
	}
	if properties then
		for key, value in pairs(properties) do
			defaults[key] = value
		end
	end
	return make("TextLabel", parent, defaults, nil, textRole or "Text") :: TextLabel
end

local function makeButton(parent: Instance, text: string, themeRole: string, textRole: string?): TextButton
	local button = make("TextButton", parent, {
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(23, 30, 43),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamSemibold,
		Text = text,
		TextSize = 12,
		Size = UDim2.new(0, 120, 0, 38),
	}, themeRole, textRole or (themeRole == "Accent" and "AccentText" or "Text")) :: TextButton
	addCorner(button, 9)
	return button
end

local function makePanel(parent: Instance, name: string, height: number?): Frame
	local panel = make("Frame", parent, {
		Name = name,
		BackgroundColor3 = Color3.fromRGB(23, 30, 43),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height or 100),
		AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
	}, "Surface") :: Frame
	addCorner(panel, 13)
	addStroke(panel)
	return panel
end

local function addVerticalLayout(parent: Instance, gap: number)
	make("UIListLayout", parent, {
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
	})
end

local function trim(value: string): string
	return value:gsub("^%s+", ""):gsub("%s+$", "")
end

function UIController.new(playerGui: PlayerGui, config: {[string]: any})
	local self = setmetatable({}, UIController)
	self.playerGui = playerGui
	self.config = Config.copy(config)
	self.mode = self.config.defaultMode
	self.history = History.new(self.config.maxHistoryEntries)
	self.connections = {}
	self.pageButtons = {}
	self.pages = {}
	self.modeButtons = {}
	self.historyFilter = "all"
	self.currentPage = "dashboard"
	self.gui = nil
	self.cameraViewportConnection = nil
	self.processing = false
	self.destroyed = false
	self.refs = {}
	return self
end

function UIController:_connect(signal: RBXScriptSignal, callback: (...any) -> ())
	local connection = signal:Connect(callback)
	table.insert(self.connections, connection)
	return connection
end

function UIController:_notify(title: string, message: string, severity: string?)
	if self.gui then
		NotificationController.show(self.gui, title, message, severity or "info", self.config.theme)
	end
end

function UIController:_makeScrollPage(name: string): ScrollingFrame
	local page = make("ScrollingFrame", self.main, {
		Name = name .. "Page",
		Position = UDim2.new(0, 22, 0, 145),
		Size = UDim2.new(1, -44, 1, -166),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, nil) :: ScrollingFrame
	addPadding(page, 2, 8, 2, 12)
	addVerticalLayout(page, 12)
	self.pages[name] = page
	return page
end

function UIController:_buildShell()
	self.gui = make("ScreenGui", self.playerGui, {
		Name = "CodeSentry",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	local overlay = make("Frame", self.gui, {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.42,
		BorderSizePixel = 0,
	}, "Background") :: Frame

	self.main = make("Frame", overlay, {
		Name = "MainWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.9),
		BackgroundColor3 = Color3.fromRGB(12, 16, 25),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, "Background") :: Frame
	addCorner(self.main, 18)
	addStroke(self.main)
	make("UISizeConstraint", self.main, {
		MinSize = Vector2.new(260, 320),
		MaxSize = Vector2.new(1120, 780),
	})
	self.uiScale = make("UIScale", self.main, { Scale = 1 }) :: UIScale

	local header = make("Frame", self.main, {
		Name = "Header",
		Position = UDim2.new(0, 22, 0, 16),
		Size = UDim2.new(1, -44, 0, 62),
		BackgroundTransparency = 1,
	}, nil) :: Frame

	local logo = make("Frame", header, {
		Name = "LogoMark",
		Size = UDim2.new(0, 42, 0, 42),
		Position = UDim2.new(0, 0, 0, 8),
		BorderSizePixel = 0,
	}, "Accent") :: Frame
	addCorner(logo, 12)
	makeLabel(logo, "CS", 15, "AccentText", {
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	})
	makeLabel(header, "CodeSentry", 20, "Text", {
		Position = UDim2.new(0, 54, 0, 7),
		Size = UDim2.new(0, 210, 0, 25),
		Font = Enum.Font.GothamBold,
	})
	makeLabel(header, "SAB ANNOUNCEMENT CODE DETECTOR", 9, "Muted", {
		Position = UDim2.new(0, 55, 0, 33),
		Size = UDim2.new(0, 260, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextTransparency = 0.08,
	})
	makeLabel(header, "v" .. Config.VERSION, 10, "Muted", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 11),
		Size = UDim2.new(0, 65, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local statusDot = make("Frame", header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -76, 0, 16),
		Size = UDim2.new(0, 8, 0, 8),
		BorderSizePixel = 0,
	}, "Success") :: Frame
	addCorner(statusDot, 8)
	makeLabel(header, "READY", 9, "Muted", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -90, 0, 10),
		Size = UDim2.new(0, 52, 0, 20),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local nav = make("Frame", self.main, {
		Name = "Navigation",
		Position = UDim2.new(0, 22, 0, 91),
		Size = UDim2.new(1, -44, 0, 42),
		BackgroundTransparency = 1,
	}, nil) :: Frame
	make("UIListLayout", nav, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) :: UIListLayout

	for index, item in ipairs({
		{ id = "dashboard", label = "Dashboard" },
		{ id = "history", label = "History" },
		{ id = "settings", label = "Settings" },
	}) do
		local button = makeButton(nav, item.label, "Surface")
		button.Name = item.id .. "Tab"
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / 3, -6, 1, 0)
		self.pageButtons[item.id] = button
		self:_connect(button.Activated, function()
			self:_showPage(item.id)
		end)
	end

	self:_makeScrollPage("dashboard")
	self:_makeScrollPage("history")
	self:_makeScrollPage("settings")
end

function UIController:_buildDashboard()
	local page = self.pages.dashboard
	makeLabel(page, "Scan an announcement", 18, "Text", {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 1,
	})
	makeLabel(page, "Paste the message text below. CodeSentry only reads text you provide.", 11, "Muted", {
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 2,
	})

	local inputPanel = makePanel(page, "AnnouncementInput", 180)
	inputPanel.LayoutOrder = 3
	addPadding(inputPanel, 15, 15, 13, 13)
	makeLabel(inputPanel, "ANNOUNCEMENT TEXT", 10, "Muted", {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, 18),
	})
	local input = make("TextBox", inputPanel, {
		Name = "AnnouncementText",
		Position = UDim2.new(0, 0, 0, 27),
		Size = UDim2.new(1, 0, 0, 99),
		BackgroundColor3 = Color3.fromRGB(15, 21, 33),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		MultiLine = true,
		Text = "",
		PlaceholderText = "Example: New code: ALPHA BETA GAMMA",
		PlaceholderColor3 = Color3.fromRGB(151, 165, 187),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Font = Enum.Font.Code,
		TextEditable = true,
	}, "Input", "Text") :: TextBox
	addCorner(input, 9)
	addPadding(input, 11, 11, 10, 8)
	self.refs.input = input
	local clearInput = makeButton(inputPanel, "Clear input", "SurfaceAlt", "Muted")
	clearInput.Position = UDim2.new(1, -105, 1, -26)
	clearInput.Size = UDim2.new(0, 105, 0, 24)
	clearInput.TextSize = 10
	self:_connect(clearInput.Activated, function()
		input.Text = ""
		input:CaptureFocus()
	end)

	local modePanel = makePanel(page, "DetectionMode", 76)
	modePanel.LayoutOrder = 4
	addPadding(modePanel, 15, 15, 10, 10)
	makeLabel(modePanel, "DETECTION MODE", 10, "Muted", {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(0.35, 0, 0, 18),
	})
	local modeRow = make("Frame", modePanel, {
		Position = UDim2.new(0.37, 0, 0, 1),
		Size = UDim2.new(0.63, 0, 0, 42),
		BackgroundTransparency = 1,
	}, nil) :: Frame
	make("UIListLayout", modeRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) :: UIListLayout
	for index, mode in ipairs({ "3", "4", "auto" }) do
		local label = mode == "auto" and "AUTO" or ("MODE " .. mode)
		local button = makeButton(modeRow, label, "SurfaceAlt")
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / 3, -5, 1, 0)
		button.TextSize = 10
		self.modeButtons[mode] = button
		self:_connect(button.Activated, function()
			self:_setMode(mode)
		end)
	end

	local detect = makeButton(page, "DETECT ANNOUNCEMENT", "Accent", "AccentText")
	detect.Name = "DetectButton"
	detect.Size = UDim2.new(1, 0, 0, 48)
	detect.TextSize = 13
	detect.LayoutOrder = 5
	self.refs.detectButton = detect
	self:_connect(detect.Activated, function()
		self:_detect()
	end)

	local resultPanel = makePanel(page, "DetectionResult", 135)
	resultPanel.LayoutOrder = 6
	addPadding(resultPanel, 15, 15, 12, 12)
	local resultHeader = make("Frame", resultPanel, {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
	}, nil) :: Frame
	makeLabel(resultHeader, "LATEST RESULT", 10, "Muted", {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(0.55, 0, 1, 0),
	})
	local status = makeLabel(resultHeader, "WAITING", 9, "Muted", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 110, 1, 0),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local code = makeLabel(resultPanel, "No code detected yet", 17, "Text", {
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, 32),
		Font = Enum.Font.GothamBold,
		TextWrapped = true,
	})
	local details = makeLabel(resultPanel, "Your detection result will appear here.", 10, "Muted", {
		Position = UDim2.new(0, 0, 0, 72),
		Size = UDim2.new(1, 0, 0, 42),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	self.refs.resultStatus = status
	self.refs.resultCode = code
	self.refs.resultDetails = details
end

function UIController:_buildHistory()
	local page = self.pages.history
	makeLabel(page, "Detection history", 18, "Text", {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 1,
	})
	makeLabel(page, "Recent detections from this session appear first.", 11, "Muted", {
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 2,
	})

	local controls = makePanel(page, "HistoryControls", 112)
	controls.LayoutOrder = 3
	addPadding(controls, 12, 12, 10, 10)
	local search = make("TextBox", controls, {
		Name = "HistorySearch",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(15, 21, 33),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		PlaceholderText = "Search code history...",
		Text = "",
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, "Input", "Text") :: TextBox
	addCorner(search, 8)
	addPadding(search, 10, 10, 0, 0)
	self.refs.historySearch = search

	local filterRow = make("Frame", controls, {
		Position = UDim2.new(0, 0, 0, 44),
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
	}, nil) :: Frame
	make("UIListLayout", filterRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) :: UIListLayout
	for index, filter in ipairs({
		{ id = "all", label = "ALL" },
		{ id = "three-word", label = "MODE 3" },
		{ id = "four-digit", label = "MODE 4" },
	}) do
		local button = makeButton(filterRow, filter.label, filter.id == "all" and "Accent" or "SurfaceAlt")
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / 3, -5, 1, 0)
		button.TextSize = 9
		self:_connect(button.Activated, function()
			self.historyFilter = filter.id
			for filterId, filterButton in pairs(self.refs.filterButtons) do
				filterButton:SetAttribute("ThemeRole", filterId == self.historyFilter and "Accent" or "SurfaceAlt")
			end
			ThemeController.apply(self.gui, self.config.theme)
			self:_renderHistory()
		end)
		self.refs.filterButtons = self.refs.filterButtons or {}
		self.refs.filterButtons[filter.id] = button
	end

	local listPanel = makePanel(page, "HistoryList", 370)
	listPanel.LayoutOrder = 4
	addPadding(listPanel, 10, 10, 10, 10)
	makeLabel(listPanel, "RECENT CODES", 10, "Muted", {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, 18),
	})
	local list = make("ScrollingFrame", listPanel, {
		Name = "HistoryEntries",
		Position = UDim2.new(0, 0, 0, 26),
		Size = UDim2.new(1, 0, 1, -68),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, nil) :: ScrollingFrame
	addVerticalLayout(list, 7)
	self.refs.historyList = list
	local clear = makeButton(listPanel, "CLEAR SESSION HISTORY", "Danger", "AccentText")
	clear.Position = UDim2.new(0, 0, 1, -34)
	clear.Size = UDim2.new(1, 0, 0, 30)
	clear.TextSize = 10
	self:_connect(clear.Activated, function()
		self.history:clear()
		self:_renderHistory()
		self:_notify("History cleared", "Session detections have been cleared.", "warning")
	end)
	self:_connect(search:GetPropertyChangedSignal("Text"), function()
		self:_renderHistory()
	end)
end

function UIController:_buildSettings()
	local page = self.pages.settings
	makeLabel(page, "Settings", 18, "Text", {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 1,
	})
	makeLabel(page, "Tune how announcement text is interpreted.", 11, "Muted", {
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 2,
	})

	local prefixPanel = makePanel(page, "PrefixSettings", 190)
	prefixPanel.LayoutOrder = 3
	addPadding(prefixPanel, 14, 14, 12, 12)
	makeLabel(prefixPanel, "RECOGNIZED PREFIXES", 10, "Muted", {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, 18),
	})
	local prefixBox = make("TextBox", prefixPanel, {
		Name = "PrefixList",
		Position = UDim2.new(0, 0, 0, 26),
		Size = UDim2.new(1, 0, 0, 108),
		BackgroundColor3 = Color3.fromRGB(15, 21, 33),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		MultiLine = true,
		Text = table.concat(self.config.prefixes, "\n"),
		PlaceholderText = "One prefix per line (for example: code:)",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Code,
		TextWrapped = true,
	}, "Input", "Text") :: TextBox
	addCorner(prefixBox, 8)
	addPadding(prefixBox, 10, 10, 8, 8)
	self.refs.prefixBox = prefixBox
	local requirePrefix = makeButton(prefixPanel, "REQUIRE PREFIX: ON", "SurfaceAlt")
	requirePrefix.Position = UDim2.new(0, 0, 1, -35)
	requirePrefix.Size = UDim2.new(1, 0, 0, 28)
	requirePrefix.TextSize = 10
	self.refs.requirePrefixButton = requirePrefix
	self:_connect(requirePrefix.Activated, function()
		self.config.requirePrefix = not self.config.requirePrefix
		self:_updateSettingsLabels()
	end)

	local appearance = makePanel(page, "AppearanceSettings", 88)
	appearance.LayoutOrder = 4
	addPadding(appearance, 14, 14, 10, 10)
	makeLabel(appearance, "APPEARANCE", 10, "Muted", {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(0.4, 0, 0, 20),
	})
	local themeButton = makeButton(appearance, "THEME: DARK", "SurfaceAlt")
	themeButton.AnchorPoint = Vector2.new(1, 0)
	themeButton.Position = UDim2.new(1, 0, 0, 0)
	themeButton.Size = UDim2.new(0, 150, 0, 36)
	themeButton.TextSize = 10
	self.refs.themeButton = themeButton
	self:_connect(themeButton.Activated, function()
		self.config.theme = self.config.theme == "dark" and "light" or "dark"
		self:_applyTheme()
		self:_updateSettingsLabels()
	end)

	local actions = makePanel(page, "SettingsActions", 94)
	actions.LayoutOrder = 5
	addPadding(actions, 12, 12, 12, 12)
	local save = makeButton(actions, "SAVE SETTINGS", "Accent", "AccentText")
	save.Position = UDim2.new(0, 0, 0, 0)
	save.Size = UDim2.new(0.58, -5, 0, 38)
	self:_connect(save.Activated, function()
		self:_saveSettings()
	end)
	local reset = makeButton(actions, "RESET", "SurfaceAlt")
	reset.AnchorPoint = Vector2.new(1, 0)
	reset.Position = UDim2.new(1, 0, 0, 0)
	reset.Size = UDim2.new(0.42, -5, 0, 38)
	self:_connect(reset.Activated, function()
		self:_resetSettings()
	end)
	makeLabel(actions, "History and settings are session-only; neither persists after restart.", 9, "Muted", {
		Position = UDim2.new(0, 0, 0, 46),
		Size = UDim2.new(1, 0, 0, 22),
		TextWrapped = true,
	})
	self:_updateSettingsLabels()
end

function UIController:_applyTheme()
	if self.gui then
		ThemeController.apply(self.gui, self.config.theme)
	end
end

function UIController:_showPage(pageName: string)
	if not self.pages[pageName] then
		return
	end
	self.currentPage = pageName
	for name, page in pairs(self.pages) do
		page.Visible = name == pageName
	end
	for name, button in pairs(self.pageButtons) do
		button:SetAttribute("ThemeRole", name == pageName and "Accent" or "Surface")
	end
	self:_applyTheme()
	if pageName == "history" then
		self:_renderHistory()
	end
end

function UIController:_setMode(mode: string)
	if mode ~= "3" and mode ~= "4" and mode ~= "auto" then
		return
	end
	self.mode = mode
	for name, button in pairs(self.modeButtons) do
		button:SetAttribute("ThemeRole", name == mode and "Accent" or "SurfaceAlt")
	end
	self:_applyTheme()
end

function UIController:_showResult(result: {[string]: any})
	local status = tostring(result.status or "ERROR")
	local statusRole = "Muted"
	if status == "NEW" then
		statusRole = "Success"
	elseif status == "DUPLICATE" then
		statusRole = "Warning"
	elseif status == "ERROR" then
		statusRole = "Danger"
	end
	self.refs.resultStatus.Text = status
	local statusTextRole = statusRole == "Muted" and "Muted" or (statusRole .. "Text")
	self.refs.resultStatus:SetAttribute("TextRole", statusTextRole)
	if result.code then
		self.refs.resultCode.Text = result.code
		self.refs.resultDetails.Text = Formatter.formatLabel(result.format) .. "  ·  " .. Formatter.timestamp(result.timestamp)
	else
		self.refs.resultCode.Text = status == "IGNORED" and "No valid code found" or "Detection error"
		self.refs.resultDetails.Text = tostring(result.message or result.reason or "No additional information")
	end
	self:_applyTheme()
end

function UIController:_detect()
	if self.processing or self.destroyed then
		return
	end
	self.processing = true
	local button = self.refs.detectButton
	button.Active = false
	button.Text = "ANALYZING..."

	-- Yield once so the loading label can render before the bounded parser runs.
	task.spawn(function()
		task.wait()
		if self.destroyed or not self.gui or not self.gui.Parent then
			self.processing = false
			return
		end

		local ok, result = pcall(function()
			return Processor.process(self.refs.input.Text, self.mode, self.config, self.history)
		end)
		if not ok then
			result = {
				status = "ERROR",
				message = "Unexpected processing error: " .. tostring(result),
			}
		end

		local uiOk, uiError = pcall(function()
			self:_showResult(result)
			if result.status == "NEW" then
				self:_notify("New code detected", result.code, "success")
			elseif result.status == "DUPLICATE" then
				self:_notify("Duplicate detected", result.code .. " was already seen this session.", "warning")
			elseif result.status == "ERROR" then
				self:_notify("Detection error", tostring(result.message or result.reason), "warning")
			end
			if self.currentPage == "history" then
				self:_renderHistory()
			end
		end)
		if not uiOk then
			warn("CodeSentry UI update failed: " .. tostring(uiError))
		end
		if not self.destroyed then
			button.Text = "DETECT ANNOUNCEMENT"
			button.Active = true
		end
		self.processing = false
	end)
end

function UIController:_renderHistory()
	local list = self.refs.historyList
	if not list then
		return
	end
	for _, child in ipairs(list:GetChildren()) do
		if child:GetAttribute("HistoryRow") == true then
			child:Destroy()
		end
	end

	local entries = self.history:search(self.refs.historySearch.Text, self.historyFilter)
	if #entries == 0 then
		local empty = make("Frame", list, {
			Name = "HistoryEmpty",
			Size = UDim2.new(1, -4, 0, 76),
			BackgroundColor3 = Color3.fromRGB(31, 41, 58),
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, "SurfaceAlt") :: Frame
		empty:SetAttribute("HistoryRow", true)
		addCorner(empty, 9)
		makeLabel(empty, "No matching detections", 12, "Text", {
			Position = UDim2.new(0, 12, 0, 10),
			Size = UDim2.new(1, -24, 0, 22),
			Font = Enum.Font.GothamSemibold,
		})
		makeLabel(empty, "Codes you detect will be listed here.", 10, "Muted", {
			Position = UDim2.new(0, 12, 0, 36),
			Size = UDim2.new(1, -24, 0, 20),
		})
		self:_applyTheme()
		return
	end

	for index, entry in ipairs(entries) do
		local row = make("Frame", list, {
			Name = "HistoryRow" .. tostring(index),
			Size = UDim2.new(1, -4, 0, 66),
			BackgroundColor3 = Color3.fromRGB(31, 41, 58),
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, "SurfaceAlt") :: Frame
		row:SetAttribute("HistoryRow", true)
		addCorner(row, 9)
		makeLabel(row, entry.code, 13, "Text", {
			Position = UDim2.new(0, 12, 0, 8),
			Size = UDim2.new(1, -24, 0, 22),
			Font = Enum.Font.GothamBold,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local historyStatus = entry.lastStatus or "NEW"
		local duplicateSuffix = entry.duplicateCount > 0 and ("  ·  " .. tostring(entry.duplicateCount) .. " duplicate(s)") or ""
		makeLabel(row, Formatter.formatLabel(entry.format) .. "  ·  " .. historyStatus .. duplicateSuffix .. "  ·  " .. Formatter.timestamp(entry.lastSeenTimestamp or entry.timestamp), 9, "Muted", {
			Position = UDim2.new(0, 12, 0, 34),
			Size = UDim2.new(1, -24, 0, 18),
		})
	end
	self:_applyTheme()
end

function UIController:_updateSettingsLabels()
	if self.refs.requirePrefixButton then
		self.refs.requirePrefixButton.Text = self.config.requirePrefix and "REQUIRE PREFIX: ON" or "REQUIRE PREFIX: OFF"
	end
	if self.refs.themeButton then
		self.refs.themeButton.Text = "THEME: " .. string.upper(self.config.theme)
	end
	self:_applyTheme()
end

function UIController:_saveSettings()
	local prefixes = {}
	for line in self.refs.prefixBox.Text:gmatch("[^\r\n]+") do
		local value = trim(line)
		if value ~= "" then
			table.insert(prefixes, value)
		end
	end
	local candidate = Config.copy({
		prefixes = prefixes,
		requirePrefix = self.config.requirePrefix,
		defaultMode = self.mode,
		theme = self.config.theme,
	})
	local valid, reason = Config.validate(candidate)
	if not valid then
		self:_notify("Settings not saved", tostring(reason), "warning")
		return
	end
	self.config = candidate
	self:_notify("Settings saved", "Your detection settings are ready.", "success")
end

function UIController:_resetSettings()
	self.config = Config.copy()
	self.mode = self.config.defaultMode
	self.refs.prefixBox.Text = table.concat(self.config.prefixes, "\n")
	self:_setMode(self.mode)
	self:_updateSettingsLabels()
	self:_notify("Settings reset", "Default CodeSentry settings restored.", "success")
end

function UIController:_updateResponsiveScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local width = camera.ViewportSize.X
	self.uiScale.Scale = math.clamp(width / 950, 0.9, 1)
	if width < 520 then
		self.main.Size = UDim2.fromScale(0.97, 0.94)
	else
		self.main.Size = UDim2.fromScale(0.94, 0.9)
	end
end

function UIController:_bindCameraViewport()
	if self.cameraViewportConnection then
		self.cameraViewportConnection:Disconnect()
		self.cameraViewportConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		self.cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:_updateResponsiveScale()
		end)
	end
end

function UIController:Start()
	self:_buildShell()
	self:_buildDashboard()
	self:_buildHistory()
	self:_buildSettings()
	self:_setMode(self.mode)
	self:_showPage("dashboard")
	self:_renderHistory()
	self:_applyTheme()

	self:_bindCameraViewport()
	self:_connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
		self:_bindCameraViewport()
		self:_updateResponsiveScale()
	end)
	self:_updateResponsiveScale()
end

function UIController:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.cameraViewportConnection then
		self.cameraViewportConnection:Disconnect()
		self.cameraViewportConnection = nil
	end
	for _, connection in ipairs(self.connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(self.connections)
	if self.gui and self.gui.Parent then
		self.gui:Destroy()
	end
	self.gui = nil
end

return UIController
