-- ### BindingsTree test
select(2, ...).setenv()

local BindingsTree = LeaderKey.BindingsTree
local Node = LeaderKey.BindingsTree.Node

if runTests then
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
	LeaderKey.VDT.TestBindings = Bindings
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

--[[
/script docoroutine()

/dump C_FriendList.GetWhoInfo(1)
--]]
--[[
local results = {}
local lastwho

f = CreateFrame("Frame")
f:RegisterEvent("WHO_LIST_UPDATE")
f:SetScript("OnEvent", function(table, func)
	print("WHO_LIST_UPDATE")
	if C_FriendList.GetNumWhoResults() == 50 then print("warning", lastwho, "at least 50 results") end
	for i=1,C_FriendList.GetNumWhoResults() do
		local whoresult = C_FriendList.GetWhoInfo(i)
		local classStr = whoresult.classStr
		results[lastwho] = results[lastwho] or {}
		results[lastwho][classStr] = (results[lastwho][classStr] or 0) + 1
	end
end)

local function a(text)
	tocopyfrom = CreateFrame("EDITBOX")
	tocopyfrom:SetAutoFocus(false)
	tocopyfrom:Show()
	tocopyfrom:SetParent(UIParent)
	tocopyfrom:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
	tocopyfrom:SetSize(100, 100)
	tocopyfrom:SetText(text)
end

function docoroutine()
	local co
	co = coroutine.create(function()
		for i=30,60 do
			lastwho = i
			-- print("whoing", i, "will resume", co)
			C_FriendList.SendWho(tostring(i))
			C_Timer.After(10, function() print("resuming", co) coroutine.resume(co) end)

			coroutine.yield()
		end
		local s = ""
		local totals = {}
		for i,v in pairs(results) do
			s = s .. i .. "\n"
			for i,v in pairs(v) do
				totals[i] = totals[i] or 0
				totals[i] = totals[i] + v
				s = s .. "\t" .. i .. " " .. v .. "\n"
			end
		end
		local total = 0
		for i,v in pairs(totals) do
			total = total + v
		end
		print("total", total)
		for i,v in pairs(totals) do
			s = s .. i .. " " .. (v / total) .. " " .. v .. "\n"
			print(i .. " " .. (v / total) .. " " .. v)
		end
		a(s)
	end)
	coroutine.resume(co)
end
--]]

