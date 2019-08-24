if not LeaderKey then LeaderKey = {} end
if not LeaderKey.private then LeaderKey.private = {} end

local ns = LeaderKey.private

--[[
Slash command:
/lkb[ind] pluginname [customNodeName]
/lkb[ind] spell spellname [customNodeName]
/lkb[ind] item itemname [customNodeName] -- Take item links? Links are easy to insert.
/lkb[ind] macro macrotext [customNodeName]

/lkname

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

LeaderKey.VDT = {}

ns.runTests = true

LeaderKey.BindingsTree = {}
-- ### Node types
LeaderKey.BindingsTree.Node = {}
LeaderKey.BindingsTree.Node.submenu = "submenu"
LeaderKey.BindingsTree.Node.helmSubmenu = "helm_submenu"
LeaderKey.BindingsTree.Node.macro = "macro"
LeaderKey.BindingsTree.Node.spell = "spell"
LeaderKey.BindingsTree.Node.softlink = "softlink"

LeaderKey.BindingsTree.Node.SUBMENU = LeaderKey.BindingsTree.Node.submenu
LeaderKey.BindingsTree.Node.HELM_SUBMENU = LeaderKey.BindingsTree.Node.helmSubmenu
LeaderKey.BindingsTree.Node.MACRO = LeaderKey.BindingsTree.Node.macro
LeaderKey.BindingsTree.Node.SPELL = LeaderKey.BindingsTree.Node.spell
LeaderKey.BindingsTree.Node.SOFTLINK = LeaderKey.BindingsTree.Node.softlink

-- ### Colors
ns.colors = {}
-- TODO name these with a canonical name.
ns.colors[LeaderKey.BindingsTree.Node.submenu] = "acd3ff"
ns.colors[LeaderKey.BindingsTree.Node.helmSubmenu] = "51baff"
ns.colors[LeaderKey.BindingsTree.Node.macro] = "ffa500"
ns.colors[LeaderKey.BindingsTree.Node.softlink] = "3dd91e"
ns.colors.castPrint = "ff00ff"
ns.colors.keySequence = "c8cfa7"
for name,color in pairs(ns.colors) do
	ns.colors[name] = "|cff" .. color
end
ns.colors.noColor = "|r"

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
LeaderKey.private.AfterLeaderKeyHandlerFrame:SetFrameRef("ref", MovePadJump) -- This isn't really a good way to do it because it has to happen out of combat.
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

local Node = LeaderKey.BindingsTree.Node

local mydynamicmenu = Node.CreateHelmSubmenu("inventory")

for bag = 0, NUM_BAG_SLOTS do
	for slot = 1, GetContainerNumSlots(bag) do
		local icon, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
		if itemID then
			local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
			itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
			isCraftingReagent = GetItemInfo(itemID) 

	-- https://wowwiki.fandom.com/wiki/ItemType
			-- TODO on use items.
			-- TODO equipment sets.
			-- equipped items (in case you unequip them in combat).
			-- Combat filter? For Armor.
			if not itemName then print(itemID) end
			if itemType == "Armor" or itemType == "Weapon" then
				local node = Node.CreateMacroNode(itemName, "/equip "..itemName)
				node.icon = itemIcon
				tinsert(mydynamicmenu.bindings, node)
			elseif itemType == "Consumable" then
				tinsert(mydynamicmenu.bindings, Node.CreateMacroNode(itemName, "/use "..itemName))
			end
			-- print(itemName, itemType, itemSubType)
		end
	end
end
LeaderKey.RegisterDynamicMenu("inventory", mydynamicmenu) -- TODO should the name be optional? It's currently included twice.

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
function events:PLAYER_SPECIALIZATION_CHANGED(...)
	if ... ~= "player" then return end
	-- TODO detect spec vs talent change.
	-- Log.debug("PLAYER_SPECIALIZATION_CHANGED new spec", GetSpecialization())
	-- LeaderKey.UpdateKeybinds()
end
function events:PLAYER_REGEN_ENABLED(...)
	LeaderKey.private.flushOutOfCombatQueue()
end

registerEventHandlers(events)

