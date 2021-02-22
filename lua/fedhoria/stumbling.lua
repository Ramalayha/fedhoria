include("falling.lua")

local bone_list_torso = 
{
	--"ValveBiped.Bip01_Pelvis",
	"ValveBiped.Bip01_Spine2",
	--"ValveBiped.Bip01_Head1", 
	--"ValveBiped.Bip01_R_Upperarm",
	--"ValveBiped.Bip01_R_Forearm",
	--"ValveBiped.Bip01_R_Hand",
	--"ValveBiped.Bip01_L_Upperarm",
	--"ValveBiped.Bip01_L_Forearm",
	--"ValveBiped.Bip01_L_Hand"
}

local bone_list_legs = 
{	
	"ValveBiped.Bip01_R_Thigh",
	"ValveBiped.Bip01_R_Calf",
	"ValveBiped.Bip01_R_Foot",
	"ValveBiped.Bip01_L_Thigh",
	"ValveBiped.Bip01_L_Calf",
	"ValveBiped.Bip01_L_Foot"
}

local function PhysicsCollide(self, data)
	if (data.HitEntity == self or data.HitNormal.z > -0.5) then
		return
	end
	
	local contr = self.contr_torso

	if !IsValid(contr) then
		return
	end

	local phys_bone = data.PhysObject:GetID()

	local bone = self:TranslatePhysBoneToBone(phys_bone)

	if !table.HasValue(self.allowed_to_collide, bone) then
		self.LastCollide = CurTime()
	elseif self:GetBoneName(bone):find("Foot") then
		--[[timer.Simple(0, function()
			local const = constraint.Weld(self, data.HitEntity, phys_bone, phys_bone, 1000)
			SafeRemoveEntityDelayed(const, 0)
		end)]]
	end
end

local trace = {output={}}

local torso_offset = Vector(0, 0, 60)

local function PhysicsSim(self, phys, dt)
	local target = self:GetTarget()

	if (target.GS2IsDismembered and target:GS2IsDismembered(target.phys_bone_head)) then
		self:Remove()
		return
	end

	local vel = target:GetPhysicsObjectNum(0):GetVelocity()
	if (CurTime() - self.Created > 1 and vel:LengthSqr() < 150) then
		self:Remove()		
		return false
	end

	if target.LastCollide then
		local delta = CurTime() - target.LastCollide
		if (delta < 0.2) then
			return false
		elseif (delta < 1) then
			return true, delta
		end
	end

	local phys_bone = phys:GetID()
	
	local pos = phys:GetPos()

	if (phys_bone == self.root_phys_bone) then
		trace.start = pos
		trace.endpos = pos - torso_offset
		trace.filter = target

		util.TraceLine(trace)

		if !trace.output.Hit then
			self:Remove()
			Fedh_DoFallingAnim(target)
			return
		end

		self.last_root_pos = self.last_root_pos or pos

		local offset = pos - self.last_root_pos
		
		local a = target:GetAngles()
		a.p = 0
		a.y = 0

		local dot = a:Forward():Dot(offset)

		local pbr = math.Clamp(dot/20, -2, 2)

		self:SetPlaybackRate(pbr)
		
		local vel = phys:GetVelocity()

		vel.x = 0
		vel.y = 0

		vel.z = vel.z * (1 - math.min(1, offset:Length2D() / 80)) * math.max(0, 1 - (CurTime() - self.Created))

		phys:ApplyForceCenter(-vel * phys:GetMass() * 0.99)

		--return false
	end

	local dis = false
	if target.GS2IsDismembered then
		local bone = target:TranslatePhysBoneToBone(phys_bone)
		repeat
			phys_bone = target:TranslateBoneToPhysBone(bone)
			if target:GS2IsDismembered(phys_bone) then	
				dis = true
				break
			end
			bone = target:GetBoneParent(bone)
		until (phys_bone == 1 or phys_bone == 0)

		if (phys_bone == 0) then
			dis = target:GS2IsDismembered(1)
		elseif (phys_bone != 1) then
			dis = true
		end
	end

	if dis then
		return false
	end
end

local PCOLLIDE_CACHE = {}

local vec_max = Vector(2, 2, 2)
local vec_min = -vec_max

