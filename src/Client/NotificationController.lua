--!strict
-- Lightweight transient notification surface. It owns and destroys each toast.

local TweenService = game:GetService("TweenService")
local ThemeController = require(script.Parent.ThemeController)

local NotificationController = {}

local function create(className: string, parent: Instance, properties: {[string]: any}): Instance
	local instance = Instance.new(className)
	for property, value in pairs(properties) do
		(instance :: any)[property] = value
	end
	instance.Parent = parent
	return instance
end

function NotificationController.show(screenGui: ScreenGui, title: string, message: string, severity: string, theme: string)
	local palette = ThemeController.getPalette(theme)
	local toast = create("Frame", screenGui, {
		Name = "CodeSentryToast",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.new(0, 300, 0, 78),
		BackgroundColor3 = palette.Surface,
		BorderSizePixel = 0,
		ZIndex = 50,
	}) :: Frame
	toast:SetAttribute("ThemeRole", "Surface")
	create("UICorner", toast, { CornerRadius = UDim.new(0, 12) })
	local stroke = create("UIStroke", toast, { Color = palette.Border, Thickness = 1 }) :: UIStroke
	stroke:SetAttribute("ThemeRole", "Border")

	local accentRole = severity == "success" and "Success" or (severity == "warning" and "Warning" or "Accent")
	local bar = create("Frame", toast, {
		Size = UDim2.new(0, 4, 1, -20),
		Position = UDim2.new(0, 10, 0, 10),
		BackgroundColor3 = palette[accentRole],
		BorderSizePixel = 0,
		ZIndex = 51,
	}) :: Frame
	bar:SetAttribute("ThemeRole", accentRole)
	create("UICorner", bar, { CornerRadius = UDim.new(1, 0) })

	local titleLabel = create("TextLabel", toast, {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 25, 0, 10),
		Size = UDim2.new(1, -38, 0, 22),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 51,
	}) :: TextLabel
	titleLabel:SetAttribute("TextRole", "Text")
	local messageLabel = create("TextLabel", toast, {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 25, 0, 32),
		Size = UDim2.new(1, -38, 0, 34),
		Font = Enum.Font.Gotham,
		Text = message,
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 51,
	}) :: TextLabel
	messageLabel:SetAttribute("TextRole", "Muted")

	toast.BackgroundTransparency = 1
	toast.Position = UDim2.new(1, 330, 0, 18)
	TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -18, 0, 18),
		BackgroundTransparency = 0,
	}):Play()

	task.delay(3.2, function()
		if not toast.Parent then
			return
		end
		local tween = TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 330, 0, 18),
			BackgroundTransparency = 1,
		})
		tween:Play()
		local completedConnection: RBXScriptConnection? = nil
		completedConnection = tween.Completed:Connect(function()
			if completedConnection then
				completedConnection:Disconnect()
			end
			if toast.Parent then
				toast:Destroy()
			end
		end)
	end)
end

return NotificationController
