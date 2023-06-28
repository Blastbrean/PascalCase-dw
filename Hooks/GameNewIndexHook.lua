local GameNewIndexHook = {
	OriginalFn = nil,
}

-- Requires
local Pascal = require("Modules/Helpers/Pascal")
local Helper = require("Modules/Helpers/Helper")

function GameNewIndexHook.HookFn(Self, Key, Value)
	-- Return original, we don't need to do anything further...
	return GameNewIndexHook.OriginalFn(Self, Key, Value)
end

return GameNewIndexHook
