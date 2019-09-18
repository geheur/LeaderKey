select(2, ...).setenv()

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
		local prefix = lkKeybindPrefixLabel(s, 500)
		local keybind = lkKeybind("Keybind:", 100, nodeattributes, "keybind")
		local macro = lkMacroscript("Macro text:", 300, nodeattributes, "macrotext")
		local nodeName = lkEditBox("Node name:", 300, nodeattributes, "nodename")
		parent:AddChild(prefix)
		parent:AddChild(keybind)
		parent:AddChild(macro)
		parent:AddChild(nodeName)

		nodeattributes.prefix = keysequence

		if parent:GetUserDataTable().node then
			local keysequenceprefix = copyKeySequence(keysequence)
			keysequenceprefix[#keysequenceprefix] = nil

			nodeattributes.prefix = keysequenceprefix
			nodeattributes.keybind = keysequence[#keysequence]
			nodeattributes.macrotext = parent:GetUserDataTable().node.macro
			nodeattributes.nodename = parent:GetUserDataTable().node.name
			prefix:SetText(s)
			keybind:SetKey(keysequence[#keysequence])
			macro:SetText(parent:GetUserDataTable().node.macro)
			nodeName:SetText(parent:GetUserDataTable().node.name)
		end
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
		local s = ""
		for i,v in pairs(keysequence) do
			s = s .. " " .. v
		end
		local prefix = lkKeybindPrefixLabel(s, 500)
		local keybind = lkKeybind("Keybind:", 100, nodeattributes, "keybind")
		local nodeName = lkEditBox("Node name:", 300, nodeattributes, "nodename")
		parent:AddChild(prefix)
		parent:AddChild(keybind)
		parent:AddChild(nodeName)

		nodeattributes.prefix = keysequence

		if parent:GetUserDataTable().node then
			local keysequenceprefix = copyKeySequence(keysequence)
			keysequenceprefix[#keysequenceprefix] = nil

			nodeattributes.prefix = keysequenceprefix
			nodeattributes.keybind = keysequence[#keysequence]
			nodeattributes.nodename = parent:GetUserDataTable().node.name
			prefix:SetText(s)
			keybind:SetKey(keysequence[#keysequence])
			nodeName:SetText(parent:GetUserDataTable().node.name)
		end
	end
}
menuGenerators[spell] = menuGenerators[item]

local nodeGenerators = {
	-- actions
	[Node.macro] = function(nodeattributes)
		local node = Node.CreateMacroNode(nodeattributes.nodename, nodeattributes.macrotext)
		return node
	end,
	[item] = function(nodeattributes) -- same used for spells.
		print("nyi")
		-- keybind
		-- item/spell name
	end,

	-- technical types.
	[Node.submenu] = function(nodeattributes)
		-- keybind
		-- name
	end,
	[Node.helmSubmenu] = function(nodeattributes)
		-- keybind
		-- name
	end,
	[Node.softlink] = function(nodeattributes)
		print("nodeattributes.dynamicmenuname", nodeattributes.dynamicmenuname)
		local sequence = LeaderKey.GetDynamicMenuSequence(nodeattributes.dynamicmenuname)

		local node = Node.CreateSoftlink(nodeattributes.nodename, sequence)
		return node
	end
}
nodeGenerators[spell] = nodeGenerators[item]

local aceguiframe = AceGui:Create("Frame")
aceguiframe:Hide()
aceguiframe:SetTitle("edit keybind")
aceguiframe:SetStatusText("status text")

local groupList = {[Node.macro]="Macro",[item]="Item"}
local typeDropDown = AceGui:Create("DropdownGroup")
typeDropDown:SetWidth(200)
typeDropDown:SetGroupList(groupList)
typeDropDown:SetCallback("OnGroupSelected", function(self, callback, group)
	self:ReleaseChildren()

	local nodeattributes = {}
	local isSearchableParent = false

	keysequence = copyKeySequence(self:GetUserDataTable().keysequence or {})
	print("group", group)

	if menuGenerators[group] then menuGenerators[group](self, isSearchableParent, nodeattributes, keysequence or {})
	else
		nodeattributes.dynamicmenuname = group
		menuGenerators[Node.softlink](self, isSearchableParent, nodeattributes, keysequence or {})
	end

	self:AddChild(button("Create keybind.", 200, function()
		if not nodeattributes.keybind then print("no keybind") return end

		print("nodeattributes")
		for i,v in pairs(nodeattributes) do
			print("\t", i,v)
		end

		local fullkeysequence = copyKeySequence(nodeattributes.prefix)
		tinsert(fullkeysequence, nodeattributes.keybind)

		local node
		if nodeGenerators[group] then node = nodeGenerators[group](nodeattributes)
		else
			nodeattributes.dynamicMenuName = group
			node = nodeGenerators[Node.softlink](nodeattributes)
		end

		dobind(fullkeysequence, node)

		-- reset state so that the editbox can be used again.
		keysequence = copyKeySequence(self:GetUserDataTable().keysequence)
	end))
end)
typeDropDown:SetGroup("macro")
aceguiframe:AddChild(typeDropDown)

aceguiframe:SetCallback("OnShow", function(self)
	local keySequence = typeDropDown:GetUserDataTable().keysequence
	local node = typeDropDown:GetUserDataTable().node

	if node then
		typeDropDown:SetGroup(node.type)
	end
end)

function showEditor(keySequence, node)
	if aceguiframe:IsShown() then
		print("already shown.")
		return
	end
	typeDropDown:GetUserDataTable().keysequence = keySequence
	typeDropDown:GetUserDataTable().node = node
	aceguiframe:Show()
	typeDropDown:SetGroup("macro")
end

LeaderKey.RegisterForDynamicMenuAdded(function(name, node)
	if groupList[name] then error("name already in use.") return end
	groupList[name] = name
	typeDropDown:SetGroupList(groupList)
end)

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

local function addModifiersToBaseKeyName(baseKeyName)
	local t = {}
	-- Order matters! "SHIFT-ALT-T" is not a valid keybind!
	t[#t+1] = IsAltKeyDown() and "ALT" or nil
	t[#t+1] = IsControlKeyDown() and "CTRL" or nil
	t[#t+1] = IsShiftKeyDown() and "SHIFT" or nil
	t[#t+1] = baseKeyName
	return table.concat(t, "-")
end

local keyboardFrame = CreateFrame("Frame", "myframe", UIParent)
local mode
keyboardFrame:EnableKeyboard(true)
keyboardFrame:SetPropagateKeyboardInput(true)
keyboardFrame:SetFrameStrata("TOOLTIP") -- Determines priority for receiving keyboard events.
keyboardFrame:HookScript("OnKeyDown", function(frame, key)
	frame:SetPropagateKeyboardInput(true)

	-- TODO just use a queue and allow this in combat.

	if mode then
		local currentSequence = LeaderKey.GetCurrentKeySequence()
		tinsert(currentSequence, addModifiersToBaseKeyName(key))
		local node = LeaderKey.GetCurrentBindingsTree():GetNode(currentSequence)
		if not node then print("no binding on that key.") end
		if mode == "delete" then
			LeaderKey.GetAccountBindingsTree():DeleteNode(currentSequence)
			LeaderKey.UpdateKeybinds()
			print("deleted node")
		elseif mode == "change" then
			showEditor(currentSequence, node)
		end
		mode = nil
		frame:SetPropagateKeyboardInput(false)
	elseif key == "ESCAPE" and aceguiframe:IsShown() then
		aceguiframe:Hide()
	elseif key == "A" and IsAltKeyDown() and LeaderKey.IsMenuOpen() then
		showEditor(LeaderKey.GetCurrentKeySequence())
		frame:SetPropagateKeyboardInput(false)
	elseif key == "E" and IsAltKeyDown() and LeaderKey.IsMenuOpen() then
		mode = "change"
		print("Press key to edit.")
		frame:SetPropagateKeyboardInput(false)
	elseif key == "D" and IsAltKeyDown()
		and IsCtrlKeyDown() and IsShiftKeyDown()
	and LeaderKey.IsMenuOpen() then
		mode = "delete"
		print("Press key to delete.")
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


-- for plugin in plugins do if menuGenerators[pluginName] then error end menuGenerators[pluginName] = pluginfunc.



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
