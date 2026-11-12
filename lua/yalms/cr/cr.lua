---@class YalmsCrBase
local CrBase = {}

---@param fn fun(...) Error-first-Callback Last function
CrBase.async = function(fn)
	local func = function(...)
		local cr = coroutine.running()
		assert(cr, "await must be called inside a coroutine")

		fn(..., function(err, result)
			coroutine.resume(cr, not err, err or result)
		end)

		return coroutine.yield()
	end

	return func
end

CrBase.spawn = function(fn)
	coroutine.wrap(fn)()
end

return CrBase
