AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

ENT.CoasterID 	= -1 //Unique ID of the coaster this cart is attached to
ENT.NumCarts 	= 1 //Length of the train of carts
ENT.Powered 	= false //If powered, never slow beyond a certain speed. Basically silent always-on chains
ENT.MinSpeed 	= 0 //minimum speed to travel at. 0 means dont touch shit.
ENT.Controller 	= nil //Controller
ENT.IsOffDaRailz  = false 

//Physics stuff
ENT.GRAVITY = 9.8
ENT.InitialMass = 100
ENT.WheelFriction = 0.04 //Coeffecient for mechanical friction (NOT drag) (no idea what the actual mew is for a rollercoaster, ~wild guesses~)
ENT.Restitution = 0.9
ENT.Velocity = 4 //Starting velocity
ENT.Multiplier = 0.99999 //Multiplier to set the same speed per node segment
ENT.IsOffDaRailz = false
ENT.Rotation = 0

//Speedup node options/variables
ENT.SpeedupForce = 1400 //Force of which to accelerate the car
ENT.MaxSpeed = 3600 //The maximum speed to which accelerate the car
ENT.LastSpark = 0

//Home station options/variables
ENT.HomeStage = 0
ENT.StopTime = 5 //Time to stop and wait for people to leave/board

//Break node options/variables
ENT.BreakForce = 1400 //Force of which to deccelerate the car
ENT.BreakSpeed = 4 //The minimum speed of the car when in break zone


//Credits to LPine for code on how to use a shadow controller 
ENT.PhysShadowControl = {}
ENT.PhysShadowControl.secondstoarrive  = .01
ENT.PhysShadowControl.pos              = Vector(0, 0, 0)
ENT.PhysShadowControl.angle            = Angle(0, 0, 0)
ENT.PhysShadowControl.maxspeed         = 1000000000000
ENT.PhysShadowControl.maxangular       = 1000000
ENT.PhysShadowControl.maxspeeddamp     = 10000
ENT.PhysShadowControl.maxangulardamp   = 1000000
ENT.PhysShadowControl.dampfactor       = 1
ENT.PhysShadowControl.teleportdistance = 0
ENT.PhysShadowControl.deltatime        = deltatime

function ENT:Initialize()
	self:SetModel( self.Model )	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
	
	//Spawn at the beginning second node, where the curve starts
	self.CurSegment = 2
	self.Percent = 0
	
	//Start simulating our own physics
	self:StartMotionController()
	
	//Tell the client of our owner
	//Currently has no use
	timer.Simple( 0, function()
		umsg.Start("coaster_train_fullupdate")
			umsg.Entity( self )
			umsg.Entity( self.Controller )
		umsg.End()
	end )
	
	//more random guesses
	if IsValid( self:GetPhysicsObject() ) then
		self:GetPhysicsObject():SetMass( self.InitialMass )
		self:GetPhysicsObject():Wake()
	end

	self.SparkEffect = EffectData()
	self.SparkEffect:SetEntity( self )

	if self:GetModel() == "models/props_c17/playground_carousel01.mdl" then
		self.Carousel = true
	end
end

//Pop
function ENT:OffDaRailz()
	self.IsOffDaRailz = true

	self:SetCurrentNode( Entity( 1 ) ) //Basically set the entity to something improper to show we have no current node
	
	self:EmitSound("coaster_offdarailz.wav", 100, 100 )
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:GetPhysicsObject():SetMass( 500 ) //If this is wrong I don't wanna be right
end

