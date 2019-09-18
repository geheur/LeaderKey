select(2, ...).setenv()

Log = {}
function Log.info(...)
	print("[LeaderKey]:", ...)
end

function Log.warn(...)
	print("|cFFFFA500[LeaderKey]:", ...)
end

function Log.debug(...)
	local str = "|cFFFFA500" .. "[LeaderKey]: "
	for _,arg in ipairs({...}) do
		str = str .. " " .. tostring(arg)
	end

	ChatFrame5:AddMessage(str)
end

function Log.error(...)
	print("|cFFFF0000[LeaderKey]:", ...)
end

