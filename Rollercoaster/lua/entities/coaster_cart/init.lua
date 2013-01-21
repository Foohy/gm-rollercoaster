AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

//General Cart Stuff
ENT.CoasterID 	= -1 //Unique ID of the coaster this cart is attached to
ENT.NumCarts 	= 1 //Length of the train of carts
ENT.Powered 	= false //If powered, never slow beyond a certain speed. Basically silent always-on chains
ENT.MinSpeed 	= 0 //minimum speed to travel at. 0 means dont touch shit.
ENT.Controller 	= nil //Controller
ENT.IsOffDaRailz  = false 
ENT.Occupants = {} //List of people sitting in this seat
ENT.MaxOBBSize = 400 //Maximum size a model can be for the cart, in any dimension

//Barfing/Screaming
ENT.BarfThinkTime = 0

//Physics stuff
ENT.GRAVITY = 9.81
ENT.InitialMass = 100
ENT.WheelFriction = 0.04 //Coeffecient for mechanical friction (NOT drag) (no idea what the actual mew is for a rollercoaster, ~wild guesses~)
ENT.Restitution = 0.9
ENT.Velocity = 4 //Starting velocity
ENT.LastVelocity = 4 //Velocity of the previous frame
ENT.Multiplier = 0.99999 //Multiplier to set the same speed per node segment
ENT.IsOffDaRailz = false
ENT.Rotation = 0
ENT.RotationSpeed = 0

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
ENT.PhysShadowControl.secondstoarrive  = 0.00000001 //SMALL NUMBERS
ENT.PhysShadowControl.pos              = Vector(0, 0, 0)
ENT.PhysShadowControl.angle            = Angle(0, 0, 0)
ENT.PhysShadowControl.maxspeed         = 1000000000000
ENT.PhysShadowControl.maxangular       = 1000000
ENT.PhysShadowControl.maxspeeddamp     = 10000
ENT.PhysShadowControl.maxangulardamp   = 1000000
ENT.PhysShadowControl.dampfactor       = 1
ENT.PhysShadowControl.teleportdistance = 0
ENT.PhysShadowControl.deltatime        = deltatime

ENT.Timer = math.huge

function ENT:Initialize()
	//Check if it's some ungodly large prop
	if self:Size() >= self.MaxOBBSize then
		self:SetModel("models/XQM/coastertrain2seat.mdl")
		self.Model = "models/XQM/coastertrain2seat.mdl"

		print("Someone tried to spawn a massive model!")
	else
		self:SetModel( self.Model )	
	end

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	
	//Spawn at the beginning second node, where the curve starts
	self.CurSegment = 2
	self.Percent = 0
	
	//Start simulating our own physics
	self:StartMotionController()
	
	//more random guesses
	if IsValid( self:GetPhysicsObject() ) then
		self:GetPhysicsObject():SetMass( self.InitialMass )
		self:GetPhysicsObject():Wake()
	else
		self:Remove() //no stop frick off
	end

	self.SparkEffect = EffectData()
	self.SparkEffect:SetEntity( self )

	if self:GetModel() == "models/props_c17/playground_carousel01.mdl" || Coaster_do_bad_things then
		self.Carousel = true
	end

	if self:GetModel() == "models/sunabouzu/sonic_the_carthog.mdl" then
		self.Timer = CurTime() + 24.00
		self.Enabled = true
	end

	if self.IsDummy then
		self:SetNoDraw( true )
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:SetNotSolid( true )
	end
	
	//QUICKFIX BECAUSE IT'S BREAKING DUE TO BROKEN SHOULDCOLLIDE
	self:SetCustomCollisionCheck(true)

	self.Occupants = {}
end

