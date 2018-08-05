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
			local secureTableInsertStack = newtable() -- keeps track of the parents.
			secureTableInsertStack.current = _G
			secureTableInsertStack.parent = nil

			while true do
				local type = select(i, ...)
				if not type then
					if secureTableInsertStack.current ~= _G then error("format issue, table incomplete") end
					break -- should be the end of the table.
				elseif type == "ENDTABLE" then
					secureTableInsertStack = secureTableInsertStack.parent
					if not secureTableInsertStack then error("tried to modify above _G") end

					i = i + 1
				elseif type == "TABLE" then
					local name = select(i + 1, ...)

					local createdTable = newtable()
					secureTableInsertStack.current[name] = createdTable

					-- push onto secureTableInsertStack
					local newstack = newtable()
					newstack.current = createdTable
					newstack.parent = secureTableInsertStack
					secureTableInsertStack = newstack
					
					i = i + 2
				elseif type == "VALUE" then
					local name = select(i + 1, ...)
					local value = select(i + 2, ...)

					secureTableInsertStack.current[name] = value
					
					i = i + 3
				else
					error("invalid type, check serializing f\\117nction: " .. type)
				end
			end
		--]=],%s)]]
		local serializedVar = serializeVariable(varName, table)
		snippet = string.format(snippet, serializedVar)

		print("snippet length:", snippet:len())

		local count = 0
		for i in string.gmatch(serializedVar, ",") do
			count = count + 1
		end
		print("num commas:", count)

		secureHeader:Execute(snippet)
	end
end

-- ### start of addon code
LeaderKey = {}

local debug = false
local function debugPrint(...)
	if not debug then return end
	print("|cFFFFA500[LeaderKey]:", ...)
end

local function warning(...)
	local bla = slice({...}, 2)
	print("|cFFFFA500[LeaderKey]:" .. select(1, ...), unpack(bla))
end

local function info(...)
	local bla = slice({...}, 2)
	print("[LeaderKey]: " .. select(1, ...), unpack(bla))
end

-- ### Bindings table, and manipulating functions.
local SUBMENU = "submenu"
local MACRO = "macro"

local function CreateNode(name, type)
	return {name = name, type = type}
end

local function CreateMacroNode(name, macro)
	name = name or "MACRO: " .. macro
	local macroNode = CreateNode(name, MACRO)
	macroNode.macro = macro
	return macroNode
end

local function CreateSpellNode(name, spellName)
	local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellName)
	if not name then
		error("|cFFFFA500Could not find spell " .. spellName .. ".|r") -- TODO do not error here. Either that or catch it.
	end
	return CreateMacroNode(name, '/use ' .. spellName)
end

local function CreateSubmenu(name)
	local submenu = CreateNode(name, SUBMENU)
	submenu.bindings = {}
	return submenu
end

local BindingsTree = {type = SUBMENU}
BindingsTree.__index = BindingsTree

function BindingsTree:new()
	return BindingsTree:cast({})
end

function BindingsTree:cast(toCast)
	setmetatable(toCast, self)
	if toCast.bindings == nil then toCast.bindings = {} end
	return toCast
end

