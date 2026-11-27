--!strict
-- Centralized palette application. UI instances declare ThemeRole/TextRole attributes.

local ThemeController = {}

local PALETTES = {
	dark = {
		Background = Color3.fromRGB(12, 16, 25),
		Surface = Color3.fromRGB(23, 30, 43),
		SurfaceAlt = Color3.fromRGB(31, 41, 58),
		Input = Color3.fromRGB(15, 21, 33),
		Border = Color3.fromRGB(53, 66, 88),
		Text = Color3.fromRGB(237, 243, 252),
		Muted = Color3.fromRGB(151, 165, 187),
		Accent = Color3.fromRGB(76, 132, 255),
		AccentText = Color3.fromRGB(255, 255, 255),
		Success = Color3.fromRGB(28, 115, 84),
		Warning = Color3.fromRGB(145, 100, 31),
		Danger = Color3.fromRGB(147, 57, 67),
		SuccessText = Color3.fromRGB(109, 224, 177),
		WarningText = Color3.fromRGB(240, 191, 105),
		DangerText = Color3.fromRGB(255, 137, 150),
	},
	light = {
		Background = Color3.fromRGB(239, 243, 250),
		Surface = Color3.fromRGB(255, 255, 255),
		SurfaceAlt = Color3.fromRGB(229, 235, 245),
		Input = Color3.fromRGB(246, 248, 252),
		Border = Color3.fromRGB(203, 212, 226),
		Text = Color3.fromRGB(29, 39, 57),
		Muted = Color3.fromRGB(101, 115, 138),
		Accent = Color3.fromRGB(47, 104, 224),
		AccentText = Color3.fromRGB(255, 255, 255),
		Success = Color3.fromRGB(183, 231, 210),
		Warning = Color3.fromRGB(250, 225, 174),
		Danger = Color3.fromRGB(248, 205, 209),
		SuccessText = Color3.fromRGB(24, 118, 79),
		WarningText = Color3.fromRGB(142, 91, 19),
		DangerText = Color3.fromRGB(164, 45, 58),
	},
}

function ThemeController.apply(root: Instance, themeName: string)
	local palette = PALETTES[themeName] or PALETTES.dark
	local function applyInstance(instance: Instance)
		local role = instance:GetAttribute("ThemeRole")
		local textRole = instance:GetAttribute("TextRole")
		if role and palette[role] then
			if instance:IsA("GuiObject") then
				instance.BackgroundColor3 = palette[role]
			elseif instance:IsA("UIStroke") then
				instance.Color = palette[role]
			end
		end
		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
			local selectedTextRole = textRole or "Text"
			instance.TextColor3 = palette[selectedTextRole] or palette.Text
		end
		if instance:IsA("TextBox") then
			instance.PlaceholderColor3 = palette.Muted
		end
	end
	applyInstance(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		applyInstance(descendant)
	end
end

function ThemeController.getPalette(themeName: string)
	return PALETTES[themeName] or PALETTES.dark
end

return ThemeController
