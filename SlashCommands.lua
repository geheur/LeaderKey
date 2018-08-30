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

	--[[
	Log.debug("args:")
	for i,v in pairs(args) do
		Log.debug(i,v)
	end
	--]]

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
local function SlashCommandMapBind(bindingsTree, txt)
	local args = parseArgs(txt)
	if not args or not args[4] then errorp("invalid arguments"); return end

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
			errorp("|cFFFFA500Could not find spell " .. spellName .. ".|r")
			return
		end
		node = Node.CreateSpellNode(name, spellName)
		ViragDevTool_AddData(node, "bla")
	elseif type == helmtype then
		node = Node.CreateHelmSubmenu(name)
	else
		errorp("Unknown type \"" .. type .. "\"")
		return
	end

	LeaderKey.CreateBinding(bindingsTree, node, keySequence)
	LeaderKey.UpdateCurrentBindings()
	Log.info("Created bind " .. table.concat(keySequence, " ") .. " to " .. name)
end

local function SlashCommandMapUnbind(bindingsTree, txt)
	local args = parseArgs(txt)
	if not args or not args[1] then errorp("invalid arguments"); return end
	local keySequence = cleanKeySequence(args)

	LeaderKey.DeleteNode(bindingsTree, keySequence)
	LeaderKey.UpdateCurrentBindings()
	Log.info("Deleted node " .. table.concat(keySequence, " ") .. " (or, it didn't exist in the first place)")
end

local function SlashCommandNameNode(bindingsTree, txt)
	local args = parseArgs(txt)
	if not args or not args[1] then errorp("invalid arguments"); return end
	local name = args[1] or "nil"
	local keySequence = cleanKeySequence(slice(args, 2))

	local successful = LeaderKey.NameNode(bindingsTree, name, keySequence)
	LeaderKey.UpdateCurrentBindings()
	if successful then
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
								printCurrentBindings(LeaderKey.GetCurrentBindingsTree())
                     end
)

