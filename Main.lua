-- Check for cloneref...
-- If it doesn't exist, we will halt the script (special and important function...)
if not cloneref then
	return rconsoleprint("Failed to find cloneref method...")
end

-- Global service function (cloneref)
getgenv().GetService = function(ServiceName)
	local Game = cloneref(game)
	return cloneref(Game:GetService(ServiceName))
end

-- Services
local Players = GetService("Players")
local RunService = GetService("RunService")
local Workspace = GetService("Workspace")
local UserInputService = GetService("UserInputService")

-- Requires
local Event = require("Modules/Helpers/Event")
local Thread = require("Modules/Helpers/Thread")
local Pascal = require("Modules/Helpers/Pascal")
local Helper = require("Modules/Helpers/Helper")
local Menu = require("UI/Menu")
local AutoParry = require("Features/AutoParry")

-- Entity folder & entity handler (special)...
local EntityFolder = nil
local EntityHandlerObject = nil

-- Events
local RenderEvent = require("Events/RenderEvent")
local EntityHandler = require("Events/EntityHandler")

-- Create logger, thread, and event.
local MainThread = Thread:New()
local RenderEventObject = Event:New(RunService.RenderStepped)
local OnTeleportEventObject = Event:New(Players.LocalPlayer.OnTeleport)

local function StartDetachFn()
	Helper.TryAndCatch(
		-- Try...
		function()
			-- Unload menu...
			Menu:Unload()

			-- Reset Pascal...
			Pascal:Reset()

			-- Remove events...
			if not Pascal:DebugPreventYield() then
				RenderEventObject:Disconnect()
				EntityHandlerObject:Disconnect()
				OnTeleportEventObject:Disconnect()

				-- Special disconnect (see EventHandler)...
				if EntityHandler.DisconnectAutoParry then
					EntityHandler.DisconnectAutoParry()
				end
			end

			-- Disconnect stuff...
			Pascal:GetEffectReplicator():Disconnect()
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

			-- Reset Pascal...
			Pascal:Reset()

			if not Pascal:DebugPreventYield() then
				-- Queue our script on teleport...
				OnTeleportEventObject:Connect(function(State, PlaceId, SpawnName)
					if State ~= Enum.TeleportState.RequestedFromServer then
						return
					end

					if not getgenv().PascalGhostMode then
						-- Notify user...
						Library:Notify("PascalCase is queuing itself on teleport...", 5.0)
					end

					-- Queue our script to run...
					Pascal:GetMethods().QueueOnTeleport(Pascal:GetQueueScript())
				end)

				-- Stop execution if we're in the start menu...
				if Pascal:GetPlaceId() == 4111023553 then
					if not getgenv().PascalGhostMode then
						-- Notify user...
						Library:Notify("PascalCase cannot run in the start menu...", 5.0)
					end

					-- Stop script...
					return Pascal:StopScriptWithReason(MainThread, "Stopping execution, we are in the start menu!")
				end

				-- Special event, aswell as the fact we have to do this after the start menu check and queue so we don't yield...
				EntityFolder = Workspace:WaitForChild("Live", math.huge)
				EntityHandlerObject = Event:New(EntityFolder.ChildAdded)

				-- Start effect replicator...
				Pascal:GetEffectReplicator():Start()

				-- Connect all events...
				RenderEventObject:Connect(RenderEvent.CallbackFn)
				EntityHandlerObject:Connect(EntityHandler.CallbackFn)

				-- EntityHandler is a special event...
				-- We should call the CallbackFn with our current entities...
				Helper.LoopCurrentEntities(false, EntityFolder, function(Index, Entity)
					EntityHandler.CallbackFn(Entity)
				end)

				-- Get auto-parry workspace sounds...
				AutoParry.GetWorkspaceSounds()

				-- Get auto-parry thrown sounds...
				AutoParry.GetThrownProjectiles()
			end

			-- Create menu...
			Menu:Setup()

			-- Notify user that we successfully ran the script...
			if not getgenv().PascalGhostMode then
				Library:Notify("Successfully loaded PascalCase, waiting for detach...", 5.0)
			end

			-- Wait for detach
			repeat
				Pascal:GetMethods().Wait()
			until Pascal:IsScriptShuttingDown()

			-- Run detach code
			StartDetachFn()
		end,

		-- Catch...
		function(Error)
			Pascal:GetLogger():Print("MainThreadFn - Exception caught: %s", Error)
		end
	)
end

-- Run thread
MainThread:Create(MainThreadFn)
MainThread:Start()