//Pop
function ENT:OffDaRailz(safemode)
	if self.IsOffDaRailz then return end
	self.IsOffDaRailz = true
	
	self:SetCurrentNode( Entity( 1 ) ) //Basically set the entity to something improper to show we have no current node
	
	if !self.IsDummy then self:EmitSound("coaster_offdarailz.wav", 100, 100 ) end
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:GetPhysicsObject():SetMass( 500 ) //If this is wrong I don't wanna be right
	if self.CartTable != nil then
		if self.IsDummy then
			if self.CartTable != nil then
				for z, x in pairs(self.CartTable) do
					if IsValid( x ) then
						x:OffDaRailz(true)
					end
				end
			end
			if self.CartTable != nil then //must be separate from the above loop stuff
				for z, x in pairs(self.CartTable) do
					if IsValid( x ) then
						table.remove(self.CartTable,z)
						RollercoasterUpdateCartTable(self.CartTable)
					end
				end
			end
			self:Remove()
		end
		if self.CartTable != nil then
			for k, v in pairs(self.CartTable) do
				if v == self then
					if safemode != true then
						table.remove(self.CartTable,k)
						RollercoasterUpdateCartTable(self.CartTable)
					end
				end
			end
			if #self.CartTable == 1 then 
				self.CartTable[1]:Remove() 
			end
			self.CartTable = nil
		end
	end
end


local function UCT(ctable,x)
	//this supplements the working of RollercoasterUpdateCartTable()
	//print("checking for lead")
	for k, v in pairs(ctable) do
		if !IsValid( v ) then continue end

		if x != v then
			if v.Velocity >= 0 then
				if v.CurSegment < x.CurSegment then
					//x is not the lead
					//print("returned false 1a")
					return false
				elseif v.CurSegment == x.CurSegment then
					if v.Percent < x.Percent then
						//print("returned false 1b")
						return false
					elseif v.Percent == x.Percent then
						//print("returned nil 1")
						return nil
					end
				end
			else
				if v.CurSegment > x.CurSegment then
					//print("returned false 2a")
					return false
				elseif v.CurSegment == x.CurSegment then
					if v.Percent > x.Percent then
						//print("returned false 2b")
						return false
					elseif v.Percent == x.Percent then
						//print("returned nil 2")
						return nil
					end
				end
			end
		end
	end

	return true
end

function RollercoasterUpdateCartTable(ctable)
	//determine the leader of this cart table in here
	//call this function whenever anything happens that might change the cart setup on the track
	//this updates cart.IsTableLead for every cart in the table, for use in ENT:PhysicsSimulate()
	if ctable == nil then return nil end //alarm for debugging
	for k, v in pairs(ctable) do
		//print("check a")
		v.IsTableLead = UCT(ctable,v)
		//if v.IsTableLead == nil then return nil end //alarm for debugging
	end
end

local function CalcAverageCartFriction(ctable,dt)
	if ctable == nil then return nil end if dt == nil then return nil end
	local total = 0
	for k, v in pairs(ctable) do
		if !IsValid( v ) then continue end
		//Specific exception if they want to have 1 cart (no need for all this silly business)
		if #ctable == 1 then
			return v:CalcFrictionalForce(v.CurSegment,v.Percent,dt)
		end

		if k > 1 then
			total = total + v:CalcFrictionalForce(v.CurSegment,v.Percent,dt)
		end
	end

	return (total/(table.Count(ctable)-1))
end

local function CalcAverageCartSlopeVelocity(ctable,dt)
	if ctable == nil then return nil end if dt == nil then return nil end
	local total = 0
	for k, v in pairs(ctable) do
		if !IsValid( v ) then continue end
		//Specific exception if they want to have 1 cart (no need for all this silly business)
		if #ctable == 1 then
			return v:CalcChangeInVelocity(v.CurSegment,v.Percent,dt)
		end
		if k > 1 then
			total = total + v:CalcChangeInVelocity(v.CurSegment,v.Percent,dt)
		end
	end
	return (total/(table.Count(ctable)-1))
end

local function NoCartHoldOrFreeze(ctable)
	local notheld = true
	for k, v in pairs(ctable) do
		if IsValid(v) && v:IsPlayerHolding() then
			notheld = false
			return notheld
		end
		if IsValid(v) && !v:GetPhysicsObject():IsMotionEnabled() then
			notheld = false
			return notheld
		end
	end
	return notheld
end

