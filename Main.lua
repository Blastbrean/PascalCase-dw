-- Check for cloneref...
-- If it doesn't exist, we will halt the script (special and important function...)
if not cloneref then
	return print("Failed to find cloneref method...")
end

-- Global service function (cloneref)
getgenv().GetService = function(ServiceName)
	return cloneref(game:GetService(ServiceName))
end

-- Services
local RunService = GetService("RunService")
local Workspace = GetService("Workspace")
local UserInputService = GetService("UserInputService")

-- Requires
local Event = require("Modules/Helpers/Event")
local Thread = require("Modules/Helpers/Thread")
local Pascal = require("Modules/Helpers/Pascal")
local Helper = require("Modules/Helpers/Helper")
local Menu = require("UI/Menu")

-- Hooking
local HookHandler = require("Modules/Helpers/HookHandler")

-- Entity folder...
local EntityFolder = Workspace:WaitForChild("Live")

-- Events
local RenderEvent = require("Events/RenderEvent")
local EntityHandler = require("Events/EntityHandler")

-- Create logger, thread, and event.
local MainThread = Thread:New()
local RenderEventObject = Event:New(RunService.RenderStepped)
local EntityHandlerObject = Event:New(EntityFolder.ChildAdded)

local function StartDetachFn()
	Helper.TryAndCatch(
		-- Try...
		function()
			-- Unload menu...
			Menu:Unload()

			-- Unload sense...
			Pascal:GetSense().Unload()

			-- Reset Pascal...
			Pascal:Reset()

			-- Remove events...
			RenderEventObject:Disconnect()
			EntityHandlerObject:Disconnect()

			-- Special disconnect (see EventHandler)...
			if EntityHandler.DisconnectAutoParry then
				EntityHandler.DisconnectAutoParry()
			end

			-- Disconnect stuff...
			Pascal:GetEffectReplicator():Disconnect()

			-- Remove hooks...
			if not HookHandler:RemoveHooks() then
				Pascal:GetLogger():Print("Unable to remove hooks while detaching!")
			end
		end,

		-- Catch...
		function(Error)
			Pascal:GetLogger():Print("StartDetachFn - Exception caught: %s", Error)
		end
	)

	-- Stop script and return...
	return Pascal:StopScriptWithReason(MainThread, "Detached from script!")
end

local function MainThreadFn()
	Helper.TryAndCatch(
		-- Try...
		function()
			-- Check for all methods, if we are missing any, stop the thread and return.
			if not Pascal:CheckForAllMethods() then
				return Pascal:StopScriptWithReason(MainThread, "Failed to find all needed methods!")
			end

			-- Start hooks...
			if not HookHandler:StartHooks() then
				return Pascal:StopScriptWithReason(MainThread, "Failed to start hooks!")
			end

			-- Reset Pascal...
			Pascal:Reset()

			-- Load sense...
			Pascal:GetSense().Load()

			-- Create menu...
			Menu:Setup()

			-- Connect all events...
			RenderEventObject:Connect(RenderEvent.CallbackFn)
			EntityHandlerObject:Connect(EntityHandler.CallbackFn)

			-- EntityHandler is a special event...
			-- We should call the CallbackFn with our current entities...
			Helper.LoopCurrentEntities(false, EntityFolder, function(Index, Entity)
				EntityHandler.CallbackFn(Entity)
			end)

			-- Wait for detach
			repeat
				task.wait()
			until Pascal:IsScriptShuttingDown()
		end,

		-- Catch...
		function(Error)
			Pascal:GetLogger():Print("MainThreadFn - Exception caught: %s", Error)
		end
	)

	-- Run detach code
	StartDetachFn()
end

-- Run thread
MainThread:Create(MainThreadFn)
MainThread:Start()
