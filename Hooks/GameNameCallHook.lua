local GameNameCallHook = {
	OriginalFn = nil,
}

-- Requires
local Pascal = require("Modules/Helpers/Pascal")
local Helper = require("Modules/Helpers/Helper")

function GameNameCallHook.HookFn(Self, ...)
	-- Return original, we don't need to do anything further...
	return GameNameCallHook.OriginalFn(Self, ...)
end

return GameNameCallHook
