-- Our environment
local Pascal = {}

-- Methods (thank Hydroxide for these)
local Methods = {
	GetGenv = getgenv,
	NewCClosure = newcclosure,
	GetRawMetatable = getrawmetatable,
	GetInfo = getinfo or debug.getinfo,
	CheckCaller = checkcaller,
	HookMetaMethod = hookmetamethod,
	HookFunction = hookfunction,
	GetNameCallMethod = getnamecallmethod or get_namecall_method,
	GetUpValue = getupvalue or debug.getupvalue,
	GetUpValues = getupvalues or debug.getupvalues,
	SetUpValue = setupvalue or debug.setupvalue,
	Mouse2Press = mouse2press,
	Mouse2Release = mouse2release,
	KeyPress = keypress,
	KeyRelease = keyrelease,
	Random = math.random,
	GetConnections = getconnections,
	ToNumber = tonumber,
	RandomSeed = math.randomseed,
	Max = math.max,
	Clamp = math.clamp,
	ExecutionClock = os.clock,
	QueueOnTeleport = queue_on_teleport
		or fluxus and fluxus.queue_on_teleport
		or syn and syn.queue_on_teleport
		or function() end,
	Wait = task.wait or wait,
	IsXClosure = is_synapse_function
		or issentinelclosure
		or is_protosmasher_closure
		or is_sirhurt_closure
		or iselectronfunction
		or istempleclosure
		or iskrnlclosure
		or isexecutorclosure
		or checkclosure,
	Request = request or http_request,
}

-- Hotfix for HookMetaMethod...
if not Methods.HookMetaMethod and Methods.HookFunction and Methods.GetRawMetatable then
	Methods.HookMetaMethod = function(Object, MetaMethod, NewFunction)
		-- Get object's metatable...
		local MetaTable = Methods.GetRawMetatable(Object)

		-- Hook metamethod function inside of metatable, and replace it with our new function...
		-- Also call NewCClosure for prevention of call-stack abuse, and error message abuse.
		-- We will also return the original...
		return Methods.HookFunction(MetaTable[MetaMethod], Methods.NewCClosure(NewFunction))
	end
end

-- Hotfix for HookFunction...
if Methods.HookFunction then
	-- Save the old so we dont stack overflow...
	local OldHookFunction = Methods.HookFunction

	-- Call NewCClosure for prevention of call-stack abuse, and error message abuse.
	Methods.HookFunction = function(FunctionToHook, NewFunction)
		return OldHookFunction(FunctionToHook, Methods.NewCClosure(NewFunction))
	end
end

-- Default settings
local DefaultSettings = {
	AutoParry = {
		Enabled = true,
		BindEnabled = false,
		InputMethod = "KeyPress",
		ShowAutoParryNotifications = true,
		AutoFeint = false,
		IfLookingAtEnemy = false,
		EnemyLookingAtYou = false,
		LocalAttackAutoParry = false,
		ShouldRollCancel = false,
		RollCancelDelay = 0.0,
		RollOnFeints = false,
		PingAdjust = 25,
		AdjustTimingsBySlider = 0,
		AdjustDistancesBySlider = 0,
		MinimumFeintDistance = 0,
		MaximumFeintDistance = 0,
		RollOnFeintDelay = 0.0,
		DistanceThresholdInRange = 0.0,
		Hitchance = 100,
	},
	AutoParryBuilder = {
		Animation = {
			Type = "Animation",
			NickName = "",
			AnimationId = "",
			MinimumDistance = 5,
			MaximumDistance = 15,
			AttemptDelay = 150.0,
			ShouldRoll = false,
			ShouldBlock = false,
			ActivateOnEnd = false,
			DelayUntilInRange = false,
			ParryRepeat = false,
			ParryRepeatTimes = 3,
			ParryRepeatDelay = 150.0,
			ParryRepeatAnimationEnds = false,
			BuilderSettingsList = {},
		},
		Sound = {
			Type = "Sound",
			NickName = "",
			SoundId = "",
			MinimumDistance = 5,
			MaximumDistance = 15,
			AttemptDelay = 150.0,
			ShouldRoll = false,
			ParryRepeat = false,
			ParryRepeatTimes = 3,
			ParryRepeatDelay = 150.0,
			BuilderSettingsList = {},
		},
		Part = {
			Type = "Part",
			NickName = "",
			PartParentName = "",
			PartName = "",
			MinimumDistance = 5,
			MaximumDistance = 15,
			AttemptDelay = 150.0,
			ShouldRoll = false,
			ShouldBlock = false,
			ParryRepeat = false,
			ParryRepeatTimes = 3,
			ParryRepeatDelay = 150.0,
			BuilderSettingsList = {},
		},
		ActiveConfigurationString = "",
		ActiveConfigurationNameString = "",
		BuilderSettingType = "Animation",
	},
	AutoParryLogging = {
		Enabled = false,
		Type = "Animation",
		CurrentIdentifierBlacklist = "",
		BlacklistedIdentifiers = {},
		MinimumDistance = 5.0,
		MaximumDistance = 15.0,
		LogExtraPartNames = false,
		MaximumSize = 8,
		LogYourself = false,
		BlockLogged = false,
		CurrentActiveIdentifiersSetting = {},
	},
}

-- Requires
local Logger = require("Modules/Logging/Logger")
local EffectReplication = require("Modules/Deepwoken/EffectReplication")
local Helper = require("Modules/Helpers/Helper")

-- Variables
local LoggerObject = Logger:New()
local EffectReplicator = EffectReplication:New()

function Pascal:GetConfigurationPath()
	return "PascalCase/Deepwoken"
end

function Pascal:GetQueueScript()
	return "loadstring(game:HttpGet('https://raw.githubusercontent.com/Blastbrean/PascalCase/main/Main.lua'))()"
end

function Pascal:DebugPreventYield()
	return false
end

function Pascal:GetBuilderSettingFromIdentifier(Type, Identifier)
	return Helper.LoopLuaTable(
		Pascal:GetConfig().AutoParryBuilder[Type].BuilderSettingsList,
		function(Index, BuilderSetting)
			if BuilderSetting.Identifier ~= Identifier then
				return false
			end

			return {
				ReturningData = true,
				Data = BuilderSetting,
			}
		end
	)
end

function Pascal:GetLogger()
	return LoggerObject
end

function Pascal:GetEffectReplicator()
	return EffectReplicator
end

function Pascal:GetPlaceId()
	return game.PlaceId
end

function Pascal:GetEnvironment()
	local Environment = getgenv()
	return Environment
end

function Pascal:Reset()
	self:GetEnvironment().Settings = nil

	if self:IsScriptShuttingDown() then
		self:GetEnvironment().ShutdownScript = false
		self:GetEffectReplicator():Disconnect()
	end
end

function Pascal:GetConfig()
	if not self:GetEnvironment().Settings then
		self:GetEnvironment().Settings = DefaultSettings
	end

	return self:GetEnvironment().Settings
end

function Pascal:CheckForAllMethods()
	return Helper.LoopLuaTable(Methods, function(Index, Value)
		if Value ~= nil then
			return false
		end

		return {
			ReturningData = true,
			Data = false,
		}
	end) == false and false or true
end

function Pascal:GetMethods()
	return Methods
end

function Pascal:StopScriptWithReason(Thread, Reason)
	-- Print out reason
	self:GetLogger():Print("Script stopped: %s", Reason)

	-- Stop thread
	Thread:Stop()
end

function Pascal:IsScriptShuttingDown()
	return self:GetEnvironment().ShutdownScript
end

return Pascal