//Calculate our movement along the curve
function ENT:PhysicsSimulate(phys, deltatime)
	if self.IsOffDaRailz then return SIM_NOTHING end

	local CurPos  = self:GetPos()
	local CurNode = self.Controller.Nodes[self.CurSegment]
	local NextNode = self.Controller.Nodes[ self.CurSegment + 1]
	if !IsValid( CurNode ) || !IsValid( NextNode ) then self.CurSegment = #Rollercoasters[self.CoasterID].Nodes end
	self:SetCurrentNode( CurNode )

	//Forces that are always being applied to the cart
	self.Velocity = self.Velocity - self:CalcFrictionalForce(self.CurSegment, self.Percent, deltatime)
	self.Velocity = self.Velocity - self:CalcChangeInVelocity( self.CurSegment, self.Percent, deltatime )

	//Node specific forces
	self:ChainThink()
	self:SpeedupThink(deltatime)
	self:BreakThink(deltatime)
	self:MinSpeedThink()
	self:HomeStationThink(deltatime)
	
	self.PhysShadowControl.pos = self.Controller.CatmullRom:Point(self.CurSegment, self.Percent)
	
	//Each node has a certain multiplier so the cart travel at a constant speed throughout the track
	self.Multiplier = self:GetMultiplier(self.CurSegment, self.Percent)



	//Check for collisions
	for k, v in pairs( ents.FindInSphere( self:GetPos(), 150 ) ) do
		if !self.IsOffDaRailz && ( IsValid(v) && v:GetClass() == "coaster_cart" ) && v.Velocity then
			local ourmass = self:GetPhysicsObject():GetMass()
			local theirmass = v:GetPhysicsObject():GetMass()

			local SelfVelocity = ( (ourmass*self.Velocity) + (theirmass*v.Velocity)) / (ourmass + theirmass)
			local TheirVelocity = SelfVelocity
			//local SelfVelocity = ( self.Restitution*theirmass*( v.Velocity - self.Velocity ) + (ourmass*self.Velocity) + (theirmass*v.Velocity ) ) / ( ourmass + theirmass )
			//local TheirVelocity = ( self.Restitution*ourmass*(self.Velocity - v.Velocity) + (ourmass*self.Velocity) + (theirmass*v.Velocity)) / ( ourmass + theirmass )

			//local SelfVelocity = ( self.Velocity * ( ourmass - theirmass ) + ( 2 *theirmass*v.Velocity)) / (ourmass + theirmass)
			//local TheirVelocity = ( v.Velocity * ( theirmass - ourmass ) + ( 2*ourmass*self.Velocity )) / ( ourmass + theirmass)


			//self.Velocity = SelfVelocity
			//v.Velocity = TheirVelocity

		end
	end

	//Move ourselves forward along the track
	self.Percent = self.Percent + (deltatime * self.Multiplier * self.Velocity )
	
	//Manage moving between nodes/looping around
	if self.Percent > 1 then
		self.CurSegment = self.CurSegment + 1
		if self.CurSegment > #self.Controller.Nodes - 2 then 
		
			//If the track isn't looped, it's OFF DA RAILZ
			if IsValid( Rollercoasters[ self.CoasterID ] ) then
				if !Rollercoasters[ self.CoasterID ]:Looped() then
					self:OffDaRailz()
					return
				end
			end
			
			self.CurSegment = 2 
			local newPos = self.Controller.Nodes[ self.CurSegment ]:GetPos()
			//self:SetPos( newPos ) //Teleport us to the first 'real' node
			self.PhysShadowControl.pos = newPos
		end	
		self.Percent = 0
		
	elseif self.Percent < 0 then
		self.CurSegment = self.CurSegment - 1
		if self.CurSegment < 2 then 
		
			//If the track isn't looped, it's OFF DA RAILZ
			if IsValid( Rollercoasters[ self.CoasterID ] ) then
				if !Rollercoasters[ self.CoasterID ]:Looped() then
					self:OffDaRailz()
					return
				end
			end
		
			self.CurSegment = #self.Controller.Nodes - 2
			local newPos = self.Controller.Nodes[ self.CurSegment ]:GetPos()
			//self:SetPos( newPos ) //Teleport us to the last 'real' node
			self.PhysShadowControl.pos = newPos
		end
		self.Percent = 1
		
	end
	
	phys:Wake()

	//self.PhysShadowControl.angle = self:GetVelocity():Angle()
	local ang = self:AngleAt(self.CurSegment, self.Percent)
	
	//Change the roll depending on the track
	local Roll = 0
	if IsValid( CurNode ) && IsValid( NextNode ) then
		Roll = -Lerp( self.Percent, CurNode:GetRoll(), NextNode:GetRoll())	
	end
	
	//Set the roll for the current track peice
	ang:RotateAroundAxis( self:AngleAt(self.CurSegment, self.Percent):Forward(), Roll ) //BAM
	ang.r = -ang.r
	
	//Offsets
	ang.p = -ang.p
	ang.y = ang.y + 180

	//If we are a carousel, SPIN
	if self.Carousel then
		local ang1 = self:AngleAt( self.CurSegment, self.Percent )
		local p1 = self.Controller.CatmullRom:Point( self.CurSegment , self.Percent )
		local p2 = self.Controller.CatmullRom:Point( self.CurSegment , self.Percent + 0.01 )
		local angvec = p2 - p1
		angvec:Angle()

		//local angDif = ang1 - ang2
		self.Rotation = self.Rotation + ( deltatime * angvec.y * 100 )
		self.Rotation = math.NormalizeAngle( self.Rotation )

		if ( Coaster_do_bad_things ) then
			ang:RotateAroundAxis( ang1:Up(), self.Rotation )
		else
			ang:RotateAroundAxis( ang:Up(), self.Rotation )
		end
		//ang.y = Rotation
	end

	self.PhysShadowControl.angle = ang

	self.PhysShadowControl.pos = self.PhysShadowControl.pos + ang:Up() * 10


	self.PhysShadowControl.deltatime = deltatime	
	//print( tostring( self:EntIndex() ) .. ": " .. tostring( self.Velocity ) )
	return phys:ComputeShadowControl(self.PhysShadowControl)
