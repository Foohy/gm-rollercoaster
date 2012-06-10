include( "shared.lua" )

local MatCable  = Material("cable/cable2")

function ENT:Initialize()
	self:SetModelScale( Vector( 0.3, 0.3, 0.3 ))
end

function ENT:Draw()
	self:DrawModel()

	if IsValid( self:GetMainNode() ) then
		render.SetMaterial( MatCable )
		render.StartBeam( 2 )
		render.AddBeam( self:GetPos(), 8, 10, color_white)
		render.AddBeam( self:GetMainNode():GetPos(), 8, 10, color_white )
		render.EndBeam()
	end
end

function ENT:Think()
	if IsValid( self:GetMainNode() ) then
		self:SetRenderBoundsWS( self:GetPos(),  self:GetMainNode():GetPos() )
	end
end

function ENT:OnRemove()

end
