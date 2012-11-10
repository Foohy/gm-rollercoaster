ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.PrintName		= "Rollercoaster cart"
ENT.Author			= "Foohy"

ENT.Spawnable		= false
ENT.AdminSpawnable	= false

ENT.Model			= Model( "models/XQM/coastertrain2seat.mdl" )

ENT.Tri_Width 		= 30
ENT.Tri_Height 		= 30
ENT.Resolution 		= 10


function ENT:SetupDataTables()
	self:DTVar("Int", 0, "Segment")
	self:DTVar("Int", 1, "Controller")
end

function ENT:Initialize()
	self:SetMaterial( "metal" )
end

function ENT:SetSegment(segment)
	self.dt.Segment = segment
end

function ENT:GetSegment()
	return self.dt.Segment
end

function ENT:SetController(node)
	self.dt.Controller = node:EntIndex()
end

function ENT:GetController()
	return Entity(self.dt.Controller)
end

function ENT:Think()
	local controller = self:GetController()
	if !IsValid( controller ) then return end 

	//DONT EVEN TRY ME
	if self:GetPos() != controller:GetPos() then
		self:SetPos( controller:GetPos() )
		self:SetAngles( Angle(0,0,0))
	end
end