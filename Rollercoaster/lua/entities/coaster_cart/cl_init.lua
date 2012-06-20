include( "shared.lua" )

ENT.OffDaRailz = false

ENT.Mass = 80

ENT.Velocity = 10 //Starting velocity
ENT.Multiplier = 1 //Multiplier to set the same speed per node segment
ENT.Controller = nil //Controller entity. Useless
ENT.CoastSound = nil //Sound of just moving
ENT.ChainSound = nil //Sound of chains (Move to serverside?)
ENT.WindSound  = nil //Sound of wind
ENT.ShakeMultiplier = 1 //Multiplier to fine-tune shaking
ENT.Timer = math.huge

ENT.RenderGroup 	= RENDERGROUP_TRANSLUCENT

//Update with the controller node. Currently has no use
usermessage.Hook("coaster_train_fullupdate", function(um)
	local self = um:ReadEntity()
	local controller = um:ReadEntity()
	
	self.Controller = controller

end )


//Create the sounds
function ENT:Initialize()
	self.CoastSound = CreateSound( self, "coaster_ride.wav" )
	self.CoastSound:PlayEx(0.5, 100)

	self.WindSound = CreateSound( self, "coaster_wind.wav")
	self.WindSound:PlayEx(0, 100)
	
	self.ChainSound = CreateSound( self, "coaster_chain.wav" )

	local sequence = self:LookupSequence( "idle" )
	self:ResetSequence( sequence )
	self:SetPlaybackRate( 1.0 )

	if self:GetModel() == "models/sunabouzu/sonic_the_carthog.mdl" then
		surface.PlaySound("coaster_sonic_the_carthog.mp3")
		self.Timer = CurTime() + 24.00
		self.Enabled = true

		local sequence = self:LookupSequence( "GOING_FAST" )
		self:ResetSequence( sequence )
		self:SetPlaybackRate( 1.0 )
	end
end

function ENT:Draw()
	if self.Enabled then
		if !self.Frame then self.Frame = 0 end

		self.Frame = self.Frame + ( FrameTime() * self:GetVelocity():Length() / 300 )
		self:FrameAdvance( self.Frame )
		self:SetCycle( self.Frame )
	end
	self:DrawModel()	

end

function ENT:Think()
	if self.Enabled then
		if !self.Frame then self.Frame = 0 end
		
		self.Frame = self.Frame + ( FrameTime() * self:GetVelocity():Length() / 300 )
		self:FrameAdvance( self.Frame )
		self:SetCycle( self.Frame )
	end


	local CurrentNode = self:GetCurrentNode()
	if IsValid( CurrentNode ) && CurrentNode:EntIndex() != 1 && CurrentNode:GetType() == COASTER_NODE_CHAINS then
		if self.ChainSound then
			if !self.ChainSound:IsPlaying() then
				self.ChainSound:PlayEx(1, 100)
			end
		else
			self.ChainSound = CreateSound( self, "coaster_chain.wav" )
		end
	else
		if self.ChainSound then
			if self.ChainSound:IsPlaying() then
				self.ChainSound:Stop()
			end
		end

		if CurrentNode:EntIndex() == 1 then
			self.OffDaRailz = true
		end
	end

	if CurTime() >= self.Timer then
		CoasterBlur = 1.000
		self.ShakeMultiplier = 30
	end


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
	
	//I have no idea, I just threw these values in
	local amp = 0
	if LocalPlayer():InVehicle() then
		amp = math.Clamp( self:GetVelocity():Length() / 4000, 0, 32 )
	else
		amp = math.Clamp( self:GetVelocity():Length() / 30, 0, 32 )
		amp = math.Clamp( amp / ( LocalPlayer():GetPos():Distance( self:GetPos() ) ), 0, 2000 )
	end
	amp = amp * self.ShakeMultiplier
	util.ScreenShake( LocalPlayer():GetPos(), amp, 300, .5, 300 )

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
