AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

function ENT:Initialize()
	self:SetModel( self.Model )	

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	
	self:DrawShadow(false)
	
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)

	local phys = self:GetPhysicsObject()

	if phys:IsValid() then
		phys:Sleep()
	end
	
end

function ENT:PhysicsUpdate(physobj)
	if !self:IsPlayerHolding() then
		physobj:Sleep()
		physobj:EnableMotion( false )
		
		if self.WasBeingHeld then
			self.WasBeingHeld = false
		end
	else
		if IsValid( self:GetMainNode() ) then
			self:GetMainNode():ControlNodeUpdate( self )
		end

		if self.WasBeingHeld == false then
			self.WasBeingHeld = true
		end
	end
end