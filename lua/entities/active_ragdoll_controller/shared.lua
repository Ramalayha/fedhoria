ENT.Type = "anim"
ENT.Base = "base_anim"
 
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Target")
end