function ENT:DATPATUpdate()
	//Percent Across Track Update (also gets total track distance progress, DAT)
	//local nwt = #Rollercoasters[self.CoasterID].Nodes-2 //total nodes with track, excluding #1. 
	//NOT the number of total nodes with track, but something representing the total nodes to
	//call on by segment number that have track.
	
	local disttrav = 0
	//print("0="..self.CurSegment)
	//print("1="..Rollercoasters[self.CoasterID])
	//print("2="..Rollercoasters[self.CoasterID].Nodes[self.CurSegment])
	local curseglength = Rollercoasters[self.CoasterID].Nodes[self.CurSegment].SegLength
	if !curseglength then return end

	for i = 2, self.CurSegment-1 do
		disttrav = disttrav + curseglength
	end
	local cursegdisttrav = curseglength*self.Percent
	disttrav = disttrav + cursegdisttrav
	self.DAT = disttrav //Distance Across Track
	self.PAT = self.DAT/Rollercoasters[self.CoasterID].TotalTrackLength
end

//Calculate our movement along the curve
function ENT:PhysicsSimulate(phys, deltatime)
	if self.IsOffDaRailz or self.CartTable == nil then return SIM_NOTHING end

	local CurPos  = self:GetPos()
	local CurNode = self.Controller.Nodes[self.CurSegment]
	local NextNode = self.Controller.Nodes[ self.CurSegment + 1]
	if !IsValid( CurNode ) || !IsValid( NextNode ) then self.CurSegment = #Rollercoasters[self.CoasterID].Nodes end
	self:SetCurrentNode( CurNode )

	//Set the previous velocity
	self.LastVelocity = self.Velocity

	//Forces that are always being applied to the cart
	if self.CartTable[1] == self then
		if NoCartHoldOrFreeze(self.CartTable) then
			local friction = CalcAverageCartFriction(self.CartTable,deltatime)
			local slopelev = CalcAverageCartSlopeVelocity(self.CartTable,deltatime)

			for k, v in pairs(self.CartTable) do
				if !IsValid( v ) then continue end
				v.Velocity = v.Velocity - friction
				v.Velocity = v.Velocity - slopelev
			end

			//Node specific forces
			self:ChainThink()
			self:SpeedupThink(deltatime)
			self:BreakThink(deltatime)
		else
			for k, v in pairs(self.CartTable) do
				if !IsValid( v ) then continue end
				v.Velocity = 0
			end
		end
	end


	self:MinSpeedThink()
	self:HomeStationThink(deltatime)


	self.PhysShadowControl.pos = self.Controller.CatmullRom:Point(self.CurSegment, self.Percent)
	
	//Each node has a certain multiplier so the cart travel at a constant speed throughout the track
	self.Multiplier = self:GetMultiplier(self.CurSegment, self.Percent)

	//average this into the cart trains as well
	if CurTime() >= self.Timer && self.Enabled then
		for k, v in pairs(self.CartTable) do
			v.Velocity = v.Velocity + (2/table.Count(self.CartTable))
		end
		
		if self.LastSpark && self.LastSpark < CurTime() then
			self.LastSpark = CurTime() + 0.01

			self.SparkEffect:SetOrigin( self:GetPos() )
			local newangles = self:GetAngles() + Angle( 15, 0, 0 )
			self.SparkEffect:SetNormal( -newangles:Right() + Vector( 0, 0, 0.5) )
			util.Effect("ManhackSparks", self.SparkEffect )
		end

	end

	//Do some fancy effects
	if self:GetCurrentNode():GetType() == COASTER_NODE_SPEEDUP then
		if self.LastSpark && self.LastSpark < CurTime() then
			self.LastSpark = CurTime() + 0.08

			self.SparkEffect:SetOrigin( self:GetPos() )
			local newangles = self:GetAngles() + Angle( 15, 0, 0 )
			self.SparkEffect:SetNormal( -newangles:Forward() + Vector( 0, 0, 0.5) )
			util.Effect("ManhackSparks", self.SparkEffect )
		end
	end

	/*Check for collisions
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
	end*/

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
			//self:CorrectCartSpacing(1)
			
		end	
		self.Percent = 0
		self:CorrectCartSpacing(1)
		
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
			//self:CorrectCartSpacing(-1)
		end
		self.Percent = 1
		self:CorrectCartSpacing(-1)
		
	end

	//Update current and next nodes with the most up to date segment
	CurNode = self.Controller.Nodes[self.CurSegment]
	NextNode = self.Controller.Nodes[ self.CurSegment + 1]

	
	phys:Wake()

	//self.PhysShadowControl.angle = self:GetVelocity():Angle()
	local ang = self:AngleAt(self.CurSegment, self.Percent)
	
	//Change the roll depending on the track
	local Roll = 0
	if IsValid( CurNode ) && IsValid( NextNode ) then
		Roll = -Lerp( self.Percent, math.NormalizeAngle( CurNode:GetRoll() ), NextNode:GetRoll())	
	end
	
	//Set the roll for the current track peice
	ang:RotateAroundAxis( self:AngleAt(self.CurSegment, self.Percent):Forward(), Roll ) //BAM
	ang.r = -ang.r
	
	//Offsets
	ang.p = -ang.p
	ang.y = ang.y + 180

	if self:GetModel() == "models/sunabouzu/sonic_the_carthog.mdl" then
		ang:RotateAroundAxis( ang:Up(), -90 )
	end

	//If we are a carousel, SPIN
	if self.Carousel && !self.IsDummy then
		local FixedAngle = Angle( ang.p, ang.y, ang.r )
		local ang1 = self:AngleAt( self.CurSegment, self.Percent )
		local ang2 = self:AngleAt( self.CurSegment, self.Percent + 0.1 )
		local angDif = math.AngleDifference( ang1.y, ang2.y )
		local FakeFriction = 1.0003

		if self:GetCurrentNode():GetType() == COASTER_NODE_BRAKES || self:GetCurrentNode():GetType() == COASTER_NODE_HOME then
			FakeFriction = 1.04
		end
		//Make it so it doesnt rotate with the track
		FixedAngle:RotateAroundAxis( FixedAngle:Up(), -ang.y )

		self.RotationSpeed = ( self.RotationSpeed + ( angDif * self.Velocity * deltatime  ) ) / FakeFriction //Do-it-yourself friction
		self.RotationSpeed = math.Clamp( self.RotationSpeed, -1000, 1000 )

		//calculate how much we should rotate
		self.Rotation = ( self.Rotation + (self.RotationSpeed * deltatime) ) 

		self.Rotation = math.NormalizeAngle( self.Rotation )

		if ( Coaster_do_bad_things ) then
			FixedAngle:RotateAroundAxis( ang1:Up(), self.Rotation )
		else
			//Apply the rotation
			FixedAngle:RotateAroundAxis( FixedAngle:Up(), self.Rotation )
		end
		ang = FixedAngle
	else
		self.RotationSpeed = 0
	end

	self:BarfThink()
	self:DATPATUpdate()

	self.PhysShadowControl.angle = ang
	self.PhysShadowControl.pos = self.PhysShadowControl.pos + ang:Up() * 10


	self.PhysShadowControl.deltatime = deltatime	

	return phys:ComputeShadowControl(self.PhysShadowControl)
