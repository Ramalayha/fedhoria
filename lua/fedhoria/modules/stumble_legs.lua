MODULE.Model = "models/barney.mdl"
MODULE.BoneList = 
{
	"ValveBiped.Bip01_Pelvis",
	--"ValveBiped.Bip01_Spine2",
	--"ValveBiped.Bip01_Head1",
	--"ValveBiped.Bip01_R_Upperarm",
	--"ValveBiped.Bip01_R_Forearm",
	--"ValveBiped.Bip01_R_Hand",
	--"ValveBiped.Bip01_L_Upperarm",
	--"ValveBiped.Bip01_L_Forearm",
	--"ValveBiped.Bip01_L_Hand",
	"ValveBiped.Bip01_R_Thigh",
	"ValveBiped.Bip01_R_Calf",
	"ValveBiped.Bip01_R_Foot",
	"ValveBiped.Bip01_L_Thigh",
	"ValveBiped.Bip01_L_Calf",
	"ValveBiped.Bip01_L_Foot"
}

local stumble_time 	= CreateConVar("fedhoria_stumble_time", 2, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local grab_chance 	= CreateConVar("fedhoria_woundgrab_chance", 0.9, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local grab_time 	= CreateConVar("fedhoria_woundgrab_time", 5, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))

local math_atan2 = math.atan2
local math_pi = math.pi
local math_Clamp = math.Clamp
local math_max = math.max
local math_min = math.min

local constant = 10000

local function CreateSpring(phys1, phys2)
	if (!IsValid(phys1) or !IsValid(phys2)) then return NULL end
	local str_axis = tostring(phys2:LocalToWorld(phys2:GetAABBCenter()))

	local const = ents.Create("phys_spring")
	const:SetPos(phys1:LocalToWorld(phys1:GetAABBCenter()))
	const:SetKeyValue("springaxis", str_axis)
	const:SetKeyValue("constant", constant)
	const:SetKeyValue("damping", 0.1)
	const:SetKeyValue("relativedamping", 0.1)
	const:SetPhysConstraintObjects(phys1, phys2)
	const:Spawn()
	const:Activate()
	--const:Fire("SetSpringLength", 0, 0)

	return const
end

local allowed_touch =
{
	"ValveBiped.Bip01_R_Calf",
	"ValveBiped.Bip01_R_Foot",
	"ValveBiped.Bip01_L_Calf",
	"ValveBiped.Bip01_L_Foot"
}

local hand_offset = Vector(2, 0, 0)

function MODULE:Init(phys_bone, lpos)
	self.seq_walk = self:LookupSequence("walk_all")	
	self.seq_walk_speed = self:GetSequenceMoveDist(self.seq_walk) * self:SequenceDuration(self.seq_walk)

	self.seq_run = self:LookupSequence("run_all")	
	self.seq_run_speed = self:GetSequenceMoveDist(self.seq_run) * self:SequenceDuration(self.seq_run)

	self.seq_sprint = self:LookupSequence("sprint_all")	
	self.seq_sprint_speed = self:GetSequenceMoveDist(self.seq_sprint) * self:SequenceDuration(self.seq_sprint)

	self:ResetSequence(self:LookupSequence("idle01"))

	local target = self:GetTarget()

	for _, bone_name in pairs(self.BoneList) do
		local bone = self:LookupBone(bone_name)
		if bone then
			local phys_bone = target:TranslateBoneToPhysBone(bone)
			local phys = target:GetPhysicsObjectNum(phys_bone)
			--phys:AddGameFlag(FVPHYSICS_NO_SELF_COLLISIONS)
		end
	end

	self.bone_lthigh = self:LookupBone("ValveBiped.Bip01_L_Thigh")
	self.bone_rthigh = self:LookupBone("ValveBiped.Bip01_R_Thigh")

	if (self.bone_lthigh and self.bone_rthigh) then
		self.phys_bone_lthigh = self:TranslateBoneToPhysBone(self.bone_lthigh)
		self.phys_bone_rthigh = self:TranslateBoneToPhysBone(self.bone_rthigh)
	end

	self.bone_lcalf = self:LookupBone("ValveBiped.Bip01_L_Calf")
	self.bone_rcalf = self:LookupBone("ValveBiped.Bip01_R_Calf")

	if (self.bone_lcalf and self.bone_rcalf) then
		self.phys_bone_lcalf = self:TranslateBoneToPhysBone(self.bone_lcalf)
		self.phys_bone_rcalf = self:TranslateBoneToPhysBone(self.bone_rcalf)
	end

	self.bone_lfoot = self:LookupBone("ValveBiped.Bip01_L_Foot")
	self.bone_rfoot = self:LookupBone("ValveBiped.Bip01_R_Foot")

	if (self.bone_lfoot and self.bone_rfoot) then
		self.phys_bone_lfoot = self:TranslateBoneToPhysBone(self.bone_lfoot)
		self.phys_bone_rfoot = self:TranslateBoneToPhysBone(self.bone_rfoot)
	end

	self.bone_lhand = self:LookupBone("ValveBiped.Bip01_L_Hand")
	self.bone_rhand = self:LookupBone("ValveBiped.Bip01_R_Hand")

	if (self.bone_lhand and self.bone_rhand) then
		self.phys_bone_lhand = self:TranslateBoneToPhysBone(self.bone_lhand)
		self.phys_bone_rhand = self:TranslateBoneToPhysBone(self.bone_rhand)
	end

	self.phys_allowed_touch = {}

	for _, bone_name in pairs(allowed_touch) do
		local bone = self:LookupBone(bone_name)
		if bone then
			local phys_bone = self:TranslateBoneToPhysBone(bone)
			self.phys_allowed_touch[phys_bone] = true
		end
	end

	self.bone_pelvis = self:LookupBone("ValveBiped.Bip01_Pelvis")
	self.bone_torso = self:LookupBone("ValveBiped.Bip01_Spine2")

	if (self.bone_pelvis and self.bone_torso) then
		self.phys_bone_pelvis = target:TranslateBoneToPhysBone(self.bone_pelvis)
		self.phys_bone_torso = target:TranslateBoneToPhysBone(self.bone_torso)

		--constraint.Weld(target, target, phys_bone_pelvis, phys_bone_torso)
	end

	local vel = target:GetVelocity():Length2D()

	if phys_bone then
		self.Springs = {}
		--Grab wound
		local phys = target:GetPhysicsObjectNum(phys_bone)
		local dmgpos = phys:LocalToWorld(lpos)
		if (IsValid(phys) and phys_bone != self.phys_bone_lhand and phys_bone != self.phys_bone_rhand) then
			local phys_lhand = target:GetPhysicsObjectNum(self.phys_bone_lhand)
			local phys_rhand = target:GetPhysicsObjectNum(self.phys_bone_rhand)

			local str_axis = tostring(dmgpos)

			if (IsValid(phys_lhand) and math.random() < grab_chance:GetFloat()) then
				local const = ents.Create("phys_spring")
				const:SetPos(phys_lhand:LocalToWorld(hand_offset))
				const:SetKeyValue("springaxis", str_axis)
				const:SetKeyValue("constant", 300)
				const:SetKeyValue("damping", 0.1)
				const:SetKeyValue("relativedamping", 0.1)
				const:SetPhysConstraintObjects(phys_lhand, phys)
				const:Spawn()
				const:Activate()
				const:Fire("SetSpringLength", 0, 0)

				SafeRemoveEntityDelayed(const, grab_time:GetFloat())

				table.insert(self.Springs, const)
			end

			if (IsValid(phys_rhand) and math.random() < grab_chance:GetFloat()) then
				local const = ents.Create("phys_spring")
				const:SetPos(phys_rhand:LocalToWorld(hand_offset))
				const:SetKeyValue("springaxis", str_axis)
				const:SetKeyValue("constant", 300)
				const:SetKeyValue("damping", 0.1)
				const:SetKeyValue("relativedamping", 0.1)
				const:SetPhysConstraintObjects(phys_rhand, phys)
				const:Spawn()
				const:Activate()
				const:Fire("SetSpringLength", 0, 0)

				SafeRemoveEntityDelayed(const, grab_time:GetFloat())

				table.insert(self.Springs, const)
			end
		end
	end

	--[[if (!target.GS2IsDismembered and vel < self.seq_walk_speed) then
		--self:Remove()
		self.Springs = {}
		if (self.phys_bone_lthigh and self.phys_bone_lcalf) then
			local phys_lthigh = target:GetPhysicsObjectNum(self.phys_bone_lthigh)
			local phys_lcalf = target:GetPhysicsObjectNum(self.phys_bone_lcalf)

			table.insert(self.Springs, CreateSpring(phys_lthigh, phys_lcalf))
		end

		if (self.phys_bone_rthigh and self.phys_bone_rcalf) then
			local phys_rthigh = target:GetPhysicsObjectNum(self.phys_bone_rthigh)
			local phys_rcalf = target:GetPhysicsObjectNum(self.phys_bone_rcalf)

			table.insert(self.Springs, CreateSpring(phys_rthigh, phys_rcalf))
		end

		if (self.phys_bone_pelvis and self.phys_bone_torso) then
			local phys_pelvis = target:GetPhysicsObjectNum(self.phys_bone_pelvis)
			local phys_torso = target:GetPhysicsObjectNum(self.phys_bone_torso)

			--CreateSpring(phys_pelvis, phys_torso)
		end

		if (self.phys_bone_pelvis and self.phys_bone_lthigh) then
			local phys_pelvis = target:GetPhysicsObjectNum(self.phys_bone_pelvis)
			local phys_lthigh = target:GetPhysicsObjectNum(self.phys_bone_lthigh)

			--CreateSpring(phys_pelvis, phys_lthigh)
		end

		if (self.phys_bone_pelvis and self.phys_bone_rthigh) then
			local phys_pelvis = target:GetPhysicsObjectNum(self.phys_bone_pelvis)
			local phys_rthigh = target:GetPhysicsObjectNum(self.phys_bone_rthigh)

			--CreateSpring(phys_pelvis, phys_rthigh)
		end
	end]]
end

local function DoFallingAnim(ent)
	local mod1 = fedhoria.StartModule(ent, "falling_legs")
	local mod2 = fedhoria.StartModule(ent, "falling_torso")
end

function MODULE:OnRemove()
	local target = self:GetTarget()
	if !IsValid(target) then return end

	for _, bone_name in pairs(self.BoneList) do
		local bone = target:LookupBone(bone_name)
		if bone then
			local phys_bone = target:TranslateBoneToPhysBone(bone)
			local phys = target:GetPhysicsObjectNum(phys_bone)
			if IsValid(phys) then
				phys:ClearGameFlag(FVPHYSICS_NO_SELF_COLLISIONS)
			end
		end
	end

	--[[if self.Springs then
		for _, spring in pairs(self.Springs) do
			SafeRemoveEntityDelayed(spring, 1)
		end
	end]]

	DoFallingAnim(target)
end

function MODULE:Think()

end

function MODULE:PhysicsCollide(ent, data)
	--if (data.HitEntity == ent) then return end
	if (data.HitEntity != game.GetWorld()) then return end
	if (CurTime() - self.Created < 0.1) then return end

	local phys = data.PhysObject
	local phys_bone = phys:GetID()

	if !self.phys_allowed_touch[phys_bone] then
		SafeRemoveEntityDelayed(self, 0)
	end
end

local constant = 1

local tilt_ang = Angle(0, 0, 0)

local pelvis_offset = Vector(0, 0, 35)
local torso_offset = Vector(0, 0, 50)

local trace = {output={}}
local tr = trace.output

function MODULE:PhysicsSimulate(phys, dt)
	local phys_bone = phys:GetID()

	local target = self:GetTarget()

	if (self.Springs and target:GetNWInt("GS2DisMask", 0) != 0) then
		for _, spring in pairs(self.Springs) do
			SafeRemoveEntity(spring)
		end
	end

	local st = stumble_time:GetFloat()

	if (st <= 0) then
		self:Remove()		
		return false
	end

	local f = 1 - (CurTime() - self.Created) / st

	if (f <= 0) then
		self:Remove()
		return false
	end

	--helps reduce excessive twitching
	if (phys:GetStress() > 100) then
		return false
	end

	if (phys_bone == (self.phys_bone_pelvis or 0)) then
		local phys_torso = target:GetPhysicsObjectNum(self.phys_bone_torso or 1)
		--calculate animation settings here so its only done once per frame
		local pos = phys:GetPos()
		local ang = phys:GetAngles()		
		--local vel = phys:GetVelocity()
		local vel = phys_torso:GetVelocity()

		local forward = ang:Forward()
		local right = ang:Right()
		local up = ang:Up()

		--try keeping  balance a little bit better
		tilt_ang.y = math_Clamp(90 + 180 * math_atan2(right.z, up.z) / math_pi, -50, 20) * f

		--too much balance?
		tilt_ang.p = -ang.p * f

		self:ManipulateBoneAngles(self.bone_lthigh, tilt_ang)
		self:ManipulateBoneAngles(self.bone_rthigh, tilt_ang)

		local speed = vel:Length2D()

		local slow = false

		if (speed > self.seq_sprint_speed) then
			self:ResetSequence(self.seq_sprint)
		elseif (speed > self.seq_run_speed) then
			self:ResetSequence(self.seq_run)
		elseif (speed > self.seq_walk_speed) then		
			self:ResetSequence(self.seq_walk)
		else
			slow = true
		end

		if slow then
			return false
		--[[elseif (self.Springs) then
			for _, spring in pairs(self.Springs) do
				SafeRemoveEntity(spring)
			end
			self.Springs = nil]]
		end

		--self:ResetSequence(self.seq_sprint)
		
		--local mass_center = target:GetMassCenter()

		self.last_pos = self.last_pos or pos

		local delta = (pos - self.last_pos) / dt

		self.last_pos = pos

		local pbr = vel:Length2D() / self:GetSequenceMoveDist(self:GetSequence())
		--local pbr = vel:Dot(ang:Right()) / self:GetSequenceMoveDist(self:GetSequence())

		--pbr = pbr / self:SequenceDuration()

		vel.z = 0
		vel:Normalize()

		local ang = phys:GetAngles()
		ang.p = 0
		ang.r = 0

		local x = ang:Right():Dot(vel)
		local y = ang:Forward():Dot(vel)

		self.pbr = math.min(3, Lerp(dt * constant, self.pbr or pbr, pbr))

		local yaw = 180 * math_atan2(y, x) / math_pi

		local m = 1

		if (yaw > 90) then
			m = -1.5
			yaw = -90 + yaw - 90
			self:ResetSequence(self.seq_sprint)
		elseif (yaw < -90) then
			m = -1.5
			yaw = 90 - (yaw + 90)
			self:ResetSequence(self.seq_sprint)
		end

		self.move_yaw = Lerp(dt * constant, self.move_yaw or yaw, yaw)

		self:SetPoseParameter("move_yaw", self.move_yaw)

		self:SetPlaybackRate(m * self.pbr * self:SequenceDuration())

		trace.filter = target
		trace.start = pos
		trace.endpos = pos - torso_offset

		util.TraceLine(trace)

		if tr.Hit then		
			if (x < 0) then	
				ang = phys:GetAngles()
				local a = math.max(0, -ang:Right().z)

				if (a < 0.2) then
					self:Remove()
					return false
				end		

				pos = phys_torso:GetPos()	

				local d = (pos - tr.HitPos):Length2D()

				local div = self:GetSequenceMoveDist(self:GetSequence()) * self:SequenceDuration()

				local m = math_max(0, 1 - (d / div))
		
				vel = phys:GetVelocity()
				vel.x = 0
				vel.y = 0
				
				m = m * a

				vel.z = vel.z * m

				phys:ApplyForceCenter(-vel * phys:GetMass() * f)

				vel = phys_torso:GetVelocity()
				vel.x = 0
				vel.y = 0
				
				vel.z = vel.z * m

				phys_torso:ApplyForceCenter(-vel * phys_torso:GetMass() * f)
				return false
			else
				local l2d = delta:Length2D()

				local f = f * math_Clamp(l2d / self:GetSequenceMoveDist(self:GetSequence()), 0, 1)

				local targetZ = tr.HitPos.z + torso_offset.z * f

				local offsetZ = targetZ - phys_torso:GetPos().z

				if (offsetZ > 0) then					
					local force = offsetZ^2 - phys_torso:GetVelocity().z
					force = force * 0.5
					force = math_min(force, 40)
					phys_torso:ApplyForceCenter(Vector(0, 0, force) * phys_torso:GetMass() * f)
				end

				local targetZ = tr.HitPos.z + pelvis_offset.z * f

				local offsetZ = targetZ - phys:GetPos().z

				if (offsetZ > 0) then
					local force = offsetZ^2 - phys:GetVelocity().z
					force = force * 0.5
					force = math_min(force, 40)
					phys:ApplyForceCenter(Vector(0, 0, force) * phys:GetMass() * f)					
				end
			end
		else		
			self:Remove()				
			return false		
		end

		if (self.phys_bone_lhand) then
			--[[local phys_lhand = target:GetPhysicsObjectNum(self.phys_bone_lhand)

			pos = phys_lhand:GetPos()

			local pos2 = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_L_Upperarm"))

			local offset = pos2 - pos

			offset:Add(phys:GetVelocity() * dt)

			offset.z = 0

			offset = offset:GetNormal() * offset:Length()^2

			offset:Sub(phys_lhand:GetVelocity())

			phys_lhand:ApplyForceCenter(offset * phys_lhand:GetMass() * f)]]
		end

		if (self.phys_bone_rhand) then
			--[[local phys_rhand = target:GetPhysicsObjectNum(self.phys_bone_rhand)

			pos = phys_rhand:GetPos()

			local pos2 = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_R_Upperarm"))

			local offset = pos2 - pos

			offset:Add(phys:GetVelocity() * dt)

			offset.z = 0

			offset = offset:GetNormal() * offset:Length()^2

			offset:Sub(phys_rhand:GetVelocity())

			phys_rhand:ApplyForceCenter(offset * phys_rhand:GetMass() * f)]]
		end

		return false
	end

	--[[if self.Springs then		
		return false
	end]]

	return true, f
end