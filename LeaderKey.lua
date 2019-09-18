local _,private = ...
private.env = {}
setmetatable(private.env, {__index = _G})
private.setenv = function()
	setfenv(2, private.env)
end

select(2, ...).setenv()

_G.LeaderKey = {}
LeaderKey.private = private.env
LeaderKey.VDT = {}

VDT = {} -- Virag dev tools pointer.

runTests = true

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
colors = {}
-- TODO name these with a canonical name.
colors[LeaderKey.BindingsTree.Node.submenu] = "acd3ff"
colors[LeaderKey.BindingsTree.Node.helmSubmenu] = "51baff"
colors[LeaderKey.BindingsTree.Node.macro] = "ffa500"
colors[LeaderKey.BindingsTree.Node.softlink] = "3dd91e"
colors.castPrint = "ff00ff"
colors.keySequence = "c8cfa7"
for name,color in pairs(colors) do
	colors[name] = "|cff" .. color
end
colors.noColor = "|r"