end

//Calculate the frictional force experienced on the cart's wheels
//this uses PHYSICS
function ENT:CalcFrictionalForce(i, perc, dt)
	local Force = 0
	local Velocity = 0

	local mass = self:GetPhysicsObject():GetMass()

	local Ang = self:AngleAt( i, perc )

	Force = self.WheelFriction * ( math.cos( math.rad(Ang.p) ) * mass * self.GRAVITY ) //frictional force = mew*normal of weight
	Velocity = (Force / mass) * dt // F = MA and your every day best friend DVA
	

	if self.Velocity < 0 then
		Velocity = -Velocity
	end

	//Prevent floating point numbers from fucking shit up
	if math.abs(self.Velocity) < 0.05 then
		return 0
	end

	return Velocity
end

function ENT:CalcChangeInVelocity(i, perc, dt)
	local Force = 0
	local Velocity = 0

	local mass = self:GetPhysicsObject():GetMass()
	local Ang = self:AngleAt( i, perc )

	Force = math.sin( math.rad( Ang.p )) * mass * self.GRAVITY

	return (Force / mass) * dt //A = VelocityChange / TimeChange. thus, V = AT
end

//Make sure we're above our minimum set speed
function ENT:MinSpeedThink()
	if self.MinSpeed > 0 && self.Velocity < self.MinSpeed then
		self.Velocity = self.MinSpeed
	end
end

function ENT:SpeedupThink(dt)
	if self:GetCurrentNode():GetType() == COASTER_NODE_SPEEDUP && self.Velocity < self.MaxSpeed then
		local Acceleration = self.SpeedupForce / self:GetPhysicsObject():GetMass() //F = MA. thus, (F / M) = A
		local Velocity = Acceleration * dt //A = VelocityChange / TimeChange. thus, V = AT

		self.Velocity = self.Velocity + Velocity

		if self.LastSpark && self.LastSpark < CurTime() then
			self.LastSpark = CurTime() + 0.01

			self.SparkEffect:SetOrigin( self:GetPos() )
			local newangles = self:GetAngles() + Angle( 15, 0, 0 )
			self.SparkEffect:SetNormal( -newangles:Forward() + Vector( 0, 0, 0.5) )
			util.Effect("ManhackSparks", self.SparkEffect )
		end
	end
