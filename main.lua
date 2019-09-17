local Log = LeaderKey.private.Log
local secureTableInsert = LeaderKey.private.secureTableInsert

local BindingsTree = LeaderKey.BindingsTree
local Node = LeaderKey.BindingsTree.Node

local keySequencePrefix = {"L"}
local dynamicMenuPrefix = {"D"}
LeaderKey.private.dynamicMenuPrefix = dynamicMenuPrefix

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
function LeaderKey.private.doOutOfCombat(func)
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

function LeaderKey.private.prepend(prefix, keySequence)
	local result = {}
	for i=1,#prefix do
		result[#result + 1] = prefix[i]
	end
	for i=1,#keySequence do
		result[#result + 1] = keySequence[i]
	end
	return result
end

function LeaderKey.GetDynamicMenuSequence(name)
	return LeaderKey.private.prepend(dynamicMenuPrefix, {name})
end

function LeaderKey.GetDynamicMenuHandle(name)
	local sequence = LeaderKey.private.prepend(dynamicMenuPrefix, {name})
	return RootNode:GetNode(sequence)
end



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
-- LeaderKey.private.AfterLeaderKeyHandlerFrame:SetFrameRef("ref", MovePadJump) -- This isn't really a good way to do it because it has to happen out of combat.
	LeaderKey.private.Log.debug("PLAYER_ENTERING_WORLD")
	local debug = true
	if ViragDevTool_AddData and debug then
		ViragDevTool_AddData(LeaderKey.ViragCurrentBindingsPointer.bindings, "LKMAP")
		ViragDevTool_AddData(LeaderKeyData.accountBindings, "LKMAP_ACCOUNT")
		ViragDevTool_AddData(LeaderKeyData.classBindings, "LKMAP_CLASS")
		-- ViragDevTool_AddData(LeaderKey.GetCurrentClassBindingsTree(), "LKMAP_CURRENT_CLASS")
		ViragDevTool_AddData(LeaderKey.VDT, "LeaderKey")
		--ViragDevTool_AddData(ViragCurrentSpecBindingsPointer.bindings, "LKMAP")
	end

end
do
	local addonIsLoaded = false
	function events:ADDON_LOADED(...)
		if addonIsLoaded then return end

		-- LeaderKeyData = nil -- for debugging
		-- LeaderKey.loadstuff() -- load in my keybindings if something goes wrong and I have to restore from backup.

		LeaderKeyData = LeaderKeyData or {} -- TODO initialize account/class/spec/character bindings?
		LeaderKey.UpdateKeybinds()

		addonIsLoaded = true
	end
end
function events:PLAYER_REGEN_ENABLED(...)
	LeaderKey.private.flushOutOfCombatQueue()
end

registerEventHandlers(events)

