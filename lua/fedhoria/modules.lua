fedhoria = {}

local modules = {}

function fedhoria.GetModule(name)
	if modules[name] then
		return modules[name]
	end
	local path = "fedhoria/modules/"..name..".lua"
	if !file.Exists(path, "LUA") then
		print("fedhoria.GetModule failed, couldn't find module '"..name.."'")
		return
	end
	local MODULE_old = MODULE
	MODULE = {}
	include(path)
	modules[name] = MODULE
	MODULE = MODULE_old

	return modules[name]
end

function fedhoria.GetModuleList()
	return modules
end

function fedhoria.StartModule(ent, name, ...)
	if (!modules[name] and !fedhoria.GetModule(name)) then
		return false
	end
	local contr = ents.Create("active_ragdoll_controller")
	contr:SetTarget(ent)
	contr:SetModule(modules[name])
	contr:SetInitParams(...)
	contr:Spawn()

	return contr
end

--preload modules
for _, file_name in pairs(file.Find("fedhoria/modules/*.lua", "LUA")) do
	fedhoria.GetModule(file_name:sub(1, -5))
end

local ENTITY = FindMetaTable("Entity")

--TODO: make this actually take mass into account
function ENTITY:GetMassCenter()
	local center = Vector(0, 0, 0)
	local mass = 0
	local count = self:GetPhysicsObjectCount()
	for phys_bone = 0, count - 1 do
		local phys = self:GetPhysicsObjectNum(phys_bone)
		local m = phys:GetMass()
		mass = mass * m
		--center:Add(phys:LocalToWorld(phys:GetMassCenter()) * m)
		center:Add(phys:LocalToWorld(phys:GetMassCenter()))
	end
	--center:Div(mass)
	center:Div(count)
	return center
end

local PCOLLIDE_CACHE = {}

local vec_max = Vector(1, 1, 1) * 4
local vec_min = -vec_max

function ENTITY:GetClosestPhysBone(pos)
	local mdl = self:GetModel()
	local collides = PCOLLIDE_CACHE[mdl]
	if !collides then
		PCOLLIDE_CACHE[mdl] = CreatePhysCollidesFromModel(mdl)
		collides = PCOLLIDE_CACHE[mdl]
	end

	if !collides then return end

	local closest_bone
	local dist = math.huge

	for phys_bone = 0, self:GetPhysicsObjectCount() - 1 do
		local phys = self:GetPhysicsObjectNum(phys_bone)		
		local collide = collides[phys_bone + 1]	
		if IsValid(collide) then			
			local phys_pos = phys:GetPos()
			local phys_ang = phys:GetAngles()
			local lpos = phys:WorldToLocal(pos)
			local hitpos, _, d = collide:TraceBox(phys_pos, phys_ang, pos, pos, vec_min, vec_max)
			if hitpos then					
				if (d < dist) then
					dist = d
					closest_bone = phys_bone	
				end
			end
		end		
	end

	return closest_bone
end

local PHYS = FindMetaTable("PhysObj")

function PHYS:GetID()
	local ent = self:GetEntity()
	for phys_bone = 0, ent:GetPhysicsObjectCount() - 1 do
		if (ent:GetPhysicsObjectNum(phys_bone) == self) then
			return phys_bone
		end
	end
	return -1
end

function PHYS:GetAABBCenter()
	local min, max = self:GetAABB()
	return (min + max) / 2
end