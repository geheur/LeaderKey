-- ### Slash commands.
-- TODO usage info for bad command

local Log = LeaderKey.private.Log

local Node = LeaderKey.BindingsTree.Node

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
			if start then Log.warn("unclosed " .. c); return nil end
		else
			if c == '\\' then
				i = i + 1
				if i > #txt then Log.warn("unclosed \\"); return nil end
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

	Log.debug("args:")
	for i,v in pairs(args) do
		Log.debug(i,v)
	end

	return args
end

-- Interactive keybinds.

local invalid = {
	LALT=true,
	RALT=true,
	LCTRL=true,
	RCTRL=true,
	LSHIFT=true,
	RSHIFT=true,
}
local function HandleKey(frame, key, keyup)
	if invalid[key] then return end -- TODO don't I have a list of valid keys somewhere? If not, make one (can also be a list of invalid keys).
	if key == "ENTER" then
		frame:Hide()
		frame.whenDone(frame.keysInputted)
		frame.keysInputted = {}
		return
	elseif key == "BACKSPACE" then
		tremove(frame.keysInputted)
	elseif key == "ESCAPE" then
		frame:Hide()
		Log.info("Cancelled key sequence input")
		return
	else
		tinsert(frame.keysInputted, key)
	end

	local node = LeaderKey.GetCurrentBindingsTree():GetNode(frame.keysInputted)
	if #frame.keysInputted == 0 then
		Log.info("Current sequence:" .. LeaderKey.keySequenceForPrint(frame.keysInputted))
	else
		Log.info("Current sequence:" .. LeaderKey.keySequenceForPrint(frame.keysInputted) .. " " .. (node and LeaderKey.nodeForPrint(node) or "<nothing bound to this key sequence>"))
	end
end

local function doBind(keySequence, nodeToAdd)
	local s = ""
	for i,v in pairs(keySequence) do
		s = s .. " " .. v
	end

	local node = LeaderKey.GetAccountBindingsTree():GetNode(keySequence)
	if node then Log.warn("Overwriting bind " .. LeaderKey.bindForPrint(nodeToAdd, keySequence) .. s) end

	LeaderKey.GetAccountBindingsTree():AddBind(
			nodeToAdd,
			keySequence
	)
	Log.info("Created bind" .. s .. " for " .. LeaderKey.nodeForPrint(nodeToAdd))

	LeaderKey.UpdateKeybinds()
end

LeaderKey.dobind = doBind

local function doUnbind(keySequence)
	local s = ""
	for i,v in pairs(keySequence) do
		s = s .. " " .. v
	end

	local node = LeaderKey.GetAccountBindingsTree():GetNode(keySequence)
	if not node then
		Log.error("No keybind for " .. LeaderKey.keySequenceForPrint(keySequence))
	else
		LeaderKey.GetAccountBindingsTree():DeleteNode(keySequence)
		Log.info("Deleted bind" .. s)
	end

	LeaderKey.UpdateKeybinds()
end

local function doRebind(keySequence) -- TODO implement correctly.
	local s = ""
	for i,v in pairs(keySequence) do
		s = s .. " " .. v
	end

	error("NYI")
	local node = LeaderKey.GetAccountBindingsTree():GetNode(keySequence)
	if not node then
		Log.error("No keybind for " .. LeaderKey.keySequenceForPrint(keySequence))
	else
		LeaderKey.GetAccountBindingsTree():DeleteNode(keySequence)
		LeaderKey.GetAccountBindingsTree():AddBind(node, keySequence)
		Log.info("Rebound " .. s)
	end

	LeaderKey.UpdateKeybinds()
end

local keybindingFrame = CreateFrame("FRAME")
keybindingFrame:EnableKeyboard(true)
keybindingFrame:SetPropagateKeyboardInput(false);
keybindingFrame:SetFrameStrata("TOOLTIP") -- Determines priority for receiving keyboard events.
keybindingFrame:SetScript("OnKeyDown", HandleKey)
-- keybindingFrame:SetScript("OnKeyUp", function(frame, key) HandleKey(frame, key, true) end)
-- keybindingFrame:SetScript("OnHide", function() keysInputted = {} end)
keybindingFrame:Hide()

