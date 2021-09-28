net.Receive("Fedhoria.SetRagdollColor", function(ln)
	local ply = net.ReadEntity()
	local ragdoll = net.ReadEntity()

	ragdoll.GetPlayerColor = function(self)
		return ply:GetPlayerColor()
	end
end)
