AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local FORCE_SCALE = 3

local math_atan2 	= math.atan2
local math_min 		= math.min
local math_max 		= math.max
local math_abs 		= math.abs

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

local phys_settings = 
{
	["ValveBiped.Bip01_Pelvis"] = {mass = 12.741364, inertia = Vector(0.80, 0.97, 0.96)},

	["ValveBiped.Bip01_Spine2"] = {mass = 24.297474, inertia = Vector(2.15, 3.33, 3.12)},

	["ValveBiped.Bip01_R_UpperArm"] = {mass = 3.529606, inertia = Vector(0.06, 0.28, 0.28)},

	["ValveBiped.Bip01_L_UpperArm"] = {mass = 3.466939, inertia = Vector(0.06, 0.27, 0.27)},

	["ValveBiped.Bip01_L_Forearm"] = {mass = 1.801132, inertia = Vector(0.02, 0.10, 0.10)},

	["ValveBiped.Bip01_L_Hand"] = {mass = 1.075074, inertia = Vector(0.02, 0.02, 0.02)},

	["ValveBiped.Bip01_R_Forearm"] = {mass = 1.781718, inertia = Vector(0.02, 0.10, 0.10)},

	["ValveBiped.Bip01_R_Hand"] = {mass = 1.018670, inertia = Vector(0.02, 0.02, 0.02)},

	["ValveBiped.Bip01_R_Thigh"] = {mass = 10.187500, inertia = Vector(0.35, 1.74, 1.76)},

	["ValveBiped.Bip01_R_Calf"] = {mass = 4.996145, inertia = Vector(0.10, 0.63, 0.64)},

	["ValveBiped.Bip01_Head1"] = {mass = 5.163157, inertia = Vector(0.19, 0.21, 0.27)},

	["ValveBiped.Bip01_L_Thigh"] = {mass = 10.188610, inertia = Vector(0.35, 1.74, 1.76)},

	["ValveBiped.Bip01_L_Calf"] = {mass = 4.995875, inertia = Vector(0.10, 0.63, 0.64)},

	["ValveBiped.Bip01_L_Foot"] = {mass = 2.378366, inertia = Vector(0.05, 0.13, 0.13)},

	["ValveBiped.Bip01_R_Foot"] = {mass = 2.378366, inertia = Vector(0.05, 0.13, 0.13)}
}

local function AlignAngles(phys, ang) 
	local avel = Vector(0, 0, 0)
	
	local ang1 = phys:GetAngles()
		
	local forward1 = ang1:Forward()
	local forward2 = ang:Forward()
	local fd = forward1:Dot(forward2)
	
	local right1 = ang1:Right()
	local right2 = ang:Right()
	local rd = right1:Dot(right2)
	
	local up1 = ang1:Up()
	local up2 = ang:Up()
	local ud = up1:Dot(up2)
	
	local pitchvel = math.asin(forward1:Dot(up2)) * 180 / math.pi
	local yawvel = math.asin(forward1:Dot(right2)) * 180 / math.pi
	local rollvel = math.asin(right1:Dot(up2)) * 180 / math.pi
		
	avel.y = avel.y + pitchvel
	avel.z = avel.z + yawvel
	avel.x = avel.x + rollvel
		
	return avel
end

function ENT:SetBoneList(list)
	self.bone_list = list
end

function ENT:SetCollideCallback(callback)
	self.callback_collide = callback
end

function ENT:SetSimulateCallback(callback)
	self.callback_sim = callback
end

function ENT:Initialize()
	self:StartMotionController()

	local target = self:GetTarget()

	if !target._FixedSettings then
		target._FixedSettings = true
		for bone_name, info in pairs(phys_settings) do
		 	local bone = target:LookupBone(bone_name)
		 	if bone then
		 		local phys_bone = target:TranslateBoneToPhysBone(bone)
		 		local phys = target:GetPhysicsObjectNum(phys_bone)
		 		phys:SetMass(info.mass)
		 		phys:SetInertia(info.inertia)
			end
		end
	end

	self.bone_translate = {}
	self.bone_parent = {}

	local is_match = false

	for _, bone_name in pairs(self.bone_list) do
		local bone = target:LookupBone(bone_name)
		if bone then
			is_match = true				
			local phys_bone = target:TranslateBoneToPhysBone(bone)
			bone = target:TranslatePhysBoneToBone(phys_bone)

			self.root_bone = self.root_bone or bone
			self.root_phys_bone = self.root_phys_bone or phys_bone

			local phys = target:GetPhysicsObjectNum(phys_bone)
			self:AddToMotionController(phys)
			self.bone_translate[bone] = self:LookupBone(bone_name)

			local bone_parent = target:GetBoneParent(bone)
			bone_parent = target:TranslateBoneToPhysBone(bone_parent)
			bone_parent = target:TranslatePhysBoneToBone(bone_parent)
			local bone_name_parent = target:GetBoneName(bone_parent)

			self.bone_parent[bone] = bone_parent

			self.bone_translate[bone_parent] = self:LookupBone(bone_name_parent)
		end
	end

	if !is_match then
		self:Remove()
		return
	end

	self.Created = CurTime()

	if self.callback_collide then
		target:AddCallback("PhysicsCollide", self.callback_collide)
	end

	target:DeleteOnRemove(self)
end

function ENT:UpdateTransmitState()
	return TRANSMIT_NEVER
end

function ENT:PhysicsSimulate(phys, dt)
	local target = self:GetTarget()

	local factor = 1 

	--Allow callback to override simulation
	if self.callback_sim then
		local b, f = self.callback_sim(self, phys, dt)
		if (b == false) then
			return
		end
		factor = math_min(f or factor, 1)
	end

	self:FrameAdvance()

	local phys_bone = phys:GetID()

	local bone = target:TranslatePhysBoneToBone(phys_bone)
	local bone_parent = self.bone_parent[bone]

	local self_bone = self.bone_translate[bone]
	local self_bone_parent = self.bone_translate[bone_parent]

	if (self_bone and self_bone_parent) then
		local _, bone_ang = self:GetBonePosition(self_bone)
		
		local _, bone_ang_parent = self:GetBonePosition(self_bone_parent)

		local _, lang = WorldToLocal(vector_origin, bone_ang, vector_origin, bone_ang_parent)

		_, bone_ang = LocalToWorld(vector_origin, lang, target:GetBonePosition(bone_parent))

		--TODO: clamp to ragdoll joint limits to avoid spazz

		local ang_vel = AlignAngles(phys, bone_ang, factor)

		ang_vel:Mul(15 * factor)

		ang_vel:Sub(phys:GetAngleVelocity())

		local len_sqr = ang_vel:LengthSqr()

		if (len_sqr > 400 * 400) then
			ang_vel:Normalize()
			ang_vel:Mul(400)
		end

		if self.DieTime then
			local delta = CurTime() - self.DieTime
			if (delta > 5) then
				self:Remove()
			else
				ang_vel:Mul(1 - delta / 5)
			end
		elseif (target.GS2IsDismembered and target:GS2IsDismembered(1)) then
			self.DieTime = CurTime()
		end

		phys:AddAngleVelocity(ang_vel)
	end
end