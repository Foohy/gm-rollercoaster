AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "mesh_beams.lua")
include( "shared.lua" )
include( "mesh_physics.lua")


ENT.TrackEnts		= {} //List of all the track entities
ENT.Nodes 			= {} //List of nodes (assuming we are the controller)
ENT.CoasterID 		= -1 //The rollercoaster ID this node is associated with
ENT.WasBeingHeld	= false //Was the entity being held just now (by the physgun)
ENT.PhysMeshes		= {}

//Chain
ENT.ChainSpeed		= 5

//Speedup node options/variables
ENT.SpeedupForce = 1400 //Force of which to accelerate the car
ENT.MaxSpeed = 3600 //The maximum speed to which accelerate the car

//Home station options/variables
ENT.HomeStage = 0
ENT.StopTime = 5 //Time to stop and wait for people to leave/board

//Break node options/variables
ENT.BreakForce = 1400 //Force of which to deccelerate the car
ENT.BreakSpeed = 3 //The minimum speed of the car when in break zone

function ENT:Initialize()
	self.Nodes = {} //List of nodes (assuming we are the controller)
	self.PhysMeshes = {}
	self:SetModel( self.Model )	

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	
	//self:DrawShadow(false)
	
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)

	local phys = self:GetPhysicsObject()

	if phys:IsValid() then
		phys:Sleep()
	end
	
	self.CatmullRom = CoasterManager.Controller:New( self )
	self.CatmullRom:Reset()

	self:SetLooped( false ) //Default to false

end

function ENT:GetNumNodes()
	return #self.Nodes or 0
end

function ENT:CheckForInvalidNodes()
	if !self.Nodes or #self.Nodes < 1 then return end

	for k, v in pairs( self.Nodes ) do
		if !IsValid( v ) then table.remove( self.Nodes, k ) end
	end

end

function ENT:AddNodeSimple( ent, ply ) //For use when being spawned by a file
	if IsValid( ent ) && ent:GetClass() == self:GetClass() then
		local index = table.insert( self.Nodes, ent )

		if IsValid( self.Nodes[ index - 1] ) then
			self.Nodes[index - 1]:SetNextNode( ent )
		end

		// First node is the node after the controller
		if !IsValid(self:GetFirstNode()) and !ent:IsController() then
			self:SetFirstNode(ent)
		end
	end
end

function ENT:AddTrackNode( ent, ply )
	if IsValid( ent ) && ent:GetClass() == self:GetClass() then
		local index = table.insert( self.Nodes, ent )
		local FirstNode = self:GetFirstNode()

		local prevNode = self.Nodes[index-1]
		if IsValid(prevNode) then
			prevNode:SetNextNode(ent)	
			
			//Set the new node to the old 'unconnected' node's position
			if !prevNode:IsController() && prevNode != FirstNode then
				prevNode:SetModel( self.Model )
				prevNode:SetPos( ent:GetPos() )
				ent:SetModel( "models/props_junk/PopCan01a.mdl" )
			end

			//Add our undo stuff
			if IsValid( ply ) && index > 4 then
				undo.Create("Coaster Node")
					undo.AddEntity( prevNode )
					undo.SetPlayer( ply )
					undo.SetCustomUndoText("Undone Track Node")
				undo.Finish()
			end

		end
		
		//Create the second node if we are the very first created node(controller)
		if ( !IsValid( FirstNode ) || FirstNode:EntIndex() == 1 ) && ent:IsController() then
			print( ent:GetPos() )
			local node = CoasterManager.CreateNode( ent.CoasterID, ent:GetPos(), ent:GetAngles(), ent:GetType(), ply )

			undo.Create("Rollercoaster")
				undo.AddEntity( ent )
				undo.AddEntity( node )
				undo.SetPlayer( ply )
				undo.SetCustomUndoText("Undone Rollercoaster")
			undo.Finish()
			//node:Invalidate()
		end
		
		//Create the 4th node if we are the 3rd node created (2nd click)
		if IsValid( FirstNode ) && FirstNode:EntIndex() != 1 && FirstNode:GetNextNode() == ent then
			local node = CoasterManager.CreateNode( ent.CoasterID, ent:GetPos(), ent:GetAngles(), ent:GetType(), ply )
			
			undo.Create("Coaster Node")
				undo.AddEntity( ent )
				undo.AddEntity( node )
				undo.SetPlayer( ply )
				undo.SetCustomUndoText("Undone Rollercoaster")
			undo.Finish()

			node:SetModel( "models/props_junk/PopCan01a.mdl" )
		end
		
		// First node is the node after the controller
		if ( !IsValid(FirstNode ) || FirstNode:EntIndex() == 1 ) and !ent:IsController() then
			self:SetFirstNode(ent)
			self:SetPos( ent:GetPos() )
		end


		self:UpdateServerSpline()

		timer.Simple( 0.21, function() //Delay so the client can initialize too before we send the usermessage
			umsg.Start("Coaster_AddNode")
				umsg.Short( self:EntIndex() )
				//umsg.Short( ent:EntIndex() )
			umsg.End()
		end )

	end
