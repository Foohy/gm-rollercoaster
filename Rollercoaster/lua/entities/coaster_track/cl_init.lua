include( "shared.lua" )

function ENT:Initialize()
	self.CurPos = self:GetPos()
	self.CurAngle = self:GetAngles()
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:Think()

end
