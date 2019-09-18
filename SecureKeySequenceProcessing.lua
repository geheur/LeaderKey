select(2, ...).setenv()

local Node = LeaderKey.BindingsTree.Node

-- ### Core keybind setup code.
AfterLeaderKeyHandlerFrame = CreateFrame("BUTTON", "After Leader Key Handler Frame", nil, "SecureHandlerClickTemplate,SecureActionButtonTemplate")

AfterLeaderKeyHandlerFrame:RegisterForClicks(--[["AnyUp", ]]"AnyDown")

-- TODO currently your results are like cd -P, which imo is not good (at least not as the default).

local helmMenuSearchSnippet = [[

	local list = newtable()
	local mapping = newtable()

	for bind,node in pairs(bindings) do
		if node.name == nil then
			self:CallMethod("debugPrint", "Helm Menu Search: found node with nil name")
		end

		if strfind(node.name:lower(), str) then
			mapping[#list + 1] = bind
			list[#list + 1] = node
			self:CallMethod("debugPrint", "mapping", bind)
		end
	end
]]

do
	local func, err = loadstring([[
		local function newtable() return {} end
		local self = {}
		function self:CallMethod(str, ...) debugPrint(...) end
		return function(str, bindings)
			]] .. helmMenuSearchSnippet .. [[
			return list, mapping
		end
		]]
	)
	local context = {debugPrint=Log.debug, pairs=pairs, strfind=strfind}
	setfenv(func, context)
	if err then error(err) else helmMenuSearch = func() end
end

-- TODO some of these are like 1k characters in order to insert like 15 characters of payload. Can this be improved?
secureTableInsert(AfterLeaderKeyHandlerFrame, "SUBMENU", Node.SUBMENU)
secureTableInsert(AfterLeaderKeyHandlerFrame, "MACRO", Node.MACRO)
secureTableInsert(AfterLeaderKeyHandlerFrame, "HELM_SUBMENU", Node.HELM_SUBMENU)
secureTableInsert(AfterLeaderKeyHandlerFrame, "SOFTLINK", Node.SOFTLINK)
secureTableInsert(AfterLeaderKeyHandlerFrame, "TYPABLE_CHARS", keyCodeToChar)
secureTableInsert(AfterLeaderKeyHandlerFrame, "prefix", keySequencePrefix)
local helmMenuSearchRestrictedSnippet = [[
	local str = arg1
	local bindings = arg2
	]] .. helmMenuSearchSnippet .. [[
	ret1 = list
	ret2 = mapping
	]]
secureTableInsert(AfterLeaderKeyHandlerFrame, "helmMenuSearch", helmMenuSearchRestrictedSnippet)


local keySequenceStateUpdateListeners = {}
-- TODO documentation.
function LeaderKey.registerForKeySequenceStateUpdate(listener)
	tinsert(keySequenceStateUpdateListeners, listener)
end

local currentSequence, currentHelmString
function AfterLeaderKeyHandlerFrame:printOptions(keySequenceString, helmString)
	currentSequence = keySequenceString and sequenceStringToArray(keySequenceString) or {}
	currentHelmString = helmString
	for _,listener in ipairs(keySequenceStateUpdateListeners) do
		listener(keySequenceString, helmString)
	end
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
		self:CallMethod("printOptions", nil)
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
		self:CallMethod("debugPrint", "Menu item selected, type:", node.type)
		-- if node.type == nil then -- root node. TODO no longer works
			-- self:CallMethod("printOptions", "")
		-- end
		if node.type == MACRO then
			self:SetAttribute("type", "macro")
			self:SetAttribute("macrotext", node.macro)

			arg1 = button
			self:Run(ClearSequenceInProgress)
			return
		elseif node.type == SUBMENU then
			self:ClearBindings()
			for _,bind in pairs(AlwaysBind) do
				self:SetBindingClick(true, bind, self:GetName(), bind)
			end
			for newBind in pairs(node.bindings) do
				-- print("new bind: ", newBind)
				self:SetBindingClick(true, newBind, self:GetName(), newBind)
			end

			self:SetAttribute("type", nil)

			self:CallMethod("printOptions", self:Run(NonBuggedConcat, " ", unpack(currentSequence)))
			return
		elseif node.type == HELM_SUBMENU then
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
		elseif node.type == SOFTLINK then
			currentSequence = node.softlink

			local seq = newtable()
			for i,v in pairs(currentSequence) do -- TODO fucking disgusting, fix securetableinsert.
				seq[#seq + 1] = v
			end
			currentSequence = seq

			arg1 = currentSequence
			self:Run(GetNode)
			arg1 = ret1
			self:Run(MenuItemSelected)
			return
		end
		local type
		if node == nil then str = "[nil node]" else str = (node.type or "nil") end
		local name
		if node == nil then name = "[nil node]" else name = (node.name or "nil") end
		self:CallMethod("debugPrint", button, "(node type " .. str .. " name " .. name .. " unknown; this is a bug)")
	--]]

	GetNode = [[
		local currentSequence = arg1

		local currentNode = Bindings
		for _,bind in pairs(currentSequence) do
			local found
			for nodeBind,node in pairs(currentNode.bindings) do
				if bind == nodeBind then
					currentNode = node
					found = true
					break
				end
			end
			if not found then
				self:CallMethod("debugPrint", "Could not find node", bind, "in", currentNode.name)
			end
		end
		ret1 = currentNode
	--]]

	OnClick = [[
		local button, down = ...
		self:CallMethod("debugPrint", "===Button clicked===:", button)

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
		self:CallMethod("debugPrint", "current node is "..currentNode.name)

		-- main chunk of code.
		if currentNode.type == HELM_SUBMENU then
			if button == BACKSPACE and currentHelmString:len() > 0 then
				currentHelmString = currentHelmString:sub(0, currentHelmString:len() - 1)
				self:CallMethod("printOptions", self:Run(NonBuggedConcat, " ", unpack(currentSequence)), currentHelmString)
				return
			elseif button == ESCAPE then
				-- use default behavior
			elseif button == BACKSPACE and currentHelmString:len() == 0 then
			-- elseif button == ESCAPE or (button == BACKSPACE and currentHelmString:len() == 0) then
				button = BACKSPACE
				-- Does not return
			elseif button == ENTER then
				arg1 = currentHelmString
				arg2 = currentNode.bindings
				self:Run(helmMenuSearch)
				local matchingOptions = ret1
				local mapping = ret2

				local size = 0
				for i,v in pairs(matchingOptions) do
					size = size + 1
				end

				local index = currentHelmPosition % size
				if index == 0 then index = size end
				currentSequence[#currentSequence + 1] = mapping[index]
				arg1 = matchingOptions[index] -- TODO no options error.
				arg2 = nil
				self:Run(MenuItemSelected)
				arg1 = button
				-- self:Run(ClearSequenceInProgress)
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

function LeaderKey.IsMenuOpen()
	return #LeaderKey.GetCurrentKeySequence() > 0
end

function LeaderKey.GetCurrentKeySequence()
	local keysequence = copyKeySequence(currentSequence)
	tremove(keysequence, 1)
	return keysequence, currentHelmString
end

LeaderKeyOverrideBindOwner = CreateFrame("BUTTON", "Leader Key Override Bind Owner", nil, "SecureHandlerBaseTemplate")

function AfterLeaderKeyHandlerFrame:errorPrint(...)
	Log.error(...)
end

function AfterLeaderKeyHandlerFrame:debugPrint(...)
	Log.debug(...)
end

