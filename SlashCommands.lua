-- ### Slash commands.
-- TODO usage info for bad command

local slice = LeaderKey.private.slice
local Log = LeaderKey.private.Log

local Node = LeaderKey.BindingsTree.Node

local function registerSlashCommand(id, names, func)
  for i,v in ipairs(names) do
    _G["SLASH_" .. id .. i] = v
  end
  SlashCmdList[id] = func
end

local function parseArgs(txt)
	local args = {}
	local start = nil
	local breakLoop = false;
	local i = 1
	while i <= #txt do
		local c = txt:sub(i,i)
		if c == " " then
			if start then
				args[#args + 1] = txt:sub(start,i - 1)
				start = nil
			end
			-- continue
		elseif c == "'" or c == '"' then
			if start then
				args[#args + 1] = txt:sub(start,i - 1)
				start = nil
			end
			i = i + 1
			start = i
			while i <= #txt do
				local c2 = txt:sub(i,i)
				if c2 == c then
					args[#args + 1] = txt:sub(start,i - 1)
					start = nil
					break
				elseif c2 == "\\" then
					i = i + 1
				end
				i = i + 1
			end
			if start then Log.warning("unclosed " .. c); return nil end
		else
			if c == '\\' then
				i = i + 1
				if i > #txt then Log.warning("unclosed \\"); return nil end
			end
			if not start then
				start = i
			end
		end
		i = i + 1
	end
	if start then
		args[#args + 1] = txt:sub(start,i - 1)
		start = nil
	end

	Log.debug("args:")
	for i,v in pairs(args) do
		Log.debug(i,v)
	end

	return args
end

local function cleanKeySequence(keySequence)
	for i,v in pairs(keySequence) do
		keySequence[i] = string.upper(v)
	end
	return keySequence
end

local macrotype = "macro"
local spelltype = "spell"
local helmtype = "helm"
local function SlashCommandMapBind(bindingsTree, txt, silent)
	Log.debug("raw slash command argument:", txt)
	local args = parseArgs(txt)
	if not args or not args[4] then Log.error("invalid arguments"); return end

	local type = args[1]
	local name = args[2]
	if name == "_" then name = nil end
	local contents = args[3]:gsub("\\n","\n")
	local keySequence = cleanKeySequence(slice(args, 4))

	local node
	if type == macrotype then
		node = Node.CreateMacroNode(name, contents)
	elseif type == spelltype then
		local spellName, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(contents)
		if not spellName then
			Log.error("|cFFFFA500Could not find spell " .. contents .. ".|r")
			return
		end
		node = Node.CreateSpellNode(name, spellName)
		--ViragDevTool_AddData(node, "bla")
	elseif type == helmtype then
		node = Node.CreateHelmSubmenu(name)
	else
		for i,v in pairs(LeaderKey.DynamicMenuRegistry) do
			Log.debug("dynamic menu registry:", i, v)
			if type == i then
				node = Node.CreateSoftLink(name, {"D", name})
			end
		end

		if node == nil then
			Log.error("Unknown type \"" .. type .. "\"")
			return
		end
	end

	LeaderKey.CreateBinding(bindingsTree, node, keySequence)
	LeaderKey.UpdateCurrentBindings()
	if not silent then Log.info("Created bind " .. table.concat(keySequence, " ") .. " to " .. name) end
end

local function SlashCommandMapUnbind(bindingsTree, txt)
	local args = parseArgs(txt)
	if not args or not args[1] then Log.error("invalid arguments"); return end
	local keySequence = cleanKeySequence(args)

	LeaderKey.DeleteNode(bindingsTree, keySequence)
	LeaderKey.UpdateCurrentBindings()
	Log.info("Deleted node " .. table.concat(keySequence, " ") .. " (or, it didn't exist in the first place)")
end

local function SlashCommandNameNode(bindingsTree, txt, silent)
	local args = parseArgs(txt)
	if not args or not args[1] then Log.error("invalid arguments"); return end
	local name = args[1] or "nil"
	local keySequence = cleanKeySequence(slice(args, 2))

	local successful = LeaderKey.NameNode(bindingsTree, name, keySequence)
	LeaderKey.UpdateCurrentBindings()
	if successful and not silent then
		Log.info("Named node " .. table.concat(keySequence, " ") .. " to " .. name)
	end
end

registerSlashCommand("LEADERKEY_ACCOUNT_MAP", {"/lkamap"},
                     function(txt, editbox)
								SlashCommandMapBind(LeaderKey.GetAccountBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_CLASS_MAP", {"/lkclmap"},
                     function(txt, editbox)
								SlashCommandMapBind(LeaderKey.GetCurrentClassBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_SPEC_MAP", {"/lksmap"},
                     function(txt, editbox)
								SlashCommandMapBind(LeaderKey.GetCurrentSpecBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_ACCOUNT_UNMAP", {"/lkaunmap"},
                     function(txt, editbox)
								SlashCommandMapUnbind(LeaderKey.GetAccountBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_CLASS_UNMAP", {"/lkclunmap"},
                     function(txt, editbox)
								SlashCommandMapUnbind(LeaderKey.GetCurrentClassBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_SPEC_UNMAP", {"/lksunmap"},
                     function(txt, editbox)
								SlashCommandMapUnbind(LeaderKey.GetCurrentSpecBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_ACCOUNT_NAME", {"/lkaname"},
                     function(txt, editbox)
								SlashCommandNameNode(LeaderKey.GetAccountBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_CLASS_NAME", {"/lkclname"},
                     function(txt, editbox)
								SlashCommandNameNode(LeaderKey.GetCurrentClassBindingsTree(), txt)
                     end
)
registerSlashCommand("LEADERKEY_SPEC_NAME", {"/lksname"},
                     function(txt, editbox)
								SlashCommandNameNode(LeaderKey.GetCurrentSpecBindingsTree(), txt)
                     end
)
-- Delete this binding in the highest priority table. TODO.
--[[
registerSlashCommand("LEADERKEY_UNMAP", {"/lkunmap"},
                     function(txt, editbox)
								error("NYI")
								local args = parseArgs(txt)
                     end
)
--]]
registerSlashCommand("LEADERKEY_PRINT_CURRENT", {"/lkpc"},
                     function(txt, editbox)
								LeaderKey.printCurrentBindings(LeaderKey.GetCurrentBindingsTree())
                     end
)

function LeaderKey.loadstuff()
	local cmds = {
	-- Collectionts
	[[macro 'Mounts' '/script ToggleCollectionsJournal(1) MountJournalSearchBox:SetFocus()' K C M]],
	[[macro "Pets" "/script ToggleCollectionsJournal(2) PetJournalSearchBox:SetFocus()" K C P]],
	[[macro "Toys" "/script ToggleCollectionsJournal(3) ToyBox.searchBox:SetFocus()" K C T]],
	[[macro "Heirlooms" "/script ToggleCollectionsJournal(4)" K C H]],
	[[macro "Appearances" "/script ToggleCollectionsJournal(5)" K C A]],

	-- Mounts
	[[helm "Mounts" _ K M]],
	[[helm "Pets" _ K P]],
	--[=[
	[[spell "Astral Cloud Serpent" "Astral Cloud Serpent" K M 1]],
	[[spell "Mimiron's Head" "Mimiron's Head" K M 2]],
	[[spell "Fire Dog" "Antoran Charhound" K M 3]],
	[[spell "Shadow Dog" "Antoran Gloomhound" K M 4]],
	[[spell "Kite" "Pandaren Kite" K M 5]],
	[[spell "Kite (Jade)" "Jade Pandaren Kite" K M 13]],
	[[spell "Firehawk" "Pureblood Fire Hawk" K M 6]],
	[[spell "Shadowhawk" "Corrupted Fire Hawk" K M 7]],
	[[spell "Headless Horseman's Mount" "Headless Horseman's Mount" K M 8]],
	[[spell "Anzu" "Raven Lord" K M 9]],
	[[spell "Cloud" "Red Flying Cloud" K M 10]],
	[[spell "Pink bird" "Swift Lovebird" K M 11]],
	[[spell "Dreamrunner" "Wild Dreamrunner" K M 12]],
	--]=]

	[[macro "Naked Set" "/equipset Naked" K E]],

	-- Dungeon Journal
	[[macro "Toggle Journal" "/script ToggleEncounterJournal();" K J J]],
	[[macro Vanilla "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectRaidTab\n/click DropDownList1Button1" K J R V]],
	[[macro "TBC" "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectRaidTab\n/click DropDownList1Button2" K J R T]],
	[[macro "TBC" "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectRaidTab\n/click DropDownList1Button2" K J R B]],
	[[macro Wrath "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectRaidTab\n/click DropDownList1Button3" K J R W]],
	[[macro Cataclysm "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectRaidTab\n/click DropDownList1Button4" K J R C]],
	[[macro Mists "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectRaidTab\n/click DropDownList1Button5" K J R M]],
	[[macro Warlords "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectRaidTab\n/click DropDownList1Button6" K J R D]],
	[[macro Legion "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectRaidTab\n/click DropDownList1Button7" K J R L]],
	[[macro BfA "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectRaidTab\n/click DropDownList1Button8" K J R B]],
	[[macro Vanilla "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectDungeonTab\n/click DropDownList1Button1" K J D V]],
	[[macro "TBC" "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectDungeonTab\n/click DropDownList1Button2" K J D T]],
	[[macro "TBC" "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectDungeonTab\n/click DropDownList1Button2" K J D B]],
	[[macro Wrath "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectDungeonTab\n/click DropDownList1Button3" K J D W]],
	[[macro Cataclysm "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectDungeonTab\n/click DropDownList1Button4" K J D C]],
	[[macro Mists "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectDungeonTab\n/click DropDownList1Button5" K J D M]],
	[[macro Warlords "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectDungeonTab\n/click DropDownList1Button6" K J D D]],
	[[macro Legion "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectDungeonTab\n/click DropDownList1Button7" K J D L]],
	[[macro BfA "/script ToggleEncounterJournal(); ShowUIPanel(EncounterJournal)\n/click EncounterJournalInstanceSelectDungeonTab\n/click DropDownList1Button8" K J D B]],

	[[macro "Group Finder" "/script PVEFrame_ToggleFrame()" K I]],
	[[macro "Communities" "/script ToggleGuildFrame()" K O]],
	[[macro "Guild" "/guildroster" K G]],
	[[macro "Achievements" "/script ToggleAchievementFrame()" K A]],
	[[macro "Talents" "/script ToggleTalentFrame(2)" K N]],
	[[macro "Close Windows" "/script CloseAllWindows()" K E]],

	[[macro "Katy (Mailbox 10 mins)" "/use Katy's Stampwhistle" K T K]],

	[[macro "Hearthstone" "/use Headless Horseman's Hearthstone" K T H]],
	[[macro "Garrison Hearthstone" "/use Garrison Hearthstone" K T G]],
	[[macro "Dalaran Hearthstone" "/use Dalaran Hearthstone" K T D]],
	[[macro "Whistle" "/use Flight Master's Whistle" K T W]],

	[[macro /fstack /fstack K D F]],
	[[macro /reload /reload K D R]],
	[[macro /logout /logout K D L]],
	[[macro "/vuhdo opt" "/vuhdo opt" K D V]],
	[[macro "Table Attributes" "/fstack\n/fstack\n/script MyTad()" K D T]],
	[[macro "Table Attributes" "/fstack\n/fstack\n/script local f = TableAttributeDisplay f.LinesScrollFrame:SetSize(935, 400); f:SetSize(1000, 500); f.HighlightButton:SetChecked(true) f:InspectTable(PlayerTalentFrameTalents); f:Show()" K D T]],
	[[macro /test1 /test1 K D S]],

	[[macro Star "/script local n = 1 local t='target' if n~=GetRaidTargetIndex(t) then SetRaidTarget(t, n) end" NUMPADMINUS R S]],
	[[macro Circle "/script local n = 2 local t='target' if n~=GetRaidTargetIndex(t) then SetRaidTarget(t, n) end" NUMPADMINUS R C]],
	[[macro Diamond "/script local n = 3 local t='target' if n~=GetRaidTargetIndex(t) then SetRaidTarget(t, n) end" NUMPADMINUS R D]],
	[[macro Triangle "/script local n = 4 local t='target' if n~=GetRaidTargetIndex(t) then SetRaidTarget(t, n) end" NUMPADMINUS R T]],
	[[macro Moon "/script local n = 5 local t='target' if n~=GetRaidTargetIndex(t) then SetRaidTarget(t, n) end" NUMPADMINUS R A]],
	[[macro Square "/script local n = 6 local t='target' if n~=GetRaidTargetIndex(t) then SetRaidTarget(t, n) end" NUMPADMINUS R Q]],
	[[macro Cross "/script local n = 7 local t='target' if n~=GetRaidTargetIndex(t) then SetRaidTarget(t, n) end" NUMPADMINUS R G]],
	[[macro Skull "/script local n = 8 local t='target' if n~=GetRaidTargetIndex(t) then SetRaidTarget(t, n) end" NUMPADMINUS R F]],
	[[macro Clear "/script local t='target' local n = GetRaidTargetIndex(t) if n~=nil then SetRaidTarget(t, n) end" NUMPADMINUS R E]],
	[[macro Star "/wm 5" NUMPADMINUS R SHIFT-S]],
	[[macro Circle "/wm 6" NUMPADMINUS R SHIFT-C]],
	[[macro Diamond "/wm 3" NUMPADMINUS R SHIFT-D]],
	[[macro Triangle "/wm 2" NUMPADMINUS R SHIFT-T]],
	[[macro Moon "/wm 7" NUMPADMINUS R SHIFT-A]],
	[[macro Square "/wm 1" NUMPADMINUS R SHIFT-Q]],
	[[macro Cross "/wm 4" NUMPADMINUS R SHIFT-G]],
	[[macro Skull "/wm 8" NUMPADMINUS R SHIFT-F]],

	[[macro Star "/cwm 5" NUMPADMINUS R R S]],
	[[macro Circle "/cwm 6" NUMPADMINUS R R C]],
	[[macro Diamond "/cwm 3" NUMPADMINUS R R D]],
	[[macro Triangle "/cwm 2" NUMPADMINUS R R T]],
	[[macro Moon "/cwm 7" NUMPADMINUS R R A]],
	[[macro Square "/cwm 1" NUMPADMINUS R R Q]],
	[[macro Cross "/cwm 4" NUMPADMINUS R R G]],
	[[macro Skull "/cwm 8" NUMPADMINUS R R F]],
	[[macro "Clear All" "/cwm all" NUMPADMINUS R R E]],

	[[macro "Addon List" "/script ShowUIPanel(AddonList)" K L A]],
	}
	for i=0,C_MountJournal.GetNumMounts() do
		local name, spellID,_,_,usable,_,_,_,_, hidden, collected,_ = C_MountJournal.GetMountInfoByID(i)
		if collected and usable and not hidden then
			cmds[#cmds+1] = [[spell "]]..name..[[" "]]..name..[[" K M ]]..i
		end
	end
	local petIDs = {}
	for i=0,select(2, C_PetJournal.GetNumPets()) do
		local petID,_,_,_,_,_,_,speciesName, icon,_,_, tooltip, description,_,_,_,_,_ = C_PetJournal.GetPetInfoByIndex(i)
		if not petID then break end
		if owned and not hidden and not petIDs[petID] then
			petIDs[petID] = true
			print("adding", [[spell "]]..speciesName..[[" "]]..speciesName..[[" K P ]]..i)
			cmds[#cmds+1] = [[spell "]]..speciesName..[[" "]]..speciesName..[[" K P ]]..i
		end
	end

	local nameCmds = {
	[["Raid Markers" NUMPADMINUS R]],
	[[Debug K D]],
	[[Teleports K T]],
	[["Toys" K T]],
	[[Dungeon K J D]],
	[[Raid K J R]],
	[["Dungeon Journal" K J]],
	[["Pets" K P]],
	[[Collections K C]],
	[["Clear Marker(s)" NUMPADMINUS R R]],
	[["Addon List" K L]],
	}

	if true then
	for i,v in pairs(cmds) do
		SlashCommandMapBind(LeaderKey.GetAccountBindingsTree(), v, true)
	end
	for i,v in pairs(nameCmds) do
		SlashCommandNameNode(LeaderKey.GetAccountBindingsTree(), v, true)
	end
	end

	--[[
	-- portals (Ideal candidate for helm.)
	/lkclmap macro "Orgimmar" "/cast Teleport: Orgrimmar" P T O
	/lkclmap macro "Undercity" "/cast Teleport: Undercity" P T U
	/lkclmap macro "Thunder Bluff" "/cast Teleport: Thunder Bluff" P T T
	/lkclmap macro "Silvermoon" "/cast Teleport: Silvermoon" P T S M
	/lkclmap macro "Stonard" "/cast Teleport: Stonard" P T S T
	/lkclmap macro "Shattrath" "/cast Teleport: Shattrath" P T S H
	/lkclmap macro "Dalaran - Northrend" "/cast Teleport: Dalaran - Northrend" P T D N
	/lkclname "Teleports" P T
	/lkclmap macro "Orgimmar" "/cast Portal: Orgrimmar" P P O
	/lkclmap macro "Undercity" "/cast Portal: Undercity" P P U
	/lkclmap macro "Thunder Bluff" "/cast Portal: Thunder Bluff" P P T
	/lkclmap macro "Silvermoon" "/cast Portal: Silvermoon" P P S M
	/lkclmap macro "Stonard" "/cast Portal: Stonard" P P S T
	/lkclmap macro "Shattrath" "/cast Portal: Shattrath" P P S H
	/lkclmap macro "Dalaran - Northrend" "/cast Portal: Dalaran - Northrend" P P D N
	/lkclname "Portals" P P

	-- Pick lock
	/lkclmap macro "Unlock" "/use Pick Lock" L U (rogue)
	/lkclmap macro "Detection" "/use Detection" L D (rogue)
	/lkclunmap L U (rogue)
	/lkclunmap L D (rogue)
	/lkclmap macro "Detection" "/use Detection" L D (rogue) -- Shroud.
	/lkclmap macro "Detection" "/use Detection" L D (rogue) -- Pick Pocket.
	--]]

end

