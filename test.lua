-- ### set up some test keybinds.
if false then
	local CurrentBindings = LeaderKey.GetCurrentBindingsTree()
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
		return CurrentBindings:GetNode(kssplit(str))
	end
	local function GetParentNode(str)
		return CurrentBindings:GetParentNode(kssplit(str))
	end
	local function AddBind(str, node)
		node = node or CreateNode(nil, MACRO)
		CurrentBindings:AddBind(node, kssplit(str))
	end
	local function NameNode(str, name)
		CurrentBindings:NameNode(name, kssplit(str))
	end
	local function DeleteNode(str)
		CurrentBindings:DeleteNode(kssplit(str))
	end

	-- Test GetNode and GetParentNode.
	CurrentBindings = {
		name = "Root node",
		type = SUBMENU,
		bindings = {
			A = { name = "A", type = SUBMENU, bindings = {
				B = { name = "B", type = SUBMENU, bindings = {
					C = { name = "C", type = MACRO },
				}},
				D = { name = "D", type = SUBMENU, bindings = {
					E = { name = "E", type = MACRO },
				}},
			}},
			F = { name = "F", type = MACRO, },
		}
	}
	assert(GetNode('') == CurrentBindings)
	assert(GetParentNode('A') == CurrentBindings)
	assert(GetParentNode('') == CurrentBindings)
	assert(GetNode('A') == CurrentBindings.bindings.A)
	assert(GetNode('A B') == CurrentBindings.bindings.A.bindings.B)
	assert(GetNode('A B C') == CurrentBindings.bindings.A.bindings.B.bindings.C)
	assert(GetNode('A D') == CurrentBindings.bindings.A.bindings.D)
	assert(GetNode('A D E') == CurrentBindings.bindings.A.bindings.D.bindings.E)
	assert(GetNode('F') == CurrentBindings.bindings.F)
	assert(GetParentNode('A B') == CurrentBindings.bindings.A)
	assert(GetParentNode('A B C') == CurrentBindings.bindings.A.bindings.B)
	assert(GetParentNode('A D') == CurrentBindings.bindings.A)
	assert(GetParentNode('A D E') == CurrentBindings.bindings.A.bindings.D)
	assert(GetParentNode('F') == CurrentBindings)
	assert(not GetNode('G'))
	assert(not GetNode('A B G'))
	assert(not GetNode('A B C G'))
	--assert(not GetParentNode('G')) -- I'll let this one go.
	--assert(not GetParentNode('A B G')) -- I'll let this one go.
	--assert(not GetParentNode('A B C G')) -- I'll let this one go.
	assert(not GetParentNode('A B C G H'))

	assert(GetNode('') == CurrentBindings)

	-- Test AddBind.
	CreateBindingsTree()
	local node = CreateMacro("testMacro", "/notacommand")
	AddBind('A B', node)
	assert(GetNode('A B') == node)
	AddBind('A', node)
	assert(not GetNode('A B'))
	assert(GetNode('A') == node)
	AddBind('A B C', node)
	assert(GetNode('A B C') == node)

	-- Test.
	CreateBindingsTree()
	AddBind('A B C')
	NameNode('A', 'A')
	NameNode('A B', 'B')
	AddBind('A E')
	NameNode('A E', 'E')

	-- Test bind deletion.
	CreateBindingsTree()
	AddBind('A B C')
	AddBind('A B D')
	DeleteNode('A B C')
	assert(not GetNode('A B C'))
	assert(GetNode('A B D'))

	-- test non-sequence bind deletion.
	CreateBindingsTree()
	AddBind('A')
	DeleteNode('A')
	assert(not GetNode('A'))

	-- Tests deletion of orphaned parents.
	CreateBindingsTree()
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
	CreateBindingsTree()
	AddBind('A B C')
	DeleteNode('A B C')
	assert(not GetNode('A'))

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
	-- Set up some nice defaults for ingame testing.
	CreateBindingsTree()
	AddBind('K T K', CreateMacro("Katy (Mailbox, 10 mins)", "/use Katy's Stampwhistle"))
	--AddBind('K C', CreateMacro("Pyroblast", "/use Pyroblast"))
	--AddBind('K B', CreateMacro("Fireball", "/use Fireball"))
	AddBind('K M S L', CreateMacro("Swift Lovebird", "/use Swift Lovebird"))
	AddBind('K C M', CreateMacro("Mounts", "/script ToggleCollectionsJournal(1)"))
	AddBind('K C P', CreateMacro("Pets", "/script ToggleCollectionsJournal(2)"))
	AddBind('K C T', CreateMacro("Toys", "/script ToggleCollectionsJournal(3)"))
	AddBind('K C H', CreateMacro("Heirlooms", "/script ToggleCollectionsJournal(4)"))
	AddBind('K C A', CreateMacro("Appearances", "/script ToggleCollectionsJournal(5)"))
	NameNode('K', "K menu")
	NameNode('K C', "Collections")
	NameNode('K M', "Mounts")
	NameNode('K T', "Toys")

	LeaderKey.UpdateCurrentKeybinds()

	--rsc("LEADERKEY_MAP", "'/script ToggleCollectionsJournal(1)' K C M")
	--[[
end

