MODULE.Model = "models/police.mdl"
MODULE.BoneList = 
{
	"ValveBiped.Bip01_Pelvis",
	"ValveBiped.Bip01_Spine2",
	"ValveBiped.Bip01_Head1", 
	"ValveBiped.Bip01_R_Upperarm",
	"ValveBiped.Bip01_R_Forearm",
	--"ValveBiped.Bip01_R_Hand",
	"ValveBiped.Bip01_L_Upperarm",
	"ValveBiped.Bip01_L_Forearm",
	--"ValveBiped.Bip01_L_Hand",
	--"ValveBiped.Bip01_R_Thigh",
	--"ValveBiped.Bip01_R_Calf",
	--"ValveBiped.Bip01_R_Foot",
	--"ValveBiped.Bip01_L_Thigh",
	--"ValveBiped.Bip01_L_Calf",
	--"ValveBiped.Bip01_L_Foot"
}

local math_Clamp = math.Clamp

local hand_offset = Vector(2, 0, 0)

local function CreateSpring(phys1, phys2, constant)
	local str_axis = tostring(phys2:LocalToWorld(hand_offset))

	local const = ents.Create("phys_spring")
	--const:SetPos(phys1:LocalToWorld(phys1:GetAABBCenter()))
	const:SetPos(phys1:GetPos())
	const:SetKeyValue("springaxis", str_axis)
	const:SetKeyValue("constant", constant)
	const:SetKeyValue("damping", 0.1)
	const:SetKeyValue("relativedamping", 0.1)
	const:SetPhysConstraintObjects(phys1, phys2)
	const:Spawn()
	const:Activate()
	const:Fire("SetSpringLength", 0, 0)

	return const
end

function MODULE:Init()
	self:ResetSequence(self:LookupSequence("idleonfire"))

	self.LastCollide = 0
end

function MODULE:Think()

end

function MODULE:PhysicsCollide(ent, data)
	if (data.HitEntity == ent) then
		return
	end
	
	if (data.HitNormal.z > -0.6) then return end

	local cur_time = CurTime()

	if (cur_time - self.LastCollide < 0.5) then
		--self.StartDie = self.StartDie or CurTime()
	else
		--self.StartDie = nil
	end
	
	self.LastCollide = CurTime()
end

local die_time = CreateConVar("fedhoria_dietime", 5, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))

function MODULE:PhysicsSimulate(phys, dt)
	local f = self.StartDie and 1 - (CurTime() - self.StartDie) / die_time:GetFloat() or 1

	--if we have been still for too long we are dead x_x
	if (f < 0) then
		self:Remove()
		return false
	end

	local target = self:GetTarget()

	local phys_bone = phys:GetID()

	if (phys_bone == 0) then
		local vel = phys:GetVelocity()
		
		local pbr = math_Clamp(vel.z / -600, 0.5, 1.5)
		self:SetPlaybackRate(pbr)

		if (target:WaterLevel() > 0) then
			self:ResetSequence(self:LookupSequence("Choked_Barnacle"))
			timer.Simple(0.5, function()
				if !IsValid(target) then return end
				SafeRemoveEntity(self)
				local bone_head = target:LookupBone("ValveBiped.Bip01_Head1")
				if bone_head then
					local phys_bone_head = target:TranslateBoneToPhysBone(bone_head)
					local phys_head = target:GetPhysicsObjectNum(phys_bone_head)

					local bone_lhand = target:LookupBone("ValveBiped.Bip01_L_Hand")
					if bone_lhand then
						local phys_bone_lhand = target:TranslateBoneToPhysBone(bone_lhand)
						local phys_lhand = target:GetPhysicsObjectNum(phys_bone_lhand)				
						SafeRemoveEntityDelayed(CreateSpring(phys_head, phys_lhand, 500), die_time:GetFloat())
					end

					local bone_rhand = target:LookupBone("ValveBiped.Bip01_R_Hand")
					if bone_rhand then
						local phys_bone_rhand = target:TranslateBoneToPhysBone(bone_rhand)
						local phys_rhand = target:GetPhysicsObjectNum(phys_bone_rhand)				
						SafeRemoveEntityDelayed(CreateSpring(phys_head, phys_rhand, 500), die_time:GetFloat())
					end
				end
			end)					
		else
			self:ResetSequence(self:LookupSequence("idleonfire"))

			local pos = phys:GetPos()

			self.last_pos = self.last_pos or pos

			local offset = (pos - self.last_pos) / dt

			self.last_pos = pos

			if (offset:LengthSqr() < 900) then 
				self.StartDie = self.StartDie or CurTime()				
				return false
			else
				self.StartDie = nil
			end
		end

		local delta = CurTime() - self.LastCollide
		if (delta < 0.2) then 
			return false 
		elseif (delta < 1.2) then
			return true, delta - 0.2
		end
		
		return false
	end

	local delta = CurTime() - self.LastCollide
	if (delta < 0.2) then 
		return false 
	elseif (delta < 1.2) then
		return true, delta - 0.2
	end

	return true, f
end