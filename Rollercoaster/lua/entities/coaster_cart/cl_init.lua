include( "shared.lua" )

ENT.OffDaRailz = false

ENT.Mass = 80

ENT.Velocity = 10 //Starting velocity
ENT.Multiplier = 1 //Multiplier to set the same speed per node segment
ENT.Controller = nil //Controller entity. Useless
ENT.CoastSound = nil //Sound of just moving
ENT.ChainSound = nil //Sound of chains (Move to serverside?)
ENT.WindSound  = nil //Sound of wind

usermessage.Hook("Coaster_OffDaRailz", function( um )
	local ent = um:ReadEntity()
	
	if IsValid( ent ) then
		ent.OffDaRailz = true
	end

end )

//Update with the controller node. Currently has no use
usermessage.Hook("coaster_train_fullupdate", function(um)
	local self = um:ReadEntity()
	local controller = um:ReadEntity()
	
	self.Controller = controller

end )

//Start on a segment with a chain
usermessage.Hook("ChainStart", function(um)
	local ent = um:ReadEntity()
	
	if IsValid( ent ) && ent.ChainSound != nil then
		ent.ChainSound:PlayEx( 1, 100 )
	end

end )

//Get off a segment with a chain
usermessage.Hook("ChainStop", function(um)
	local ent = um:ReadEntity()
	
	if IsValid( ent ) && ent.ChainSound != nil then
		ent.ChainSound:Stop()
	end

end )

//Create the sounds
function ENT:Initialize()
	self.CoastSound = CreateSound( self, "coaster_ride.wav" )
	self.CoastSound:PlayEx(0.5, 100)

	self.WindSound = CreateSound( self, "coaster_wind.wav")
	self.WindSound:PlayEx(0, 100)
	
	self.ChainSound = CreateSound( self, "coaster_chain.wav" )
end

function ENT:Draw()
	self:DrawModel()	
end

function ENT:Think()
	//Change sound pitch and volume depending on speed
	if self.OffDaRailz then
		if self.CoastSound != nil then self.CoastSound:Stop() end
	else
		if self.CoastSound != nil then
			self.CoastSound:ChangePitch(math.Clamp( (self:GetVelocity():Length() / 8) , 1, 240 ) )
		else
			self.CoastSound = CreateSound( self, "coaster_ride.wav" )
		end

		if self.WindSound != nil then
			self.WindSound:ChangeVolume(math.Clamp( (self:GetVelocity():Length() / 900) , 0, 1 ) )

			local pitch = 90 + (self:GetVelocity():Length() / 13)
			self.WindSound:ChangePitch(math.Clamp( pitch , 90, 110 ) )
		else
			self.WindSound = CreateSound( self, "coaster_wind.wav" )
		end
	end
	
	//Manage shaking TODO: screenshake doesn't lower amplitude as distance from center becomes higher. Come up with alternative shake?
	local amp = math.Clamp( self:GetVelocity():Length() / 2000, 0, 32 )
	amp = math.Clamp( amp - LocalPlayer():GetPos():Distance( self:GetPos() ), 0, 2000 )
	util.ScreenShake( self:GetPos(), amp, 300, .5, 300 )

end

//Remove sounds
function ENT:OnRemove()
	if self.CoastSound != nil then
		self.CoastSound:Stop()
		self.CoastSound = nil
	end
	
	if self.ChainSound != nil then
		self.ChainSound:Stop()
		self.ChainSound = nil
	end

	if self.WindSound != nil then
		self.WindSound:Stop()
		self.WindSound = nil
	end
end


//Debris effect
//TODO: It kinda sucks for this. Make something better
local EFFECT = {};
	
function EFFECT:Init( data )

	self.DieTime = CurTime() + 0.25

	local normal = data:GetNormal() * -1
	local pos = data:GetOrigin()

	local numdebris = math.random( 5, 14 )
	local DebrisModels = {
		Model( "models/gibs/manhack_gib01.mdl" ), Model( "models/gibs/manhack_gib02.mdl" ),
		Model( "models/gibs/manhack_gib04.mdl" ), Model( "models/gibs/metal_gib1.mdl" ),
		Model( "models/gibs/metal_gib2.mdl" ), Model( "models/gibs/metal_gib3.mdl" ),
		Model( "models/gibs/metal_gib4.mdl" ), Model( "models/Gibs/Glass_shard.mdl" ),
		Model( "models/Gibs/Glass_shard02.mdl" ), Model( "models/Gibs/Glass_shard03.mdl" )
	}

	for i=0, numdebris do

		local debris = ClientsideModel( DebrisModels[ math.random( 1, #DebrisModels ) ], RENDERGROUP_OPAQUE )
		if IsValid( debris ) then
			debris:SetPos( self:GetPos() + Vector( 0, 0, 10 ) )
			debris:SetMaterial( "models/props_pipes/GutterMetal01a" )

			debris:PhysicsInitBox( Vector( -6, -6, -6 ), Vector( 6, 6, 6 ) )
			debris:SetCollisionBounds( Vector( -6, -6, -6 ), Vector( 6, 6, 6 ) )

			if math.random( 1, 3 ) == 1 then
				debris:SetColor( Color( 255, 125, 0, 255 ) )
			else
				debris:SetColor( Color( 215, 0, 0, 255 ) )
			end

			local phys = debris:GetPhysicsObject()
			if IsValid( phys ) then

				local force = 30
				phys:AddVelocity( Vector( math.random( -force, force ), math.random( -force, force ), math.random( 30, 80 ) ) )
				phys:AddAngleVelocity( Angle( 1500, 0, 0 ) )

			end

			timer.Simple( math.Rand( 4, 6 ), debris.Remove, debris )
		end

	end

end

function EFFECT:Think() return false end
function EFFECT:Render() end

effects.Register( EFFECT, "coaster_cart_debris" )
