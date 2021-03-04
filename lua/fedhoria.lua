include("fedhoria/modules.lua")

local enabled 	= CreateConVar("fedhoria_enabled", 1, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local players 	= CreateConVar("fedhoria_players", 1, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local npcs 		= CreateConVar("fedhoria_npcs", 1, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))

local last_dmgpos = {}

hook.Add("CreateEntityRagdoll", "Fedhoria", function(ent, ragdoll)
	if (!enabled:GetBool() or !npcs:GetBool()) then return end
	local dmgpos = last_dmgpos[ent]

	local phys_bone, lpos

	if dmgpos then
		phys_bone = ragdoll:GetClosestPhysBone(dmgpos)
		if phys_bone then
			local phys = ragdoll:GetPhysicsObjectNum(phys_bone)
			lpos = phys:WorldToLocal(dmgpos)
		end
	end

	timer.Simple(0.1, function()
		if !IsValid(ragdoll) then return end	
		
		fedhoria.StartModule(ragdoll, "stumble_legs", phys_bone, lpos)
		last_dmgpos[ent] = nil		
	end)
end)

hook.Add("EntityTakeDamage", "Fedhoria", function(ent, dmginfo)
	if (!enabled:GetBool() or !npcs:GetBool()) then return end
	if (!ent:IsNPC() or dmginfo:GetDamage() < ent:Health()) then return end

	last_dmgpos[ent] = dmginfo:GetDamagePosition()
end)

local once = true

--RagMod/TTT support
hook.Add("OnEntityCreated", "Fedhoria", function(ent)
	--If RagMod isn't installed remove this hook
	if once then
		once = nil
		if (!RMA_Ragdolize and !CORPSE) then
			hook.Remove("OnEntityCreated", "Fedhoria")
			return
		end
		--these hooks fucks shit up
		if RMA_Ragdolize then
			hook.Remove( "PlayerDeath", "RM_PlayerDies")
			hook.Add( "PostPlayerDeath", "RemoveRagdoll", function(ply)
				if IsValid(ply.RM_Ragdoll) then
					SafeRemoveEntity(ply:GetRagdollEntity())
					ply:SpectateEntity(ply.RM_Ragdoll)
				end
			end)
		end
	end
	if (!enabled:GetBool() or !players:GetBool() or !ent:IsRagdoll()) then return end
	timer.Simple(0.1, function()
		if !IsValid(ent) then return end
		if CORPSE then
			local ply = ent:GetDTEntity(CORPSE.dti.ENT_PLAYER)
			if (IsValid(ply) and ply:IsPlayer()) then
				fedhoria.StartModule(ent, "stumble_legs")
				return
			end
		end
		for _, ply in ipairs(player.GetAll()) do
			if (ply.RM_IsRagdoll and ply.RM_Ragdoll == ent) then
				fedhoria.StartModule(ent, "stumble_legs")
				return
			end
		end
	end)
end)

local PLAYER = FindMetaTable("Player")

local oldCreateRagdoll = PLAYER.CreateRagdoll

local dolls = {}

local function CreateRagdoll(self)
	SafeRemoveEntity(dolls[self])

	local ragdoll = ents.Create("prop_ragdoll")
	ragdoll:SetModel(self:GetModel())
	ragdoll:SetPos(self:GetPos())
	ragdoll:SetAngles(self:GetAngles())
	ragdoll:Spawn()

	ragdoll:SetSkin(self:GetSkin())

	for i = 0, self:GetNumBodyGroups() - 1 do
		ragdoll:SetBodygroup(i, self:GetBodygroup(i))
	end

	for i = 0, ragdoll:GetPhysicsObjectCount()-1 do
		local phys = ragdoll:GetPhysicsObjectNum(i)
		local bone = ragdoll:TranslatePhysBoneToBone(i)
		local matrix = self:GetBoneMatrix(bone)
		local pos, ang = matrix:GetTranslation(), matrix:GetAngles()--self:GetBonePosition(bone)
		phys:SetPos(pos)
		phys:SetAngles(ang)
		phys:SetVelocity(self:GetVelocity())
	end

	self:SpectateEntity(ragdoll)
	self:Spectate(OBS_MODE_CHASE)

	dolls[self] = ragdoll
end

local oldGetRagdollEntity = PLAYER.GetRagdollEntity

local function GetRagdollEntity(self)
	return dolls[self] or NULL
end

if enabled:GetBool() then
	PLAYER.CreateRagdoll = CreateRagdoll
	PLAYER.GetRagdollEntity = GetRagdollEntity
end

cvars.AddChangeCallback("fedhoria_enabled", function(name, old, new)
	if (new == "1") then
		if players:GetBool() then
			PLAYER.CreateRagdoll = CreateRagdoll
			PLAYER.GetRagdollEntity = GetRagdollEntity
		end
	else
		PLAYER.CreateRagdoll = oldCreateRagdoll
		PLAYER.GetRagdollEntity = oldGetRagdollEntity
	end
end)

cvars.AddChangeCallback("fedhoria_players", function(name, old, new)
	if (new == "1") then
		if enabled:GetBool() then
			if (debug.getinfo(PLAYER.CreateRagdoll).short_src == "[C]") then
				PLAYER.CreateRagdoll = CreateRagdoll
				PLAYER.GetRagdollEntity = GetRagdollEntity
			end
		end
	else
		PLAYER.CreateRagdoll = oldCreateRagdoll
		PLAYER.GetRagdollEntity = oldGetRagdollEntity
	end
end)

hook.Add("PostPlayerDeath", "Fedhoria", function(ply)
	if (!enabled:GetBool() or !players:GetBool()) then return end
	timer.Simple(0.1, function()
		if !IsValid(ply) then return end
		local ragdoll = ply:GetRagdollEntity()
		if (IsValid(ragdoll) and ragdoll:IsRagdoll()) then
			fedhoria.StartModule(ragdoll, "stumble_legs")
		end
	end)
end)