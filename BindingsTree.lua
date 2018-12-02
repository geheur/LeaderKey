LeaderKey.BindingsTree = {}
LeaderKey.BindingsTree.Node = {}

local BindingsTree = LeaderKey.BindingsTree
local Node = BindingsTree.Node

local slice = LeaderKey.private.slice
local debugPrint = LeaderKey.private.debugPrint
local tableSize = LeaderKey.private.tableSize
local Log = LeaderKey.private.Log

-- ### Node constructors.

local SUBMENU = "submenu"
local HELM_SUBMENU = "helm-submenu"
local MACRO = "macro"
local SOFTLINK = "softlink"
local SPELL = "spell"
local PET = "spell"
--local MOUNT = SPELL
Node.SUBMENU = SUBMENU
Node.HELM_SUBMENU = HELM_SUBMENU
Node.MACRO = MACRO
Node.SOFTLINK = SOFTLINK
Node.SPELL = SPELL
Node.PET = PET
--Node.MOUNT = MOUNT

function Node.CreateNode(name, type)
	return {name = name, type = type}
end

function Node.CreateMacroNode(name, macro)
	name = name or "MACRO: " .. macro
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

function Node.CreateSoftLink(name, keySequence)
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
	--print("bla", table.concat(keySequence, ","))
	keySequence = slice(keySequence, 1, #keySequence - 1)
	i = 1
	local value = keySequence[i]
	local node = self

	while value do
		--print("value", value)
		--print("value", node.bindings[value])
		if not node.bindings[value] or not Node.isMenu(node.bindings[value]) then
			return nil
		end
		--print("value2", node.bindings[value].type)
		node = node.bindings[value]
		i = i + 1
		value = keySequence[i]
	end
	return node
end

function BindingsTree:GetNode(keySequence)
	if #keySequence == 0 then return self end
	local parent = self:GetParentNode(keySequence)
	--print("parent", parent, bind)
	--if parent ~= nil then print("parentname", parent.name, bind) end
	if not parent then return nil end
	local bind = keySequence[#keySequence]
	--if parent ~= nil then print("parentname2", parent.name, bind) end
	if not parent or not Node.isMenu(parent) or not parent.bindings[bind] then
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

function BindingsTree:NameNode(name, keySequence)
	local node = self:GetNode(keySequence)
	if not node then Log.warning("Node " .. table.concat(keySequence, " ") .. " does not exist."); return false end
	node.name = name
	return true
end

