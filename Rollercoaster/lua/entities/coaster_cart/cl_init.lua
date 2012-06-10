include( "shared.lua" )

ENT.OffDaRailz = false

ENT.Mass = 80

ENT.Velocity = 10 //Starting velocity
ENT.Multiplier = 1 //Multiplier to set the same speed per node segment
ENT.Controller = nil
ENT.CoastSound = nil
ENT.ChainSound = nil
ENT.WindSound  = nil

usermessage.Hook("Coaster_OffDaRailz", function( um )
	local ent = um:ReadEntity()
	
	if IsValid( ent ) then
		ent.OffDaRailz = true
	end

end )

usermessage.Hook("coaster_train_fullupdate", function(um)
	local self = um:ReadEntity()
	local controller = um:ReadEntity()
	
	self.Controller = controller

end )

usermessage.Hook("ChainStart", function(um)
	local ent = um:ReadEntity()
	
	if IsValid( ent ) && ent.ChainSound != nil then
		ent.ChainSound:PlayEx( 1, 100 )
	end

end )

usermessage.Hook("ChainStop", function(um)
	local ent = um:ReadEntity()
	
	if IsValid( ent ) && ent.ChainSound != nil then
		ent.ChainSound:Stop()
	end

end )

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
/*
function ENT:AngleAt(i, perc )
	local AngVec = Vector(0,0,0)
	local curSpline = self:GetCurrentSpline( i, perc )

	if #self.Controller.CatmullRom.Spline > curSpline + 1 then

		AngVec = self.Controller.CatmullRom.Spline[curSpline] - self.Controller.CatmullRom.Spline[curSpline + 1]
		AngVec:Normalize()
	end
	return AngVec:Angle()
end

function ENT:GetCurrentSpline(i, perc)
	local STEPS = 10//(self.Controller.CatmullRom.STEPS
	
	local spline = (i - 2 ) * STEPS + (STEPS * perc)
	//print(math.floor(spline))
	return math.Clamp( math.floor(spline), 1, #self.Controller.CatmullRom.Spline)
end

function ENT:GetMultiplier(i, perc)
	local Dist = 1
	local curSpline = self:GetCurrentSpline( i, perc )

	if #self.Controller.CatmullRom.Spline > curSpline + 1 then
		Dist = self.Controller.CatmullRom.Spline[curSpline]:Distance( self.Controller.CatmullRom.Spline[curSpline + 1] )
	end

	
	return 1 / Dist 
end

function ENT:PhysThink()
	self.Velocity = self.Velocity + ((math.NormalizeAngle(self:GetAngles().p )) / -self.Mass ) * FrameTime() * 100
	self.CoastSound:ChangePitch(math.Clamp( math.abs(self.Velocity), 1, 240 ) )
end

function ENT:Think()
	if IsValid( self.Controller ) then		
		self.Multiplier = self:GetMultiplier(self.CurSegment, self.Percent)
		self:SetPos( self.Controller.CatmullRom:Point(self.CurSegment, self.Percent) )
		//self:SetAngles( self.Controller.CatmullRom:Angle(self.CurSegment, self.CurTime) )
		self:SetAngles( self:AngleAt(self.CurSegment, self.Percent) )
		
		if self.Percent > 1 then
			self.CurSegment = self.CurSegment + 1
			if self.CurSegment > #self.Controller.Nodes - 2 then self.CurSegment = 2 end

			self.Percent = 0
		elseif self.Percent < 0 then
			self.CurSegment = self.CurSegment - 1
			if self.CurSegment < 2 then self.CurSegment = #self.Controller.Nodes end
			self.Percent = 1
		end
		
		self.Percent = self.Percent + (FrameTime() * self.Multiplier * self.Velocity )
	end
	
	self:PhysThink()
end
*/

function ENT:Think()
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
	
	//Manage shaking
	local amp = math.Clamp( self:GetVelocity():Length() / 2000, 0, 32 )
	amp = math.Clamp( amp - LocalPlayer():GetPos():Distance( self:GetPos() ), 0, 2000 )
	util.ScreenShake( self:GetPos(), amp, 300, .5, 300 )

end

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
				debris:SetColor( 255, 125, 0, 255 )
			else
				debris:SetColor( 215, 0, 0, 255 )
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
