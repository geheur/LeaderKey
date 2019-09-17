local ns = LeaderKey.private
local colors = LeaderKey.private.colors
local Log = ns.Log

local Node = LeaderKey.BindingsTree.Node

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

function ns.copyKeySequence(keysequence)
	local copy = {}
	for _,v in pairs(keysequence) do
		copy[#copy + 1] = v
	end
	return copy
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
	local TABLE = "T"
	local VALUE = "V"
	local ENDTABLE = "E"
	local splitvalue = 21 -- "negative acknowledge" - no clue what it does, but I don't expect anyone to use it.
	local splitchar = string.char(splitvalue)

	local serializeTableContents, serializeVariable
	function serializeTableContents(table, strarray)
		for i,v in pairs(table) do
			serializeVariable(i, v, strarray)
			strarray[#strarray + 1] = splitchar
		end
	end
	local s2 = VALUE .. splitchar .. "%s" .. splitchar .. "%s"
	local s1 = TABLE .. splitchar
	function serializeVariable(name, value, strarray)
		value = value or _G[name]
		local valueType = type(value)
		if valueType == "function" or valueType == "userdata" or valueType == "thread" then
			error("key " .. name .. " is not serializable into the secure environment because its value is of type " .. valueType)
		elseif valueType == "table" then
			strarray[#strarray + 1] = s1
			strarray[#strarray + 1] = tostring(name)
			strarray[#strarray + 1] = splitchar
			serializeTableContents(value, strarray)
			strarray[#strarray + 1] = ENDTABLE
		else -- string, number, boolean
			strarray[#strarray + 1] = string.format(s2, tostring(name), tostring(value))
		end
	end
	local escapes = {u="\\117", ["{"]="\\123", ["}"]="\\125"} -- "{" and "}" are not allowed in snippets passed to secure environment, "u" is included because "function" is not allowed.
	local function escapeForSecureEnvironment(s)
		return (s:gsub("[{}u]", escapes))
	end
	local snippet = [[self:Run([=[
		local stack = newtable() -- keeps track of the parents.
		stack.current = _G
		stack.parent = nil

		local type, arg2, arg3
		for str in string.gmatch((...), "([^\]] .. splitvalue .. [[]+)") do
			if not type then type = str
			elseif not arg2 then arg2 = str
			else arg3 = str
			end

			if type == "]] .. ENDTABLE .. [[" then
				stack = stack.parent
				if not stack then print("ERROR: tried to modify above _G") end

				type = nil
			elseif type == "]] .. TABLE .. [[" then
				if arg2 then
					local name = arg2

					local createdTable = newtable()
					stack.current[name] = createdTable

					-- push onto stack
					local newstack = newtable()
					newstack.current = createdTable
					newstack.parent = stack
					stack = newstack
					
					type, arg2 = nil, nil
				end
			elseif type == "]] .. VALUE .. [[" then
				if arg2 and arg3 then
					local name = arg2
					local value = arg3

					stack.current[name] = value

					type, arg2, arg3 = nil, nil, nil
					arg2 = nil
					type = nil
				end
			else
				print("invalid type, check serializing f\\117nction: " .. type)
				return
			end
		end
	--]=],%s)]]
	function ns.secureTableInsert(secureHeader, varName, toSerialize)
		local startTime = debugprofilestop()
		local strarray = {}
		serializeVariable(varName, toSerialize, strarray)
		local mysnippet = string.format(snippet, escapeForSecureEnvironment(("%q"):format(table.concat(strarray))))
		-- print("snippet length: " .. strlen(mysnippet))
		secureHeader:Execute(mysnippet)
		Log.debug("Secure table insert for snippet of length " .. strlen(mysnippet) .. " took " .. (debugprofilestop() - startTime) .. "ms")
	end
end

ns.keyCodeToChar = { ["A"]="a", ["B"]="b", ["C"]="c", ["D"]="d", ["E"]="e", ["F"]="f", ["G"]="g", ["H"]="h", ["I"]="i", ["J"]="j", ["K"]="k", ["L"]="l", ["M"]="m", ["N"]="n", ["O"]="o", ["P"]="p", ["Q"]="q", ["R"]="r", ["S"]="s", ["T"]="t", ["U"]="u", ["V"]="v", ["W"]="w", ["X"]="x", ["Y"]="y", ["Z"]="z", ["SHIFT-A"]="A", ["SHIFT-B"]="B", ["SHIFT-C"]="C", ["SHIFT-D"]="D", ["SHIFT-E"]="E", ["SHIFT-F"]="F", ["SHIFT-G"]="G", ["SHIFT-H"]="H", ["SHIFT-I"]="I", ["SHIFT-J"]="J", ["SHIFT-K"]="K", ["SHIFT-L"]="L", ["SHIFT-M"]="M", ["SHIFT-N"]="N", ["SHIFT-O"]="O", ["SHIFT-P"]="P", ["SHIFT-Q"]="Q", ["SHIFT-R"]="R", ["SHIFT-S"]="S", ["SHIFT-T"]="T", ["SHIFT-U"]="U", ["SHIFT-V"]="V", ["SHIFT-W"]="W", ["SHIFT-X"]="X", ["SHIFT-Y"]="Y", ["SHIFT-Z"]="Z", ["SPACE"]=" ", ["1"]="1", ["2"]="2", ["3"]="3", ["4"]="4", ["5"]="5", ["6"]="6", ["7"]="7", ["8"]="8", ["9"]="9", ["0"]="0", ["SHIFT-1"]="!", ["SHIFT-2"]="@", ["SHIFT-3"]="#", ["SHIFT-4"]="$", ["SHIFT-5"]="%", ["SHIFT-6"]="^", ["SHIFT-7"]="&", ["SHIFT-8"]="*", ["SHIFT-9"]="(", ["SHIFT-0"]=")", [";"]=";", ["'"]="'", ["["]="[", ["]"]="]", ["-"]="-", ["="]="=", ["\\"]="\\", [","]=",", ["."]=".", ["/"]="/", ["SHIFT-;"]=":", ["SHIFT-'"]='"', ["SHIFT-["]="{", ["SHIFT-]"]="}", ["SHIFT--"]="_", ["SHIFT-="]="+", ["SHIFT-\\"]="|", ["SHIFT-,"]="<", ["SHIFT-."]=">", ["SHIFT-/"]="?", }

--[[
(key1 key2 key3) -- off-white
[MACRO Name] -- cyan (spell), red (macro)
[MACRO Name (key1, key2, key3)]
--]]

function LeaderKey.keySequenceForPrint(keySequence)
	local s = "("
	for _,keyName in ipairs(keySequence) do
		s = s .. keyName .. " "
	end
	if #keySequence > 0 then
		s = strsub(s, 0, strlen(s) - 1)
	end
	return colors.keySequence .. s .. ")" .. colors.noColor
end

--[[
/script print(LeaderKey.keySequenceForPrint({"key1", "key2", "key3"}))
--]]

function LeaderKey.nodeForPrint(node)
	return LeaderKey.bindForPrint(node, nil)
end

function LeaderKey.bindForPrint(node, keySequence)
	local s = "["
	if node.type == Node.MACRO then
		s = s .. "MACRO "
	elseif node.type == Node.SUBMENU then
		s = s .. "SUBMENU "
	elseif node.type == Node.HELM_SUBMENU then
		s = s .. "HELM "
	end
	s = s .. (node.name and node.name or "<no name>")
	local keySeqString = keySequence and " " .. LeaderKey.keySequenceForPrint(keySequence) or ""
	return colors[node.type] .. s .. keySeqString .. "]" .. colors.noColor
end

function LeaderKey.registerSlashCommand(names, func, id, donotwarn)
	if type(names) == "string" then names = {names}
	elseif #names == 0 then return end
	if not id then id = names[1] end
	for i,v in ipairs(names) do
		if not donotwarn and _G["SLASH_" .. id .. i] then message("SLASH_" .. id .. i .. " already exists") end
		_G["SLASH_" .. id .. i] = v
	end
	SlashCmdList[id] = func
end

local function printBindings(bindingsTree, sequence)
	sequence = sequence or ""
	for key,node in pairs(bindingsTree.bindings) do
		local newSequence = sequence .. key .. " "
		if not isMenu(node) then
			Log.warn(newSequence:sub(1, newSequence:len() - 1) .. ":", node.name)
		else
			printBindings(node, newSequence)
		end
	end
end

do
	local function printCurrentBindsHelper(bindingsTree, checkAgainst, sequence)
		sequence = sequence or ""
		for key,node in pairs(bindingsTree.bindings) do
			local newSequence = sequence .. key .. " "
			if not isMenu(node) then
				local str = ""
				for bindingsName,otherBindingsTree in pairs(checkAgainst) do
					local split = {}
					for i in newSequence:gmatch("%S+") do
						split[#split + 1] = i
					end
					--Log.debug("looking at binding " .. table.concat(split, " ") .. " for tree " .. bindingsName)
					local otherNode = otherBindingsTree:GetNode(split) -- TODO can't use getnode - need something like "bindingconflicts".
					if otherNode then
						str = str .. " Overriden by " .. bindingsName
					end
				end
				if str:len() > 0 then
					str = "|cFFFF0000 (" .. str:sub(2, str:len()) .. ")"
				end
				Log.warn(newSequence:sub(1, newSequence:len() - 1) .. ":", (node.name or "nil") .. str)
			else
				printCurrentBindsHelper(node, checkAgainst, newSequence)
			end
		end
	end

	function LeaderKey.printCurrentBindings()
		Log.warn("|c4aacd3FF### Account bindings: ###|r")
		printCurrentBindsHelper(LeaderKey.GetAccountBindingsTree(), {})
		-- printCurrentBindsHelper(LeaderKey.GetAccountBindingsTree(), {["Current Class"] = LeaderKey.GetCurrentClassBindingsTree(), ["Current Spec"] = LeaderKey.GetCurrentSpecBindingsTree()})
		--[[
		Log.warn("|c4aacd3FF### Class bindings: ###|r")
		printCurrentBindsHelper(LeaderKey.GetCurrentClassBindingsTree(), {["Current Spec"] = LeaderKey.GetCurrentSpecBindingsTree})
		Log.warn("|c4aacd3FF### Spec bindings: ###|r")
		printCurrentBindsHelper(LeaderKey.GetCurrentSpecBindingsTree(), {})
		--]]
	end
end

