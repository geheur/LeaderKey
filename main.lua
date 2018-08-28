-- ### utility
local function slice(tbl, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

local debug = true
local function debugPrintInternal(prefix, ...)
	if not debug then return end

	local str = "|cFFFFA500" .. prefix
	for _,arg in ipairs({...}) do
		str = str .. " " .. tostring(arg)
	end

	ChatFrame5:AddMessage(str)
end
local function debugPrint(...)
	if not debug then return end
	debugPrintInternal("[LeaderKey]:", ...)
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
		return false
	end
	return true
end

local function info(...)
	local bla = slice({...}, 2)
	print("[LeaderKey]: " .. select(1, ...), unpack(bla))
end

local function warning(...)
	local bla = slice({...}, 2)
	print("|cFFFFA500[LeaderKey]:" .. select(1, ...), unpack(bla))
end

local function errorp(...)
	local bla = slice({...}, 2)
	print("|cFFFF0000[LeaderKey]:" .. select(1, ...), unpack(bla))
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
local secureTableInsert do
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
	function secureTableInsert(secureHeader, varName, table)
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

-- ### Colors
local color = {}
color.submenu = "|c4aacd3ff"
color.helm_submenu = "|c1051baff"
color.macro = "|cffffa500"
color.castPrint = "|cffff00ff"

-- ### Node constructors.

local SUBMENU = "submenu"
local HELM_SUBMENU = "helm-submenu"
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
	return CreateMacroNode(name, '/use ' .. spellName)
end

local function CreateSubmenu(name)
	local submenu = CreateNode(name, SUBMENU)
	submenu.bindings = {}
	return submenu
end

local function CreateHelmSubmenu(name)
	local helmMenu = CreateNode(name, HELM_SUBMENU)
	helmMenu.bindings = {}
	return helmMenu
end

-- ### BindingsTree class.

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

local function isMenu(node)
	return node.type == SUBMENU or node.type == HELM_SUBMENU
end

function BindingsTree:GetParentNode(keySequence)
	keySequence = slice(keySequence, 1, #keySequence - 1)
	i = 1
	local value = keySequence[i]
	local node = self

	while value do
		if not node.bindings[value] or not isMenu(node.bindings[value]) then
			return nil
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
	if not parent or not isMenu(parent) or not parent.bindings[bind] then
		return nil
	else 
		if parent.type == SUBMENU then
			return parent.bindings[bind]
		elseif parent.type == HELM_SUBMENU then
			for binding,node in pairs(parent.bindings) do
				if node.name == bind then
					return node
				end
			end
		end
	end
end

function BindingsTree:PrepareSubmenus(keySequence)
	local bindings = self.bindings
	keySequence = slice(keySequence, 1, #keySequence - 1)
	local i = 1
	local value = keySequence[i]

	while value do
		if not bindings[value] or not isMenu(bindings[value]) then
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
		if not node.bindings[value] or not isMenu(node.bindings[value]) then
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
		debugPrint("result 1")
		--self.bindings = {}
	end
	if lastStraightTreeBind then
		debugPrint("result 2")
		lastStraightTreeParent.bindings[lastStraightTreeBind] = nil
		return true, true
	else
		debugPrint("result 3")
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

local helmMenuSearchSnippet = [[

	local list = newtable()

	for bind,node in pairs(bindings) do
		if node.name == nil then
			self:CallMethod("debugPrint", "Helm Menu Search: found node with nil name")
		end

		if strfind(node.name, str) then
			list[#list + 1] = node
		end
	end
]]

local helmMenuSearch do
	local func, err = loadstring([[
		local function newtable() return {} end
		local self = {}
		function self:CallMethod(str, ...) debugPrint(...) end
		return function(str, bindings)
			]] .. helmMenuSearchSnippet .. [[
			return list
		end
		]]
	)
	local context = {debugPrint=debugPrint, pairs=pairs, strfind=strfind}
	setfenv(func, context)
	if err then error(err) else helmMenuSearch = func() end
end

local keyCodeToChar = { ["A"]="a", ["B"]="b", ["C"]="c", ["D"]="d", ["E"]="e", ["F"]="f", ["G"]="g", ["H"]="h", ["I"]="i", ["J"]="j", ["K"]="k", ["L"]="l", ["M"]="m", ["N"]="n", ["O"]="o", ["P"]="p", ["Q"]="q", ["R"]="r", ["S"]="s", ["T"]="t", ["U"]="u", ["V"]="v", ["W"]="w", ["X"]="x", ["Y"]="y", ["Z"]="z", ["SHIFT-A"]="A", ["SHIFT-B"]="B", ["SHIFT-C"]="C", ["SHIFT-D"]="D", ["SHIFT-E"]="E", ["SHIFT-F"]="F", ["SHIFT-G"]="G", ["SHIFT-H"]="H", ["SHIFT-I"]="I", ["SHIFT-J"]="J", ["SHIFT-K"]="K", ["SHIFT-L"]="L", ["SHIFT-M"]="M", ["SHIFT-N"]="N", ["SHIFT-O"]="O", ["SHIFT-P"]="P", ["SHIFT-Q"]="Q", ["SHIFT-R"]="R", ["SHIFT-S"]="S", ["SHIFT-T"]="T", ["SHIFT-U"]="U", ["SHIFT-V"]="V", ["SHIFT-W"]="W", ["SHIFT-X"]="X", ["SHIFT-Y"]="Y", ["SHIFT-Z"]="Z", ["1"]="1", ["2"]="2", ["3"]="3", ["4"]="4", ["5"]="5", ["6"]="6", ["7"]="7", ["8"]="8", ["9"]="9", ["0"]="0", ["SHIFT-1"]="!", ["SHIFT-2"]="@", ["SHIFT-3"]="#", ["SHIFT-4"]="$", ["SHIFT-5"]="%", ["SHIFT-6"]="^", ["SHIFT-7"]="&", ["SHIFT-8"]="*", ["SHIFT-9"]="(", ["SHIFT-0"]=")", [";"]=";", ["'"]="'", ["["]="[", ["]"]="]", ["-"]="-", ["="]="=", ["\\"]="\\", [","]=",", ["."]=".", ["/"]="/", ["SHIFT-;"]=":", ["SHIFT-'"]='"', ["SHIFT-["]="{", ["SHIFT-]"]="}", ["SHIFT--"]="_", ["SHIFT-="]="+", ["SHIFT-\\"]="|", ["SHIFT-,"]="<", ["SHIFT-."]=">", ["SHIFT-/"]="?", }

secureTableInsert(AfterLeaderKeyHandlerFrame, "SUBMENU", SUBMENU)
secureTableInsert(AfterLeaderKeyHandlerFrame, "MACRO", MACRO)
secureTableInsert(AfterLeaderKeyHandlerFrame, "HELM_SUBMENU", HELM_SUBMENU)
secureTableInsert(AfterLeaderKeyHandlerFrame, "TYPABLE_CHARS", keyCodeToChar)
local helmMenuSearchRestrictedSnippet = [[
	local str = arg1
	local bindings = arg2
	]] .. helmMenuSearchSnippet .. [[
	ret1 = list
	]]
secureTableInsert(AfterLeaderKeyHandlerFrame, "helmMenuSearch", helmMenuSearchRestrictedSnippet)


AfterLeaderKeyHandlerFrame:Execute([===[
	Bindings = newtable()

	currentSequence = newtable()

	inHelmMenu = false
	currentHelmString = ""
	currentHelmPosition = 1

	ESCAPE = "ESCAPE"
	BACKSPACE = "BACKSPACE"
	ENTER = "ENTER"
	C_N = "CTRL-N"
	C_P = "CTRL-P"
	AlwaysBind = newtable()
	AlwaysBind[#AlwaysBind + 1] = ESCAPE
	AlwaysBind[#AlwaysBind + 1] = BACKSPACE
	HelmBind = newtable()
	HelmBind[#HelmBind + 1] = ENTER
	HelmBind[#HelmBind + 1] = C_N
	HelmBind[#HelmBind + 1] = C_P

	ClearSequenceInProgress = [[
		currentNode = nil
		currentSequence = newtable()
		self:ClearBindings()
		self:CallMethod("cancelSequence")
	--]]

	NonBuggedConcat = [[
	local joiner = select(1, ...)
	local str = select(2, ...)
	if str == nil then return "" end
	local i = 3
	while true do
		local next = select(i, ...)
		if not next then break end
		str = str .. joiner .. next
		i = i + 1
	end
	return str
	--]]

	MenuItemSelected = [[
		local node = arg1
		local button = arg2
		if node.type == nil then -- root node.
			self:CallMethod("printOptions", "")
		end
		if node.type == MACRO then
			self:CallMethod("debugPrint", button, "(macro)")
			self:SetAttribute("type", "macro")
			self:SetAttribute("macrotext", node.macro)

			self:CallMethod("printOptions", self:Run(NonBuggedConcat, " ", unpack(currentSequence)))
			self:Run(ClearSequenceInProgress)
			return
		elseif node.type == SUBMENU then
			self:CallMethod("debugPrint", button, "(submenu)")

			self:ClearBindings()
			for _,bind in pairs(AlwaysBind) do
				self:SetBindingClick(true, bind, self:GetName(), bind)
			end
			for newBind in pairs(node.bindings) do
				self:SetBindingClick(true, newBind, self:GetName(), newBind)
			end
			--self:SetBindingClick(true, "BINDING_HEADER_CHAT", self:GetName(),  "BINDING_HEADER_CHAT")
			--self:SetBindingClick(true, "ENTER", self:GetName(),  "ENTER")
			--self:SetBindingClick(true, "RETURN", self:GetName(),  "RETURN")

			self:SetAttribute("type", nil)

			self:CallMethod("printOptions", self:Run(NonBuggedConcat, " ", unpack(currentSequence)))
			return
		elseif node.type == HELM_SUBMENU then
			self:CallMethod("debugPrint", button, "(helm menu)")
			self:CallMethod("debugPrint", "button for helm menu pressed")

			currentHelmString = ""
			currentHelmPosition = 1

			self:ClearBindings()
			for _,bind in pairs(AlwaysBind) do
				self:SetBindingClick(true, bind, self:GetName(), bind)
			end
			for _,bind in pairs(HelmBind) do
				self:SetBindingClick(true, bind, self:GetName(), bind)
			end
			for bind,_ in pairs(TYPABLE_CHARS) do
				self:SetBindingClick(true, bind, self:GetName(), bind)
			end

			self:SetAttribute("type", nil)

			self:CallMethod("printOptions", self:Run(NonBuggedConcat, " ", unpack(currentSequence)), currentHelmString, currentHelmPosition)

			-- TODO that bug with deleting. this todo should be in a different part of the file, but I'm in a hurry.
			return
		end
		self:CallMethod("debugPrint", button, "(node type unknown; this is a bug)")
	--]]

	GetNode = [[
		local currentSequence = arg1

		local currentNode = Bindings
		for i=1,#currentSequence do
			if currentNode.type == HELM_SUBMENU then
				self:CallMethod("debugPrint", "current sequence goes through a helm submenu. TODO.") -- TODO
			--elseif currentNode.type ~= SUBMENU then
				--print("(LeaderKey) ERROR: current sequence passes through non-submenu node.")
			else
				for bind,node in pairs(currentNode.bindings) do
					if currentSequence[i] == bind then
						currentNode = node
						break
					end
				end
			end
		end
		ret1 = currentNode
	--]]

	OnClick = [[
		local button, down = ...
		self:CallMethod("debugPrint", button)

		-- Get current bindings node.
		arg1 = currentSequence
		self:Run(GetNode)
		local currentNode = ret1

		local chars

		-- main chunk of code.
		if currentNode.type == HELM_SUBMENU then
			self:CallMethod("debugPrint", "Helm submenu.")
			if button == BACKSPACE and currentHelmString:len() > 0 then
				currentHelmString = currentHelmString:sub(0, currentHelmString:len() - 1)
				self:CallMethod("printOptions", self:Run(NonBuggedConcat, " ", unpack(currentSequence)), currentHelmString)
				return
			elseif button == ESCAPE or (button == BACKSPACE and currentHelmString:len() == 0) then
				button = BACKSPACE
				-- Does not return
			elseif button == ENTER then
				self:CallMethod("debugPrint", "Enter pressed in helm mode, string is", currentHelmString)
				arg1 = currentHelmString
				arg2 = currentNode.bindings
				self:Run(helmMenuSearch)
				local oldret = ret1
				local matchingOptions = ret1

				local size = 0
				for i,v in pairs(matchingOptions) do
					size = size + 1
					self:CallMethod("debugPrint", i, v)
				end

				local index = currentHelmPosition % size
				if index == 0 then index = size end
				currentSequence[#currentSequence + 1] = matchingOptions[index].name
				arg1 = matchingOptions[index]
				arg2 = nil
				self:Run(MenuItemSelected)
				self:Run(ClearSequenceInProgress)
				return
			elseif button == C_N then
				currentHelmPosition = currentHelmPosition + 1
				-- display
				return
			elseif button == C_P then
				currentHelmPosition = currentHelmPosition - 1
				-- display
				return
			else
				local char = TYPABLE_CHARS[button]
				currentHelmString = currentHelmString .. char

				currentHelmPosition = 1

				self:CallMethod("printOptions", self:Run(NonBuggedConcat, " ", unpack(currentSequence)), currentHelmString)
				return
			end
		else
			for bind,node in pairs(currentNode.bindings) do
				if bind == button then
					currentSequence[#currentSequence + 1] = button
					arg1 = node
					arg2 = button
					self:Run(MenuItemSelected)
				end
			end
		end

		if button == ESCAPE then
			self:CallMethod("debugPrint", "Escape received")
			self:Run(ClearSequenceInProgress)
			return
		end
		if button == BACKSPACE then
			self:CallMethod("debugPrint", "Backspace received")
			currentSequence[#currentSequence] = nil

			arg1 = currentSequence
			self:Run(GetNode)
			local node = ret1

			arg1 = node
			arg2 = button
			self:Run(MenuItemSelected)
			--self:CallMethod("printOptions", self:Run(NonBuggedConcat, " ", unpack(currentSequence)))
			return
		end

	--]]
  --]===]
)
AfterLeaderKeyHandlerFrame:WrapScript(AfterLeaderKeyHandlerFrame, "OnClick", "self:Run(OnClick, button, down) return true", "print('|cFFFF0000After onclick wrap called.|r') self:SetAttribute('type', nil)") -- TODO why doesn't the after script run?
LeaderKeyOverrideBindOwner = CreateFrame("BUTTON", "Leader Key Override Bind Owner", nil, "SecureHandlerBaseTemplate")

-- TODO make into method.
local function CopyInBindingsTree(currentBindingsTree, bindingsTree)
	for key,node in pairs(bindingsTree.bindings) do
		local currentNode = currentBindingsTree.bindings[key]
		if node.type == SUBMENU then
			if currentNode ~= nil and currentNode.type ~= SUBMENU then
				--print("|cFFFFA500LeaderKey: Warning: overwrote binding " .. (key or "") .. ": " .. (currentNode.name or "nil") .. " in submenu " .. (currentBindingsTree.name or "nil") .. "|r")
			end
			if currentNode == nil or currentNode.type ~= SUBMENU then
				currentBindingsTree.bindings[key] = CreateSubmenu(node.name) -- TODO copy function?
			end
			CopyInBindingsTree(currentBindingsTree.bindings[key], node)
			-- TODO helm submenus.
		else
			if currentNode ~= nil then
				--print("|cFFFFA500LeaderKey: Warning: overwrote binding " .. (key or "") .. ": " .. (currentNode.name or "nil") .. " in submenu " .. (currentBindingsTree.name or "nil") .. "|r")
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

	secureTableInsert(AfterLeaderKeyHandlerFrame, "Bindings", CurrentBindings)
	AfterLeaderKeyHandlerFrame:Execute("self:Run(ClearSequenceInProgress)")
end


-- ### user interface display code.

local numRows, numCols = 8, 3
local listItems = {}
local function setupFrames()
	local lastTopFrame = nil
	local lastFrame = nil
	local bottomAnchor = nil
	for col=1,numCols do
		for row=1,numRows do
			--local frame = CreateFrame("Frame", "LeaderKeyNextKeyListEntry" .. ((col - 1) * numRows + row), LeaderKeyMenu, "LeaderKeyNextKeyListEntry")
			local frame = CreateFrame("Frame", nil, LeaderKeyMenu, "LeaderKeyNextKeyListEntry")
			if col == 1 and row == 1 then -- The very first list item can't be anchored to another list item.
				frame:SetPoint("TOPLEFT", "LeaderKeyMenuSequenceInProgressBar", "BOTTOMLEFT")
				lastTopFrame = frame
			elseif row == 1 then
				frame:SetPoint("TOPLEFT", lastTopFrame, "TOPRIGHT")
				lastTopFrame = frame
			elseif col == 1 and row == numRows then
				frame:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT")
				bottomAnchor = frame
			else
				frame:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT")
			end

			listItems[#listItems + 1] = frame
			lastFrame = frame
		end
	end
	LeaderKeyMenuOptions:SetPoint("TOPLEFT", bottomAnchor, "BOTTOMLEFT")
end

local function clearListItems()
	for _,listItem in pairs(listItems) do
		listItem.Text:SetText("")
	end
end

local function sequenceStringToArray(keySequenceString)
	local keySequence = {}
	for key in keySequenceString:gmatch("%S+") do
		keySequence[#keySequence + 1] = key
	end
	return keySequence
end

function AfterLeaderKeyHandlerFrame:debugPrint(...)
	debugPrint(...)
end

local function prettySort(nodeList)
	local sorted = {}

	for nextBind,nextNode in pairs(nodeList) do
		if not isMenu(nextNode) then
			sorted[#sorted + 1] = {[nextBind]=nextNode}
		end
	end
	for nextBind,nextNode in pairs(nodeList) do
		if isMenu(nextNode) then
			sorted[#sorted + 1] = {[nextBind]=nextNode}
		end
	end

	return sorted
end

local function displayNodes(nodeList)
	local i = 1
	local sortedNodes = prettySort(nodeList)
	for _,node in pairs(sortedNodes) do
		local nextBind, nextNode
		for i,v in pairs(node) do -- should only be 1 item in there.
			nextBind, nextNode = i, v
		end
		local text
		if nextNode.type == MACRO then
			text = nextBind .. " -> " .. color.macro .. (nextNode.name or nextNode.macro or "nil") .. "|r"
		elseif nextNode.type == HELM_SUBMENU then
			text = nextBind .. " -> " .. color.helm_submenu .. (nextNode.name or "[no name]") .. "|r"
		elseif nextNode.type == SUBMENU then
			text = nextBind .. " -> " .. color.submenu .. (nextNode.name or "[no name]") .. "|r"
		end

		local actionFrame = listItems[i]
		if actionFrame ~= nil then
			actionFrame.Text:SetText(text)
		end
		i = i + 1
	end
end

-- Takes a string which is the buttons pressed so far separated by spaces.
function AfterLeaderKeyHandlerFrame:printOptions(keySequenceString, helmString)
	-- TODO print something special when submenu has no binds.
	debugPrint("Displaying menu for", keySequenceString .. ".")
	if helmString then
		debugPrint("Helm string detected", helmString)
	end

	local keySequence = sequenceStringToArray(keySequenceString)

	clearListItems()

	local node = CurrentBindings:GetNode(keySequence)
	if not node then warning("Node " .. table.concat(keySequence, " ") .. " does not exist."); return end

	if node.type == SUBMENU then
		LeaderKeyMenu:Show()

		LeaderKeyMenuSequenceInProgressBar.Text:SetText(node.name or "nil")

		if tableIsEmpty(node.bindings) then
			print("|cFFFF0000No bindings, press escape to quit. This should not happen.|r")
		end

		displayNodes(node.bindings)
	elseif node.type == HELM_SUBMENU then
		debugPrint("showing options helm submenu")
		LeaderKeyMenuSequenceInProgressBar.Text:SetText((node.name or "nil") .. " " .. (helmString or "nil"))

		local matchingNodes = helmMenuSearch(helmString, node.bindings)
		displayNodes(matchingNodes)
	elseif node.type == MACRO then
		LeaderKeyMenu:Hide()

		print(color.castPrint .. "-> casting spell:", node.macro, "|r")
	end
end

function AfterLeaderKeyHandlerFrame:cancelSequence()
	clearListItems()
	LeaderKeyMenu:Hide()
end

local function printBindings(bindingsTree, sequence)
	sequence = sequence or ""
	for key,node in pairs(bindingsTree.bindings) do
		local newSequence = sequence .. key .. " "
		if not isMenu(node) then
			warning(newSequence:sub(1, newSequence:len() - 1) .. ":", node.name)
		else
			printBindings(node, newSequence)
		end
	end
end

local printCurrentBindings do
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

	function printCurrentBindings()
		warning("|c4aacd3FF### Account bindings: ###|r")
		printCurrentBindsHelper(LeaderKey.GetAccountBindingsTree(), {["Current Class"] = LeaderKey.GetCurrentClassBindingsTree(), ["Current Spec"] = LeaderKey.GetCurrentSpecBindingsTree()})
		warning("|c4aacd3FF### Class bindings: ###|r")
		printCurrentBindsHelper(LeaderKey.GetCurrentClassBindingsTree(), {["Current Spec"] = LeaderKey.GetCurrentSpecBindingsTree})
		warning("|c4aacd3FF### Spec bindings: ###|r")
		printCurrentBindsHelper(LeaderKey.GetCurrentSpecBindingsTree(), {})
	end
end

-- ### Slash commands.
-- TODO usage info for bad command

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

	debugPrint("args:")
	if debug then
		for i,v in pairs(args) do
			debugPrint(i,v)
		end
	end

	return args
end

local function cleanKeySequence(keySequence)
	for i,v in pairs(keySequence) do
		keySequence[i] = string.upper(v)
	end
	return keySequence
end

local macrotype = "macro"
local spelltype = "spell"
local helmtype = "helm"
local function SlashCommandMapBind(bindingsTree, txt)
	local args = parseArgs(txt)
	if not args or not args[4] then errorp("invalid arguments"); return end

	local type = args[1]
	local name = args[2]
	if name == "_" then name = nil end
	local contents = args[3]:gsub("\\n","\n")
	local keySequence = cleanKeySequence(slice(args, 4))

	local node
	if type == macrotype then
		node = CreateMacroNode(name, contents)
	elseif type == spelltype then
		local spellName, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(contents)
		if not spellName then
			errorp("|cFFFFA500Could not find spell " .. spellName .. ".|r")
			return
		end
		node = CreateSpellNode(name, spellName)
		ViragDevTool_AddData(node, "bla")
	elseif type == helmtype then
		node = CreateHelmSubmenu(name)
	else
		errorp("Unknown type \"" .. type .. "\"")
		return
	end

	LeaderKey.CreateBinding(bindingsTree, node, keySequence)
	UpdateKeybinds()
	info("Created bind " .. table.concat(keySequence, " ") .. " to " .. name)
end

local function SlashCommandMapUnbind(bindingsTree, txt)
	local args = parseArgs(txt)
	if not args or not args[1] then errorp("invalid arguments"); return end
	local keySequence = cleanKeySequence(args)

	LeaderKey.DeleteNode(bindingsTree, keySequence)
	UpdateKeybinds()
	info("Deleted node " .. table.concat(keySequence, " ") .. " (or, it didn't exist in the first place)")
end

local function SlashCommandNameNode(bindingsTree, txt)
	local args = parseArgs(txt)
	if not args or not args[1] then errorp("invalid arguments"); return end
	local name = args[1] or "nil"
	local keySequence = cleanKeySequence(slice(args, 2))

	local successful = LeaderKey.NameNode(bindingsTree, name, keySequence)
	UpdateKeybinds()
	if successful then
		info("Named node " .. table.concat(keySequence, " ") .. " to " .. name)
	end
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
--[[
registerSlashCommand("LEADERKEY_UNMAP", {"/lkunmap"},
                     function(txt, editbox)
								error("NYI")
								local args = parseArgs(txt)
                     end
)
--]]
registerSlashCommand("LEADERKEY_PRINT_CURRENT", {"/lkpc"},
                     function(txt, editbox)
								printCurrentBindings(LeaderKey.GetCurrentBindingsTree())
                     end
)

-- ### public api.
-- Should I expose the bindings trees like this? It feel very weird to call a function which requires the return value of another function. What if I made strings to represent each scope instead?

LeaderKey = {}

function LeaderKey.GetCurrentBindingsTree()
	return CurrentBindings
end

function LeaderKey.UpdateCurrentBindings()
	UpdateKeybinds()
end

function LeaderKey.CreateBinding(bindingsTree, node, keySequence)
	bindingsTree:AddBind(node, keySequence)
end

function LeaderKey.DeleteNode(bindingsTree, keySequence)
	bindingsTree:DeleteNode(keySequence)
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
	local localizedName, class = UnitClass("player")
	local specId = GetSpecialization()
	debugPrint("Class:", localizedName, "(" .. (specId or "nil") .. ")")
	if not specId then return BindingsTree:new() end -- Happens sometimes on load. TODO see if you can move bindings load to a later event, like PLAYER_ENTERING_WORLD. TODO move code related to this (if there will be any) into the loading code, not here.
	local currentSpecBindingsTree = LeaderKey.GetSpecBindingsTree(class, specId) -- 2 is the localization-independent name.
	ViragCurrentSpecBindingsPointer = currentSpecBindingsTree
	return currentSpecBindingsTree
end

function LeaderKey.GetCurrentClassBindingsTree()
	return LeaderKey.GetClassBindingsTree(select(2, UnitClass("player"))) -- 2 is the localization-independent name.
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
function events:PLAYER_ENTERING_WORLD(...)
	if ViragDevTool_AddData and debug then
		ViragDevTool_AddData(ViragCurrentBindingsPointer.bindings, "LKMAP")
		ViragDevTool_AddData(LeaderKeyData.accountBindings, "LKMAP_ACCOUNT")
		ViragDevTool_AddData(LeaderKeyData.classBindings, "LKMAP_CLASS")
		ViragDevTool_AddData(LeaderKey.GetCurrentClassBindingsTree(), "LKMAP_CURRENT_CLASS")
		--ViragDevTool_AddData(ViragCurrentSpecBindingsPointer.bindings, "LKMAP")
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

		setupFrames()

		addonIsLoaded = true
	end
end
function events:PLAYER_SPECIALIZATION_CHANGED(...)
	if ... ~= "player" then return end
	-- TODO detect spec vs talent change.
	debugPrint("PLAYER_SPECIALIZATION_CHANGED new spec", GetSpecialization())
	LeaderKey.UpdateCurrentBindings()
end

registerEventHandlers(events)

-- Test code. TODO remove this eventually.
if debug then
	registerSlashCommand("TEST", {"/test"}, function(txt) local bla = parseArgs(txt); if not bla then print("returned nil"); return end; for i,v in pairs(bla) do warning(i,v) end end)
	registerSlashCommand("RL", {"/rl"}, SlashCmdList["RELOAD"])
end