--borrowed from gibsplat
local function GetClosestPhysBone(self, pos, target_phys_bone, use_collides)
	local mdl = self:GetModel()
	local collides = PCOLLIDE_CACHE[mdl]
	if (!collides and use_collides) then
		PCOLLIDE_CACHE[mdl] = CreatePhysCollidesFromModel(mdl)
		collides = PCOLLIDE_CACHE[mdl]
	end

	local closest_bone
	local dist = math.huge

	local target_bone = target_phys_bone and self:TranslatePhysBoneToBone(target_phys_bone)

	for phys_bone = 0, self:GetPhysicsObjectCount() - 1 do		
		local bone = self:TranslatePhysBoneToBone(phys_bone)
		local is_conn = target_phys_bone == nil and true
		if !is_conn then			
			local parent_bone = self:GetBoneParent(bone)
			if parent_bone then
				local parent_phys_bone = self:TranslateBoneToPhysBone(parent_bone)
				if (parent_phys_bone == target_phys_bone) then
					is_conn = true
				end
			end
			if !is_conn then
				for _, child_bone in pairs(self:GetChildBones(target_bone)) do
					local child_phys_bone = self:TranslateBoneToPhysBone(child_bone)
					if (child_phys_bone == phys_bone) then
						is_conn = true
						break
					end
				end
			end
		end	

		if is_conn then	
			--Vector, Vector, number PhysCollide:TraceBox( Vector origin, Angle angles, Vector rayStart, Vector rayEnd, Vector rayMins, Vector rayMaxs )
			local phys = self:GetPhysicsObjectNum(phys_bone)
			if (use_collides and collides) then
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
			else
				local min, max = phys:GetAABB()
				local bone_pos = phys:LocalToWorld((min + max) * 0.5)--self:GetBoneMatrix(bone):GetTranslation()
				local d = bone_pos:DistToSqr(pos)
				if (d < dist) then
					dist = d
					closest_bone = phys_bone			
				end
			end
		end		
	end

	return closest_bone
end

local hand_offset = Vector(2, 0, 0)

local force_limit = 10000

local function AABBCenter(phys)
	local min, max = phys:GetAABB()
	return (min + max) * 0.5
end

