local VisualsTab = {}

-- Requires
local Pascal = require("Modules/Helpers/Pascal")

function VisualsTab:CreateElements()
	local TabBox = self.Tab:AddLeftTabbox("ESPTabBox")
	local SubTab1 = TabBox:AddTab("Enemy")
	local SubTab2 = TabBox:AddTab("Friendly")
	local SubTab3 = TabBox:AddTab("Shared")

	SubTab1:AddToggle("EnableEnemyESP", {
		Text = "Enable ESP",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.enabled = Value
		end,
	})

	SubTab1:AddToggle("EnableBoxESP", {
		Text = "Enable Box ESP",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.box = Value
		end,
	})

	SubTab1:AddToggle("EnableHealthTextESP", {
		Text = "Enable Health Text",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.healthText = Value
		end,
	})

	SubTab1:AddToggle("EnableHealthBarESP", {
		Text = "Enable Health Bar",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.healthBar = Value
		end,
	})

	SubTab1:AddToggle("EnableNameESP", {
		Text = "Enable Name ESP",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.name = Value
		end,
	})

	SubTab1:AddToggle("EnableWeaponESP", {
		Text = "Enable Weapon ESP",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.weapon = Value
		end,
	})

	SubTab1:AddToggle("EnableDistanceESP", {
		Text = "Enable Distance ESP",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.distance = Value
		end,
	})

	SubTab2:AddToggle("EnableFriendlyESP", {
		Text = "Enable ESP",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.enabled = Value
		end,
	})

	SubTab2:AddToggle("EnableBoxESPFriendly", {
		Text = "Enable Box ESP",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.box = Value
		end,
	})

	SubTab2:AddToggle("EnableHealthTextESPFriendly", {
		Text = "Enable Health Text",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.healthText = Value
		end,
	})

	SubTab2:AddToggle("EnableHealthBarESPFriendly", {
		Text = "Enable Health Bar",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.healthBar = Value
		end,
	})

	SubTab2:AddToggle("EnableNameESPFriendly", {
		Text = "Enable Name ESP",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.name = Value
		end,
	})

	SubTab2:AddToggle("EnableWeaponESPFriendly", {
		Text = "Enable Weapon ESP",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.weapon = Value
		end,
	})

	SubTab2:AddToggle("EnableDistanceESPFriendly", {
		Text = "Enable Distance ESP",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.distance = Value
		end,
	})

	SubTab3:AddDropdown("ESPFonts", {
		Values = { "UI", "System", "Plex", "Monospace" },
		Default = 2, -- number index of the value / string
		Multi = false, -- true / false, allows multiple choices to be selected
		Text = "Font used for text",

		Callback = function(Value)
			local ESPFontTable = {
				["UI"] = 0,
				["System"] = 1,
				["Plex"] = 2,
				["Monospace"] = 3,
			}

			Pascal:GetSense().sharedSettings.textFont = ESPFontTable[Value]
		end,
	})

	SubTab3:AddSlider("TextSize", {
		Text = "Size used for text",
		Default = 13,
		Min = 0,
		Max = 50,
		Rounding = 0,
		Compact = false,

		Callback = function(Value)
			Pascal:GetSense().sharedSettings.textSize = Value
		end,
	})

	SubTab3:AddToggle("EnableLimitDistance", {
		Text = "Limit render-distance",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().sharedSettings.limitDistance = Value
		end,
	})

	SubTab3:AddSlider("LimitDistance", {
		Text = "Maximum render-distance",
		Default = 150,
		Min = 0,
		Max = 10000,
		Rounding = 0,
		Compact = false,

		Callback = function(Value)
			Pascal:GetSense().sharedSettings.maxDistance = Value
		end,
	})

	local TabBox2 = self.Tab:AddRightTabbox("MiscVisualsTabBox")
	local VisualsSubTab1 = TabBox2:AddTab("Enemy")
	local VisualsSubTab2 = TabBox2:AddTab("Friendly")
	local VisualsSubTab3 = TabBox2:AddTab("Shared")

	VisualsSubTab1:AddToggle("EnableTracerVisuals", {
		Text = "Enable Tracers",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.tracer = Value
		end,
	})

	VisualsSubTab1:AddToggle("EnableChams", {
		Text = "Enable Chams",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.chams = Value
		end,
	})

	VisualsSubTab1:AddToggle("EnableOffScreenArrows", {
		Text = "Enable Off-Screen Arrows",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.offScreenArrow = Value
		end,
	})

	VisualsSubTab2:AddToggle("EnableTracerVisualsFriendly", {
		Text = "Enable Tracers",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.tracer = Value
		end,
	})

	VisualsSubTab2:AddToggle("EnableChamsFriendly", {
		Text = "Enable Chams",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.chams = Value
		end,
	})

	VisualsSubTab2:AddToggle("EnableOffScreenArrowsFriendly", {
		Text = "Enable Off-Screen Arrows",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.offScreenArrow = Value
		end,
	})

	VisualsSubTab3:AddToggle("EnableVisibleOnlyChams", {
		Text = "Enable Visible Chams",
		Tooltip = "Chams will only show if they are visible...",
		Default = false,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.chamsVisibleOnly = Value
			Pascal:GetSense().teamSettings.enemy.chamsVisibleOnly = Value
		end,
	})

	VisualsSubTab3:AddToggle("EnableOutlinesOffScreenArrows", {
		Text = "Outlined Off-Screen Arrows",
		Default = true,
		Callback = function(Value)
			Pascal:GetSense().teamSettings.enemy.offScreenArrowOutline = Value
			Pascal:GetSense().teamSettings.friendly.offScreenArrowOutline = Value
		end,
	})

	VisualsSubTab3:AddSlider("OffScreenArrowSize", {
		Text = "Off-Screen Arrow-Size",
		Default = 15,
		Min = 0,
		Max = 50,
		Rounding = 0,
		Compact = false,

		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.offScreenArrowSize = Value
			Pascal:GetSense().teamSettings.enemy.offScreenArrowSize = Value
		end,
	})

	VisualsSubTab3:AddSlider("OffScreenArrowRadius", {
		Text = "Off-Screen Radius",
		Default = 150,
		Min = 0,
		Max = 500,
		Rounding = 0,
		Compact = false,

		Callback = function(Value)
			Pascal:GetSense().teamSettings.friendly.offScreenArrowRadius = Value
			Pascal:GetSense().teamSettings.enemy.offScreenArrowRadius = Value
		end,
	})
end

function VisualsTab:Setup(Window, Library)
	-- Setup window / tab
	self.Window = Window
	self.Tab = Window:AddTab("Visuals")

	-- Create elements
	self:CreateElements()
end

return VisualsTab
