-- Module
local RenderEvent = {
	SecondFrameTimestamp = nil,
	ElapsedFramesPerSecond = 0,
	FramesElapsedSinceSecond = 0,
}

-- Services
local StatsService = GetService("Stats")

-- Requires
local AutoParryLogger = require("Features/AutoParryLogger")
local Helper = require("Modules/Helpers/Helper")
local Pascal = require("Modules/Helpers/Pascal")

function RenderEvent.CallbackFn(Step)
	Helper.TryAndCatch(
		-- Try...
		function()
			-- Run AutoParryLogger update...
			AutoParryLogger:RunUpdate()

			-- Increment our frame counter...
			RenderEvent.FramesElapsedSinceSecond = RenderEvent.FramesElapsedSinceSecond + 1

			-- Check if a second has passed since our last frame timestamp...
			if (Pascal:GetMethods().ExecutionClock() - (RenderEvent.SecondFrameTimestamp or 0.0)) >= 1 then
				-- Reset our timestamp...
				RenderEvent.SecondFrameTimestamp = Pascal:GetMethods().ExecutionClock()

				-- Set current frames per second...
				RenderEvent.ElapsedFramesPerSecond = RenderEvent.FramesElapsedSinceSecond

				-- Reset our counter...
				RenderEvent.FramesElapsedSinceSecond = 0
			end

			-- Update watermark...
			Library:SetWatermark(
				string.format(
					"PascalCase (Deepwoken) | %i fps | %.2f ms",
					RenderEvent.ElapsedFramesPerSecond,
					StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
				)
			)
		end,

		-- Catch...
		function(Error)
			Pascal:GetLogger():Print("RenderEvent.CallBackFn - Caught exception: %s", Error)
		end
	)
end

-- Return event
return RenderEvent