end

function ENT:CorrectCartSpacing(dir)
	if dir == nil then return end
	
	//before continuing, check that all carts are on the same segment
	local proceed = true
	for k, v in pairs(self.CartTable) do
		if proceed then
			if self.CartTable[1].CurSegment != self.CartTable[k].CurSegment then
				proceed = false
			end
		end
	end
	
	if proceed then
		if dir == 1 then
			if self == self.CartTable[1] then
				//print("train back, passing, all carts on segment")
				self:CCS()
			end
		elseif dir == -1 then
			if self == self.CartTable[table.Count(self.CartTable)] then
				//print("train front, passing, all carts on segment")
				self:CCS()
			end
		end
	end
end

function ENT:CCS()
	//supplements the use of ENT:CorrectCartSpacing()
	local prevpercent = 0
	for i = 1, table.Count(self.CartTable) do
		if self.CartTable[i].CartTable[i-1] != nil && self.CartTable[i].CartTable[i-1].CurSegment == self.CurSegment then 
			prevpercent = self.CartTable[i].CartTable[i-1].Percent
			if i != 1 then 
				local targperc = prevpercent + (self:GetMultiplier(self.CurSegment,prevpercent)*(self:Size("x")/32))
				if targperc > 0 and targperc < 1 then self.CartTable[i].Percent = targperc else self.CartTable[i].Percent = self.CartTable[i].Percent end
			else
				self.CartTable[i].Percent = self.CartTable[i].Percent
			end
		else
			self.CartTable[i].Percent = self.CartTable[i].Percent
		end
	end
