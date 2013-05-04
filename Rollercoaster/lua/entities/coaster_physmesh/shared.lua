ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.PrintName		= "Rollercoaster physics mesh"
ENT.Author			= "Foohy"

ENT.Spawnable		= false
ENT.AdminSpawnable	= false

ENT.Model			= Model( "models/XQM/coastertrain2seat.mdl" )

ENT.Tri_Width 		= 30
ENT.Tri_Height 		= 30
ENT.Resolution 		= 10


function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Segment")
	self:NetworkVar("Entity", 0, "Controller")
end

function ENT:Initialize()
	self:SetMaterial( "metal" )
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