function Fedh_DoStumblingAnim(ent, dmgpos)
	local bg_hc = ent:FindBodygroupByName("headcrab1")

	if (bg_hc != -1) then
		--a zombie with no headcrab shouldnt move
		if (ent:GetBodygroup(bg_hc) == 0) then
			return
		end
	end

	ent.phys_bone_head = ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_Head1") or -1) or -1
	
	local contr_torso = ents.Create("active_ragdoll_controller")
	contr_torso:SetModel("models/police.mdl")
	contr_torso:SetTarget(ent)
	contr_torso:SetBoneList(bone_list_torso)
	contr_torso:SetCollideCallback(PhysicsCollide)
	contr_torso:SetSimulateCallback(PhysicsSim)
	contr_torso:Spawn()

	contr_torso:ResetSequence(contr_torso:LookupSequence("cower"))
	contr_torso:SetPlaybackRate(0)
	contr_torso:SetCycle(0.9)

	ent.allowed_to_collide = {
		ent:LookupBone("ValveBiped.Bip01_R_Foot"),
		ent:LookupBone("ValveBiped.Bip01_R_Calf"),
		ent:LookupBone("ValveBiped.Bip01_L_Foot"),
		ent:LookupBone("ValveBiped.Bip01_L_Calf")
	}

	ent.contr_torso = contr_torso

	local phys0 = ent:GetPhysicsObjectNum(0)

	if (phys0:GetVelocity():Length2DSqr() < 900) then --30^2
		local const = constraint.Elastic(ent, ent, 0, 1, vector_origin, vector_origin, force_limit, 0, 0, "", 0, false)
		contr_torso:DeleteOnRemove(const)
		SafeRemoveEntityDelayed(const, 2)

		local bone_lthigh = ent:LookupBone("ValveBiped.Bip01_L_Thigh")
		local bone_lcalf = ent:LookupBone("ValveBiped.Bip01_L_Calf")

		if (bone_lthigh and bone_lcalf) then
			local phys_bone_lthigh = ent:TranslateBoneToPhysBone(bone_lthigh)
			local phys_bone_lcalf = ent:TranslateBoneToPhysBone(bone_lcalf)

			local phys_lthigh = ent:GetPhysicsObjectNum(phys_bone_lthigh)
			local phys_lcalf = ent:GetPhysicsObjectNum(phys_bone_lcalf)

			--local const = constraint.Weld(ent, ent, phys_bone_lthigh, phys_bone_lcalf, force_limit)
			local const = constraint.Elastic(ent, ent, phys_bone_lthigh, phys_bone_lcalf, AABBCenter(phys_lthigh), AABBCenter(phys_lcalf), force_limit, 0, 0, "", 0, false)
			contr_torso:DeleteOnRemove(const)
			SafeRemoveEntityDelayed(const, 2)
		end

		local bone_rthigh = ent:LookupBone("ValveBiped.Bip01_R_Thigh")
		local bone_rcalf = ent:LookupBone("ValveBiped.Bip01_R_Calf")

		if (bone_rthigh and bone_rcalf) then
			local phys_bone_rthigh = ent:TranslateBoneToPhysBone(bone_rthigh)
			local phys_bone_rcalf = ent:TranslateBoneToPhysBone(bone_rcalf)

			local phys_rthigh = ent:GetPhysicsObjectNum(phys_bone_rthigh)
			local phys_rcalf = ent:GetPhysicsObjectNum(phys_bone_rcalf)

			--local const = constraint.Weld(ent, ent, phys_bone_rthigh, phys_bone_rcalf, force_limit)
			local const = constraint.Elastic(ent, ent, phys_bone_rthigh, phys_bone_rcalf, AABBCenter(phys_rthigh), AABBCenter(phys_rcalf), force_limit, 0, 0, "", 0, false)
			contr_torso:DeleteOnRemove(const)
			SafeRemoveEntityDelayed(const, 2)
		end
	else
		local contr_legs = ents.Create("active_ragdoll_controller")
		contr_legs:SetModel("models/police.mdl")
		contr_legs:SetTarget(ent)
		contr_legs:SetBoneList(bone_list_legs)
		contr_legs:SetCollideCallback(PhysicsCollide)
		contr_legs:SetSimulateCallback(PhysicsSim)
		contr_legs:Spawn()

		contr_legs:ResetSequence(contr_legs:LookupSequence("run_all"))

		contr_torso:DeleteOnRemove(contr_legs)
		contr_legs:DeleteOnRemove(contr_torso)
	end

	if dmgpos then
		local phys_bone = GetClosestPhysBone(ent, dmgpos, nil, true)

		if phys_bone then
			local bone_rhand = ent:LookupBone("ValveBiped.Bip01_R_Hand")
			if bone_rhand then
				local phys_bone_rhand = ent:TranslateBoneToPhysBone(bone_rhand)

				local dis = false
				if ent.GS2IsDismembered then
					local phys_bone = phys_bone_rhand
					local bone = ent:TranslatePhysBoneToBone(phys_bone)
					repeat
						phys_bone = ent:TranslateBoneToPhysBone(bone)
						if ent:GS2IsDismembered(phys_bone) then	
							dis = true		
							break
						end
						bone = ent:GetBoneParent(bone)
					until (phys_bone == -1)

					if (phys_bone != -1) then
						dis = true
					end
				end

				if (!dis and phys_bone != phys_bone_rhand) then
					local phys = ent:GetPhysicsObjectNum(phys_bone)						
					local const = constraint.Elastic(ent, ent, phys_bone, phys_bone_rhand, phys:WorldToLocal(dmgpos), hand_offset, 300, 0, 0, "", 0, false)
					const:Fire("SetSpringLength", 0, 0)
					contr_torso:CallOnRemove("rem"..const:EntIndex(), function()
						SafeRemoveEntityDelayed(const, 3)
					end)
					
					timer.Simple(0.5, function()
						if (IsValid(ent) and IsValid(contr_torso)) then							
							contr_torso:DeleteOnRemove(constraint.Weld(ent, ent, phys_bone, phys_bone_rhand))							
						end
					end)
				end
			end

			local bone_lhand = ent:LookupBone("ValveBiped.Bip01_L_Hand")
			if bone_lhand then
				local phys_bone_lhand = ent:TranslateBoneToPhysBone(bone_lhand)

				local dis = false
				if ent.GS2IsDismembered then
					local phys_bone = phys_bone_lhand
					local bone = ent:TranslatePhysBoneToBone(phys_bone)
					repeat
						phys_bone = ent:TranslateBoneToPhysBone(bone)
						if ent:GS2IsDismembered(phys_bone) then	
							dis = true		
							break
						end
						bone = ent:GetBoneParent(bone)
					until (phys_bone == -1)

					if (phys_bone != -1) then
						dis = true
					end
				end

				if (!dis and phys_bone != phys_bone_lhand) then
					local phys = ent:GetPhysicsObjectNum(phys_bone)						
					local const = constraint.Elastic(ent, ent, phys_bone, phys_bone_lhand, phys:WorldToLocal(dmgpos), hand_offset, 300, 0, 0, "", 0, false)
					const:Fire("SetSpringLength", 0, 0)
					contr_torso:CallOnRemove("rem"..const:EntIndex(), function()
						SafeRemoveEntityDelayed(const, 3)
					end)
					
					timer.Simple(0.5, function()
						if (IsValid(ent) and IsValid(contr_torso)) then							
							contr_torso:DeleteOnRemove(constraint.Weld(ent, ent, phys_bone, phys_bone_lhand))							
						end
					end)					
				end
			end
		end
	end
end