local function getKeySequenceFromUserAndThen(whenDone)
	keybindingFrame.whenDone = whenDone
	keybindingFrame.keysInputted = {}
	Log.info("Enter key sequence:")
	keybindingFrame:Show()
end

--[[
desired: /lk(re)bind TYPE SUBJECT NAME
--]]

local lkbindTypes = {
	macro = function(type, name, content)
		return Node.CreateMacroNode(name, contents:gsub("\\n","\n"))
	end,
	spell = function(type, name, content)
		local spellName, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(contents)
		if not spellName then
			Log.error("|cFFFFA500Could not find spell " .. contents .. ".|r")
			return
		end
		node = Node.CreateSpellNode(name, spellName)
	end,
	item = function(type, name, content)
		node = Node.CreateItemNode(name, content)
	end,
	searchable = function(type, name, content)
		print("nyi")
	end,
	softlink = function(type, name, content)
		print("nyi")
	end,
}

local function handleSlashCommand(command, txt)
	Log.debug("raw slash command argument: /"..command, txt)
	local args = parseArgs(txt)
	-- if not args then Log.error("invalid arguments"); return end

	if command == "bind" then
		-- local type = strlower(args[1])
		local type = args[1]
		local name = args[2]
		local content = args[3]
		if not content then content = name end

		if not type then
			print("TODO implement help.")
			return
		end

		local node
		local f = lkbindTypes[type]
		if not f then
			for pluginName,plugin in pairs(LeaderKey.DynamicMenuRegistry) do
				if type == pluginName then
					node = Node.CreateSoftlink(pluginName, {"D", type})
				end
			end

			if not node then
				print("type "..type.." does not exist")
				-- TODO include help.
				return
			end
		end

		if not node then node = f(type, name, content) end

		if node == nil then
			Log.error("Unknown type \"" .. type .. "\"")
			return
		end

		getKeySequenceFromUserAndThen(function(keySequence) doBind(keySequence, node) end)
	elseif command == "unbind" then
		getKeySequenceFromUserAndThen(doUnbind)
	elseif command == "rebind" then
		-- getKeySequenceFromUserAndThen(function(keySequence) doUnbind(keySequence) end) -- TODO
	else
		Log.error("this shouldn't happen")
	end
end

local function InteractiveAddNode(currentSequence)
	-- TODO coroutines are not needed here.
	coroutine.create(function() -- establish variable. "local co =" wouldn't work because the rvalue is evaluated before the local variable is created.
														    -- Ex: /script local p = function() print("p:", p) end p() -- prints nil
		if InCombatLockdown() then
			print("Cannot change binds in combat, try again later!")
			return
		end
		OpenEditMenu(currentSequence, co)

		local node, sequence = yield()

		-- Add node.
		if not node then return end
		if InCombatLockdown() then
			print("Cannot change binds in combat, try again later!")
			return
		end
		LeaderKey.GetAccountBindingsTree():AddNode(node, sequence)
		LeaderKey.SelectSequence(currentSequence)
	end)
	coroutine.resume(co)
end

local deleteMode = false
local function InteractiveRmNode()
	if InCombatLockdown() then
		print("Cannot change binds in combat, try again later!")
		return
	end

	LeaderKey.DisableNodeActions()
	-- Popup menu indicator of delete mode.
end
LeaderKey.registerForKeySequenceStateUpdate(function()
	-- If deleteMode is true:
	-- Delete node.
	-- Reset to deleted node's parent.
	-- Possibly disable deleteMode.
	-- un-disable menu if appropriate.
end)

local function InteractiveEditNode()
	if InCombatLockdown() then
		print("Cannot change binds in combat, try again later!")
		return
	end
end

--[[
m-a - add node. Open interface to create node.

m-e - enter key for node. Open interface to create node.
	You'll have to block non-menu node (e.g. macro node) execution in the secure frame - as well as any other actions (if you add action submenus).

m-d - enter key for node.

	Copying nodes.
--]]

