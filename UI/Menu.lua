local Menu = {}

-- Requires
local Library = require("UI/Library/Library")

-- Tabs
local SettingsTab = require("UI/Tabs/SettingsTab")
local CombatTab = require("UI/Tabs/CombatTab")
local VisualsTab = require("UI/Tabs/VisualsTab")

function Menu:Setup()
	-- Create Window
	self.Library = Library
	self.Window = Library:CreateWindow({
		Title = "PascalCase | Deepwoken",
		Center = true,
		AutoShow = true,
	})

	-- Setup Tabs
	CombatTab:Setup(self.Window)
	VisualsTab:Setup(self.Window)
	SettingsTab:Setup(self.Window, Library)
end

function Menu:Unload()
	Library:Unload()
end

return Menu