end


function ENT:UpdateServerSpline()
	local controller = Rollercoasters[ self.CoasterID ]

	controller.CatmullRom:Reset()
	local amt = 1
	for i=1, #controller.Nodes do
		if IsValid( controller.Nodes[i] ) then
			controller.CatmullRom:AddPointAngle( amt, controller.Nodes[i]:GetPos(), controller.Nodes[i]:GetAngles(), 1.0 )
			amt = amt + 1
		end
	end
	
	if #controller.CatmullRom.PointsList > 3 then
		controller.CatmullRom:CalcEntireSpline()
		controller:BuildPhysicsMesh()

		//if self:IsController() then
		//	local node = self.Nodes[3]
			//controller:UpdateTrackLength()
		//end
	end
end

//How does ENT:PhysicsFromMesh work?
function ENT:BuildPhysicsMesh()
	local Vertices = {} //Create an array that will hold an array of vertices (This is to split up the model)
	local Meshes = {} 
	local Radius = 10
	local modelCount = 1 

	Cylinder.Start( Radius, 2 ) //We're starting up making a beam of cylinders

	local LastAngle = Angle( 0, 0, 0 )
	local ThisAngle = Angle( 0, 0, 0 )

	local ThisPos = Vector( 0, 0, 0 )
	local NextPos = Vector( 0, 0, 0 )
	for i = 1, #self.CatmullRom.Spline do
		ThisPos = self.CatmullRom.Spline[i]
		NextPos = self.CatmullRom.Spline[i+1]

		if i==#self.CatmullRom.Spline then
			NextPos = self.CatmullRom.PointsList[#self.CatmullRom.PointsList]
		end
		local ThisAngleVector = ThisPos - NextPos
		ThisAngle = ThisAngleVector:Angle()

		ThisAngle:RotateAroundAxis( ThisAngleVector:Angle():Right(), 90 )
		ThisAngle:RotateAroundAxis( ThisAngleVector:Angle():Up(), 270 )

		if i==1 then LastAngle = ThisAngle end

		Cylinder.AddBeam(ThisPos, LastAngle, NextPos, ThisAngle, Radius )

		if #Cylinder.Vertices > 50000 then// some arbitrary limit to split up the verts into seperate meshes

			Vertices[modelCount] = Cylinder.Vertices
			modelCount = modelCount + 1

			Cylinder.Vertices = {}
			Cylinder.TriCount = 1
		end

		LastAngle = ThisAngle
	end

	local Remaining = Cylinder.EndBeam()

	//Doesn't give "Degenerate Triangle" error, but _doesn't actually work_
	local tmpTable = {}
	tmpTable[1] = {}
	tmpTable[1].pos = self:GetPos() + Vector( 0, -5, 50 )
	tmpTable[2] = {}
	tmpTable[2].pos = self:GetPos() + Vector( -50, -5, 0 )
	tmpTable[3] = {}
	tmpTable[3].pos = self:GetPos() + Vector( -50, 5, 0 )

	Vertices[modelCount] = Remaining
	self:GetPhysicsObject():Wake()
	self:PhysicsFromMesh( Vertices[1] ) //THIS MOTHERFUCKER

	//self:PhysicsFromMesh( tmpTable ) //Verticices[i]
	//for i=1, #Vertices do
	//	if #Vertices[i] > 2 then
	//		//Meshes[i] = NewMesh()
	//		print( #Vertices, #Vertices[i] )
	//		self:PhysicsFromMesh( Vertices[i] ) //Technically, this'll fuck up if we ever have multiple models. TODO: Figure this out.
	//	end
	//end
end

function ENT:PhysicsUpdate(physobj)
	if !self:IsPlayerHolding() then
		physobj:Sleep()
		physobj:EnableMotion( false )
		
		if self.WasBeingHeld then
			self.WasBeingHeld = false

			umsg.Start("Coaster_RefreshTrack")
				umsg.Entity( self:GetController() )
			umsg.End()

			local controller = Rollercoasters[ self.CoasterID ]

			if IsValid( controller ) then
				controller:UpdateServerSpline()
			end
		end
	else
		if self.WasBeingHeld == false then
			self.WasBeingHeld = true
			self:Invalidate() //invalidate ourselves, we moved
		end
		
		self:UpdateMagicPositions()
		
	end
end

//This is a bit nasty... it sets the appropriate nodes to their proper position to keep a looped track looped
//I wasn't being very creative for a function name
function ENT:UpdateMagicPositions()
	if self:Looped() || Rollercoasters[ self.CoasterID ]:Looped() then
		local controller = Rollercoasters[ self.CoasterID ]
		
		if controller.Nodes[ #controller.Nodes - 2] == self then
			controller:SetPos( self:GetPos() )
		elseif self:IsController() && IsValid( controller.Nodes[ #controller.Nodes - 2 ] ) then
			controller.Nodes[ #controller.Nodes - 2 ]:SetPos( self:GetPos() )
		elseif controller:GetFirstNode() == self then
			controller.Nodes[ #controller.Nodes - 1 ]:SetPos( self:GetPos() )
		elseif controller.Nodes[ #controller.Nodes - 1 ] == self then
			controller:GetFirstNode():SetPos( controller.Nodes[ #controller.Nodes - 1 ]:GetPos() )
		elseif controller.Nodes[ #controller.Nodes ] == self then
			controller.Nodes[ 3 ]:SetPos( self:GetPos() )
		elseif controller.Nodes[ 3 ] == self then
			controller.Nodes[ #controller.Nodes ]:SetPos( self:GetPos() )
		end
	else //If it isn't looped, just set the controller/end node to a place to hide
		local controller = Rollercoasters[ self.CoasterID ]
		
		if self == controller:GetFirstNode() then
			controller:SetPos( self:GetPos() )
		elseif self == controller.Nodes[ #controller.Nodes - 1 ] && IsValid( controller.Nodes[#controller.Nodes] ) then //If we are grabbing the last connected node, set the last unconnected node's position to it
			controller.Nodes[ #controller.Nodes]:SetPos( self:GetPos() )
		end

	end

end

//Invalidate the node on the client
function ENT:Invalidate(minimal)
	umsg.Start("Coaster_nodeinvalidate")
		umsg.Entity( self:GetController() )
		umsg.Entity( self )
		umsg.Bool( minimal )
	umsg.End()
end

function ENT:UpdateTrackLength()
	//update length()
	//update length for other appropriate nodes too
	//print("invalidating")
	local controller = Rollercoasters[self.CoasterID]
	if !IsValid( controller ) or !IsValid( self ) then /*print("returning1")*/ return end
	if #controller.Nodes < 1 then /*print("returning2")*/ return end
	
	controller.TotalTrackLength = 0
	for k, v in pairs(controller.Nodes) do
		if k > 1 && k < #controller.Nodes-1 then
			v:GetSegmentLength()
			if v.SegLength != nil then
				controller.TotalTrackLength = controller.TotalTrackLength+v.SegLength
			else /*print("NIL")*/ end
		end
	end
	//print("track length: "..controller.TotalTrackLength)
end

function ENT:GetSegmentLength()
	
	local segment = nil
	for k, v in pairs(Rollercoasters[self.CoasterID].Nodes) do
		if v == self then segment = k end
	end

	//if not self:IsController() then print("fail1") return end
	//print("segment: "..segment)
	//print("otherthing: "..#Rollercoasters[self.CoasterID].CatmullRom.PointsList)
	if not (segment > 1 && (#Rollercoasters[self.CoasterID].CatmullRom.PointsList > segment )) then /*print("fail2")*/ return end
	if Rollercoasters[self.CoasterID].CatmullRom.Spline == nil or #Rollercoasters[self.CoasterID].CatmullRom.Spline < 1 then /*print("fail3")*/ return end


	local node = (segment - 2) * Rollercoasters[self.CoasterID].CatmullRom.STEPS
	local Dist = 0
	
	if Rollercoasters[self.CoasterID].CatmullRom.Spline[node + 1] == nil then /*print("fail4")*/ return end
	if Rollercoasters[self.CoasterID].CatmullRom.PointsList[segment] == nil then /*print("fail5")*/ return end

	for i = 1, (Rollercoasters[self.CoasterID].CatmullRom.STEPS) do
		if i==1 then
			Dist = Dist + Rollercoasters[self.CoasterID].CatmullRom.Spline[node + 1]:Distance( Rollercoasters[self.CoasterID].CatmullRom.PointsList[segment] ) 
		else
			Dist = Dist + Rollercoasters[self.CoasterID].CatmullRom.Spline[node + i]:Distance( Rollercoasters[self.CoasterID].CatmullRom.Spline[node + i - 1] ) 
		end
	end

	Dist = Dist + Rollercoasters[self.CoasterID].CatmullRom.PointsList[segment + 1]:Distance( Rollercoasters[self.CoasterID].CatmullRom.Spline[ node + Rollercoasters[self.CoasterID].CatmullRom.STEPS ] )

	//print( "foohy segment"..segment.." dist"..Dist )
	self.SegLength = Dist
end

//Return the controller in charge of this node, which is also a node
function ENT:GetController()
	return Rollercoasters[self.CoasterID]
end

function ENT:SetTrain(ply, model, cartnum)
	if #self.Nodes < 4 then
		umsg.Start("Coaster_CartFailed", ply)
			umsg.Char( 4 - #self.Nodes )
		umsg.End()
		return
	end

	if RCCartGroups == nil then RCCartGroups = 1 end

	if !_G["CartTable_" .. RCCartGroups] then
		_G["CartTable_" .. RCCartGroups] = {}
	end
	local cartgroup = _G["CartTable_" .. RCCartGroups]
	RCCartGroups = RCCartGroups + 1

	local Segment = 2
	local Multiplier = 1
	local Position = Vector( 0, 0, 0 )
	local Percent = 0
	local createdCarts = 1
	local Offset = 1

	local Train = {}
	while Percent < 1 do
		if createdCarts > cartnum then 
			RollercoasterUpdateCartTable(cartgroup)
			return Train
		end

		Position = self.CatmullRom:Point(Segment, Percent)
		Multiplier = self:GetMultiplier(Segment, Percent)

		//Create a dummy cart for bletotum's code for fixing up cart spacing
		if createdCarts == 1 then
			local dummy			= ents.Create( "coaster_cart")
			dummy.Model 		= model 
			dummy.NumCarts 		= cartnum
			dummy.CoasterID 	= self.CoasterID
			dummy.Controller 	= self
			dummy.IsDummy 		= true
			table.insert( Train, dummy )


			table.insert( cartgroup, dummy )
			dummy.CartTable = cartgroup
			
			dummy:Spawn()
			dummy:Activate()
			dummy.Percent = Percent
			dummy.CurSegment = Segment
			

			//Get the offset relative to the size of the cart
			Offset = dummy:Size("x") / 32

			//Move ourselves forward along the track
			Percent = Percent + ( Multiplier * Offset )

			Position = self.CatmullRom:Point(Segment, Percent)
			Multiplier = self:GetMultiplier(Segment, Percent)

		end

		//Create the cart
		local cart			= ents.Create( "coaster_cart")
		cart.Model 			= model 
		cart.NumCarts 		= cartnum
		cart.CoasterID 		= self.CoasterID
		cart.Controller 	= self
		cart.IsDummy		= false
		table.insert( Train, cart )


		table.insert( cartgroup, cart )
		cart.CartTable = cartgroup
		
		cart:Spawn()
		cart:Activate()
		
		//Set their percent and segment
		cart:SetPos( Position )
		cart.Percent = Percent
		cart.CurSegment = Segment


		//Get the offset relative to the size of the cart
		Offset = cart:Size("x") / 32

		//Move ourselves forward along the track
		Percent = Percent + ( Multiplier * Offset )

		createdCarts = createdCarts + 1
	end	
	RollercoasterUpdateCartTable(cartgroup)
	return Train
end

//Get the multiplier for the current spline (to make things smooth )
function ENT:GetMultiplier(i, perc)
	local Dist = 1
	local Vec1 = self.CatmullRom:Point( i, perc  )
	local Vec2 = self.CatmullRom:Point( i, perc + 0.03 )

	Dist = Vec1:Distance( Vec2 )
	return 1 / Dist 
end

function ENT:ClearTrains()
	if IsValid( self.Train ) then
		self.Train:Remove()
		self.Train = nil
	end
	
	//Remove any trains that may have been leftover
	for _, v in pairs( ents.FindByClass("coaster_cart") ) do
		if IsValid( v ) && v.CoasterID == self.CoasterID then
			v:Remove()
		end
	end
end

function ENT:Think()

end

function ENT:OnRemove()	
	local cont = Rollercoasters[self.CoasterID]

	if self:IsController() || (IsValid( cont ) && #cont.Nodes <= 4 )|| (IsValid( cont ) && self == cont.Nodes[2]) then // || (IsValid( cont ) && cont.Nodes[2] == self ) 
		for _, v in pairs( cont.Nodes ) do
			if IsValid( v ) then 
				v.SafeDeleted = true 
				v:Remove() 
			end
		end
		
		self:ClearTrains() 


		timer.Simple(0.25, function() 
			umsg.Start("Coaster_RefreshTrack")
				umsg.Entity( cont )
			umsg.End()
		end )
	elseif ( IsValid( cont ) && #cont.Nodes <= 4 ) && cont.Nodes[4] == self || cont.Nodes[3] == self then
		if cont.Nodes[4] == self then
			if IsValid( cont.Nodes[3] ) then
				cont.Nodes[3]:Remove() 
			end
		end

		if cont.Nodes[3] == self then
			if IsValid( cont.Nodes[4] ) then 
				cont.Nodes[4]:Remove() 
			end
		end


		timer.Simple(0.25, function() 
			umsg.Start("Coaster_RefreshTrack")
				umsg.Entity( cont )
			umsg.End()
		end )

	else
		//This massive bit of ugly code removes unvalid nodes from the tables and stuff
		if !self.SafeDeleted then

			if IsValid( cont ) then
				for k, v in pairs( cont.Nodes ) do
					if v == self then 
						if IsValid( cont.Nodes[ k - 1 ] ) && IsValid( self:GetNextNode() ) then //Get the node previous to this one
							cont.Nodes[ k - 1]:SetNextNode( self:GetNextNode() ) //Set our previous node to point to our next node
						end
						
						table.remove( cont.Nodes, k ) 
					end
				end
			end

			//Only send the umsg if one particular node was not safely deleted
			timer.Simple(0.25, function() 
				umsg.Start("Coaster_RefreshTrack")
					umsg.Entity( cont )
				umsg.End()
			end )
			
		end
	end

	if !self.SafeDeleted then
		//Update the track
		cont:CheckForInvalidNodes()
		cont:UpdateServerSpline() 
	end



	//Go through and make sure everything is in their proper place
	if !IsValid( cont ) || !cont.Nodes then return end

	for _, v in pairs( cont.Nodes ) do
		if IsValid( v ) then v:UpdateMagicPositions() end
	end
end

