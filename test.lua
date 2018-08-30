-- ### BindingsTree test
local BindingsTree = LeaderKey.BindingsTree
local Node = LeaderKey.BindingsTree.Node
local Log = LeaderKey.private.Log

if LeaderKey.private.runTests then
	local Bindings = BindingsTree:new()

	local function rsc(id,  txt)
		SlashCmdList[id](txt, nil)
	end

	local function kssplit(str)
		local split = {}
		for i in str:gmatch("%S+") do
			split[#split + 1] = i
		end
		return split
	end

	do
		local result = kssplit('A B')
		assert(result[1] == 'A')
		assert(result[2] == 'B')
	end

	local function GetNode(str)
		return Bindings:GetNode(kssplit(str))
	end
	local function GetParentNode(str)
		return Bindings:GetParentNode(kssplit(str))
	end
	local function AddBind(str, node)
		node = node or Node.CreateNode(nil, Node.MACRO)
		Bindings:AddBind(node, kssplit(str))
	end
	local function NameNode(str, name)
		Bindings:NameNode(name, kssplit(str))
	end
	local function DeleteNode(str)
		Bindings:DeleteNode(kssplit(str))
	end

	-- Test GetNode and GetParentNode.
	Bindings.name = "Root node"
	Bindings.bindings = {
			A = { name = "A", type = Node.SUBMENU, bindings = {
				B = { name = "B", type = Node.SUBMENU, bindings = {
					C = { name = "C", type = Node.MACRO },
				}},
				D = { name = "D", type = Node.SUBMENU, bindings = {
					E = { name = "E", type = Node.MACRO },
				}},
			}},
			F = { name = "F", type = Node.MACRO, },
		}
	assert(GetNode('') == Bindings)
	assert(GetParentNode('A') == Bindings)
	assert(GetParentNode('') == Bindings)
	assert(GetNode('A') == Bindings.bindings.A)
	print(GetNode('A B'))
	assert(GetNode('A B') == Bindings.bindings.A.bindings.B)
	assert(GetNode('A B C') == Bindings.bindings.A.bindings.B.bindings.C)
	assert(GetNode('A D') == Bindings.bindings.A.bindings.D)
	assert(GetNode('A D E') == Bindings.bindings.A.bindings.D.bindings.E)
	assert(GetNode('F') == Bindings.bindings.F)
	assert(GetParentNode('A B') == Bindings.bindings.A)
	assert(GetParentNode('A B C') == Bindings.bindings.A.bindings.B)
	assert(GetParentNode('A D') == Bindings.bindings.A)
	assert(GetParentNode('A D E') == Bindings.bindings.A.bindings.D)
	assert(GetParentNode('F') == Bindings)
	assert(not GetNode('G'))
	assert(not GetNode('A B G'))
	assert(not GetNode('A B C G'))
	--assert(not GetParentNode('G')) -- I'll let this one go.
	--assert(not GetParentNode('A B G')) -- I'll let this one go.
	--assert(not GetParentNode('A B C G')) -- I'll let this one go.
	assert(not GetParentNode('A B C G H'))

	assert(GetNode('') == Bindings)

	-- Test AddBind.
	Bindings = BindingsTree:new()

	local node = Node.CreateMacroNode("testMacro", "/notacommand")
	AddBind('A B', node)
	assert(GetNode('A B') == node)
	AddBind('A', node)
	assert(not GetNode('A B'))
	assert(GetNode('A') == node)
	AddBind('A B C', node)
	assert(GetNode('A B C') == node)

	-- Test.
	Bindings = BindingsTree:new()
	AddBind('A B C')
	NameNode('A', 'A')
	NameNode('A B', 'B')
	AddBind('A E')
	NameNode('A E', 'E')

	-- Test bind deletion.
	Bindings = BindingsTree:new()
	AddBind('A B C')
	AddBind('A B D')
	DeleteNode('A B C')
	assert(not GetNode('A B C'))
	assert(GetNode('A B D'))

	-- test non-sequence bind deletion.
	Bindings = BindingsTree:new()
	AddBind('A')
	DeleteNode('A')
	assert(not GetNode('A'))

	-- Tests deletion of orphaned parents.
	Bindings = BindingsTree:new()
	AddBind('A B C')
	NameNode('A', 'A')
	NameNode('A B', 'B')
	AddBind('A E')
	DeleteNode('A B C')
	assert(GetNode('A E'))
	assert(not GetNode('A B'))
	assert(not GetNode('A B C'))

	assert(not GetNode('A B'))
	-- Tests deletion of original bind.
	Bindings = BindingsTree:new()
	LeaderKey.VDT.Bindings = Bindings
	AddBind('A B C')
	Log.debug("bla")
	DeleteNode('A B C')
	assert(not GetNode('A'))

--[[
function timetest()
	local startTime = GetTime()
	local arr = {'A', 'B', 'C', 'D', 'E', 'F', 'G', "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}
	CreateBindingsTree()
	for _,a in pairs(arr) do
		for _,b in pairs(arr) do
			for _,c in pairs(arr) do
				for _,d in pairs(arr) do
					AddBind("K " .. a .. " " .. b .. " " .. c .. " " .. d, CreateMacro("bla", "bla"))
				end
			end
		end
	end
	local t = GetTime()
	print(startTime, t)
	local elapsed = t - startTime
	print("Time to create", #arr * #arr * #arr, "bindings:", elapsed)
	startTime = GetTime()
	--UpdateKeybinds()
	elapsed = GetTime() - startTime
	print("Time to update", #arr * #arr * #arr, "bindings:", elapsed)
end
--]]
	--rsc("LEADERKEY_MAP", "'/script ToggleCollectionsJournal(1)' K C M")
end

