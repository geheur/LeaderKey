local Log = LeaderKey.private.Log
local secureTableInsert = LeaderKey.private.secureTableInsert

local BindingsTree = LeaderKey.BindingsTree
local Node = LeaderKey.BindingsTree.Node

local keySequencePrefix = {"L"}
local dynamicMenuPrefix = {"D"}

local function CreateRootMenu()
	local rootmenu = BindingsTree:cast(Node.CreateSubmenu("Root"))
	local dynamicMenuNode = Node.CreateHelmSubmenu("Dynamic Menus")

	return rootmenu
end

local RootNode = CreateRootMenu()
LeaderKey.VDT.RootNode = RootNode

local CurrentBindings
--[[
Creates a Leader Keys submenu under the root.
--]]
local function CreateBindingsTree()
	CurrentBindings = BindingsTree:cast(Node.CreateSubmenu("Leader Keys"))
	RootNode:AddBind(CurrentBindings, keySequencePrefix)

	LeaderKey.ViragCurrentBindingsPointer = CurrentBindings
end

local function BuildCurrentBindingsTree()
	CreateBindingsTree()

	Log.debug("adding account bindings")
	CurrentBindings:mergeInTree(LeaderKey.GetAccountBindingsTree())
	--Log.debug("adding class bindings")
	--CopyInBindingsTree(CurrentBindings, LeaderKey.GetCurrentClassBindingsTree())
	--Log.debug("adding spec bindings")
	--CopyInBindingsTree(CurrentBindings, LeaderKey.GetCurrentSpecBindingsTree())
end

local function UpdateKeybinds_OutOfCombat()
	BuildCurrentBindingsTree()

	LeaderKey.private.LeaderKeyOverrideBindOwner:Execute("self:ClearBindings()")
	local LeaderKeyNode = CurrentBindings
	for key,_ in pairs(LeaderKeyNode.bindings) do
		SetOverrideBindingClick(LeaderKey.private.LeaderKeyOverrideBindOwner, true, key, LeaderKey.private.AfterLeaderKeyHandlerFrame:GetName(), key)
	end

	secureTableInsert(LeaderKey.private.AfterLeaderKeyHandlerFrame, "Bindings", RootNode)
	LeaderKey.private.AfterLeaderKeyHandlerFrame:Execute("self:Run(ClearSequenceInProgress)")
end

-- Updates keybind tree in AfterLeaderKeyHandlerFrame's restricted environment, and makes sure leader keys are bound. Out of combat only, obviously.
local updateQueue = {}
local updateKeybindsQueued = false
local function doOutOfCombat(func)
	if InCombatLockdown() then
		tinsert(updateQueue, func)
	else
		func()
	end
end
function LeaderKey.private.flushOutOfCombatQueue()
	if updateKeybindsQueued then
		UpdateKeybinds_OutOfCombat()
		updateKeybindsQueued = false
	end

	if #updateQueue == 0 then return end

	Log.debug("flushing out of combat queue (" .. #updateQueue .. " items)")
	for i,func in ipairs(updateQueue) do
		Log.debug("flushing item " .. i)
		func()
	end
end
--[[
-- TODO callback for the update being successful.

-- TODO visual menu sees updates too early. There needs to be a separate tree for that. Best way is to not update the tree in combat!
--]]
function LeaderKey.UpdateKeybinds()
	if InCombatLockdown() then
		updateKeybindsQueued = true
	else
		UpdateKeybinds_OutOfCombat()
	end
end

-- ### public api.
-- TODO Should I expose the bindings trees like this? It feel very weird to call a function which requires the return value of another function. What if I made strings to represent each scope instead?

function LeaderKey.GetCurrentBindingsTree()
	return CurrentBindings
end

function LeaderKey.GetAccountBindingsTree()
	if LeaderKeyData.accountBindings then
		if not getmetatable(LeaderKeyData.accountBindings) then
			LeaderKeyData.accountBindings = BindingsTree:cast(LeaderKeyData.accountBindings)
		end
	else
		LeaderKeyData.accountBindings = BindingsTree:new()
	end
	return LeaderKeyData.accountBindings
end

function LeaderKey.GetRootNode()
	return RootNode
end

--[[ - spec, class, character bindings
local ALL_SPECS = "ALL"
function LeaderKey.GetSpecBindingsTree(class, spec)
	LeaderKeyData.classBindings[class] = LeaderKeyData.classBindings[class] or BindingsTree:new()
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

-- NYI
function LeaderKey.GetCharacterBindingsTree(node, keySequence)
	LeaderKeyCharacterData = LeaderKeyCharacterData or {}
	LeaderKeyCharacterData.bindings = LeaderKeyCharacterData.bindings or BindingsTable:new()
	return LeaderKeyCharacterData.bindings
end
--]]

--[[
creationCallback is a function called whenever a dynamic menu is created. This happens when one is bound, either due to user action or due to the addon loading its binds.
creationCallback takes 1 argument: a token which represents the menu, used to request LeaderKey to reload the menu.
--]]

local function prepend(prefix, keySequence)
	local result = {}
	for i=1,#prefix do
		result[#result + 1] = prefix[i]
	end
	for i=1,#keySequence do
		result[#result + 1] = keySequence[i]
	end
	return result
end

function LeaderKey.GetDynamicMenuHandle(name)
	local sequence = prepend(dynamicMenuPrefix, {name})
	return RootNode:GetNode(sequence)
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

LeaderKey.DynamicMenuRegistry = {}
function LeaderKey.RegisterDynamicMenu(name, node)
	local sequence = prepend(dynamicMenuPrefix, {name}) -- name is used as the keybind only because it'll be unique. it's a searchable menu anyways so this won't affect usability.
	LeaderKey.DynamicMenuRegistry[name] = node
	doOutOfCombat(function()
		RootNode:AddBind(node, sequence)
	end)
	LeaderKey.UpdateKeybinds()
end

function LeaderKey.UpdateDynamicMenu(token)
	print("NYI - UpdateDynamicMenu")
end