-- Guaranteed to return a submenu node.
function BindingsTree:GetParentNode(keySequence)
	keySequence = slice(keySequence, 1, #keySequence - 1)
	i = 1
	local value = keySequence[i]
	local node = self

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

function BindingsTree:GetNode(keySequence)
	if #keySequence == 0 then return self end
	local parent = self:GetParentNode(keySequence)
	if not parent then return nil end
	local bind = keySequence[#keySequence]
	if not parent or parent.type ~= SUBMENU or not parent.bindings[bind] then
		return nil
	else 
		return parent.bindings[bind]
	end
end

function BindingsTree:PrepareSubmenus(keySequence)
	local bindings = self.bindings
	keySequence = slice(keySequence, 1, #keySequence - 1)
	local i = 1
	local value = keySequence[i]

	while value do
		if not bindings[value] or bindings[value].type ~= SUBMENU then
			bindings[value] = CreateSubmenu(table.concat(slice(keySequence, 1, i), " "))
		end
		bindings = bindings[value].bindings
		i = i + 1
		value = keySequence[i]
	end
	return bindings
end

function BindingsTree:GetBindingConflicts(keySequence)
	-- TODO
	error("NYI")

end

function BindingsTree:AddBind(node, keySequence)
	local bindings = self:PrepareSubmenus(keySequence)
	local bind = keySequence[#keySequence]
	bindings[bind] = node
end

-- TODO is throwing errors all the time that useful? Maybe just return an error value or something.

-- Also deletes any childless parent submenus.
function BindingsTree:DeleteNode(keySequence)
	local bind = keySequence[#keySequence]
	keySequence = slice(keySequence, 1, #keySequence - 1)

	local node = self
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
		self.bindings = {}
	end
	if lastStraightTreeBind then
		lastStraightTreeParent.bindings[lastStraightTreeBind] = nil
		return true, true
	else
		node.bindings[bind] = nil
		return true, false
	end
end

function BindingsTree:NameNode(name, keySequence)
	local node = self:GetNode(keySequence)
	if not node then warning("Node " .. table.concat(keySequence, " ") .. " does not exist."); return false end
	node.name = name
	return true
end

local ViragCurrentBindingsPointer
local CurrentBindings
local function CreateBindingsTree()
	CurrentBindings = BindingsTree:new()
	ViragCurrentBindingsPointer = CurrentBindings
end
CreateBindingsTree()

-- ### Core keybind setup code.
AfterLeaderKeyHandlerFrame = CreateFrame("BUTTON", "After Leader Key Handler Frame", nil, "SecureHandlerClickTemplate,SecureActionButtonTemplate")

AfterLeaderKeyHandlerFrame:RegisterForClicks(--[["AnyUp", ]]"AnyDown")

secureTableInsert(AfterLeaderKeyHandlerFrame, "SUBMENU", SUBMENU)
secureTableInsert(AfterLeaderKeyHandlerFrame, "MACRO", MACRO)

AfterLeaderKeyHandlerFrame:Execute([===[
	Bindings = newtable()

	currentBindings = nil -- keeps track of progress in the sequence. nil means no sequence is in progress.

	currentSequence = ""

	ClearSequenceInProgress = [[
		currentBindings = nil
		currentSequence = ""
		self:ClearBindings()
	--]]

	OnClick = [[
	if not currentBindings then currentBindings = Bindings end
	local button, down = ...

	if button == "ESCAPE" then
		print("|cFFFF0000Key sequence ESCAPE|r") -- TODO do outside.
		self:Run(ClearSequenceInProgress)
		return
	end

	for bind,node in pairs(currentBindings) do
		if bind == button then
			if node.type == MACRO then
				self:Run(ClearSequenceInProgress)

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

local function CopyInBindingsTree(currentBindingsTree, bindingsTree)
	for key,node in pairs(bindingsTree.bindings) do
		local currentNode = currentBindingsTree.bindings[key]
		if node.type == SUBMENU then
			if currentNode ~= nil and currentNode.type ~= SUBMENU then
				print("|cFFFFA500LeaderKey: Warning: overwrote binding " .. (key or "") .. ": " .. (currentNode.name or "nil") .. " in submenu " .. (currentBindingsTree.name or "nil") .. "|r")
			end
			if currentNode == nil or currentNode.type ~= SUBMENU then
				currentBindingsTree.bindings[key] = CreateSubmenu(node.name) -- TODO copy function?
			end
			CopyInBindingsTree(currentBindingsTree.bindings[key], node)
		else
			if currentNode ~= nil then
				print("|cFFFFA500LeaderKey: Warning: overwrote binding " .. (key or "") .. ": " .. (currentNode.name or "nil") .. " in submenu " .. (currentBindingsTree.name or "nil") .. "|r")
			end
			debugPrint("binding", currentBindingsTree.name or "", key, "to", node.name)
			currentBindingsTree.bindings[key] = node -- TODO make sure no one changes this node...
		end
	end
end

local function BuildCurrentBindingsTree()
	CreateBindingsTree()

	debugPrint("adding account bindings")
	CopyInBindingsTree(CurrentBindings, LeaderKey.GetAccountBindingsTree())
	debugPrint("adding class bindings")
	CopyInBindingsTree(CurrentBindings, LeaderKey.GetCurrentClassBindingsTree())
	debugPrint("adding spec bindings")
	CopyInBindingsTree(CurrentBindings, LeaderKey.GetCurrentSpecBindingsTree())
end

-- Updates keybind tree in AfterLeaderKeyHandlerFrame's restricted environment, and makes sure leader keys are bound. Out of combat only, obviously.
local function UpdateKeybinds()
	BuildCurrentBindingsTree()

	LeaderKeyOverrideBindOwner:Execute("self:ClearBindings()")
	for i,v in pairs(CurrentBindings.bindings) do
		SetOverrideBindingClick(LeaderKeyOverrideBindOwner, true, i, AfterLeaderKeyHandlerFrame:GetName(), i)
	end

	secureTableInsert(AfterLeaderKeyHandlerFrame, "Bindings", CurrentBindings.bindings)
	AfterLeaderKeyHandlerFrame:Execute("self:Run(ClearSequenceInProgress)")
end


-- ### user interface display code.
-- Takes a string which is the buttons pressed so far separated by spaces.
function AfterLeaderKeyHandlerFrame:printOptions(sequenceStr)
	-- TODO print something special when submenu has no binds.
	local keySequence = {}
	for key in sequenceStr:gmatch("%S+") do
		keySequence[#keySequence + 1] = key
	end
	local node = CurrentBindings:GetNode(keySequence)
	if not node then warning("Node " .. table.concat(keySequence, " ") .. " does not exist."); return end

	print("|c4aacd3FF#####", (node.name or "nil"), "#####|r")

	if not tableIsEmpty(node.bindings) then
		print("|cFFFF0000No bindings, press escape to quit. This should not happen.|r")
	end

	-- TODO color differently depending on type.
	for nextBind,nextNode in pairs(node.bindings) do
		if nextNode.type == MACRO then
			print(nextBind .. " -> |cFFFFA500" .. (nextNode.name or nextNode.macro or "nil") .. "|r") -- TODO color differently if name vs macro contents.
		end
	end
	for nextBind,nextNode in pairs(node.bindings) do
		if nextNode.type == SUBMENU then
			print(nextBind .. " -> |c4aacd3FF" .. (nextNode.name or "[no name]") .. "|r")
		end
	end
end

local function printBindings(bindingsTree, sequence)
	sequence = sequence or ""
	for key,node in pairs(bindingsTree.bindings) do
		local newSequence = sequence .. key .. " "
		if node.type ~= SUBMENU then
			warning(newSequence:sub(1, newSequence:len() - 1) .. ":", node.name)
		else
			printBindings(node, newSequence)
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
	local start = nil
	local breakLoop = false;
	local i = 1
	while i <= #txt do
		local c = txt:sub(i,i)
		if c == " " then
			if start then
				args[#args + 1] = txt:sub(start,i - 1)
				start = nil
			end
			-- continue
		elseif c == "'" or c == '"' then
			if start then
				args[#args + 1] = txt:sub(start,i - 1)
				start = nil
			end
			i = i + 1
			start = i
			while i <= #txt do
				local c2 = txt:sub(i,i)
				if c2 == c then
					args[#args + 1] = txt:sub(start,i - 1)
					start = nil
					break
				elseif c2 == "\\" then
					i = i + 1
				end
				i = i + 1
			end
			if start then warning("unclosed " .. c); return nil end
		else
			if c == '\\' then
				i = i + 1
				if i > #txt then warning("unclosed \\"); return nil end
			end
			if not start then
				start = i
			end
		end
		i = i + 1
	end
	if start then
		args[#args + 1] = txt:sub(start,i - 1)
		start = nil
	end

	return args
end

local function parseArgs2(txt)
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
			args[#args] = args[#args]:sub(1, args[#args]:len() - 1)
		end
		-- single quote on its own will break this most likely.
	end

	debugPrint("Args:")
	for i,v in pairs(args) do
		debugPrint(i,v)
	end

	return args
end

local macrotype = "macro"
local spelltype = "spell"
local function SlashCommandMapBind(bindingsTree, txt)
	local args = parseArgs(txt)
	if not args then return end
	local type = args[1]
	local name = args[2]
	if name == "_" then name = nil end
	local contents = args[3]
	local keySequence = slice(args, 4)

	local node
	if type == macrotype then
		node = CreateMacroNode(name, contents)
	elseif type == spelltype then
		node = CreateSpellNode(name, contents)
		ViragDevTool_AddData(node, "bla")
	else
		warning("Unknown type \"" .. type .. "\"")
		return
	end

	LeaderKey.CreateBinding(bindingsTree, node, keySequence)
	UpdateKeybinds()
	info("Created bind " .. table.concat(keySequence, " ") .. " to " .. name)
end

local function SlashCommandMapUnbind(bindingsTree, txt)
	local keySequence = parseArgs(txt)
	if not keySequence then return end

	LeaderKey.DeleteNode(bindingsTree, keySequence)
	UpdateKeybinds()
	info("Deleted node " .. table.concat(keySequence, " ") .. " (or, it didn't exist in the first place)")
end

local function SlashCommandNameNode(bindingsTree, txt)
	local args = parseArgs(txt)
	if not args then return end
	local name = args[1] or "nil"
	local keySequence = slice(args, 2)

	local successful = LeaderKey.NameNode(bindingsTree, name, keySequence)
	if successful then
		info("Named node " .. table.concat(keySequence, " ") .. " to " .. name)
	end
	UpdateKeybinds()
end

registerSlashCommand("LEADERKEY_ACCOUNT_MAP", {"/lkamap"},
                     function(txt, editbox)
								SlashCommandMapBind(LeaderKey.GetAccountBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_CLASS_MAP", {"/lkclmap"},
                     function(txt, editbox)
								SlashCommandMapBind(LeaderKey.GetCurrentClassBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_SPEC_MAP", {"/lksmap"},
                     function(txt, editbox)
								SlashCommandMapBind(LeaderKey.GetCurrentSpecBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_ACCOUNT_UNMAP", {"/lkaunmap"},
                     function(txt, editbox)
								SlashCommandMapUnbind(LeaderKey.GetAccountBindingsTree(), txt)
								UpdateKeybinds()
                     end
)
registerSlashCommand("LEADERKEY_CLASS_UNMAP", {"/lkclunmap"},
                     function(txt, editbox)
								SlashCommandMapUnbind(LeaderKey.GetCurrentClassBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_SPEC_UNMAP", {"/lksunmap"},
                     function(txt, editbox)
								SlashCommandMapUnbind(LeaderKey.GetCurrentSpecBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_ACCOUNT_NAME", {"/lkaname"},
                     function(txt, editbox)
								SlashCommandNameNode(LeaderKey.GetAccountBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_CLASS_NAME", {"/lkclname"},
                     function(txt, editbox)
								SlashCommandNameNode(LeaderKey.GetCurrentClassBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_SPEC_NAME", {"/lksname"},
                     function(txt, editbox)
								SlashCommandNameNode(LeaderKey.GetCurrentSpecBindingsTree(), txt)
                     end
)
-- Delete this binding in the highest priority table. TODO.
registerSlashCommand("LEADERKEY_UNMAP", {"/lkunmap"},
                     function(txt, editbox)
								error("NYI")
								local args = parseArgs(txt)
                     end
)
registerSlashCommand("LEADERKEY_PRINT_CURRENT", {"/lkpc"},
                     function(txt, editbox)
								LeaderKey.PrintCurrentBinds(LeaderKey.GetCurrentBindingsTree())
                     end
)

-- ### public api.

-- TODO maybe remove - is this useful?
function LeaderKey.GetCurrentBindingsTree()
	return CurrentBindings
end

function LeaderKey.UpdateCurrentBindings()
	UpdateKeybinds()
end

function LeaderKey.CreateBinding(bindingsTree, node, keySequence)
	-- TODO check existance of binding? Could also do that somewhere else.

	bindingsTree:AddBind(node, keySequence)

	--UpdateKeybinds() -- TODO do I want this here?
end

function LeaderKey.DeleteNode(bindingsTree, keySequence)
	bindingsTree:DeleteNode(keySequence)

	--UpdateKeybinds() -- TODO do I want this here?
end

function LeaderKey.NameNode(bindingsTree, name, keySequence)
	return bindingsTree:NameNode(name, keySequence)
end

function LeaderKey.GetAccountBindingsTree()
	if LeaderKeyData.accountBindings then
		LeaderKeyData.accountBindings = BindingsTree:cast(LeaderKeyData.accountBindings)
	else
		LeaderKeyData.accountBindings = BindingsTree:new()
	end
	return LeaderKeyData.accountBindings
end

local ALL_SPECS = "ALL"
function LeaderKey.GetSpecBindingsTree(class, spec)
	LeaderKeyData.classBindings[class] = LeaderKeyData.classBindings[class] or {}
	if LeaderKeyData.classBindings[class][spec] then
		LeaderKeyData.classBindings[class][spec] = BindingsTree:cast(LeaderKeyData.classBindings[class][spec])
	else
		LeaderKeyData.classBindings[class][spec] = BindingsTree:new()
	end
	return LeaderKeyData.classBindings[class][spec]
end

function LeaderKey.GetClassBindingsTree(class)
	return LeaderKey.GetSpecBindingsTree(class, ALL_SPECS)
end

function LeaderKey.GetCurrentSpecBindingsTree()
	return LeaderKey.GetSpecBindingsTree(select(2, UnitClass("player")), GetSpecialization()) -- 2 is the localization-independent name.
end

function LeaderKey.GetCurrentClassBindingsTree()
	return LeaderKey.GetClassBindingsTree(select(2, UnitClass("player"))) -- 2 is the localization-independent name.
end

function LeaderKey.PrintBinds(bindingsTree)
	warning("Account bindings:")
	printBindings(LeaderKey.GetAccountBindingsTree)
end

local function printCurrentBindsHelper(bindingsTree, checkAgainst, sequence)
	sequence = sequence or ""
	for key,node in pairs(bindingsTree.bindings) do
		local newSequence = sequence .. key .. " "
		if node.type ~= SUBMENU then
			local str = ""
			for bindingsName,otherBindingsTree in pairs(checkAgainst) do
				local split = {}
				for i in newSequence:gmatch("%S+") do
					split[#split + 1] = i
				end
				--debugPrint("looking at binding " .. table.concat(split, " ") .. " for tree " .. bindingsName)
				local otherNode = otherBindingsTree:GetNode(split) -- TODO can't use getnode - need something like "bindingconflicts".
				if otherNode then
					str = str .. " Overriden by " .. bindingsName
				end
			end
			if str:len() > 0 then
				str = "|cFFFF0000 (" .. str:sub(2, str:len()) .. ")"
			end
			warning(newSequence:sub(1, newSequence:len() - 1) .. ":", (node.name or "nil") .. str)
		else
			printCurrentBindsHelper(node, checkAgainst, newSequence)
		end
	end
end

function LeaderKey.PrintCurrentBinds()
	warning("Account bindings:")
	printCurrentBindsHelper(LeaderKey.GetAccountBindingsTree(), {["Current Class"] = LeaderKey.GetCurrentClassBindingsTree(), ["Current Spec"] = LeaderKey.GetCurrentSpecBindingsTree()})
	warning("Class bindings:")
	printCurrentBindsHelper(LeaderKey.GetCurrentClassBindingsTree(), {["Current Spec"] = LeaderKey.GetCurrentSpecBindingsTree})
	warning("Spec bindings:")
	printCurrentBindsHelper(LeaderKey.GetCurrentSpecBindingsTree(), {})
end

-- NYI
--[[
function LeaderKey.GetCharacterBindingsTree(node, keySequence)
	LeaderKeyCharacterData = LeaderKeyCharacterData or {}
	LeaderKeyCharacterData.bindings = LeaderKeyCharacterData.bindings or BindingsTable:new()
	return LeaderKeyCharacterData.bindings
end
--]]

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
-- TODO remove (debug)
function events:PLAYER_ENTERING_WORLD(...)
	if ViragDevTool_AddData then
		ViragDevTool_AddData(ViragCurrentBindingsPointer.bindings, "LKMAP")
		ViragDevTool_AddData(LeaderKeyData.accountBindings, "LKMAP_ACCOUNT")
		ViragDevTool_AddData(LeaderKeyData.classBindings, "LKMAP_CLASS")
	end
end
do
	local addonIsLoaded = false
	function events:ADDON_LOADED(...)
		if addonIsLoaded then return end

		local debugWipe = false
		if debugWipe then
			LeaderKeyData = nil
		end

		LeaderKeyData = LeaderKeyData or {}
		LeaderKeyData.classBindings = LeaderKeyData.classBindings or {}
		LeaderKey.UpdateCurrentBindings()
		addonIsLoaded = true
	end
end
function events:PLAYER_SPECIALIZATION_CHANGED(...)
	debugPrint("PLAYER_SPECIALIZATION_CHANGED new spec", GetSpecialization())
	LeaderKey.UpdateCurrentBindings()
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
	registerSlashCommand("TEST", {"/test"}, function(txt) local bla = parseArgs(txt); if not bla then print("returned nil"); return end; for i,v in pairs(bla) do warning(i,v) end end)
end

registerSlashCommand("RL", {"/rl"}, SlashCmdList["RELOAD"])

