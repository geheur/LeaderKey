LeaderKey.private.Log = {}

local ns = LeaderKey.private

-- ### utility
function ns.slice(tbl, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

function ns.tableSize(tbl)
	local count = 0
	for i,v in pairs(tbl) do
		count = count + 1
	end
	return count
end

function ns.tableIsEmpty(tbl)
	for i,v in pairs(tbl) do
		return false
	end
	return true
end

function ns.Log.info(...)
	local bla = ns.slice({...}, 2)
	print("[LeaderKey]: " .. select(1, ...), unpack(bla))
end

function ns.Log.warning(...)
	local bla = ns.slice({...}, 2)
	print("|cFFFFA500[LeaderKey]:" .. select(1, ...), unpack(bla))
end

function ns.Log.debug(...)
	local str = "|cFFFFA500" .. "[LeaderKey]: "
	for _,arg in ipairs({...}) do
		str = str .. " " .. tostring(arg)
	end

	ChatFrame5:AddMessage(str)
end

function ns.Log.error(...)
	local bla = ns.slice({...}, 2)
	print("|cFFFF0000[LeaderKey]:" .. select(1, ...), unpack(bla))
end
function ns.Log.errorp(...)
	ns.Log.debug("Warning deprecated print function")
	ns.Log.error(...)
end

-- ### secure table insert
--[[
Transfers a value to the frame's restricted environment. Most useful for
tables, but works with any variable, provided that it is not (or if it is a
table, does not contain variables) of type functions, userdata, or thread.

Does not support tables that contain cyclic graphs.

If a value appears twice in a table, it will be duplicated in the secure
environment.

Cannot serialize strings containing "\21".
]]
do
	-- TODO does not support tables with nodes with more than one parent (Graphs that are not trees). Will hang if you pass in a cyclic graph.
	-- TODO does not support inserting into anything other than the global namespace, _G. Could take another argument that is a string and gets inserted directly into the snippet. It would default to _G.
	local splitvalue = 21 -- "negative acknowledge" - no clue what it does, but I don't expect anyone to use it.
	local splitchar = string.char(splitvalue)

	local serializeTableContents, serializeVariable
	function serializeTableContents(table)
		local serializedContents = ""
		for i,v in pairs(table) do
			serializedContents = serializedContents .. serializeVariable(i, v) .. splitchar
		end
		return serializedContents
	end
	function serializeVariable(name, value)
		value = value or _G[name]
		local valueType = type(value)
		if valueType == "function" or valueType == "userdata" or valueType == "thread" then
			error("key " .. name .. " is not serializable into the secure environment because its value is of type " .. valueType)
		elseif valueType == "table" then
			return string.format("TABLE" .. splitchar .. "%s" .. splitchar .. "%sENDTABLE", tostring(name), serializeTableContents(value))
		else -- string, number, boolean
			return string.format("VALUE" .. splitchar .. "%s" .. splitchar .. "%s", tostring(name), tostring(value))
		end
	end
	local escapeForSecureEnvironment do
		local r = {u="\\117", ["{"]="\\123", ["}"]="\\125"} -- "{" and "}" are not allowed in snippets passed to secure environment, "u" is included because "function" is not allowed.
		function escapeForSecureEnvironment(s)
			return (s:gsub("[{}u]", r))
		end
	end
	function ns.secureTableInsert(secureHeader, varName, table)
		local snippet = [[self:Run([=[
			local stack = newtable() -- keeps track of the parents.
			stack.current = _G
			stack.parent = nil

         local splitchar = ""
			local t = newtable()
       	for str in string.gmatch((...), "([^\]] .. splitvalue .. [[]+)") do
         	t[#t + 1] = str
       	end

			local i = 1
			while true do
				--local type = select(i, ...)
				local type = t[i]
				if not type then
					if stack.current ~= _G then print("ERROR: format issue, table incomplete") end
					break -- should be the end of the table.
				elseif type == "ENDTABLE" then
					stack = stack.parent
					if not stack then print("ERROR: tried to modify above _G") end

					i = i + 1
				elseif type == "TABLE" then
					--local name = select(i + 1, ...)
					local name = t[i + 1]

					local createdTable = newtable()
					stack.current[name] = createdTable

					-- push onto stack
					local newstack = newtable()
					newstack.current = createdTable
					newstack.parent = stack
					stack = newstack
					
					i = i + 2
				elseif type == "VALUE" then
					--local name = select(i + 1, ...)
					local name = t[i + 1]
					--local value = select(i + 2, ...)
					local value = t[i + 2]

					stack.current[name] = value
					
					i = i + 3
				else
					error("invalid type, check serializing f\\117nction: " .. type)
				end
			end
		--]=],%s)]]
		snippet = string.format(snippet, escapeForSecureEnvironment(("%q"):format(serializeVariable(varName, table))))

		secureHeader:Execute(snippet)
	end
end

ns.keyCodeToChar = { ["A"]="a", ["B"]="b", ["C"]="c", ["D"]="d", ["E"]="e", ["F"]="f", ["G"]="g", ["H"]="h", ["I"]="i", ["J"]="j", ["K"]="k", ["L"]="l", ["M"]="m", ["N"]="n", ["O"]="o", ["P"]="p", ["Q"]="q", ["R"]="r", ["S"]="s", ["T"]="t", ["U"]="u", ["V"]="v", ["W"]="w", ["X"]="x", ["Y"]="y", ["Z"]="z", ["SHIFT-A"]="A", ["SHIFT-B"]="B", ["SHIFT-C"]="C", ["SHIFT-D"]="D", ["SHIFT-E"]="E", ["SHIFT-F"]="F", ["SHIFT-G"]="G", ["SHIFT-H"]="H", ["SHIFT-I"]="I", ["SHIFT-J"]="J", ["SHIFT-K"]="K", ["SHIFT-L"]="L", ["SHIFT-M"]="M", ["SHIFT-N"]="N", ["SHIFT-O"]="O", ["SHIFT-P"]="P", ["SHIFT-Q"]="Q", ["SHIFT-R"]="R", ["SHIFT-S"]="S", ["SHIFT-T"]="T", ["SHIFT-U"]="U", ["SHIFT-V"]="V", ["SHIFT-W"]="W", ["SHIFT-X"]="X", ["SHIFT-Y"]="Y", ["SHIFT-Z"]="Z", [" "]="SPACE", ["1"]="1", ["2"]="2", ["3"]="3", ["4"]="4", ["5"]="5", ["6"]="6", ["7"]="7", ["8"]="8", ["9"]="9", ["0"]="0", ["SHIFT-1"]="!", ["SHIFT-2"]="@", ["SHIFT-3"]="#", ["SHIFT-4"]="$", ["SHIFT-5"]="%", ["SHIFT-6"]="^", ["SHIFT-7"]="&", ["SHIFT-8"]="*", ["SHIFT-9"]="(", ["SHIFT-0"]=")", [";"]=";", ["'"]="'", ["["]="[", ["]"]="]", ["-"]="-", ["="]="=", ["\\"]="\\", [","]=",", ["."]=".", ["/"]="/", ["SHIFT-;"]=":", ["SHIFT-'"]='"', ["SHIFT-["]="{", ["SHIFT-]"]="}", ["SHIFT--"]="_", ["SHIFT-="]="+", ["SHIFT-\\"]="|", ["SHIFT-,"]="<", ["SHIFT-."]=">", ["SHIFT-/"]="?", }

