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
		listItem.Text:SetText("")
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

local function displayNodes(nodeList)
	if #nodeList == 0 then
		local actionFrame = listItems[i]
		if actionFrame ~= nil then
			actionFrame.Text:SetText("Nothing here! - TODO improve.")
		end
	end
	local i = 1
	local sortedNodes = prettySort(nodeList)
	for _,node in pairs(sortedNodes) do
		local nextBind, nextNode
		for i,v in pairs(node) do -- should only be 1 item in there.
			nextBind, nextNode = i, v
		end
		local iconText = ""
		if nextNode.icon then
			iconText = "|T"..nextNode.icon..":0|t"
		end
		local nodeName
		if nextNode.type == Node.MACRO then
			nodeName = (nextNode.name or nextNode.macro or "nil")
		else
			nodeName = (nextNode.name or "[no name]")
		end
		local text = nextBind .. " -> " .. iconText .. colors[nextNode.type] .. nodeName .. colors.noColor

		local actionFrame = listItems[i]
		if actionFrame ~= nil then
			actionFrame.Text:SetText(text)
		end
		i = i + 1
	end
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
		Log.debug("showing options helm submenu")
		LeaderKeyMenuSequenceInProgressBar.Text:SetText((node.name or "nil") .. " " .. (helmString or "nil"))

		local matchingNodes = LeaderKey.private.helmMenuSearch(helmString, node.bindings)
		displayNodes(matchingNodes)
	elseif node.type == Node.MACRO then
		LeaderKeyMenu:Hide()

		Log.info(colors.castPrint .. "-> casting spell:", node.macro, "|r")
	end
end
LeaderKey.registerForKeySequenceStateUpdate(displayKeySequenceState)