end

function ENT:BarfThink( deltatime )
	if CurTime() < self.BarfThinkTime then return end
	self.BarfThinkTime = CurTime() + 0.10

	if self.Occupants && #self.Occupants > 0 then
		for k, v in pairs( self.Occupants ) do	
			local rotate = math.Clamp( math.Round( 25000 - (math.abs(self.RotationSpeed*67)) ),42, 25000 )

			if math.random( 1, rotate ) == 42 then
				v:Puke()
			end
		end
	end
end

function ENT:PlayerLeave( ply )
	if math.random(1,42) != 42 then return end 

	timer.Simple( math.Rand(2,5), function() 
		ply:Puke()
	end	)

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
	
	//Apply a backwards force in both directions
	if self.Velocity < 0 then
		Velocity = -Velocity
	end

	//Prevent floating point numbers from fucking shit up
	if self:GetPhysicsObject():GetEnergy() < 0.05 then
		return 0
	end
	/*
	if math.abs(self.Velocity) < 0.05 then
		return 0
	end
	*/
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
	if self.MinSpeed > 0 && self.Velocity < self.MinSpeed && !self:TrainOnType(COASTER_NODE_HOME) then
		self.Velocity = self.MinSpeed
	end
end

//Get if any carts are on a specific node type
function ENT:TrainOnType( ENUM_TYPE )
	for k, v in pairs(self.CartTable) do
		local node = v:GetCurrentNode()
		if IsValid( node ) then 
			if node:GetType() == ENUM_TYPE then return true end
		end
	end

	return false
end

function ENT:SpeedupThink(dt)
	local OnSpeedup = false
	local SpeedupForce = 0
	local MaxSpeed = 0
	local NumOnSpeedup = 0
	local TotalCarts = 0

	if self.CartTable[1] == self then
		for k, v in pairs(self.CartTable) do
			if k > 1 || #self.CartTable == 1 then
				local node = v:GetCurrentNode()
				if IsValid( node ) && node:GetType() == COASTER_NODE_SPEEDUP then
					OnSpeedup = true
					SpeedupForce = node.SpeedupForce
					MaxSpeed = node.MaxSpeed
					NumOnSpeedup = NumOnSpeedup + 1
					TotalCarts = TotalCarts + 1
				end
			end
		end
	end

	if OnSpeedup && self.Velocity < MaxSpeed  then //We can get away with using our velocity because all the carts are going the same speed anyway
		local Acceleration = ( SpeedupForce / self:GetPhysicsObject():GetMass() ) * (NumOnSpeedup / (TotalCarts) ) //F = MA. thus, (F / M) = A
		local Velocity = Acceleration * dt //A = VelocityChange / TimeChange. thus, V = AT
		local newVelocity = (self.Velocity + Velocity )

		for k, v in pairs(self.CartTable) do
			v.Velocity = newVelocity
		end
	end

end

function ENT:BreakThink(dt)
	local OnBreaks = false
	local BreakForce = 0
	local MinSpeed = 0
	local NumOnBreaks = 0
	local TotalCarts = 0

	if self.CartTable[1] == self then
		for k, v in pairs(self.CartTable) do
			if k > 1 || #self.CartTable == 1 then
				local node = v:GetCurrentNode()
				if IsValid( node ) && node:GetType() == COASTER_NODE_BRAKES then
					OnBreaks = true
					BreakForce = node.BreakForce
					MinSpeed = node.BreakSpeed
					NumOnBreaks = NumOnBreaks + 1
					TotalCarts = TotalCarts + 1
				end
			end
		end
	end

	if OnBreaks && self.Velocity > MinSpeed  then //We can get away with using our velocity because all the carts are going the same speed anyway
		local Acceleration = ( BreakForce / self:GetPhysicsObject():GetMass() ) * (NumOnBreaks / (TotalCarts) ) //F = MA. thus, (F / M) = A
		local Velocity = Acceleration * dt //A = VelocityChange / TimeChange. thus, V = AT
		local newVelocity = (self.Velocity - Velocity )

		for k, v in pairs(self.CartTable) do
			v.Velocity = newVelocity
		end
	elseif OnBreaks then
		//Go at at least as slow as the breaks (no slower)
		for k, v in pairs(self.CartTable) do
			v.Velocity = MinSpeed
		end
	end

