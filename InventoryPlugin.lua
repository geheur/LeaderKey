select(2, ...).setenv()

local f = CreateFrame("FRAME")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
	if addon ~= "LeaderKey" then return end
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
				else
				-- elseif itemType == "Consumable" then
					local node = Node.CreateMacroNode(itemName, "/use "..itemName)
					node.icon = itemIcon
					tinsert(mydynamicmenu.bindings, node)
				end
				-- print(itemName, itemType, itemSubType)
			end
		end
	end
	LeaderKey.RegisterDynamicMenu("inventory", mydynamicmenu) -- TODO should the name be optional? It's currently included twice.
end)

