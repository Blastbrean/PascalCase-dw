local GameNameCallHook = {
	OriginalFn = nil,
}

-- Services
local ContentProvider = GetService("ContentProvider")
local CoreGui = GetService("CoreGui")
local PreCoreGuiChildren = CoreGui:GetChildren()

-- Requires
local Pascal = require("Modules/Helpers/Pascal")
local Helper = require("Modules/Helpers/Helper")

function GameNameCallHook.HookFn(Self, ...)
	-- This is us...
	if Pascal:GetMethods().CheckCaller() then
		return GameNameCallHook.OriginalFn(Self, ...)
	end

	-- Get arguments and namecall-method...
	local Args = { ... }
	local NamecallMethod = Pascal:GetMethods().GetNameCallMethod()

	-- Check if this is the game:FindService or game:WaitForChild function...
	if Self == game and (NamecallMethod == "FindService" or NamecallMethod == "WaitForChild") then
		-- Do not attempt to return services that get detected once created...
		for Index, Argument in next, Args do
			if Argument ~= "VirtualInputManager" and Argument ~= "VirtualUser" then
				continue
			end

			return nil
		end
	end

	-- Check if this is the ContentProvider:PreloadAsync function...
	if Self == ContentProvider and NamecallMethod == "PreloadAsync" then
		local AssetList = Args[1]

		-- Check for all assets in the AssetList...
		for Index, Instance in next, AssetList do
			-- We don't want this asset if it isn't CoreGui...
			if Instance ~= CoreGui then
				continue
			end

			-- If this asset is CoreGui, then get our saved CoreGuiChildren we got before,
			-- the one without any UI elements, and only the game's CoreGui elements...
			-- and call original with the same parameters, changing CoreGui's children...
			return GameNameCallHook.OriginalFn(Self, PreCoreGuiChildren, Args[2])
		end
	end

	-- Return original, we don't need to do anything further...
	return GameNameCallHook.OriginalFn(Self, ...)
end

return GameNameCallHook
