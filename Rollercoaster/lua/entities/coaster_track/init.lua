AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )


function ENT:SpawnFunction( ply, tr )

	if !tr.Hit then return end
	
	local SpawnPos = tr.HitPos + tr.HitNormal * 16
	local ent = ents.Create( self.ClassName )
	ent:SetPos( SpawnPos )
	ent:SetAngles( Angle( 0, 0, 0) )
	ent:Spawn()
	ent:Activate()

	return ent

end

function ENT:Initialize()

	self:SetModel( self.Model )	
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	
	local phys = self:GetPhysicsObject()

	if phys:IsValid() then
		phys:Sleep()
	end

end

function ENT:Think()

	
end

function ENT:OnRemove()

end

