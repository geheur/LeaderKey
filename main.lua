local slice = LeaderKey.private.slice
local tableSize = LeaderKey.private.tableSize
local tableIsEmpty = LeaderKey.private.tableIsEmpty
local Log = LeaderKey.private.Log
local secureTableInsert = LeaderKey.private.secureTableInsert

local colors = LeaderKey.private.colors

local BindingsTree = LeaderKey.BindingsTree
local Node = LeaderKey.BindingsTree.Node
local isMenu = Node.isMenu


local keySequencePrefix = {b="L","L",a="L"}

local ViragCurrentBindingsPointer
local function CreateRootMenu()
	local rootmenu = BindingsTree:new()
	rootmenu.name = "Root"
	rootmenu:AddBind(Node.CreateSubmenu("Leader Keys"), keySequencePrefix)
	--[[
	--]]

	return rootmenu
end
local CurrentBindings
local function CreateBindingsTree()
	CurrentBindings = CreateRootMenu()

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

		if strfind(node.name:lower(), str) then
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
	local context = {debugPrint=Log.debug, pairs=pairs, strfind=strfind}
	setfenv(func, context)
	if err then error(err) else helmMenuSearch = func() end
end

secureTableInsert(AfterLeaderKeyHandlerFrame, "SUBMENU", Node.SUBMENU)
secureTableInsert(AfterLeaderKeyHandlerFrame, "MACRO", Node.MACRO)
secureTableInsert(AfterLeaderKeyHandlerFrame, "HELM_SUBMENU", Node.HELM_SUBMENU)
secureTableInsert(AfterLeaderKeyHandlerFrame, "TYPABLE_CHARS", LeaderKey.private.keyCodeToChar)
secureTableInsert(AfterLeaderKeyHandlerFrame, "prefix", keySequencePrefix)
local helmMenuSearchRestrictedSnippet = [[
	local str = arg1
	local bindings = arg2
	]] .. helmMenuSearchSnippet .. [[
	ret1 = list
	]]
secureTableInsert(AfterLeaderKeyHandlerFrame, "helmMenuSearch", helmMenuSearchRestrictedSnippet)


-- TODO fix
function AfterLeaderKeyHandlerFrame:cancelSequence()
end

