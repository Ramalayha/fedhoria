local bone_list_torso = 
{
	"ValveBiped.Bip01_Spine2",
	"ValveBiped.Bip01_Head1", 
	"ValveBiped.Bip01_R_Upperarm",
	"ValveBiped.Bip01_R_Forearm",
	--"ValveBiped.Bip01_R_Hand",
	"ValveBiped.Bip01_L_Upperarm",
	"ValveBiped.Bip01_L_Forearm",
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
	if (data.HitEntity == self) then
		return
	end
	
	if (data.HitNormal.z > -0.6) then return end

	self.LastCollide = CurTime()
end

local function PhysicsSim(self, phys, dt)
	local target = self:GetTarget()

	if (target.GS2IsDismembered and target:GS2IsDismembered(target.phys_bone_head)) then
		self:Remove()
		return
	end

	local phys_bone = phys:GetID()

	local vel = phys:GetVelocity()
	if (!self.DieTime and CurTime() - self.Created > 1 and vel:LengthSqr() < 150) then
		if (phys_bone == self.root_phys_bone) then
			self.DieTime = CurTime()
		end
		return false
	end
	local rate = math.Clamp(vel.z / -600, 0.5, 1.5)
	self:SetPlaybackRate(rate)
	
	if target.LastCollide then
		local delta = CurTime() - target.LastCollide
		if (delta < 0.2) then
			return false
		elseif (delta < 1) then
			return true, delta
		end
	end

	if self.is_torso then
		if (!self.DieTime and target:WaterLevel() > 0) then
			self:ResetSequence(self:LookupSequence("Choked_Barnacle"))
			self.DieTime = CurTime()
			timer.Simple(0.5, function()
				if !IsValid(target) then return end
				SafeRemoveEntity(self)
				local bone_lhand = target:LookupBone("ValveBiped.Bip01_L_Hand")
				if bone_lhand then
					local phys_bone_lhand = target:TranslateBoneToPhysBone(bone_lhand)
					local const = constraint.Elastic(target, target, phys_bone_lhand, target.phys_bone_head, vector_origin, vector_origin, 500, 0, 0, "", 0, false)
					const:Fire("SetSpringLength", 0, 0)
					SafeRemoveEntityDelayed(const, 5)
				end

				local bone_rhand = target:LookupBone("ValveBiped.Bip01_R_Hand")
				if bone_rhand then
					local phys_bone_rhand = target:TranslateBoneToPhysBone(bone_rhand)
					local const = constraint.Elastic(target, target, phys_bone_rhand, target.phys_bone_head, vector_origin, vector_origin, 500, 0, 0, "", 0, false)
					const:Fire("SetSpringLength", 0, 0)
					SafeRemoveEntityDelayed(const, 5)
				end
			end)
		end
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

function Fedh_DoFallingAnim(ent)
	local bg_hc = ent:FindBodygroupByName("headcrab1")

	if (bg_hc != -1) then
		--a zombie with no headcrab shouldnt move
		if (ent:GetBodygroup(bg_hc) == 0) then
			return
		end
	end

	local contr_torso = ents.Create("active_ragdoll_controller")
	contr_torso:SetModel("models/police.mdl")
	contr_torso:SetTarget(ent)
	contr_torso:SetBoneList(bone_list_torso)
	contr_torso:SetCollideCallback(PhysicsCollide)
	contr_torso:SetSimulateCallback(PhysicsSim)
	contr_torso:Spawn()

	contr_torso:ResetSequence(contr_torso:LookupSequence("idleonfire"))

	contr_torso.is_torso = true

	ent.phys_bone_head = ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_Head1") or -1) or -1
	
	local contr_legs = ents.Create("active_ragdoll_controller")
	contr_legs:SetModel("models/police.mdl")
	contr_legs:SetTarget(ent)
	contr_legs:SetBoneList(bone_list_legs)
	contr_legs:SetCollideCallback(PhysicsCollide)
	contr_legs:SetSimulateCallback(PhysicsSim)
	contr_legs:Spawn()

	contr_legs:ResetSequence(contr_legs:LookupSequence("Choked_Barnacle"))
end