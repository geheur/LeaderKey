-- ### utility
local function slice(tbl, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

local function tableSize(tbl)
	local count = 0
	for i,v in pairs(tbl) do
		count = count + 1
	end
	return count
end

local function tableIsEmpty(tbl)
	for i,v in pairs(tbl) do
		return true
	end
	return false
end

-- ### secure table insert
--[[
-- TODO does not support tables with nodes with more than one parent.
-- TODO does not support inserting into anything other than the global namespace, _G. Could take another argument that is a string and gets inserted directly into the snippet. It would default to _G.
Serializes a value, for transfer to the restricted environment using a function like secureTableInsert. Most useful for tables, but works with any variable, provided that it is not (or if it is a table, does not contain variables) of type functions, userdata, or thread.
The resulting value will be a string containing instructions to rebuild the value in a comma-separated list.
]]
local secureTableInsert do
	local function serializeValue(value)
		if type(value) == "string" then
			return ("%q"):format(value)
		else -- number, boolean, nil
			return tostring(value)
		end
	end
	local serializeVariableHelper
	local function serializeTableContents(table)
		local serializedContents = ""
		for i,v in pairs(table) do
			local serializedValue = serializeVariableHelper(i, v)
			if serializedValue then
				serializedContents = serializedContents .. serializedValue .. ","
			end
		end
		return serializedContents
	end
	function serializeVariableHelper(name, value)
		value = value or _G[name]
		local valueType = type(value)
		if valueType == "function" or valueType == "userdata" or valueType == "thread" then
			--return nil
			error("key " .. name .. " is not serializable into the secure environment because its value is of type " .. valueType)
		elseif valueType == "table" then
			return string.format("'TABLE',%s,%s'ENDTABLE'", serializeValue(name), serializeTableContents(value))
		else -- string, number, boolean
			return string.format("'VALUE',%s,%s", serializeValue(name), serializeValue(value))
		end
	end
	local escapeForSecureEnvironment do
		local r = {u="\\117", ["{"]="\\123", ["}"]="\\125"} -- "{" and "}" are not allowed in snippets passed to secure environment, "u" is included because "function" is not allowed.
		function escapeForSecureEnvironment(s)
			return (s:gsub("[{}u]", r))
		end
	end
	local function serializeVariable(name, value)
		return escapeForSecureEnvironment(serializeVariableHelper(name, value))
	end
	function secureTableInsert(secureHeader, varName, table)
		local snippet = [[self:Run([=[
			local int i = 1
			local stack = newtable() -- keeps track of the parents.
			stack.current = _G
			stack.parent = nil

			while true do
				local type = select(i, ...)
				if not type then
					if stack.current ~= _G then error("format issue, table incomplete") end
					break -- should be the end of the table.
				elseif type == "ENDTABLE" then
					stack = stack.parent
					if not stack then error("tried to modify above _G") end

					i = i + 1
				elseif type == "TABLE" then
					local name = select(i + 1, ...)

					local createdTable = newtable()
					stack.current[name] = createdTable

					-- push onto stack
					local newstack = newtable()
					newstack.current = createdTable
					newstack.parent = stack
					stack = newstack
					
					i = i + 2
				elseif type == "VALUE" then
					local name = select(i + 1, ...)
					local value = select(i + 2, ...)

					stack.current[name] = value
					
					i = i + 3
				else
					error("invalid type, check serializing f\\117nction: " .. type)
				end
			end
		--]=],%s)]]
		local serializedVar = serializeVariable(varName, table)
		secureHeader:Execute(string.format(snippet, serializedVar))
	end
end

-- ### SavedVariables
if not LeaderKeyData then
	LeaderKeyData = {
		accountBindings = {},
		classBindings = {
--[[
			classId/name/englishname = {
				specID = {},	
			},
--]]
		},
	}
end
if not LeaderKeyCharacterData then -- TODO add to TOC.
	LeaderKeyCharacterData = {
		charactername = {}
	}
end

local ACCOUNT_SCOPE = "accountBindings"
local CLASS_SCOPE = "classBindings"
-- Class given by id/name?
-- Spec given by id.

local function CreateSavedBinding(node, binding)
	return {node = node, binding = binding}
end

local function CreateBinding(bindingsTable, node, ...)
	--for i,v in pairs(bindingsTable) do
		--if v.binding
end

local function CreateAccountBinding(node, ...)
	CreateBinding(LeaderKeyData.accountBindings, node, ...)
end

local function DeleteBinding(bindingsTable, ...)

end


-- ### Bindings table, and manipulating functions.
local SUBMENU = "submenu"
local MACRO = "macro"

local function CreateNode(name, type)
	return {name = name, type = type}
end

local function CreateMacro(name, macro)
	local macroNode = CreateNode(name, MACRO)
	macroNode.macro = macro
	return macroNode
end

local function CreateSubmenu(name)
	local submenu = CreateNode(name, SUBMENU)
	submenu.bindings = {}
	return submenu
end

local function CreateBindingsTree()
	local bindingsTree = CreateSubmenu("Root node")
end
LeaderKey = CreateBindingsTree()

-- Guaranteed to return a submenu node.
local function GetParentNode(...)
	local keySequence = {...}
	keySequence = slice(keySequence, 1, #keySequence - 1)
	i = 1
	local value = keySequence[i]
	local node = LeaderKey

	while value do
		if not node.bindings[value] or node.bindings[value].type ~= SUBMENU then
			return nil
			--error("node does not exist: " .. table.concat(keySequence, " "))
		end
		node = node.bindings[value]
		i = i + 1
		value = keySequence[i]
	end
	return node
end

-- TODO stop taking varargs, take arrays.
local function GetNode(...)
	local keySequence = {...}
	if #keySequence == 0 then return LeaderKey end
	local parent = GetParentNode(...)
	if not parent then return nil end
	local bind = keySequence[#keySequence]
	if not parent or parent.type ~= SUBMENU or not parent.bindings[bind] then
		return nil
	else 
		return parent.bindings[bind]
	end
end

local function PrepareSubmenus(...)
	local bindings = LeaderKey.bindings
	local keySequence = {...}
	keySequence = slice(keySequence, 1, #keySequence - 1)
	local i = 1
	local value = keySequence[i]

	while value do
		if not bindings[value] or bindings[value].type ~= SUBMENU then
			bindings[value] = CreateSubmenu(nil)
		end
		bindings = bindings[value].bindings
		i = i + 1
		value = keySequence[i]
	end
end

local function GetBindingConflicts(...)
	-- TODO

end

local function AddBind(node, ...)
	PrepareSubmenus(...)
	local keySequence = {...}
	local bind = keySequence[#keySequence]
	GetParentNode(...).bindings[bind] = node
end

-- TODO is throwing errors all the time that useful? Maybe just return an error value or something.

-- Also deletes any childless parent submenus.
local function DeleteNode(...)
	local keySequence = {...}
	local bind = keySequence[#keySequence]
	keySequence = slice(keySequence, 1, #keySequence - 1)

	local node = LeaderKey
	local i = 1
	local value = keySequence[i]

	local lastStraightTreeParent -- The last submenu which only has children which are not submenus with more than 1 child binding.
	local lastStraightTreeBind
	local deleteAllBindings = true
	if tableSize(node.bindings) == 1 then lastStraightTreeParent = "not nil" end

	while value do
		if not node.bindings[value] or node.bindings[value].type ~= SUBMENU then
			--error("Binding '" .. table.concat(keySequence, " ") .. "' does not exist.")
			return false, false
		end

		local nextNode = node.bindings[value]

		if tableSize(nextNode.bindings) == 1 then
			if not lastStraightTreeParent then
				lastStraightTreeParent = node
				lastStraightTreeBind = value
				deleteAllBindings = false
			end
		else
			lastStraightTreeParent = nil
			deleteAllBindings = false
		end

		node = nextNode
		i = i + 1
		value = keySequence[i]
	end

	if not node.bindings[bind] then
		--error("Binding '" .. table.concat(keySequence, " ") .. "' does not exist.")
		return false, false
	end

	if deleteAllBindings then
		LeaderKey.bindings = {}
	end
	if lastStraightTreeBind then
		lastStraightTreeParent.bindings[lastStraightTreeBind] = nil
		return true, true
	else
		node.bindings[bind] = nil
		return true, false
	end
end

local function NameNode(name, ...)
	local node = GetNode(...)
	node.name = name
end

-- ### Core keybind setup code.
AfterLeaderKeyHandlerFrame = CreateFrame("BUTTON", "After Leader Key Handler Frame", nil, "SecureHandlerClickTemplate,SecureActionButtonTemplate")

AfterLeaderKeyHandlerFrame:RegisterForClicks(--[["AnyUp", ]]"AnyDown")

secureTableInsert(AfterLeaderKeyHandlerFrame, "SUBMENU", SUBMENU)
secureTableInsert(AfterLeaderKeyHandlerFrame, "MACRO", MACRO)

AfterLeaderKeyHandlerFrame:Execute([===[
	Bindings = newtable()

	currentBindings = nil -- keeps track of progress in the sequence. nil means no sequence is in progress.

	currentSequence = ""

	OnClick = [[
	if not currentBindings then currentBindings = Bindings end
	local button, down = ...

	if button == "ESCAPE" then
		print("|cFFFF0000Key sequence ESCAPE|r") -- TODO do outside.
		currentBindings = nil
		self:ClearBindings()
		return
	end

	for bind,node in pairs(currentBindings) do
		if bind == button then
			if node.type == MACRO then
				currentBindings = nil
				currentSequence = ""
				self:ClearBindings()

				self:SetAttribute("type", "macro")
				self:SetAttribute("macrotext", node.macro)

				print("|cFFFF00FF-> casting spell:", node.macro, "|r") -- TODO do outside.
			elseif node.type == SUBMENU then
				currentBindings = node.bindings
				currentSequence = currentSequence .. button .. " "
				self:ClearBindings()
				self:SetBindingClick(true, "ESCAPE", self:GetName(), "ESCAPE")
				for newBind in pairs(currentBindings) do
					self:SetBindingClick(true, newBind, self:GetName(), newBind)
				end

				self:SetAttribute("type", nil)

				self:CallMethod("printOptions", currentSequence) -- TODO consider doing something like this as much as possible.
			end
		end
	end
	--]]
  --]===]
)
AfterLeaderKeyHandlerFrame:WrapScript(AfterLeaderKeyHandlerFrame, "OnClick", "self:Run(OnClick, button, down) return true", "print('|cFFFF0000After onclick wrap called.|r') self:SetAttribute('type', nil)") -- TODO why doesn't the after script run?
LeaderKeyOverrideBindOwner = CreateFrame("BUTTON", "Leader Key Override Bind Owner", nil, "SecureHandlerBaseTemplate")

-- Updates keybind tree in AfterLeaderKeyHandlerFrame's restricted environment, and makes sure leader keys are bound. Out of combat only, obviously.
local function UpdateKeybinds()
	LeaderKeyOverrideBindOwner:Execute("self:ClearBindings()")
	for i,v in pairs(LeaderKey.bindings) do
		SetOverrideBindingClick(LeaderKeyOverrideBindOwner, true, i, AfterLeaderKeyHandlerFrame:GetName(), i)
	end

	secureTableInsert(AfterLeaderKeyHandlerFrame, "Bindings", LeaderKey.bindings)
end


-- ### user interface display code.
-- Takes a string which is the buttons pressed so far separated by spaces.
function AfterLeaderKeyHandlerFrame:printOptions(sequenceStr)
	-- TODO print something special when submenu has no binds.
	local keySequence = {}
	for key in sequenceStr:gmatch("%S+") do
		keySequence[#keySequence + 1] = key
	end
	local node = GetNode(unpack(keySequence))

	print("|c4aacd3FF##### switched table:", node.name, "#####|r")

	if not tableIsEmpty(node.bindings) then
		print("|cFFFF0000No bindings, press escape to quit. This should not happen.|r")
	end

	-- TODO color differently depending on type.
	for nextBind,nextNode in pairs(node.bindings) do
		if nextNode.type == MACRO then
			print(nextBind .. ": " .. (nextNode.name or nextNode.macro)) -- TODO color differently if name vs macro contents.
		end
	end
	for nextBind,nextNode in pairs(node.bindings) do
		if nextNode.type == SUBMENU then
			print(nextBind .. " -> |c4aacd3FF" .. (nextNode.name or "[no name]") .. "|r")
		end
	end
end

-- ### Slash commands.
local function registerSlashCommand(id, names, func)
  for i,v in ipairs(names) do
    _G["SLASH_" .. id .. i] = v
  end
  SlashCmdList[id] = func
end

local function parseArgs(txt)
	local args = {}
	local inSingleQuote = false
	for i in txt:gmatch("%S+") do
		if inSingleQuote then
			args[#args] = args[#args] .. " " .. i
		else
			args[#args + 1] = i
		end
		if i:find("'") == 1 then
			inSingleQuote = true
			args[#args] = args[#args]:sub(2)
		end
		if i:find("'") == i:len() then
			inSingleQuote = false
			args[#args] = args[#args]:sub(1, args[#args]:len() - 1):gsub("'", "\\'")
		end
		-- single quote on its own will break this most likely.
	end

	return args
end

registerSlashCommand("BIND", {"/bind"}, function() bindLeaderKey() end)
registerSlashCommand("UNBIND", {"/unbind"}, function() unbindLeaderKey() end)
registerSlashCommand("LEADERKEY_MAP", {"/lkmap"},
                     function(txt, editbox)
								local args = parseArgs(txt)
								--old_CreateBind(args[1], unpack(slice(args, 2)))
								local node = CreateNode(nil, MACRO)
								node.macro = args[1]
								AddBind(node, unpack(slice(args, 2)))
								UpdateKeybinds()
                     end
)
registerSlashCommand("LEADERKEY_UNMAP", {"/lkunmap"},
                     function(txt, editbox)
								local args = parseArgs(txt)
								--old_DeleteNode(unpack(args))
								DeleteNode(unpack(args))
								UpdateKeybinds()
                     end
)

-- ### Register event handlers
local function registerEventHandlers(events)
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(self, event, ...)
	 events[event](self, ...); -- call one of the functions above
	end);
	for k, v in pairs(events) do
	 frame:RegisterEvent(k); -- Register all events for which handlers have been defined
	end
end

local events = {}
function events:PLAYER_ENTERING_WORLD(...)
	if ViragDevTool_AddData then
		ViragDevTool_AddData(LeaderKey.bindings, "LKMAP")
	end
end
registerEventHandlers(events)

-- Test code. TODO remove this eventually.
do
	local testTable = "dog's"
	local testTable2 = {
		subtable1 = {
			value1 = "hello",
			value2 = 3,
		},
		value3 = "value3",
		subtable2 = {
			value4 = true,
		},
	}
	registerSlashCommand("TEST", {"/test"}, function() secureTableInsert(AfterLeaderKeyHandlerFrame, "testTable", testTable) end)
end

registerSlashCommand("RL", {"/rl"}, SlashCmdList["RELOAD"])

local function rsc(id,  txt)
	SlashCmdList[id](txt, nil)
end

-- ### set up some test keybinds.
do
	local function kssplit(str)
		local split = {}
		for i in str:gmatch("%S+") do
			split[#split + 1] = i
		end
		return unpack(split)
	end

	do
		local result = {kssplit('A B')}
		assert(result[1] == 'A')
		assert(result[2] == 'B')
	end

	local actual_GetNode = GetNode
	local function GetNode(str)
		return actual_GetNode(kssplit(str))
	end
	local actual_GetParentNode = GetParentNode
	local function GetParentNode(str)
		return actual_GetParentNode(kssplit(str))
	end
	local actual_CreateBind = AddBind
	local function AddBind(str, node)
		node = node or CreateNode(nil, MACRO)
		actual_CreateBind(node, kssplit(str))
	end
	local actual_NameNode = NameNode
	local function NameNode(str, name)
		actual_NameNode(name, kssplit(str))
	end
	local actual_DeleteNode = DeleteNode
	local function DeleteNode(str)
		actual_DeleteNode(kssplit(str))
	end

	-- Test GetNode and GetParentNode.
	LeaderKey = {
		name = "Root node",
		type = SUBMENU,
		bindings = {
			A = { name = "A", type = SUBMENU, bindings = {
				B = { name = "B", type = SUBMENU, bindings = {
					C = { name = "C", type = MACRO },
				}},
				D = { name = "D", type = SUBMENU, bindings = {
					E = { name = "E", type = MACRO },
				}},
			}},
			F = { name = "F", type = MACRO, },
		}
	}
	assert(GetNode('') == LeaderKey)
	assert(GetParentNode('A') == LeaderKey)
	assert(GetParentNode('') == LeaderKey)
	assert(GetNode('A') == LeaderKey.bindings.A)
	assert(GetNode('A B') == LeaderKey.bindings.A.bindings.B)
	assert(GetNode('A B C') == LeaderKey.bindings.A.bindings.B.bindings.C)
	assert(GetNode('A D') == LeaderKey.bindings.A.bindings.D)
	assert(GetNode('A D E') == LeaderKey.bindings.A.bindings.D.bindings.E)
	assert(GetNode('F') == LeaderKey.bindings.F)
	assert(GetParentNode('A B') == LeaderKey.bindings.A)
	assert(GetParentNode('A B C') == LeaderKey.bindings.A.bindings.B)
	assert(GetParentNode('A D') == LeaderKey.bindings.A)
	assert(GetParentNode('A D E') == LeaderKey.bindings.A.bindings.D)
	assert(GetParentNode('F') == LeaderKey)
	assert(not GetNode('G'))
	assert(not GetNode('A B G'))
	assert(not GetNode('A B C G'))
	--assert(not GetParentNode('G')) -- I'll let this one go.
	--assert(not GetParentNode('A B G')) -- I'll let this one go.
	--assert(not GetParentNode('A B C G')) -- I'll let this one go.
	assert(not GetParentNode('A B C G H'))

	assert(GetNode('') == LeaderKey)

	-- Test AddBind.
	CreateBindingsTree()
	local node = CreateMacro("testMacro", "/notacommand")
	AddBind('A B', node)
	assert(GetNode('A B') == node)
	AddBind('A', node)
	assert(not GetNode('A B'))
	assert(GetNode('A') == node)
	AddBind('A B C', node)
	assert(GetNode('A B C') == node)

	-- Test.
	CreateBindingsTree()
	AddBind('A B C')
	NameNode('A', 'A')
	NameNode('A B', 'B')
	AddBind('A E')
	NameNode('A E', 'E')

	-- Test bind deletion.
	CreateBindingsTree()
	AddBind('A B C')
	AddBind('A B D')
	DeleteNode('A B C')
	assert(not GetNode('A B C'))
	assert(GetNode('A B D'))

	-- test non-sequence bind deletion.
	CreateBindingsTree()
	AddBind('A')
	DeleteNode('A')
	assert(not GetNode('A'))

	-- Tests deletion of orphaned parents.
	CreateBindingsTree()
	AddBind('A B C')
	NameNode('A', 'A')
	NameNode('A B', 'B')
	AddBind('A E')
	DeleteNode('A B C')
	assert(GetNode('A E'))
	assert(not GetNode('A B'))
	assert(not GetNode('A B C'))

	assert(not GetNode('A B'))
	-- Tests deletion of original bind.
	CreateBindingsTree()
	AddBind('A B C')
	DeleteNode('A B C')
	assert(not GetNode('A'))

	-- Set up some nice defaults for ingame testing.
	CreateBindingsTree()
	AddBind('K T K', CreateMacro("Katy (Mailbox, 10 mins)", "/use Katy's Stampwhistle"))
	--AddBind('K C', CreateMacro("Pyroblast", "/use Pyroblast"))
	--AddBind('K B', CreateMacro("Fireball", "/use Fireball"))
	AddBind('K M S L', CreateMacro("Swift Lovebird", "/use Swift Lovebird"))
	AddBind('K C M', CreateMacro("Mounts", "/script ToggleCollectionsJournal(1)"))
	AddBind('K C P', CreateMacro("Pets", "/script ToggleCollectionsJournal(2)"))
	AddBind('K C T', CreateMacro("Toys", "/script ToggleCollectionsJournal(3)"))
	AddBind('K C H', CreateMacro("Heirlooms", "/script ToggleCollectionsJournal(4)"))
	AddBind('K C A', CreateMacro("Appearances", "/script ToggleCollectionsJournal(5)"))
	NameNode('K', "K menu")
	NameNode('K C', "Collections")
	NameNode('K M', "Mounts")
	NameNode('K T', "Toys")

	UpdateKeybinds()
end
--rsc("LEADERKEY_MAP", "'/script ToggleCollectionsJournal(1)' K C M")

