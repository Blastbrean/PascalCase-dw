local CombatTab = {}

-- Requires
local Pascal = require("Modules/Helpers/Pascal")

-- Services
local HttpService = GetService("HttpService")

-- Configuration system for combat (this code is horrible, but i don't care enough right now. it works then it works.)
function CombatTab:LoadLinoriaConfigFromName(Name)
	if not isfile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/" .. Name .. ".export") then
		Library:Notify(
			string.format("Unable to load linoria-config %s, file does not exist! (make sure it is .export)", Name),
			2.0
		)
		return
	end

	local JSONData = readfile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/" .. Name .. ".export")
	if not JSONData then
		Library:Notify(string.format("Unable to load linoria-config %s, failed to read file!", Name), 2.0)
		return
	end

	local ConfigData = HttpService:JSONDecode(JSONData)
	if not ConfigData then
		Library:Notify(string.format("Unable to load linoria-config %s, data may be corrupted!", Name), 2.0)
		return
	end

	for AnimationId, AnimationData in next, ConfigData do
		Pascal:GetConfig().AutoParryBuilder["Animation"].BuilderSettingsList[AnimationId] = {
			Identifier = string.format("%s | %s", AnimationData.Name, AnimationId),
			Type = "Animation",
			NickName = AnimationData.Name,
			AnimationId = AnimationId,
			MinimumDistance = 0.0,
			MaximumDistance = AnimationData.Range,
			AttemptDelay = AnimationData.Wait,
			ShouldRoll = AnimationData.Roll,
			ShouldBlock = AnimationData.Hold,
			ParryRepeat = AnimationData.RepeatParryAmount >= 0,
			ParryRepeatTimes = AnimationData.RepeatParryAmount,
			ParryRepeatDelay = AnimationData.RepeatParryDelay,
			ParryRepeatAnimationEnds = false,
			DelayUntilInRange = AnimationData.DelayDistance and AnimationData.DelayDistance > 0 or false,
			ActivateOnEnd = false,
		}
	end

	Pascal:GetConfig().AutoParryBuilder["Sound"].BuilderSettingsList = {}
	Pascal:GetConfig().AutoParryBuilder["Part"].BuilderSettingsList = {}
	Library:Notify(string.format("Successfully linoria-config config %s", Name), 2.0)
end

function CombatTab:LoadConfigurationFromName(Name)
	if not isfile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/" .. Name .. ".json") then
		Library:Notify(string.format("Unable to load config %s, file does not exist!", Name), 2.0)
		return
	end

	local JSONData = readfile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/" .. Name .. ".json")
	if not JSONData then
		Library:Notify(string.format("Unable to load config %s, failed to read file!", Name), 2.0)
		return
	end

	local ConfigData = HttpService:JSONDecode(JSONData)
	if
		not ConfigData
		or (not ConfigData.BuilderSettingsListAnimation and not ConfigData.BuilderSettingsListSound and not ConfigData.BuilderSettingsListPart)
		or not ConfigData.BlacklistedIdList
	then
		Library:Notify(string.format("Unable to load config %s, data may be corrupted!", Name), 2.0)
		return
	end

	Pascal:GetConfig().AutoParryBuilder["Animation"].BuilderSettingsList = ConfigData.BuilderSettingsListAnimation or {}
	Pascal:GetConfig().AutoParryBuilder["Sound"].BuilderSettingsList = ConfigData.BuilderSettingsListSound or {}
	Pascal:GetConfig().AutoParryBuilder["Part"].BuilderSettingsList = ConfigData.BuilderSettingsListPart or {}
	Pascal:GetConfig().AutoParryLogging.BlacklistedIdentifiers = ConfigData.BlacklistedIdList

	Library:Notify(string.format("Successfully loaded config %s", Name), 2.0)
end

function CombatTab:CreateConfigurationWithName(Name)
	if typeof(Name) ~= "string" then
		Library:Notify(string.format("Unable to create config, name is invalid!"), 2.0)
		return
	end

	if isfile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/" .. Name .. ".json") then
		Library:Notify(string.format("Unable to create config, config already exists!"), 2.0)
		return
	end

	local ConfigData = {
		BuilderSettingsList = Pascal:GetConfig().AutoParryBuilder.BuilderSettingsList,
		BlacklistedIdList = Pascal:GetConfig().AutoParryLogging.BlacklistedIdentifiers,
	}

	local JSONData = HttpService:JSONEncode(ConfigData)
	writefile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/" .. Name .. ".json", JSONData)
	Library:Notify(string.format("Successfully created config %s", Name), 2.0)
end

function CombatTab:SaveConfigurationWithName(Name)
	if typeof(Name) ~= "string" then
		Library:Notify(string.format("Unable to save config, name is invalid!"), 2.0)
		return
	end

	local ConfigData = {
		BuilderSettingsListAnimation = Pascal:GetConfig().AutoParryBuilder["Animation"].BuilderSettingsList,
		BuilderSettingsListSound = Pascal:GetConfig().AutoParryBuilder["Sound"].BuilderSettingsList,
		BuilderSettingsListPart = Pascal:GetConfig().AutoParryBuilder["Part"].BuilderSettingsList,
		BlacklistedIdList = Pascal:GetConfig().AutoParryLogging.BlacklistedIdentifiers,
	}

	local JSONData = HttpService:JSONEncode(ConfigData)
	writefile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/" .. Name .. ".json", JSONData)
	Library:Notify(string.format("Successfully saved config %s", Name), 2.0)
end

function CombatTab:SetDefaultConfig(Name)
	if not isfile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/" .. Name .. ".json") then
		Library:Notify(string.format("Unable to set default config %s, file does not exist!", Name), 2.0)
		return
	end

	writefile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/Autoload.json", Name)
	Library:Notify(string.format("Config %s will auto-load on start-up!", Name), 2.0)
end

function CombatTab:LoadDefaultConfig()
	if not isfile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/Autoload.json") then
		return
	end

	local ConfigToAutoload = readfile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/Autoload.json")
	if not ConfigToAutoload then
		return
	end

	if not isfile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/" .. ConfigToAutoload .. ".json") then
		return
	end

	local JSONData = readfile(Pascal:GetConfigurationPath() .. "/CombatConfigurations/" .. ConfigToAutoload .. ".json")
	if not JSONData then
		return
	end

	local ConfigData = HttpService:JSONDecode(JSONData)
	if
		not ConfigData
		or (not ConfigData.BuilderSettingsListAnimation and not ConfigData.BuilderSettingsListSound and not ConfigData.BuilderSettingsListPart)
		or not ConfigData.BlacklistedIdList
	then
		Library:Notify(string.format("Unable to auto-load config, data may be corrupted!"), 2.0)
		return
	end

	Pascal:GetConfig().AutoParryBuilder["Animation"].BuilderSettingsList = ConfigData.BuilderSettingsListAnimation or {}
	Pascal:GetConfig().AutoParryBuilder["Sound"].BuilderSettingsList = ConfigData.BuilderSettingsListSound or {}
	Pascal:GetConfig().AutoParryBuilder["Part"].BuilderSettingsList = ConfigData.BuilderSettingsListPart or {}
	Pascal:GetConfig().AutoParryLogging.BlacklistedIdentifiers = ConfigData.BlacklistedIdList

	if not getgenv().PascalGhostMode then
		Library:Notify(string.format('Auto loaded combat config "%s"', ConfigToAutoload), 2.0)
	end
end

function CombatTab:GetConfigurationList()
	if not isfolder(Pascal:GetConfigurationPath() .. "/CombatConfigurations") then
		makefolder(Pascal:GetConfigurationPath() .. "/CombatConfigurations")
	end

	local list = listfiles(Pascal:GetConfigurationPath() .. "/CombatConfigurations")

	-- this part is pasted from SaveManager.lua
	local out = {}
	for i = 1, #list do
		local file = list[i]
		if file:sub(-5) == ".json" then
			-- i hate this but it has to be done ...

			local pos = file:find(".json", 1, true)
			local start = pos

			local char = file:sub(pos, pos)
			while char ~= "/" and char ~= "\\" and char ~= "" do
				pos = pos - 1
				char = file:sub(pos, pos)
			end

			if char == "/" or char == "\\" then
				local filename = file:sub(pos + 1, start - 1)
				if filename ~= "Autoload" then
					table.insert(out, filename)
				end
			end
		end

		if file:sub(-8) == ".export" then
			local pos = file:find(".export", 1, true)
			local start = pos

			local char = file:sub(pos, pos)
			while char ~= "/" and char ~= "\\" and char ~= "" do
				pos = pos - 1
				char = file:sub(pos, pos)
			end

			if char == "/" or char == "\\" then
				local filename = file:sub(pos + 1, start - 1)
				table.insert(out, filename)
			end
		end
	end

	return out
end

function CombatTab:AutoParryBuilderGroup()
	local TabBox = self.Tab:AddLeftTabbox("AutoParryBuilder")
	local SubTab1 = TabBox:AddTab("Animation")

	SubTab1:AddInput("AnimationNickNameInput", {
		Numeric = false,
		Finished = false,
		Text = "Animation Nickname",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.NickName = Value
		end,
	})

	SubTab1:AddInput("AnimationIdInput", {
		Numeric = false,
		Finished = false,
		Text = "Animation ID",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.AnimationId = Value
		end,
	})

	SubTab1:AddSlider("MinimumDistanceSlider", {
		Text = "Minimum distance to activate",
		Default = 5,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.MinimumDistance = Value
		end,
	})

	SubTab1:AddSlider("MaximumDistanceSlider", {
		Text = "Maximum distance to activate",
		Default = 15,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.MaximumDistance = Value
		end,
	})

	SubTab1:AddInput("AttemptDelayInput", {
		Numeric = true,
		Finished = false,
		Text = "Delay until attempt (ms)",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.AttemptDelay = Value
		end,
	})

	SubTab1:AddToggle("RollInsteadOfParryToggle", {
		Text = "Roll instead of parry",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.ShouldRoll = Value
		end,
	})

	SubTab1:AddToggle("BlockInsteadOfParryToggle", {
		Text = "Block until ending",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.ShouldBlock = Value
		end,
	})

	SubTab1:AddToggle("ActivateOnEnd", {
		Text = "Only activate on end",
		Tooltip = "Misleading, as this will simply run auto-parry at the end of an animation (including delay), if you want to only activate on end, run with no delay.",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.ActivateOnEnd = Value
		end,
	})

	SubTab1:AddToggle("DelayUntilInRange", {
		Text = "Delay until in range",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.DelayUntilInRange = Value
		end,
	})

	SubTab1:AddToggle("EnableParryRepeat", {
		Text = "Enable parry repeating",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.ParryRepeat = Value
		end,
	})

	SubTab1:AddToggle("EnableParryRepeatAnimationEnds", {
		Text = "Parry repeat until ending",
		Default = false, -- Default value (true / false)
		Tooltip = "This will repeat the parry until the animation ends with the specified delay, and ignores the parry-repeat slider.",
		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.ParryRepeatAnimationEnds = Value
		end,
	})

	local Depbox = SubTab1:AddDependencyBox()
	Depbox:AddSlider("ParryRepeatSlider", {
		Text = "Parry repeat times",
		Default = 3,
		Min = 1,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "x",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.ParryRepeatTimes = Value
		end,
	})

	Depbox:AddInput("ParryRepeatDelayInput", {
		Numeric = true,
		Finished = false,
		Text = "Delay between repeat parries (ms)",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Animation.ParryRepeatDelay = Value
		end,
	})

	Depbox:SetupDependencies({
		{ Toggles.EnableParryRepeat, true }, -- We can also pass `false` if we only want our features to show when the toggle is off!
	})

	local SubTab2 = TabBox:AddTab("Sound")

	SubTab2:AddInput("SoundNickNameInput", {
		Numeric = false,
		Finished = false,
		Text = "Sound Nickname",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Sound.NickName = Value
		end,
	})

	SubTab2:AddInput("SoundIdInput", {
		Numeric = false,
		Finished = false,
		Text = "Sound ID",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Sound.SoundId = Value
		end,
	})

	SubTab2:AddSlider("SoundMinimumDistanceSlider", {
		Text = "Minimum distance to activate",
		Default = 5,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Sound.MinimumDistance = Value
		end,
	})

	SubTab2:AddSlider("SoundMaximumDistanceSlider", {
		Text = "Maximum distance to activate",
		Default = 15,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Sound.MaximumDistance = Value
		end,
	})

	SubTab2:AddInput("SoundAttemptDelayInput", {
		Numeric = true,
		Finished = false,
		Text = "Delay until attempt (ms)",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Sound.AttemptDelay = Value
		end,
	})

	SubTab2:AddToggle("SoundRollInsteadOfParryToggle", {
		Text = "Roll instead of parry",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Sound.ShouldRoll = Value
		end,
	})

	SubTab2:AddToggle("SoundEnableParryRepeat", {
		Text = "Enable parry repeating",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Sound.ParryRepeat = Value
		end,
	})

	local Depbox2 = SubTab2:AddDependencyBox()
	Depbox2:AddSlider("SoundParryRepeatSlider", {
		Text = "Parry repeat times",
		Default = 3,
		Min = 1,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "x",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Sound.ParryRepeatTimes = Value
		end,
	})

	Depbox2:AddInput("SoundParryRepeatDelayInput", {
		Numeric = true,
		Finished = false,
		Text = "Delay between repeat parries (ms)",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Sound.ParryRepeatDelay = Value
		end,
	})

	Depbox2:SetupDependencies({
		{ Toggles.SoundEnableParryRepeat, true }, -- We can also pass `false` if we only want our features to show when the toggle is off!
	})

	local SubTab3 = TabBox:AddTab("Part")
	SubTab3:AddInput("PartNickNameInput", {
		Numeric = false,
		Finished = false,
		Text = "Part Nickname",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Part.NickName = Value
		end,
	})

	SubTab3:AddInput("PartNameInput", {
		Numeric = false,
		Finished = false,
		Text = "Part Name",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Part.PartName = Value
		end,
	})

	SubTab3:AddInput("PartParentNameInput", {
		Numeric = false,
		Finished = false,
		Text = "Part Parent",
		Tooltip = "Entity who threw the part (partial match), leave as none or empty for none, leave humanoid for humanoid / player...",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Part.PartParentName = Value
		end,
	})

	SubTab3:AddSlider("PartMinimumDistanceSlider", {
		Text = "Minimum distance to activate",
		Default = 5,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Part.MinimumDistance = Value
		end,
	})

	SubTab3:AddSlider("PartMaximumDistanceSlider", {
		Text = "Maximum distance to activate",
		Default = 15,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Part.MaximumDistance = Value
		end,
	})

	SubTab3:AddInput("PartAttemptDelayInput", {
		Numeric = true,
		Finished = false,
		Text = "Delay until attempt (ms)",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Part.AttemptDelay = Value
		end,
	})

	SubTab3:AddToggle("PartRollInsteadOfParryToggle", {
		Text = "Roll instead of parry",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Part.ShouldRoll = Value
		end,
	})

	SubTab3:AddToggle("PartEnableParryRepeat", {
		Text = "Enable parry repeating",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Part.ParryRepeat = Value
		end,
	})

	local Depbox3 = SubTab3:AddDependencyBox()
	Depbox3:AddSlider("PartParryRepeatSlider", {
		Text = "Parry repeat times",
		Default = 3,
		Min = 1,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "x",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Part.ParryRepeatTimes = Value
		end,
	})

	Depbox3:AddInput("PartParryRepeatDelayInput", {
		Numeric = true,
		Finished = false,
		Text = "Delay between repeat parries (ms)",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.Part.ParryRepeatDelay = Value
		end,
	})

	Depbox3:SetupDependencies({
		{ Toggles.PartEnableParryRepeat, true }, -- We can also pass `false` if we only want our features to show when the toggle is off!
	})
end

function CombatTab:BuilderSettingsGroup()
	local TabBox = self.Tab:AddRightTabbox("BuilderSettings")

	local SubTab1 = TabBox:AddTab("Settings")
	SubTab1:AddDropdown("BuilderSettingsList", {
		Values = CombatTab:UpdateBuilderSettingsList(),

		Default = 1, -- number index of the value / string
		Multi = false, -- true / false, allows multiple choices to be selected
		AllowNull = true,

		Text = "Builder Settings List",

		Callback = function(Value)
			local Type = Pascal:GetConfig().AutoParryBuilder.BuilderSettingType
			Pascal:GetConfig().AutoParryBuilder[Type].CurrentActiveSettingString = Value

			local BuilderSetting = Pascal:GetBuilderSettingFromIdentifier(Type, Value)
			if not BuilderSetting then
				return
			end

			if Type == "Animation" then
				Options.AnimationNickNameInput:SetValue(BuilderSetting.NickName)
				Options.AnimationIdInput:SetValue(BuilderSetting.AnimationId)
				Options.MinimumDistanceSlider:SetValue(BuilderSetting.MinimumDistance)
				Options.MaximumDistanceSlider:SetValue(BuilderSetting.MaximumDistance)
				Options.AttemptDelayInput:SetValue(BuilderSetting.AttemptDelay)
				Options.ParryRepeatSlider:SetValue(BuilderSetting.ParryRepeatTimes)
				Options.ParryRepeatDelayInput:SetValue(BuilderSetting.ParryRepeatDelay)
				Toggles.EnableParryRepeat:SetValue(BuilderSetting.ParryRepeat)
				Toggles.RollInsteadOfParryToggle:SetValue(BuilderSetting.ShouldRoll)
				Toggles.BlockInsteadOfParryToggle:SetValue(BuilderSetting.ShouldBlock)
				Toggles.EnableParryRepeatAnimationEnds:SetValue(BuilderSetting.ParryRepeatAnimationEnds)
				Toggles.DelayUntilInRange:SetValue(BuilderSetting.DelayUntilInRange)
				Toggles.ActivateOnEnd:SetValue(BuilderSetting.ActivateOnEnd)
			end

			if Type == "Sound" then
				Options.SoundNickNameInput:SetValue(BuilderSetting.NickName)
				Options.SoundIdInput:SetValue(BuilderSetting.SoundId)
				Options.SoundMinimumDistanceSlider:SetValue(BuilderSetting.MinimumDistance)
				Options.SoundMaximumDistanceSlider:SetValue(BuilderSetting.MaximumDistance)
				Options.SoundAttemptDelayInput:SetValue(BuilderSetting.AttemptDelay)
				Options.SoundParryRepeatSlider:SetValue(BuilderSetting.ParryRepeatTimes)
				Options.SoundParryRepeatDelayInput:SetValue(BuilderSetting.ParryRepeatDelay)
				Toggles.SoundEnableParryRepeat:SetValue(BuilderSetting.ParryRepeat)
				Toggles.SoundRollInsteadOfParryToggle:SetValue(BuilderSetting.ShouldRoll)
			end

			if Type == "Part" then
				Options.PartNickNameInput:SetValue(BuilderSetting.NickName)
				Options.PartNameInput:SetValue(BuilderSetting.PartName)
				Options.PartParentNameInput:SetValue(BuilderSetting.PartParentName)
				Options.PartMinimumDistanceSlider:SetValue(BuilderSetting.MinimumDistance)
				Options.PartMaximumDistanceSlider:SetValue(BuilderSetting.MaximumDistance)
				Options.PartAttemptDelayInput:SetValue(BuilderSetting.AttemptDelay)
				Options.PartParryRepeatSlider:SetValue(BuilderSetting.ParryRepeatTimes)
				Options.PartParryRepeatDelayInput:SetValue(BuilderSetting.ParryRepeatDelay)
				Toggles.PartEnableParryRepeat:SetValue(BuilderSetting.ParryRepeat)
				Toggles.PartRollInsteadOfParryToggle:SetValue(BuilderSetting.ShouldRoll)
			end
		end,
	})

	SubTab1:AddDropdown("BuilderSettingsType", {
		Values = { "Animation", "Sound", "Part" },

		Default = 1, -- number index of the value / string
		Multi = false, -- true / false, allows multiple choices to be selected
		AllowNull = false,
		Default = "Animation",
		Text = "Builder Setting Type",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.BuilderSettingType = Value
			CombatTab:UpdateBuilderSettingsList()
			Options.BuilderSettingsList:SetValue(nil)
		end,
	})

	SubTab1:AddButton("Register setting into list", function()
		local Type = Pascal:GetConfig().AutoParryBuilder.BuilderSettingType
		local BuilderSettingsList = Pascal:GetConfig().AutoParryBuilder[Type].BuilderSettingsList

		-- Handle the builder settings list
		if Type == "Animation" then
			if BuilderSettingsList[Pascal:GetConfig().AutoParryBuilder[Type].AnimationId] then
				Library:Notify(
					string.format(
						"%s(%s) is already in animation-list, cannot re-register it",
						Pascal:GetConfig().AutoParryBuilder[Type].NickName,
						Pascal:GetConfig().AutoParryBuilder[Type].AnimationId
					),
					2.5
				)

				return
			end

			BuilderSettingsList[Pascal:GetConfig().AutoParryBuilder[Type].AnimationId] = {
				Identifier = string.format(
					"%s | %s",
					Pascal:GetConfig().AutoParryBuilder[Type].NickName,
					Pascal:GetConfig().AutoParryBuilder[Type].AnimationId
				),
				Type = Pascal:GetConfig().AutoParryBuilder[Type].Type,
				NickName = Pascal:GetConfig().AutoParryBuilder[Type].NickName,
				AnimationId = Pascal:GetConfig().AutoParryBuilder[Type].AnimationId,
				MinimumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MinimumDistance,
				MaximumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MaximumDistance,
				AttemptDelay = Pascal:GetConfig().AutoParryBuilder[Type].AttemptDelay,
				ShouldRoll = Pascal:GetConfig().AutoParryBuilder[Type].ShouldRoll,
				ShouldBlock = Pascal:GetConfig().AutoParryBuilder[Type].ShouldBlock,
				ParryRepeat = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeat,
				ParryRepeatTimes = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatTimes,
				ParryRepeatDelay = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatDelay,
				ParryRepeatAnimationEnds = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatAnimationEnds,
				DelayUntilInRange = Pascal:GetConfig().AutoParryBuilder[Type].DelayUntilInRange,
				ActivateOnEnd = Pascal:GetConfig().AutoParryBuilder[Type].ActivateOnEnd,
			}

			Library:Notify(
				string.format(
					"Registered %s(%s) into list",
					Pascal:GetConfig().AutoParryBuilder[Type].NickName,
					Pascal:GetConfig().AutoParryBuilder[Type].AnimationId
				),
				2.5
			)
		end

		if Type == "Sound" then
			if BuilderSettingsList[Pascal:GetConfig().AutoParryBuilder[Type].SoundId] then
				Library:Notify(
					string.format(
						"%s(%s) is already in sound-list, cannot re-register it",
						Pascal:GetConfig().AutoParryBuilder[Type].NickName,
						Pascal:GetConfig().AutoParryBuilder[Type].SoundId
					),
					2.5
				)

				return
			end

			BuilderSettingsList[Pascal:GetConfig().AutoParryBuilder[Type].SoundId] = {
				Identifier = string.format(
					"%s | %s",
					Pascal:GetConfig().AutoParryBuilder[Type].NickName,
					Pascal:GetConfig().AutoParryBuilder[Type].SoundId
				),
				Type = Pascal:GetConfig().AutoParryBuilder[Type].Type,
				NickName = Pascal:GetConfig().AutoParryBuilder[Type].NickName,
				SoundId = Pascal:GetConfig().AutoParryBuilder[Type].SoundId,
				MinimumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MinimumDistance,
				MaximumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MaximumDistance,
				AttemptDelay = Pascal:GetConfig().AutoParryBuilder[Type].AttemptDelay,
				ShouldRoll = Pascal:GetConfig().AutoParryBuilder[Type].ShouldRoll,
				ParryRepeat = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeat,
				ParryRepeatTimes = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatTimes,
				ParryRepeatDelay = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatDelay,
			}

			Library:Notify(
				string.format(
					"Registered %s(%s) into list",
					Pascal:GetConfig().AutoParryBuilder[Type].NickName,
					Pascal:GetConfig().AutoParryBuilder[Type].SoundId
				),
				2.5
			)
		end

		if Type == "Part" then
			if BuilderSettingsList[Pascal:GetConfig().AutoParryBuilder[Type].PartName] then
				Library:Notify(
					string.format(
						"%s(%s) is already in sound-list, cannot re-register it",
						Pascal:GetConfig().AutoParryBuilder[Type].NickName,
						Pascal:GetConfig().AutoParryBuilder[Type].PartName
					),
					2.5
				)

				return
			end

			BuilderSettingsList[Pascal:GetConfig().AutoParryBuilder[Type].PartName] = {
				Identifier = string.format(
					"%s | %s",
					Pascal:GetConfig().AutoParryBuilder[Type].NickName,
					Pascal:GetConfig().AutoParryBuilder[Type].PartName
				),
				Type = Pascal:GetConfig().AutoParryBuilder[Type].Type,
				NickName = Pascal:GetConfig().AutoParryBuilder[Type].NickName,
				PartName = Pascal:GetConfig().AutoParryBuilder[Type].PartName,
				PartParentName = Pascal:GetConfig().AutoParryBuilder[Type].PartParentName,
				MinimumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MinimumDistance,
				MaximumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MaximumDistance,
				AttemptDelay = Pascal:GetConfig().AutoParryBuilder[Type].AttemptDelay,
				ShouldRoll = Pascal:GetConfig().AutoParryBuilder[Type].ShouldRoll,
				ParryRepeat = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeat,
				ParryRepeatTimes = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatTimes,
				ParryRepeatDelay = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatDelay,
			}

			Library:Notify(
				string.format(
					"Registered %s(%s) into list",
					Pascal:GetConfig().AutoParryBuilder[Type].NickName,
					Pascal:GetConfig().AutoParryBuilder[Type].PartName
				),
				2.5
			)
		end

		CombatTab:UpdateBuilderSettingsList()
		Options.BuilderSettingsList:SetValue(nil)
	end)

	SubTab1:AddButton("Update setting from list", function()
		local Type = Pascal:GetConfig().AutoParryBuilder.BuilderSettingType
		local BuilderSetting = Pascal:GetBuilderSettingFromIdentifier(
			Type,
			Pascal:GetConfig().AutoParryBuilder[Type].CurrentActiveSettingString
		)

		if not BuilderSetting then
			return
		end

		if Type == "Animation" then
			Library:Notify(
				string.format("Updated %s(%s) from animation-list", BuilderSetting.NickName, BuilderSetting.AnimationId),
				2.5
			)

			-- Handle the builder settings list
			BuilderSetting.Identifier = string.format(
				"%s | %s",
				Pascal:GetConfig().AutoParryBuilder[Type].NickName,
				Pascal:GetConfig().AutoParryBuilder[Type].AnimationId
			)

			BuilderSetting.NickName = Pascal:GetConfig().AutoParryBuilder[Type].NickName
			BuilderSetting.MinimumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MinimumDistance
			BuilderSetting.MaximumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MaximumDistance
			BuilderSetting.AttemptDelay = Pascal:GetConfig().AutoParryBuilder[Type].AttemptDelay
			BuilderSetting.ShouldRoll = Pascal:GetConfig().AutoParryBuilder[Type].ShouldRoll
			BuilderSetting.ShouldBlock = Pascal:GetConfig().AutoParryBuilder[Type].ShouldBlock
			BuilderSetting.ParryRepeat = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeat
			BuilderSetting.ParryRepeatTimes = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatTimes
			BuilderSetting.ParryRepeatDelay = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatDelay
			BuilderSetting.ParryRepeatAnimationEnds = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatAnimationEnds
			BuilderSetting.DelayUntilInRange = Pascal:GetConfig().AutoParryBuilder[Type].DelayUntilInRange
			BuilderSetting.ActivateOnEnd = Pascal:GetConfig().AutoParryBuilder[Type].ActivateOnEnd
		end

		if Type == "Sound" then
			Library:Notify(
				string.format("Updated %s(%s) from sound-list", BuilderSetting.NickName, BuilderSetting.SoundId),
				2.5
			)

			-- Handle the builder settings list
			BuilderSetting.Identifier = string.format(
				"%s | %s",
				Pascal:GetConfig().AutoParryBuilder[Type].NickName,
				Pascal:GetConfig().AutoParryBuilder[Type].SoundId
			)

			BuilderSetting.NickName = Pascal:GetConfig().AutoParryBuilder[Type].NickName
			BuilderSetting.MinimumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MinimumDistance
			BuilderSetting.MaximumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MaximumDistance
			BuilderSetting.AttemptDelay = Pascal:GetConfig().AutoParryBuilder[Type].AttemptDelay
			BuilderSetting.ShouldRoll = Pascal:GetConfig().AutoParryBuilder[Type].ShouldRoll
			BuilderSetting.ParryRepeat = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeat
			BuilderSetting.ParryRepeatTimes = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatTimes
			BuilderSetting.ParryRepeatDelay = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatDelay
		end

		if Type == "Part" then
			Library:Notify(
				string.format("Updated %s(%s) from part-list", BuilderSetting.NickName, BuilderSetting.PartName),
				2.5
			)

			-- Handle the builder settings list
			BuilderSetting.Identifier = string.format(
				"%s | %s",
				Pascal:GetConfig().AutoParryBuilder[Type].NickName,
				Pascal:GetConfig().AutoParryBuilder[Type].PartName
			)

			BuilderSetting.NickName = Pascal:GetConfig().AutoParryBuilder[Type].NickName
			BuilderSetting.PartParentName = Pascal:GetConfig().AutoParryBuilder[Type].PartParentName
			BuilderSetting.MinimumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MinimumDistance
			BuilderSetting.MaximumDistance = Pascal:GetConfig().AutoParryBuilder[Type].MaximumDistance
			BuilderSetting.AttemptDelay = Pascal:GetConfig().AutoParryBuilder[Type].AttemptDelay
			BuilderSetting.ShouldRoll = Pascal:GetConfig().AutoParryBuilder[Type].ShouldRoll
			BuilderSetting.ParryRepeat = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeat
			BuilderSetting.ParryRepeatTimes = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatTimes
			BuilderSetting.ParryRepeatDelay = Pascal:GetConfig().AutoParryBuilder[Type].ParryRepeatDelay
		end

		CombatTab:UpdateBuilderSettingsList()
		Options.BuilderSettingsList:SetValue(nil)
	end)

	SubTab1:AddButton("Delete setting from list", function()
		local Type = Pascal:GetConfig().AutoParryBuilder.BuilderSettingType
		local BuilderSetting = Pascal:GetBuilderSettingFromIdentifier(
			Type,
			Pascal:GetConfig().AutoParryBuilder[Type].CurrentActiveSettingString
		)

		if not BuilderSetting then
			return
		end

		if Type == "Animation" then
			Library:Notify(
				string.format("Deleted %s(%s) from list", BuilderSetting.NickName, BuilderSetting.AnimationId),
				2.5
			)

			local BuilderSettingsList = Pascal:GetConfig().AutoParryBuilder[Type].BuilderSettingsList
			BuilderSettingsList[BuilderSetting.AnimationId] = nil
		end

		if Type == "Sound" then
			Library:Notify(
				string.format("Deleted %s(%s) from list", BuilderSetting.NickName, BuilderSetting.SoundId),
				2.5
			)

			local BuilderSettingsList = Pascal:GetConfig().AutoParryBuilder[Type].BuilderSettingsList
			BuilderSettingsList[BuilderSetting.SoundId] = nil
		end

		if Type == "Part" then
			Library:Notify(
				string.format("Deleted %s(%s) from list", BuilderSetting.NickName, BuilderSetting.PartName),
				2.5
			)

			local BuilderSettingsList = Pascal:GetConfig().AutoParryBuilder[Type].BuilderSettingsList
			BuilderSettingsList[BuilderSetting.PartName] = nil
		end

		CombatTab:UpdateBuilderSettingsList()
		Options.BuilderSettingsList:SetValue(nil)
	end)

	SubTab1:AddDropdown("BlacklistedIdentifiersList", {
		Values = CombatTab:UpdateBlacklistedIdentifiersList(),

		Default = 1, -- number index of the value / string
		Multi = false, -- true / false, allows multiple choices to be selected
		AllowNull = true,

		Text = "Blacklisted Identifiers",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryLogging.CurrentActiveIdentifiersSetting = Value
		end,
	})

	SubTab1:AddInput("IdentifiersInputBlacklist", {
		Numeric = false,
		Finished = false,
		Text = "Hide ID",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryLogging.CurrentIdentifierBlacklist = Value
		end,
	})

	SubTab1:AddButton("Blacklist ID from logger", function()
		local ActiveAnimationIdValue =
			Pascal:GetConfig().AutoParryLogging.BlacklistedIdentifiers[Pascal:GetConfig().AutoParryLogging.CurrentIdentifierBlacklist]

		if ActiveAnimationIdValue == true then
			Library:Notify(
				string.format(
					"%s is already blacklisted from logging",
					Pascal:GetConfig().AutoParryLogging.CurrentIdentifierBlacklist
				),
				2.5
			)

			return
		end

		Pascal:GetConfig().AutoParryLogging.BlacklistedIdentifiers[Pascal:GetConfig().AutoParryLogging.CurrentIdentifierBlacklist] =
			true

		Library:Notify(
			string.format("Blacklisted %s from logging", Pascal:GetConfig().AutoParryLogging.CurrentIdentifierBlacklist),
			2.5
		)

		CombatTab:UpdateBlacklistedIdentifiersList()
	end)

	SubTab1:AddButton("Re-whitelist selected ID", function()
		local ActiveAnimationIdValue =
			Pascal:GetConfig().AutoParryLogging.BlacklistedIdentifiers[Pascal:GetConfig().AutoParryLogging.CurrentActiveIdentifiersSetting]

		if ActiveAnimationIdValue == nil then
			Library:Notify(string.format("Active ID does not exist in the list (error)"), 2.5)
			return
		end

		if ActiveAnimationIdValue == false then
			Library:Notify(
				string.format(
					"%s is already whitelisted from logging",
					Pascal:GetConfig().AutoParryLogging.CurrentActiveIdentifiersSetting
				),
				2.5
			)

			return
		end

		Pascal:GetConfig().AutoParryLogging.BlacklistedIdentifiers[Pascal:GetConfig().AutoParryLogging.CurrentActiveIdentifiersSetting] =
			false

		Library:Notify(
			string.format(
				"Re-whitelisted %s from logging",
				Pascal:GetConfig().AutoParryLogging.CurrentActiveIdentifiersSetting
			),
			2.5
		)

		CombatTab:UpdateBlacklistedIdentifiersList()
		Options.BlacklistedIdentifiersList:SetValue(nil)
	end)

	local SubTab2 = TabBox:AddTab("Transfering")

	SubTab2:AddDropdown("ConfigurationList", {
		Values = CombatTab:GetConfigurationList(),

		Default = 1, -- number index of the value / string
		Multi = false, -- true / false, allows multiple choices to be selected
		AllowNull = true,

		Text = "Configuration list",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.ActiveConfigurationString = Value
		end,
	})

	SubTab2:AddInput("ConfigNameInput", {
		Numeric = false,
		Finished = false,
		Text = "Configuration name",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryBuilder.ActiveConfigurationNameString = Value
		end,
	})

	SubTab2
		:AddButton("Create config", function()
			CombatTab:CreateConfigurationWithName(Pascal:GetConfig().AutoParryBuilder.ActiveConfigurationNameString)
			Options.ConfigurationList.Values = CombatTab:GetConfigurationList()
			Options.ConfigurationList:SetValues()
			Options.ConfigurationList:SetValue(nil)
		end)
		:AddButton("Load config", function()
			if
				isfile(
					Pascal:GetConfigurationPath()
						.. "/CombatConfigurations/"
						.. Pascal:GetConfig().AutoParryBuilder.ActiveConfigurationString
						.. ".json"
				)
			then
				CombatTab:LoadConfigurationFromName(Pascal:GetConfig().AutoParryBuilder.ActiveConfigurationString)
			else
				CombatTab:LoadLinoriaConfigFromName(Name)
			end

			CombatTab:UpdateBuilderSettingsList()
			CombatTab:UpdateBlacklistedIdentifiersList()
		end)

	SubTab2:AddButton("Save config", function()
		CombatTab:SaveConfigurationWithName(Pascal:GetConfig().AutoParryBuilder.ActiveConfigurationString)
	end)

	SubTab2:AddButton("Set as default config", function()
		CombatTab:SetDefaultConfig(Pascal:GetConfig().AutoParryBuilder.ActiveConfigurationString)
	end)

	SubTab2:AddButton("Refresh configuration list", function()
		Options.ConfigurationList.Values = CombatTab:GetConfigurationList()
		Options.ConfigurationList:SetValues()
		Options.ConfigurationList:SetValue(nil)
	end)
end

function CombatTab:AutoParryGroup()
	local TabBox = self.Tab:AddLeftTabbox("AutoParry")
	local SubTab2 = TabBox:AddTab("Logger")

	SubTab2:AddToggle("EnableAutoParryLogging", {
		Text = "Enable info-logger",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryLogging.Enabled = Value
			Library:SetInfoLoggerVisibility(Value)
		end,
	})

	SubTab2:AddToggle("LogLocalPlayerToggle", {
		Text = "Allow logging yourself",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryLogging.LogYourself = Value
		end,
	})

	SubTab2:AddToggle("RemoveIfAlreadyAdded", {
		Text = "Remove if already added",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParryLogging.BlockLogged = Value
		end,
	})

	SubTab2:AddDropdown("LoggerTypeDropDown", {
		Values = { "Animation", "Sound", "Part" },
		Default = 1,
		Multi = false,
		Text = "Logger Type",
		Tooltip = "The type decides what will be logged",
		Callback = function(Value)
			Pascal:GetConfig().AutoParryLogging.Type = Value
		end,
	})

	local Depbox2 = SubTab2:AddDependencyBox()
	Depbox2:AddSlider("MinimumDistanceLogSlider", {
		Text = "Minimum distance to log",
		Default = 5,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryLogging.MinimumDistance = Value
		end,
	})

	Depbox2:AddSlider("MaximumDistanceLogSlider", {
		Text = "Maximum distance to log",
		Default = 15,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryLogging.MaximumDistance = Value
		end,
	})

	Depbox2:AddSlider("InfoLoggerMaximumSize", {
		Text = "Info-logger maximum size",
		Default = 8,
		Min = 0,
		Max = 20,
		Rounding = 0,
		Compact = false,
		Suffix = "el",

		Callback = function(Value)
			Pascal:GetConfig().AutoParryLogging.MaximumSize = Value
		end,
	})

	Depbox2:SetupDependencies({
		{ Toggles.EnableAutoParryLogging, true }, -- We can also pass `false` if we only want our features to show when the toggle is off!
	})

	local SubTab3 = TabBox:AddTab("Options")

	SubTab3:AddToggle("EnableAutoParryToggle", {
		Text = "Enable auto-parry",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			if Value == false and Pascal:GetConfig().AutoParry.ShowAutoParryNotifications then
				Library:Notify("You have enabled the SmartParry technology!", 3.0)
			end

			if not Pascal:GetConfig().AutoParry.BindEnabled then
				Pascal:GetConfig().AutoParry.Enabled = Value
			end
		end,
	})

	local Depbox9 = SubTab3:AddDependencyBox()

	Depbox9:AddToggle("EnableAutoParryBindToggle", {
		Text = "Enable auto-parry bind",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Options.AutoParryBind.NoUI = not Value
			Pascal:GetConfig().AutoParry.BindEnabled = Value
		end,
	}):AddKeyPicker("AutoParryBind", {
		Default = "X",
		NoUI = not Pascal:GetConfig().AutoParry.BindEnabled,
		Text = "Auto-parry bind",
		Modes = { "Toggle", "Hold" },
		Callback = function(State)
			if not Pascal:GetConfig().AutoParry.BindEnabled then
				return
			end

			Pascal:GetConfig().AutoParry.Enabled = State
		end,
	})

	Depbox9:SetupDependencies({
		{ Toggles.EnableAutoParryToggle, true }, -- We can also pass `false` if we only want our features to show when the toggle is off!
	})

	SubTab3:AddDropdown("InputMethodDropdown", {
		Values = { "KeyPress" },
		Default = 1,
		Multi = false,
		Text = "Input Method",
		Tooltip = "For now, the only method here is KeyPress.",
		Callback = function(Value)
			Pascal:GetConfig().AutoParry.InputMethod = Value
		end,
	})

	SubTab3:AddToggle("ShouldNotifyUser", {
		Text = "Show auto-parry notifications",
		Default = true, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParry.ShowAutoParryNotifications = Value
		end,
	})

	SubTab3:AddToggle("EnableRunOnLocal", {
		Text = "Run auto-parry on local attacks",
		Default = false, -- Default value (true / false)
		Tooltip = "This feature can help you while testing your own attacks and timings.",
		Callback = function(Value)
			Pascal:GetConfig().AutoParry.LocalAttackAutoParry = Value
		end,
	})

	SubTab3:AddToggle("EnableAutoFeintToggle", {
		Text = "Auto-feint attacks",
		Default = false, -- Default value (true / false)
		Tooltip = "This will automatically feint attacks when the user is swinging while auto-parry is active.",
		Callback = function(Value)
			Pascal:GetConfig().AutoParry.AutoFeint = Value
		end,
	})

	SubTab3:AddToggle("EnableLocalLookToggle", {
		Text = "Check if looking at enemy",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParry.IfLookingAtEnemy = Value
		end,
	})

	SubTab3:AddToggle("EnableEnemyLookToggle", {
		Text = "Check if enemy looks at you",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParry.EnemyLookingAtYou = Value
		end,
	})

	SubTab3:AddToggle("EnableRollOnFeints", {
		Text = "Roll on feints",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParry.RollOnFeints = Value
		end,
	})

	SubTab3:AddSlider("FeintDistanceMinimum", {
		Text = "Minimum feint distance",
		Default = 0,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParry.MinimumFeintDistance = Value
		end,
	})

	SubTab3:AddSlider("FeintDistanceMaximum", {
		Text = "Maximum feint distance",
		Default = 0,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParry.MaximumFeintDistance = Value
		end,
	})

	SubTab3:AddToggle("EnableShouldRollCancel", {
		Text = "Should roll-cancel",
		Default = false, -- Default value (true / false)
		Callback = function(Value)
			Pascal:GetConfig().AutoParry.ShouldRollCancel = Value
		end,
	})

	SubTab3:AddSlider("RollCancelDelay", {
		Text = "Roll-cancel delay",
		Default = 0,
		Min = 0,
		Max = 100,
		Rounding = 2,
		Compact = false,
		Suffix = "ms",
		Tooltip = "The delay until right click (to cancel the roll) is pressed while rolling.",

		Callback = function(Value)
			Pascal:GetConfig().AutoParry.RollCancelDelay = Value
		end,
	})

	SubTab3:AddSlider("DistanceThresholdInRange", {
		Text = "Distance-delay threshold",
		Default = 0,
		Min = 0,
		Max = 1000,
		Rounding = 0,
		Compact = false,
		Suffix = "m",
		Tooltip = "Distance-delay won't activate if the distance is past this threshold...",

		Callback = function(Value)
			Pascal:GetConfig().AutoParry.DistanceThresholdInRange = Value
		end,
	})

	SubTab3:AddSlider("PingAdjustSlider", {
		Text = "Adjust timings by ping",
		Default = 25,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "%",

		Callback = function(Value)
			Pascal:GetConfig().AutoParry.PingAdjust = Value
		end,
	})

	SubTab3:AddSlider("GlobalTimingAdjustSlider", {
		Text = "Adjust timings by slider",
		Default = 0,
		Min = -1000,
		Max = 1000,
		Rounding = 0,
		Compact = false,
		Suffix = "ms",

		Callback = function(Value)
			Pascal:GetConfig().AutoParry.AdjustTimingsBySlider = Value
		end,
	})

	SubTab3:AddSlider("GlobalDistanceAdjustSlider", {
		Text = "Adjust distances by slider",
		Default = 0,
		Min = -100,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "m",

		Callback = function(Value)
			Pascal:GetConfig().AutoParry.AdjustDistancesBySlider = Value
		end,
	})

	SubTab3:AddSlider("HitchanceSlider", {
		Text = "Chance to activate auto-parry",
		Default = 100,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Compact = false,
		Suffix = "%",

		Callback = function(Value)
			Pascal:GetConfig().AutoParry.Hitchance = Value
		end,
	})
end

function CombatTab:CreateElements()
	self:AutoParryBuilderGroup()
	self:AutoParryGroup()
	self:BuilderSettingsGroup()
end

function CombatTab:UpdateBlacklistedIdentifiersList()
	local VisibleBlacklistedIdentifiers = {}

	for Identifier, CurrentValue in next, Pascal:GetConfig().AutoParryLogging.BlacklistedIdentifiers do
		-- Don't add this to the current list if it is whitelisted...
		if CurrentValue == false then
			continue
		end

		table.insert(VisibleBlacklistedIdentifiers, Identifier)
	end

	if Options.BlacklistedIdentifiersList then
		Options.BlacklistedIdentifiersList.Values = VisibleBlacklistedIdentifiers
		Options.BlacklistedIdentifiersList:SetValues()
	end

	return VisibleBlacklistedIdentifiers
end

function CombatTab:UpdateBuilderSettingsList()
	local VisibleBuilderSettingsList = {}

	for _, BuilderSettings in
		next,
		Pascal:GetConfig().AutoParryBuilder[Pascal:GetConfig().AutoParryBuilder.BuilderSettingType].BuilderSettingsList
	do
		table.insert(VisibleBuilderSettingsList, BuilderSettings.Identifier)
	end

	table.sort(VisibleBuilderSettingsList, function(a, b)
		return a:lower() < b:lower()
	end)

	if Options.BuilderSettingsList then
		Options.BuilderSettingsList.Values = VisibleBuilderSettingsList
		Options.BuilderSettingsList:SetValues()
	end

	return VisibleBuilderSettingsList
end

function CombatTab:Setup(Window)
	-- Setup window / tab
	self.Window = Window
	self.Tab = Window:AddTab("Combat")

	-- Load default config
	CombatTab:LoadDefaultConfig()

	-- Setup elements
	self:CreateElements()
end

return CombatTab
