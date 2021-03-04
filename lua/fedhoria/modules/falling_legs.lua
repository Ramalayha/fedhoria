MODULE.Model = "models/police.mdl"
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

local math_Clamp = math.Clamp

function MODULE:Init()
	self:ResetSequence(self:LookupSequence("Choked_Barnacle"))

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

		local pos = phys:GetPos()

		self.last_pos = self.last_pos or pos

		local offset = (pos - self.last_pos) / dt

		self.last_pos = pos

		if (target:WaterLevel() > 0) then
			self.StartDie = self.StartDie or CurTime()			
			self:SetPlaybackRate(2 * f)
		else		
			if (offset:LengthSqr() < 900) then
				self.StartDie = self.StartDie or CurTime()
				return false
			else
				self.StartDie = nil
			end
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