end

//Basically the exact opposite of speedup
function ENT:BreakThink(dt)
	if self:GetCurrentNode():GetType() == COASTER_NODE_BREAKS && self.Velocity > self.BreakSpeed then
		local Acceleration = self.BreakForce / self:GetPhysicsObject():GetMass() //F = MA. thus, (F / M) = A
		local Velocity = Acceleration * dt //A = VelocityChange / TimeChange. thus, V = AT

		self.Velocity = self.Velocity - Velocity

		/*
		if self.LastSpark && self.LastSpark < CurTime() then
			self.LastSpark = CurTime() + 0.01

			self.SparkEffect:SetOrigin( self:GetPos() )
			local newangles = self:GetAngles() + Angle( 15, 0, 0 )
			self.SparkEffect:SetNormal( -newangles:Forward() + Vector( 0, 0, 0.5) )
			util.Effect("ManhackSparks", self.SparkEffect )
		end
		*/
	end
end

function ENT:ChainThink()
	if self:GetCurrentNode():GetType() == COASTER_NODE_CHAINS then
		local CurNode = self:GetCurrentNode()

		if self.Velocity < CurNode.ChainSpeed then
			self.Velocity = CurNode.ChainSpeed //- 0.5
		end
		
	end
end

function ENT:HomeStationThink(dt)
	if self:GetCurrentNode():GetType() == COASTER_NODE_HOME then

		if self.HomeStage == 0 then //Moving to center
			if self.Percent < 0.4 || self.Percent > 0.6 then
				if self.Percent > 0.6 then
					self.Velocity = -4
				else
					self.Velocity = 4
				end
			else
				self.HomeStage = 1
				self.TimeToStart = CurTime() + self.StopTime
			end

		elseif self.HomeStage == 1 then //Stopped and waiting
			self.Velocity = 0

			if self.TimeToStart && self.TimeToStart < CurTime() then 
				self.HomeStage = 2 
			end
		else //Moving to next node
			if self.Velocity < 5 then self.Velocity = 5 end
		end

	else
		self.HomeStage = 0
	end
end

//Get the angle at a specific point on a track
function ENT:AngleAt(i, perc )
	local Vec1 = self.Controller.CatmullRom:Point( i, perc )
	local Vec2 = self.Controller.CatmullRom:Point( i, perc + 0.03 )

	local AngVec = Vector(0,0,0)

	AngVec = Vec1 - Vec2

	return AngVec:Normalize():Angle()
end

//Get the multiplier for the current spline (to make things smooth )
function ENT:GetMultiplier(i, perc)
	local Dist = 1
	local Vec1 = self.Controller.CatmullRom:Point( i, perc )
	local Vec2 = self.Controller.CatmullRom:Point( i, perc + 0.03 )

	Dist = Vec1:Distance( Vec2 )
	return 1 / Dist 
end

//Adjust cart mass based on it's current occupants
function ENT:UpdateMass()
	if self.Occupants && #self.Occupants > 0 then
		local mass = self.InitialMass
		for k, v in pairs( self.Occupants ) do
			if IsValid( v ) then mass = mass + v:GetPhysicsObject():GetMass() end
		end
		print( "New mass: " .. tostring( mass ))
		self:GetPhysicsObject():SetMass( mass )
	else
		self:GetPhysicsObject():SetMass( self.InitialMass )
	end
end