--[[
/lkl[ist]
/lkl[ist] s[ubtree]
	Asks for key sequence.
/lkl[ist] p[lugins] -- mostly redundant with going to the root.

/lkr[oot] -- Out of combat only.

/lkb[ind] [help]
/lku[nbind]
/lkre[bind]

/lkh[elp]

All of these could also be available as /lk b[ind].
--]]

LeaderKey.registerSlashCommand("/lkbind", function(msg) handleSlashCommand("bind", msg) end)
LeaderKey.registerSlashCommand("/lkunbind", function(msg) handleSlashCommand("unbind", msg) end)
LeaderKey.registerSlashCommand("/lkrebind", function(msg) handleSlashCommand("rebind", msg) end)

local Node = LeaderKey.BindingsTree.Node
local item = "todo" -- TODO.
local spell = "todo" -- TODO.

local AceGui = LibStub("AceGUI-3.0")

local function button(name, width, onclickcallback)
	local b = AceGui:Create("Button")
	b:SetWidth(width)
	b:SetText(name)
	b:SetCallback("OnClick", onclickcallback)
	return b
end

local function lkKeybindPrefixLabel(keysequence, width)
	local b = AceGui:Create("Label")
	b:SetWidth(width)
	b:SetText(keysequence)
	b:SetCallback("OnKeyChanged", function(self,callback,keybind) nodeattributes[key] = keybind end)
	return b
end

local function lkKeybind(name, width, nodeattributes, key)
	local b = AceGui:Create("Keybinding")
	b:SetWidth(width)
	b:SetCallback("OnKeyChanged", function(self,callback,keybind) nodeattributes[key] = keybind end)
	return b
end

local function lkMacroscript(name, width, nodeattributes, key)
	local b = AceGui:Create("MultiLineEditBox")
	b:SetWidth(width)
	b:SetLabel(name)
	b:SetWidth(width)
	b:SetNumLines(5)
	b:SetCallback("OnTextChanged", function(self,callback,text) nodeattributes[key] = text end)
	return b
end

local function lkEditBox(name, width, nodeattributes, key)
	local b = AceGui:Create("EditBox")
	b:SetWidth(width)
	b:SetLabel(name)
	b:SetCallback("OnTextChanged", function(self,callback,text) nodeattributes[key] = text end)
	return b
end

-- TODO add a second function to each type: the node generator.
local menuGenerators = {
	-- actions
	[Node.macro] = function(parent, isSearchableChild, nodeattributes, keysequence)
		local s = ""
		for i,v in pairs(keysequence) do
			s = s .. " " .. v
		end
		parent:AddChild(lkKeybindPrefixLabel(s, 500))
		parent:AddChild(lkKeybind("Keybind:", 100, nodeattributes, "keybind"))
		parent:AddChild(lkMacroscript("Macro text:", 300, nodeattributes, "macrotext"))
		parent:AddChild(lkEditBox("Node name:", 300, nodeattributes, "nodename"))
	end,
	[item] = function(parent, isSearchableChild, nodeattributes) -- same used for spells.
		print("nyi")
		-- keybind
		-- item/spell name
	end,

	-- technical types.
	[Node.submenu] = function(parent, isSearchableChild, nodeattributes)
		-- keybind
		-- name
	end,
	[Node.helmSubmenu] = function(parent, isSearchableChild, nodeattributes)
		-- keybind
		-- name
	end,
	[Node.softlink] = function(parent, isSearchableChild, nodeattributes)
		print("nyi.")
		-- keybind
		-- softlink
		-- name
	end
}
menuGenerators[spell] = menuGenerators[item]
-- for plugin in plugins do if menuGenerators[pluginName] then error end menuGenerators[pluginName] = pluginfunc.

local aceguiframe = AceGui:Create("Frame")
aceguiframe:Hide()
aceguiframe:SetTitle("edit keybind")
aceguiframe:SetStatusText("status text")

