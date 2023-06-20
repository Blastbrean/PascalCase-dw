-- Module
local RenderEvent = {}

-- Requires
local AutoParryLogger = require("Features/AutoParryLogger")
local Movement = require("Features/Movement")
local Helper = require("Modules/Helpers/Helper")
local Pascal = require("Modules/Helpers/Pascal")

function RenderEvent.CallbackFn(Step)
	Helper.TryAndCatch(
		-- Try...
		function()
			-- Run AutoParryLogger update...
			AutoParryLogger:RunUpdate()
		end,

		-- Catch...
		function(Error)
			Pascal:GetLogger():Print("RenderEvent.CallBackFn - Caught exception: %s", Error)
		end
	)
end

-- Return event
return RenderEvent
