local BindingsTree = LeaderKey.BindingsTree
local Node = BindingsTree.Node

local slice = LeaderKey.private.slice
local tableSize = LeaderKey.private.tableSize
local Log = LeaderKey.private.Log

-- ### Node constructors.
local SUBMENU = Node.submenu
local HELM_SUBMENU = Node.helmSubmenu
local MACRO = Node.macro
local SOFTLINK = Node.softlink
local SPELL = Node.spell
-- local PET = Node.spell

function Node.CreateNode(name, type)
	return {name = name, type = type}
end

function Node.CreateMacroNode(name, macro)
	name = name or macro
	local macroNode = Node.CreateNode(name, MACRO)
	macroNode.macro = macro
	return macroNode
end

function Node.CreateSpellNode(name, spellName)
	local node = Node.CreateMacroNode(name, '/use ' .. spellName)
	node.icon = select(3, GetSpellInfo(spellName))
	return node
end

function Node.CreateSubmenu(name)
	local submenu = Node.CreateNode(name, SUBMENU)
	submenu.bindings = {}
	return submenu
end

function Node.CreateHelmSubmenu(name)
	local helmMenu = Node.CreateNode(name, HELM_SUBMENU)
	helmMenu.bindings = {}
	return helmMenu
end

function Node.CreateSoftlink(name, keySequence)
	local node = Node.CreateNode(name, SOFTLINK)
	local keySequenceCopy = {}
	for i,v in pairs(keySequence) do
		keySequenceCopy[#keySequenceCopy + 1] = v
	end
	node.softlink = keySequenceCopy
	return node
end

function Node.isMenu(node)
	return node.type == SUBMENU or node.type == HELM_SUBMENU
end

-- ### BindingsTree class.
--[[
{
	type="SUBMENU",
	bindings={
		"KEYBIND_NAME"={
			type="?",
			bindings={...}
			-- other properties.
		}
	}
}
--]]


BindingsTree.type = SUBMENU
BindingsTree.__index = BindingsTree

function BindingsTree:new()
	return BindingsTree:cast({})
end

function BindingsTree:cast(toCast)
	setmetatable(toCast, self)
	if toCast.bindings == nil then toCast.bindings = {} end
	return toCast
end

function BindingsTree:GetParentNode(keySequence)
	keySequence = slice(keySequence, 1, #keySequence - 1)
	i = 1
	local value = keySequence[i]
	local node = self

	while value do
		if not node.bindings[value] or not Node.isMenu(node.bindings[value]) then
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
	if not parent or not Node.isMenu(parent) then return nil end
	local bind = keySequence[#keySequence]
	return parent.bindings[bind] -- may be nil if bind doesn't exist.
end

function BindingsTree:PrepareSubmenus(keySequence)
	local bindings = self.bindings
	keySequence = slice(keySequence, 1, #keySequence - 1)
	local i = 1
	local value = keySequence[i]

	while value do
		if not bindings[value] or not Node.isMenu(bindings[value]) then
			bindings[value] = Node.CreateSubmenu(table.concat(slice(keySequence, 1, i), " "))
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
-- TODO figure out what the return value is and document it
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
		if not node.bindings[value] or not Node.isMenu(node.bindings[value]) then
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

local function CopyInBindingsTree(currentBindingsTree, bindingsTree)
	for key,node in pairs(bindingsTree.bindings) do
		local currentNode = currentBindingsTree.bindings[key]
		if node.type == Node.SUBMENU then
			if currentNode ~= nil and currentNode.type ~= Node.SUBMENU then
				-- TODO why is this stuff commented out?
				Log.warn("(Not sure what this message is) |cFFFFA500LeaderKey: Warning: overwrote binding " .. (key or "") .. ": " .. (currentNode.name or "nil") .. " in submenu " .. (currentBindingsTree.name or "nil") .. "|r")
			end
			if currentNode == nil or currentNode.type ~= Node.SUBMENU then
				currentBindingsTree.bindings[key] = Node.CreateSubmenu(node.name) -- TODO copy function?
			end
			CopyInBindingsTree(currentBindingsTree.bindings[key], node)
			-- TODO helm submenus.
		else
			if currentNode ~= nil then
				-- TODO why is this stuff commented out?
				Log.warn("check BindingsTree.xml.") -- TODO.
				--print("|cFFFFA500LeaderKey: Warning: overwrote binding " .. (key or "") .. ": " .. (currentNode.name or "nil") .. " in submenu " .. (currentBindingsTree.name or "nil") .. "|r")
			end
			-- Log.debug("binding", currentBindingsTree.name or "", key, "to", node.name)
			currentBindingsTree.bindings[key] = node -- TODO make sure no one changes this node...
		end
	end
end

-- will replace parts of the current tree with otherTree when there are conflicts.
function BindingsTree:mergeInTree(otherTree)
	CopyInBindingsTree(self, otherTree)
end

function BindingsTree:NameNode(name, keySequence)
	local node = self:GetNode(keySequence)
	if not node then Log.warn("Node " .. table.concat(keySequence, " ") .. " does not exist."); return false end
	node.name = name
	return true
end

