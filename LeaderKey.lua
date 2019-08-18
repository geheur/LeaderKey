if not LeaderKey then LeaderKey = {} end
if not LeaderKey.private then LeaderKey.private = {} end

local ns = LeaderKey.private

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
		LeaderKey.UpdateCurrentBindings()

		addonIsLoaded = true
	end
end
function events:PLAYER_SPECIALIZATION_CHANGED(...)
	if ... ~= "player" then return end
	-- TODO detect spec vs talent change.
	Log.debug("PLAYER_SPECIALIZATION_CHANGED new spec", GetSpecialization())
	LeaderKey.UpdateCurrentBindings()
end
function events:PLAYER_REGEN_ENABLED(...)
	LeaderKey.UpdateKeybinds()
end

registerEventHandlers(events)

