if not LeaderKey then LeaderKey = {} end
if not LeaderKey.private then LeaderKey.private = {} end

local ns = LeaderKey.private

LeaderKey.VDT = {} -- Virag dev tools pointer.

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
