select(2, ...).setenv()

local dynamicMenuAddedListeners = {}
DynamicMenuRegistry = {}

function LeaderKey.RegisterDynamicMenu(name, node)
	local sequence = prepend(dynamicMenuPrefix, {name}) -- name is used as the keybind only because it'll be unique. it's a searchable menu anyways so this won't affect usability.
	DynamicMenuRegistry[name] = node
	doOutOfCombat(function()
		RootNode:AddBind(node, sequence) -- TODO don't use VDT.
	end)
	LeaderKey.UpdateKeybinds()

	for _,listener in ipairs(dynamicMenuAddedListeners) do
		listener(name, node)
	end
end

function LeaderKey.RegisterForDynamicMenuAdded(f)
	for name,node in pairs(DynamicMenuRegistry) do
		f(name, node)
	end
	tinsert(dynamicMenuAddedListeners, f)
end

function LeaderKey.UpdateDynamicMenu(token)
	print("NYI - UpdateDynamicMenu")
end

--[[
dmHandle = LeaderKey.RegisterDynamicMenu("inventoryplugin") -- This will throw if you use an existing name or a node type.
local pluginRoot = dmHandle.getPluginRoot() -- returns a copy.
pluginRoot.bindings["C"] = Node.CreateSubmenu("Consumables")
local callback = dmHandle.update(pluginRoot) -- Should probably set the name of the root node just in case.
if callback then
	-- wait, we didn't update yet

	-- I wonder if processes can be used here?
end

pluginRoot.bindings["C"] = Node.CreateSubmenu("Consumables")
callback = dmHandle.updatePartial({"Consumables"}, pluginRoot) -- TODO consider allowing menu names instead of keybinds - both here an in stuff like bindings["Consumables"].

dmHandle.registerCallback(function(node, sequence) print("selected:", node.name) end)

-- Should softlinks check if they're looking in a dynamic menu? If a menu is missing that should produce a different error message.

-- Should lazy loading be allowed? I say no, responsiveness and being combat-available is #1.

-- Should I allow internal softlinks? I suppose they could work, if the softlinks were discovered by update or updatePartial, and had their
-- targets edited. Or, I could offer a softlink creation function that is dynamic menu aware.

/lkdynamiclist

/lkbind inventoryplugin "My Inventory"(optional parameter)
	-- this should have a helpful error message listing the different types you can create nodes for.

--]]