//Get the current spline we are on from a percent along a specific segment
function ENT:GetCurrentSpline(i, perc)
	local STEPS = 10//(self.Controller.CatmullRom.STEPS
	
	local spline = (i - 2 ) * STEPS + (STEPS * perc)
	//print(math.floor(spline))
	return math.Clamp( math.floor(spline), 1, #self.Controller.CatmullRom.Spline)
end

//This sounds like something we might want
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

//Remove the velocity if the player grabs it with the physgun
//TODO: be able to move/fling cart with the physgun
function ENT:PhysicsUpdate(physobj)
	if self:IsPlayerHolding() then
		self.Velocity = 0
	end
end

//Explode if they are off the rails
function ENT:PhysicsCollide(data, physobj)
	if data.Speed > 60 && self.IsOffDaRailz && ( (IsValid(data.HitEntity) && data.HitEntity:GetClass() != "coaster_cart" ) || !IsValid( data.HitEntity )) then
	
		local explosion = ents.Create ("env_explosion")
		explosion:SetPos(self:GetPos())
		explosion:SetOwner( self )
		explosion:Spawn()
		explosion:SetKeyValue( "iMagnitude", 220)
		explosion:Fire("Explode", 0, 0)
		explosion:EmitSound( "weapon_AWP.Single", 400, 400 ) 
	
		local debris = EffectData()
			debris:SetOrigin( self:GetPos() )
		util.Effect( "coaster_cart_debris", debris )

		self:Remove()
	end
	//print( !self.OffDaRailz )
	//print( ( IsValid(data.HitEntity) && data.HitEntity:GetClass() == "coaster_cart" ) )
	//print( data.HitEntity.Velocity )
	if !self.IsOffDaRailz && ( IsValid(data.HitEntity) && data.HitEntity:GetClass() == "coaster_cart" ) && data.HitEntity.Velocity then
		local ourmass = physobj:GetMass()
		local theirmass = data.HitEntity:GetPhysicsObject():GetMass()

		local SelfVelocity = ( self.Restitution*theirmass*( data.HitEntity.Velocity - self.Velocity ) + (ourmass*self.Velocity) + (theirmass*data.HitEntity.Velocity ) ) / ( ourmass + theirmass )
		local TheirVelocity = ( self.Restitution*ourmass*(self.Velocity - data.HitEntity.Velocity) + (ourmass*self.Velocity) + (theirmass*data.HitEntity.Velocity)) / ( ourmass + theirmass )

		//local SelfVelocity = ( self.Velocity * ( ourmass - theirmass ) + ( 2 *theirmass*data.HitEntity.Velocity)) / (ourmass + theirmass)
		//local TheirVelocity = ( -data.HitEntity.Velocity * ( theirmass - ourmass ) + ( 2*ourmass*self.Velocity )) / ( ourmass + theirmass)

		//local SelfVelocity = ( self.Velocity * (ourmass - theirmass ) ) / ( ourmass + theirmass )
		//local TheirVelocity = ( 2 * ourmass * self.Velocity)

		//local SelfVelocity = ( ( ourmass - (self.Restitution*theirmass)) / (ourmass + theirmass) ) * self.Velocity 
		//local TheirVelocity = ( ( ( 1 + self.Restitution) * ourmass ) / (ourmass + theirmass ) ) * self.Velocity

		//print( TheirVelocity )

		//self.Velocity = SelfVelocity
		//data.HitEntity.Velocity = TheirVelocity
		//print("heyo guess what")
		//print( self.Velocity )

	end
end

function ENT:Think()
	//Make it so changing the actual gravity affects the coaster
	local Grav = GetConVar( "sv_gravity" ):GetInt()
	self.GRAVITY = (Grav / 61.2244) or 9.8

	self:NextThink( CurTime() + 1 ) //This doesn't need to happen constantly
	return true
end

function ENT:OnRemove()

end

if SERVER then
	concommand.Add("coaster_fuckyou", function( ply, cmd, args ) 
		Coaster_do_bad_things = args[1]=="1"
		print("Unknown command \"coaster_fuckyou\"")
	end )
end