AfterLeaderKeyHandlerFrame:Execute([===[
	Bindings = newtable()

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

	eatKeyUp = nil

	prefix = newtable()
	prefix[1] = "L" -- TODO figure out why you couldn't secure import this.

	ClearSequenceInProgress = [[
		currentNode = nil
		currentSequence = newtable()
		for _,v in ipairs(prefix) do
			currentSequence[#currentSequence + 1] = v
		end
		self:ClearBindings()
		self:CallMethod("cancelSequence")
		--eatKeyUp = arg1
	--]]

	self:Run(ClearSequenceInProgress)

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
			arg1 = button
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

		--if not down and button == eatKeyUp then
			--self:ClearBindings()
			--eatKeyUp = nil
		--end
		--if eatKeyUp then
			--return
		--end

		-- Get current bindings node.
		arg1 = currentSequence
		self:Run(GetNode)
		local currentNode = ret1

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
				arg1 = button
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
			arg1 = button
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
--AfterLeaderKeyHandlerFrame:WrapScript(AfterLeaderKeyHandlerFrame, "OnClick", "print('bla')", "print('|cFFFF0000After onclick wrap called.|r') self:SetAttribute('type', nil)") -- TODO why doesn't the after script run?
AfterLeaderKeyHandlerFrame:WrapScript(AfterLeaderKeyHandlerFrame, "OnClick", "self:Run(OnClick, button, down) return true", "print('|cFFFF0000After onclick wrap called.|r') self:SetAttribute('type', nil)") -- TODO why doesn't the after script run?
LeaderKeyOverrideBindOwner = CreateFrame("BUTTON", "Leader Key Override Bind Owner", nil, "SecureHandlerBaseTemplate")

-- TODO make into method.
local function CopyInBindingsTree(currentBindingsTree, bindingsTree)
	for key,node in pairs(bindingsTree.bindings) do
		local currentNode = currentBindingsTree.bindings[key]
		if node.type == Node.SUBMENU then
			if currentNode ~= nil and currentNode.type ~= Node.SUBMENU then
				--print("|cFFFFA500LeaderKey: Warning: overwrote binding " .. (key or "") .. ": " .. (currentNode.name or "nil") .. " in submenu " .. (currentBindingsTree.name or "nil") .. "|r")
			end
			if currentNode == nil or currentNode.type ~= Node.SUBMENU then
				currentBindingsTree.bindings[key] = Node.CreateSubmenu(node.name) -- TODO copy function?
			end
			CopyInBindingsTree(currentBindingsTree.bindings[key], node)
			-- TODO helm submenus.
		else
			if currentNode ~= nil then
				--print("|cFFFFA500LeaderKey: Warning: overwrote binding " .. (key or "") .. ": " .. (currentNode.name or "nil") .. " in submenu " .. (currentBindingsTree.name or "nil") .. "|r")
			end
			Log.debug("binding", currentBindingsTree.name or "", key, "to", node.name)
			currentBindingsTree.bindings[key] = node -- TODO make sure no one changes this node...
		end
	end
end

local function BuildCurrentBindingsTree()
	CreateBindingsTree()

	Log.debug("adding account bindings")
	CopyInBindingsTree(CurrentBindings, LeaderKey.GetAccountBindingsTree())
	Log.debug("adding class bindings")
	CopyInBindingsTree(CurrentBindings, LeaderKey.GetCurrentClassBindingsTree())
	Log.debug("adding spec bindings")
	CopyInBindingsTree(CurrentBindings, LeaderKey.GetCurrentSpecBindingsTree())
end

-- Updates keybind tree in AfterLeaderKeyHandlerFrame's restricted environment, and makes sure leader keys are bound. Out of combat only, obviously.
local function UpdateKeybinds()
	BuildCurrentBindingsTree()

	LeaderKeyOverrideBindOwner:Execute("self:ClearBindings()")
	local LeaderKeyNode = CurrentBindings:GetNode(keySequencePrefix)
	for i,v in pairs(LeaderKeyNode.bindings) do
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
	Log.debug(...)
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
		if nextNode.type == Node.MACRO then
			text = nextBind .. " -> " .. colors.macro .. (nextNode.name or nextNode.macro or "nil") .. "|r"
		elseif nextNode.type == Node.HELM_SUBMENU then
			text = nextBind .. " -> " .. colors.helm_submenu .. (nextNode.name or "[no name]") .. "|r"
		elseif nextNode.type == Node.SUBMENU then
			text = nextBind .. " -> " .. colors.submenu .. (nextNode.name or "[no name]") .. "|r"
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
	Log.debug("Displaying menu for", keySequenceString .. ".")
	if helmString then
		Log.debug("Helm string detected", helmString)
	end

	local keySequence = sequenceStringToArray(keySequenceString)

	clearListItems()

	local node = CurrentBindings:GetNode(keySequence)
	if not node then Log.warning("Node " .. table.concat(keySequence, " ") .. " does not exist."); return end

	if node.type == Node.SUBMENU then
		LeaderKeyMenu:Show()

		LeaderKeyMenuSequenceInProgressBar.Text:SetText(node.name or "nil")

		if tableIsEmpty(node.bindings) then
			print("|cFFFF0000No bindings, press escape to quit. This should not happen.|r")
		end

		displayNodes(node.bindings)
	elseif node.type == Node.HELM_SUBMENU then
		Log.debug("showing options helm submenu")
		LeaderKeyMenuSequenceInProgressBar.Text:SetText((node.name or "nil") .. " " .. (helmString or "nil"))

		local matchingNodes = helmMenuSearch(helmString, node.bindings)
		displayNodes(matchingNodes)
	elseif node.type == Node.MACRO then
		LeaderKeyMenu:Hide()

		print(colors.castPrint .. "-> casting spell:", node.macro, "|r")
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
			Log.warning(newSequence:sub(1, newSequence:len() - 1) .. ":", node.name)
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
					--Log.debug("looking at binding " .. table.concat(split, " ") .. " for tree " .. bindingsName)
					local otherNode = otherBindingsTree:GetNode(split) -- TODO can't use getnode - need something like "bindingconflicts".
					if otherNode then
						str = str .. " Overriden by " .. bindingsName
					end
				end
				if str:len() > 0 then
					str = "|cFFFF0000 (" .. str:sub(2, str:len()) .. ")"
				end
				Log.warning(newSequence:sub(1, newSequence:len() - 1) .. ":", (node.name or "nil") .. str)
			else
				printCurrentBindsHelper(node, checkAgainst, newSequence)
			end
		end
	end

	function printCurrentBindings()
		Log.warning("|c4aacd3FF### Account bindings: ###|r")
		printCurrentBindsHelper(LeaderKey.GetAccountBindingsTree(), {["Current Class"] = LeaderKey.GetCurrentClassBindingsTree(), ["Current Spec"] = LeaderKey.GetCurrentSpecBindingsTree()})
		Log.warning("|c4aacd3FF### Class bindings: ###|r")
		printCurrentBindsHelper(LeaderKey.GetCurrentClassBindingsTree(), {["Current Spec"] = LeaderKey.GetCurrentSpecBindingsTree})
		Log.warning("|c4aacd3FF### Spec bindings: ###|r")
		printCurrentBindsHelper(LeaderKey.GetCurrentSpecBindingsTree(), {})
	end
end

-- ### public api.
-- Should I expose the bindings trees like this? It feel very weird to call a function which requires the return value of another function. What if I made strings to represent each scope instead?

function LeaderKey.GetCurrentBindingsTree()
	return CurrentBindings
end

function LeaderKey.UpdateCurrentBindings()
	UpdateKeybinds()
end

local function prepend(keySequence)
	local result = {}
	for i=1,#keySequencePrefix do
		result[#result + 1] = keySequencePrefix[i]
	end
	for i=1,#keySequence do
		result[#result + 1] = keySequence[i]
	end
	return result
end

function LeaderKey.CreateBinding(bindingsTree, node, keySequence)
	bindingsTree:AddBind(node, prepend(keySequence))
end

function LeaderKey.DeleteNode(bindingsTree, keySequence)
	bindingsTree:DeleteNode(prepend(keySequence))
end

function LeaderKey.NameNode(bindingsTree, name, keySequence)
	return bindingsTree:NameNode(name, prepend(keySequence))
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
	LeaderKeyData.classBindings[class] = LeaderKeyData.classBindings[class] or CreateRootMenu()
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
	Log.debug("Class:", localizedName, "(" .. (specId or "nil") .. ")")
	if not specId then return BindingsTree:new() end -- Happens sometimes on load. TODO see if you can move bindings load to a later event, like PLAYER_ENTERING_WORLD. TODO move code related to this (if there will be any) into the loading code, not here.
	local currentSpecBindingsTree = LeaderKey.GetSpecBindingsTree(class, specId) -- 2 is the localization-independent name.
	ViragCurrentSpecBindingsPointer = currentSpecBindingsTree
	return currentSpecBindingsTree
end

function LeaderKey.GetCurrentClassBindingsTree()
	return LeaderKey.GetClassBindingsTree(select(2, UnitClass("player"))) -- 2 is the localization-independent name.
end

--[[
creationCallback is a function called whenever a dynamic menu is created. This happens when one is bound, either due to user action or due to the addon loading its binds.
creationCallback takes 1 argument: a token which represents the menu, used to request LeaderKey to reload the menu.
--]]
LeaderKey.DynamicMenuRegistry = {}
function LeaderKey.RegisterDynamicMenu(name, creationCallback, singleton)
	if singleton then error("singleton menus not yet supported") end
	
	LeaderKey.DynamicMenuRegistry[name] = {creationCallback=creationCallback, singleton=singleton}
end

function LeaderKey.UpdateDynamicMenu(token)
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
	local debug = true
	if ViragDevTool_AddData and debug then
		ViragDevTool_AddData(ViragCurrentBindingsPointer.bindings, "LKMAP")
		ViragDevTool_AddData(LeaderKeyData.accountBindings, "LKMAP_ACCOUNT")
		ViragDevTool_AddData(LeaderKeyData.classBindings, "LKMAP_CLASS")
		ViragDevTool_AddData(LeaderKey.GetCurrentClassBindingsTree(), "LKMAP_CURRENT_CLASS")
		ViragDevTool_AddData(LeaderKey.VDT, "LeaderKey")
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

		LeaderKeyData = LeaderKeyData or CreateRootMenu()
		LeaderKeyData.classBindings = LeaderKeyData.classBindings or CreateRootMenu()
		LeaderKey.UpdateCurrentBindings()

		setupFrames()

		if true then
			LeaderKey.loadstuff() -- TODO delete.
		end

		addonIsLoaded = true
	end
end
function events:PLAYER_SPECIALIZATION_CHANGED(...)
	if ... ~= "player" then return end
	-- TODO detect spec vs talent change.
	Log.debug("PLAYER_SPECIALIZATION_CHANGED new spec", GetSpecialization())
	LeaderKey.UpdateCurrentBindings()
end

registerEventHandlers(events)

-- Test code. TODO remove this eventually.
if debug then
	registerSlashCommand("TEST", {"/test"}, function(txt) local bla = parseArgs(txt); if not bla then print("returned nil"); return end; for i,v in pairs(bla) do Log.warning(i,v) end end)
	registerSlashCommand("RL", {"/rl"}, SlashCmdList["RELOAD"])
end

