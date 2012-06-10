AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

ENT.CoasterID 	= -1 //Unique ID of the coaster this cart is attached to
ENT.NumCarts 	= 1 //Length of the train of carts
ENT.Powered 	= false //If powered, never slow beyond a certain speed. Basically silent always-on chains
ENT.Controller 	= nil //Controller
ENT.OnChains 	= false //Currently on a track node with chains?
ENT.IsOffDaRailz  = false 

ENT.WheelFriction = 0.04 //Coeffecient for mechanical friction (NOT drag) (no idea what the actual mew is for a rollercoaster, ~wild guesses~)
ENT.Velocity = 4 //Starting velocity
ENT.Multiplier = 1 //Multiplier to set the same speed per node segment

//Credits to LPine for code on how to use a shadow controller for something like this
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
		self:GetPhysicsObject():SetMass( 150 )
		self:GetPhysicsObject():Wake()
	end

end

//Pop
function ENT:OffDaRailz()
	self.IsOffDaRailz = true
	
	umsg.Start("Coaster_OffDaRailz")
		umsg.Entity( self )
	umsg.End()
	
	self:EmitSound("coaster_offdarailz.wav", 100, 100 )
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
end

//Calculate our movement along the curve
function ENT:PhysicsSimulate(phys, deltatime)
	if self.IsOffDaRailz then return SIM_NOTHING end

	local CurPos  = self:GetPos()
	local CurNode = self.Controller.Nodes[self.CurSegment]
	local NextNode = self.Controller.Nodes[ self.CurSegment + 1]
	//self.Controller.CatmullRom:CalcPerc() -- Can't be done in the parameter call or a side effect doesn't manifest properly
	self.Velocity = self.Velocity - self:CalcFrictionalForce(self.CurSegment, self.Percent, deltatime)
	self.Velocity = self.Velocity + ((math.NormalizeAngle(self:AngleAt(self.CurSegment, self.Percent).p )) / -phys:GetMass() ) * deltatime * 30
	//self.CoastSound:ChangePitch(math.Clamp( math.abs(self.Velocity), 1, 240 ) )
	if CurNode:HasChains() then
		if self.Velocity < CurNode.ChainSpeed then
			self.Velocity = CurNode.ChainSpeed //- 0.5
		end
		
		if !self.OnChains then
			self.OnChains = true
			umsg.Start("ChainStart")
				umsg.Entity( self )
			umsg.End()
		end
		
	else
		if self.OnChains then
			self.OnChains = false
			umsg.Start("ChainStop")
				umsg.Entity( self )
			umsg.End()
		end
	end
	
	self.PhysShadowControl.pos = self.Controller.CatmullRom:Point(self.CurSegment, self.Percent)
	
	//Each node has a certain multiplier so the cart travel at a constant speed throughout the track
	self.Multiplier = self:GetMultiplier(self.CurSegment, self.Percent)

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
	//local Roll = Lerp( self.Percent, CurNode:GetAngles().r,NextNode:GetAngles().r ) //Lerp the roll from the last segments roll to the next segments roll
	local Roll = Lerp( self.Percent, CurNode:GetRoll(), NextNode:GetRoll())	
	
	//Set the roll for the current track peice
	ang:RotateAroundAxis( self:AngleAt(self.CurSegment, self.Percent):Forward(), Roll ) //BAM
	ang.r = -ang.r
	
	//Offsets
	ang.p = -ang.p
	ang.y = ang.y + 180
	
	self.PhysShadowControl.angle = ang

	self.PhysShadowControl.pos = self.PhysShadowControl.pos + ang:Up() * 10

	


	/*
	if false then //CurNode.BankOnTurn then -- :/
		self.LastPos = self.LastPos or CurPos
			
		local NextPosNrml = self:WorldToLocal(self.PhysShadowControl.pos):Normalize()
		local Multi = (math.abs(NextPosNrml.y) / NextPosNrml.y) * -1
			
		local a = (CurPos - self.LastPos):Normalize()
		local b = (self.PhysShadowControl.pos - CurPos):Normalize()
		local dot = math.Clamp((1 - (a:Dot(b) )) * CurNode.DeltaBankMulti * 50, -1, 1) * 90 * CurNode.DeltaBankMax
			
		self.LastPos = CurPos
			
		self.PhysShadowControl.angle.r = dot * 1.0
	end
	*/
	self.PhysShadowControl.deltatime = deltatime	
	return phys:ComputeShadowControl(self.PhysShadowControl)
end

//Calculate the frictional force experienced on the cart's wheels
//this uses PHYSICS
function ENT:CalcFrictionalForce(i, perc, dt)
	local Force = 0
	local Velocity = 0

	local mass = self:GetPhysicsObject():GetMass()

	local Ang = self:AngleAt( i, perc )

	Force = self.WheelFriction * ( math.cos( math.rad(Ang.p) ) * mass * 9.8 ) //frictional force = mew*normal of weight
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
end

function ENT:Think()

end

function ENT:OnRemove()

end