local typeDropDown = AceGui:Create("DropdownGroup")
typeDropDown:SetWidth(200)
typeDropDown:SetGroupList{[Node.macro]="Macro",item="Item",todo="Todo"}
typeDropDown:SetCallback("OnGroupSelected", function(self, callback, group)
	self:ReleaseChildren()

	local nodeattributes = {}
	local isSearchableParent = false

	local keysequence = LeaderKey.private.copyKeySequence(self:GetUserDataTable().keysequence or {})
	if menuGenerators[group] then menuGenerators[group](self, isSearchableParent, nodeattributes, keysequence or {}) end

	self:AddChild(button("Create keybind.", 200, function()
		print("nodeattributes")
		for i,v in pairs(nodeattributes) do
			print(i,v)
		end

		if not nodeattributes.keybind then print("no keybind") return end
		tinsert(keysequence, nodeattributes.keybind)
		local node = Node.CreateMacroNode(nodeattributes.nodename, nodeattributes.macrotext)
		LeaderKey.dobind(keysequence, node)

		LeaderKey.UpdateKeybinds()

		-- reset state so that the editbox can be used again.
		keysequence = LeaderKey.private.copyKeySequence(self:GetUserDataTable().keysequence)
	end))
end)
typeDropDown:SetGroup("macro")
aceguiframe:AddChild(typeDropDown)


--[[
/script showEditor()
/script showEditor({"K"})
/script showEditor({"K", "P"})
/script showEditor({"K", "D"})
/script showEditor({"INSERT"})

/script SetRaidTarget("mouseover", 1)
/script SetRaidTarget("mouseover", 1)
s c d t moon q g f
/script SetRaidTarget("mouseover", 8)

/cast Rockbiter Weapon(Rank 3)
/cast Flametongue Weapon(Rank 2)
/cast Lightning Shield(Rank 1)
{rt1}
{rt2}
{rt3}
{rt4}
{rt5}
{rt6}
{rt7}
{rt8}
--]]
function showEditor(keySequence)
	if aceguiframe:IsShown() then
		print("already shown.")
		return
	end
	aceguiframe:Show()
	typeDropDown:GetUserDataTable().keysequence = keySequence
	typeDropDown:SetGroup("macro")
end

local keyboardFrame = CreateFrame("Frame", "myframe", UIParent)
keyboardFrame:EnableKeyboard(true)
keyboardFrame:SetPropagateKeyboardInput(true)
keyboardFrame:SetFrameStrata("TOOLTIP") -- Determines priority for receiving keyboard events.
keyboardFrame:HookScript("OnKeyDown", function(frame, key)
	frame:SetPropagateKeyboardInput(true)
	if key == "C" and IsAltKeyDown() and LeaderKey.IsMenuOpen() then
		showEditor(LeaderKey.GetCurrentKeySequence())
		frame:SetPropagateKeyboardInput(false)
	end
end)


-- TODO refactor into separate file
--[[


local radio = AceGui:Create("Dropdown")
radio:SetWidth(200)
radio:SetList{"one", "two", "three"}
radio:SetValue(1)
aceguiframe:AddChild(radio)
--aceguiframe:SetLayout("Flow")




local typeDropDown = AceGui:Create("TabGroup")
typeDropDown:SetWidth(200)
typeDropDown:SetTabs{{[1]="macro", text="Macro"},{[3]="item", text="Item"},{[2]="todo", text="TODO"}}
typeDropDown:SelectTab("macro")
aceguiframe:AddChild(typeDropDown)

[ K L A ] [ item |v|] [ itemname ] [nodename]
See if you can use a headless inventory plugin to get the item without having to type the whole name.

Alternative, for when the menu is started from inside a partial keybinding, and you're adding a ndoe:
K L [   ] [ item |v|] [ itemname ] [nodename]

In searchable submenu:
[ K L (gray text, disabled)] [item |v] [ itemname ] [node name]

softlink:
[ K L A ] [softlink|v] [ inventory ]

Focus transfer with Tab, s-Tab.
The dropdown should be typable with autocomplete.

Below this first line should go any other attributes.

Custom node:
[ K L A ]
--]]

local AceConsole = LibStub("AceConsole-3.0")
LeaderKey.registerSlashCommand("/level", function(msg)
	level1, level2 = AceConsole:GetArgs(msg, 2)
	s = ""
	CensusPlus_UpdateView()
end)

