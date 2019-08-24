local Log = LeaderKey.private.Log
local tableIsEmpty = LeaderKey.private.tableIsEmpty

local colors = LeaderKey.private.colors

local Node = LeaderKey.BindingsTree.Node
local isMenu = Node.isMenu

-- ### user interface display code.

local numRows, numCols = 8, 3
local listItems = {}
local function setupFrames()
	local lastTopFrame = nil
	local lastFrame = nil
	local bottomAnchor = nil
	for col=1,numCols do
		for row=1,numRows do
			--local frame = CreateFrame("Frame", "LeaderKeyNextKeyListEntry" .. ((col - 1) * numRows + row), LeaderKeyMenu, "LeaderKeyNextKeyListEntry")
			local frame = CreateFrame("Frame", nil, LeaderKeyMenu, "LeaderKeyNextKeyListEntry")
			if col == 1 and row == 1 then -- The very first list item can't be anchored to another list item.
				frame:SetPoint("TOPLEFT", "LeaderKeyMenuSequenceInProgressBar", "BOTTOMLEFT")
				lastTopFrame = frame
			elseif row == 1 then
				frame:SetPoint("TOPLEFT", lastTopFrame, "TOPRIGHT")
				lastTopFrame = frame
			elseif col == 1 and row == numRows then
				frame:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT")
				bottomAnchor = frame
			else
				frame:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT")
			end

			listItems[#listItems + 1] = frame
			lastFrame = frame
		end
	end
	LeaderKeyMenuOptions:SetPoint("TOPLEFT", bottomAnchor, "BOTTOMLEFT")
end
setupFrames()

local function clearListItems()
	for _,listItem in pairs(listItems) do
		listItem.bindText:SetText("")
		listItem.actionText:SetText("")
	end
end

local function sequenceStringToArray(keySequenceString)
	local keySequence = {}
	for key in keySequenceString:gmatch("%S+") do
		keySequence[#keySequence + 1] = key
	end
	return keySequence
end

local function prettySort(nodeList)
	local sorted = {}

	for nextBind,nextNode in pairs(nodeList) do
		if not isMenu(nextNode) then
			sorted[#sorted + 1] = {[nextBind]=nextNode}
		end
	end
	for nextBind,nextNode in pairs(nodeList) do
		if isMenu(nextNode) then
			sorted[#sorted + 1] = {[nextBind]=nextNode}
		end
	end

	return sorted
end

-- f = CreateFrame("ScrollFrame", nil, UIParent)
-- f:SetSize(500, 500)
-- f:SetPoint("TOPLEFT")
-- t = f:CreateTexture("OVERLAY", "OVERLAY")
-- t:SetColorTexture(1,0,0)
-- t:SetPoint("TOPLEFT")
-- t:SetSize(900, 200)
-- f:Show()

--[[
local pool = CreateFramePool("FRAME", LeaderKeyMenu, "LeaderKeyNextKeyListEntry", nil)
local previous_Acquire = pool.Acquire
function pool:Acquire(keybind, icon, actionText, bindText)
	local f = previous_Acquire()
	f.bindText:SetText(bindText.." -> ")
	f.actionText:SetText(actionText)
end
--]]

-- getTextNodeFrame(keybind, icon, text)

--[[
--]]

local function displayNodes(nodeList)
	-- local nodeFrame = getTextNodeFrame(keybind, icon, text)
	-- addNodeFrame(nodeFrame)
	-- LeaderKeyMenu:AddChild(keybind, icon, text)

	local i = 1
	local sortedNodes = prettySort(nodeList)
	for _,node in pairs(sortedNodes) do
		local nextBind, nextNode
		for i,v in pairs(node) do -- should only be 1 item in there.
			nextBind, nextNode = i, v
		end
		local iconText = ""
		if nextNode.icon then
			iconText = "|T"..nextNode.icon..":18|t "
		end
		local nodeName = "TODO removeme"
		if nextNode.type == Node.MACRO then
			if strfind(nextNode.macro, "use") then
			else
				nodeName = (nextNode.name or nextNode.macro or "nil")
			end
		else
			nodeName = (nextNode.name or "[no name]")
		end
		local text = nextBind .. " -> " .. iconText .. colors[nextNode.type] .. nodeName .. colors.noColor

		local actionFrame = listItems[i]
		-- TODO display number.
		if actionFrame ~= nil then actionFrame.actionText:SetText(text) end
		--[[
		if actionFrame ~= nil then
			actionFrame.actionText:SetText(text)
			if not actionFrame.itemIcon then
				print("bla")
				actionFrame.itemIcon = actionFrame:CreateTexture("OVERLAY")
				actionFrame.icon:SetPoint("TOPLEFT")
				actionFrame.icon:SetSize(50,50)
			end
			actionFrame.itemIcon:SetTexture(select(10, GetItemInfo(818)))
			-- SetItemButtonTexture(itemFrame, GetContainerItemInfo(1,6))
			-- local itemFrame = CreateFrame("Button", nil, actionFrame, "ContainerFrameItemButtonTemplate")
			-- itemFrame.icon = itemFrame:CreateTexture()
			-- itemFrame.icon:SetSize(100, 100)
			-- SetItemButtonTexture(itemFrame, GetContainerItemInfo(1, 6))
			-- itemFrame:SetPoint("TOPLEFT", actionFrame, "TOPLEFT")
		end
		--]]
		i = i + 1
	end
	--[[
	if #nodeList == 0 then
		local actionFrame = listItems[1]
		if actionFrame ~= nil then
			actionFrame.bindText:SetText("Nothing here! - TODO improve.")
		end
	end
	--]]
end

-- Takes a string which is the buttons pressed so far separated by spaces.
local function displayKeySequenceState(keySequenceString, helmString)
	-- TODO print something special when submenu has no binds.
	if not keySequenceString then
		Log.debug("Not displaying menu.")
		clearListItems()
		LeaderKeyMenu:Hide()
		return
	end

	Log.debug("Displaying menu for", keySequenceString .. ".")
	if helmString then
		Log.debug("Helm string detected", helmString)
	end

	local keySequence = sequenceStringToArray(keySequenceString)

	clearListItems()

	local node = LeaderKey.GetRootNode():GetNode(keySequence)
	if not node then Log.error("Node " .. table.concat(keySequence, " ") .. " does not exist."); return end

	if node.type == Node.SUBMENU then
		LeaderKeyMenu:Show()

		LeaderKeyMenuSequenceInProgressBar.Text:SetText(node.name or "nil")

		if tableIsEmpty(node.bindings) then
			Log.error("|cFFFF0000No bindings, press escape to quit. This should not happen.|r")
		end

		displayNodes(node.bindings)
	elseif node.type == Node.HELM_SUBMENU then
		LeaderKeyMenu:Show()

		LeaderKeyMenuSequenceInProgressBar.Text:SetText((node.name or "nil") .. " " .. (helmString or "nil") .. "_")

		local matchingNodes = LeaderKey.private.helmMenuSearch(helmString, node.bindings)
		displayNodes(matchingNodes)
	elseif node.type == Node.MACRO then
		LeaderKeyMenu:Hide()

		Log.info(colors.castPrint .. "-> casting spell:", node.macro, "|r")
	end
end
LeaderKey.registerForKeySequenceStateUpdate(displayKeySequenceState)

-- TODO refactor into separate file
--[[
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
local LeaderKeyNodeEditFrame = CreateFrame("Frame") -- TODO use xml or ace?

