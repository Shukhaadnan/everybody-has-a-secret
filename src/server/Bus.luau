-- Bus.luau — tiny synchronous signal hub. Bus.on(name, fn) -> disconnect fn; Bus.fire(name, ...).
-- Each handler runs in pcall so one broken listener can't break the emitter.
local Bus = {}
local handlers = {} -- name -> {fn...}
Bus.log = {} -- ring buffer of the last fired events (debug / SelfTest)
local LOG_MAX = 200

function Bus.on(name: string, fn)
	local list = handlers[name]
	if not list then
		list = {}
		handlers[name] = list
	end
	table.insert(list, fn)
	return function()
		for i, f in ipairs(list) do
			if f == fn then
				table.remove(list, i)
				break
			end
		end
	end
end

function Bus.fire(name: string, ...)
	table.insert(Bus.log, name)
	if #Bus.log > LOG_MAX then
		table.remove(Bus.log, 1)
	end
	local list = handlers[name]
	if not list then
		return
	end
	for _, fn in ipairs(table.clone(list)) do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn(("[Bus] handler for %s failed: %s"):format(name, tostring(err)))
		end
	end
end

return Bus