end

/*
//Basically the exact opposite of speedup
function ENT:BreakThink(dt)
	if self:GetCurrentNode():GetType() == COASTER_NODE_BRAKES && self.Velocity > self.BreakSpeed then
		local Acceleration = self.BreakForce / self:GetPhysicsObject():GetMass() //F = MA. thus, (F / M) = A
		local Velocity = Acceleration * dt //A = VelocityChange / TimeChange. thus, V = AT

		self.Velocity = self.Velocity - Velocity
	end
end
*/

function ENT:ChainThink()
	local OnChain = false
	local ChainSpeed = 0

	if self.CartTable[1] == self then
		for k, v in pairs(self.CartTable) do

			local node = v:GetCurrentNode()
			if IsValid( node ) && node.GetType && node:GetType() == COASTER_NODE_CHAINS then
				OnChain = true
				ChainSpeed = node.ChainSpeed
				break
			end
		end
	end

	if OnChain && self.Velocity < ChainSpeed  then //We can get away with using our velocity because all the carts are going the same speed anyway
		for k, v in pairs(self.CartTable) do
			v.Velocity = ChainSpeed
		end
	end

end

function ENT:HomeStationThink(dt)
	local OnHome = false
	local HomeWaitTime = 0

	if self.CartTable[1] == self then
		for k, v in pairs(self.CartTable) do

			local node = v:GetCurrentNode()
			if IsValid( node ) && node:GetType() == COASTER_NODE_HOME then
				OnHome = true
				HomeWaitTime = node.StopTime
				break
			end
		end
	end


	if OnHome then

		if self.HomeStage == 0 then //Moving to center
			if self.CartTable[#self.CartTable].Percent < 0.9 then //The head car is actually the very last car
				for k, v in pairs(self.CartTable) do
					v.Velocity = 4
				end
			else
				self.HomeStage = 1
				self.TimeToStart = CurTime() + self.StopTime
			end

		elseif self.HomeStage == 1 then //Stopped and waiting
			for k, v in pairs(self.CartTable) do
				v.Velocity = 0
			end

			if self.TimeToStart && self.TimeToStart < CurTime() then 
				self.HomeStage = 2 
			end
		else //Moving to next node

			if self.Velocity < 5 then
				for k, v in pairs(self.CartTable) do
					v.Velocity = 5
				end
			end
		end

	else
		self.HomeStage = 0
	end
end

//Get the angle at a specific point on a track
function ENT:AngleAt(i, perc )
	local Vec1 = self.Controller.CatmullRom:Point( i, perc - 0.015)
	local Vec2 = self.Controller.CatmullRom:Point( i, perc + 0.015 )

	local AngVec = Vector(0,0,0)

	AngVec = Vec1 - Vec2

	return AngVec:GetNormal():Angle()
end

//Get the multiplier for the current spline (to make things smooth )
function ENT:GetMultiplier(i, perc)
	local Dist = 1
	local Vec1 = self.Controller.CatmullRom:Point( i, perc - 0.015) // + 0
	local Vec2 = self.Controller.CatmullRom:Point( i, perc + 0.015 ) // + 0.03


	Dist = Vec1:Distance( Vec2 )
	return 1 / Dist 
end

//Adjust cart mass based on it's current occupants
//Disabled for now. Really isn't very realistic
/*
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
*/

//Get the current spline we are on from a percent along a specific segment
function ENT:GetCurrentSpline(i, perc)
	local STEPS = 10//(self.Controller.CatmullRom.STEPS
	
	local spline = (i - 2 ) * STEPS + (STEPS * perc)
	//print(math.floor(spline))
	return math.Clamp( math.floor(spline), 1, #self.Controller.CatmullRom.Spline)
end

//find the largest dimension of the entity, giving preference to x, then y, over z, unless otherwise specified
function ENT:Size(axis)
	local min = self:OBBMins()
	local max = self:OBBMaxs()
	local xabs = math.abs(max.x-min.x)
	local yabs = math.abs(max.y-min.y)
	local zabs = math.abs(max.z-min.z)
	local size = 0

	//Return specific axis length if specified
	if axis then
		if string.lower(axis) == "x" then return xabs end
		if string.lower(axis) == "y"  then return yabs end
		if string.lower(axis) == "z"  then return zabs end
	end

	if xabs >= yabs then
		if xabs >= zabs then
			size = xabs
		else
			size = zabs
		end
	else
		if yabs >= zabs then
			size = yabs
		else
			size = zabs
		end
	end

	return size
end

//This sounds like something we might want
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

//Remove the velocity if the player grabs it with the physgun
//TODO: be able to move/fling cart with the physgun
function ENT:PhysicsUpdate(physobj)
	if self:IsPlayerHolding() or !self:GetPhysicsObject():IsMotionEnabled() then
		self.Velocity = 0
		if self.CartTable != nil then
			for k, v in pairs(self.CartTable) do
				if self != v then
					v.Velocity = 0
				end
			end
		end
	end
end

function ENT:CartExplode()
	if GetConVarNumber("coaster_cart_explosive_damage") == 0 then return end //wow fuck you

	local explosion = ents.Create ("env_explosion")
	explosion:SetPos(self:GetPos())
	explosion:SetOwner( self )
	explosion:Spawn()
	explosion:SetKeyValue( "iMagnitude", 220)
	explosion:Fire("Explode", 0, 0)

	if !self.Enabled then
		/*
		local debris = EffectData()
		debris:SetOrigin( self:GetPos() )
		util.Effect( "coaster_cart_debris", debris )
		*/
		self:Remove()
	end
end

//Explode if they are off the rails
function ENT:PhysicsCollide(data, physobj)
	//If we collided with another track, attach ourselves to it.
	if IsValid( data.HitEntity ) && (data.HitEntity:GetClass() == "coaster_physmesh" || data.HitEntity:GetClass() == "coaster_node") then
		if data.DeltaTime < 0.3 then return end //this function tends to be spammed a bit, so let it have a cooldown period.

		local NewID = -1
		local Segment = -1
		local Percent = 0
		local controller = nil

		if data.HitEntity:GetClass() == "coaster_physmesh" then
			Segment 	= data.HitEntity.Segment
			NewID 		= data.HitEntity:GetController():GetCoasterID()
			controller 	= data.HitEntity:GetController()
		else
			Segment 	= data.HitEntity.Segment
			NewID 		= data.HitEntity:GetCoasterID()
			controller 	= data.HitEntity:GetController()
		end

		//estimate the percent along the track we're joining we are
		local distClosest = math.huge
		for i=1, controller.CatmullRom.STEPS do
			local splinePos = controller.CatmullRom.Spline[ ((Segment - 2)*controller.CatmullRom.STEPS) + i]

			if self:GetPos():Distance( splinePos ) < distClosest then
				distClosest = self:GetPos():Distance( splinePos )
				Percent = i / controller.CatmullRom.STEPS
			end
		end

		self.CoasterID 	= NewID
		self.CurSegment = Segment
		self.Percent 	= Percent
		self.Controller = controller

		//The mass is changed when the carts fly off for realism, set the mass back
		self:GetPhysicsObject():SetMass( self.InitialMass )

		//If the yaw is in this range, the cart is boarding the track going the opposite direction
		local trackang = self:AngleAt(self.CurSegment, self.Percent)
		local curang = data.OurOldVelocity:Angle()
		local yawDif = trackang.y - curang.y 
		if yawDif > 270 || yawDif < 90 then 
			self.Velocity = data.OurOldVelocity:Length() / -25
		else
			self.Velocity = data.OurOldVelocity:Length() / 25
		end

		//Recreate the cart table
		self.CartTable = {}
		table.insert( self.CartTable, self )

		//We are now back on da railz
		self.IsOffDaRailz = false

		//Do some nice effects
		self:EmitSound("Metal.SawbladeStick")

		local effectdata = EffectData()
			effectdata:SetOrigin( self:GetPos() )
			effectdata:SetNormal( self:GetAngles():Forward() )
			effectdata:SetMagnitude( 8 )
			effectdata:SetScale( 1 )
			effectdata:SetRadius( 16 )
		util.Effect( "Sparks", effectdata )
		

		return
	end


	if data.Speed > 100 && self.IsOffDaRailz && ( (IsValid(data.HitEntity) && data.HitEntity:GetClass() != "coaster_cart" ) || !IsValid( data.HitEntity )) then
		
		self:CartExplode()
		
	end

	//the many attempts at proper elastic and inelastic collisions between carts.
	//not feasible because of the catmull rom spline algorithm 
	//print( !self.OffDaRailz )
	//print( ( IsValid(data.HitEntity) && data.HitEntity:GetClass() == "coaster_cart" ) )
	//print( data.HitEntity.Velocity )
	/*if !self.IsOffDaRailz && ( IsValid(data.HitEntity) && data.HitEntity:GetClass() == "coaster_cart" ) && data.HitEntity.Velocity then
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

	end*/
	if !self.IsOffDaRailz&&IsValid(data.HitEntity)&&data.HitEntity:GetClass()=="coaster_cart" then
		if self.CartTable != data.HitEntity.CartTable then
			if math.random(1,2) == 1 then
				self:OffDaRailz()
			else
				self:CartExplode()
			end
		end
	end
end


function ENT:Think()
	//Make it so changing the actual gravity affects the coaster
	local Grav = GetConVar( "sv_gravity" ):GetInt()
	self.GRAVITY = (Grav / 61.2244) or 9.81

	self:NextThink( CurTime() + 1 ) //This doesn't need to happen constantly
	return true
end

function ENT:OnRemove()

	if self.CartTable != nil then
		if self.IsDummy then
			if self.CartTable != nil then
				for z, x in pairs(self.CartTable) do
					x:OffDaRailz(true)
				end
			end
			if self.CartTable != nil then //must be separate from the above loop stuff
				for z, x in pairs(self.CartTable) do
					table.remove(self.CartTable,z)
					RollercoasterUpdateCartTable(self.CartTable)
				end
			end
			self:Remove()
		end
		if self.CartTable != nil then
			for k, v in pairs(self.CartTable) do
				if v == self then
					table.remove(self.CartTable,k)
					RollercoasterUpdateCartTable(self.CartTable)
				end
			end
			self.CartTable = nil
		end
	end
end

concommand.Add("coaster_fuckyou", function( ply, cmd, args ) 
	if !IsValid( ply ) || !ply:IsSuperAdmin() then return end

	Coaster_do_bad_things = args[1]=="1"

	for k, v in pairs( ents.FindByClass("coaster_cart") ) do
		v.Carousel = true
	end

	print("Unknown command \"coaster_fuckyou\"")
end )

concommand.Add("coaster_cart_click", function( ply, cmd, args )
	if !IsValid( ply ) || !ply:InVehicle() then return end
	local pod = ply:GetVehicle()
	if !IsValid( pod ) || !IsValid( pod:GetParent() ) || pod:GetParent():GetClass() != "coaster_cart" then return end

	//Mouse1 = scream
	if tonumber(args[1]) == 1 then
		if !ply.ScreamCooldown || ply.ScreamCooldown < CurTime() || !GetConVar("coaster_cart_cooldown"):GetBool() then 
			ply.ScreamCooldown = CurTime() + 5
			ply:Scream()
		end

	//Mouse2 = barf
	else 
		if !ply.BarfCooldown || ply.BarfCooldown < CurTime() || !GetConVar("coaster_cart_cooldown"):GetBool() then 
			ply.BarfCooldown = CurTime() + 30 
			ply:Puke()
		end
	end

end )


