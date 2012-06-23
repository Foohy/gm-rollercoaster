AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "mesh_beams.lua")
include( "shared.lua" )
include( "mesh_physics.lua")


ENT.TrackEnts		= {} //List of all the track entities
ENT.Nodes 			= {} //List of nodes (assuming we are the controller)
ENT.CoasterID 		= -1 //The rollercoaster ID this node is associated with
ENT.WasBeingHeld	= false //Was the entity being held just now (by the physgun)
ENT.ChainSpeed		= 5
ENT.PhysMeshes		= {}

function ENT:Initialize()
	self.Nodes = {} //List of nodes (assuming we are the controller)
	self.PhysMeshes = {}
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
		//controller:BuildPhysicsMesh()
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

	//This _does_ give "Degenerate Triangle" error, but only for certain tris. I don't know why or which ones.
	Vertices[modelCount] = Remaining

	PrintTable( tmpTable )

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

//Return the main controller in charge of me, the node
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
	local train			= ents.Create( "coaster_cart")
	train.Model = model 
	//train:SetModel(model)
	train.NumCarts = cartnum
	train.Powered 	= powered
	train.CoasterID = self.CoasterID
	train.Controller = self
	
	train:SetPos(self:GetPos())
	train:Spawn()
	train:Activate()
	train:SetAngles( Angle( 0, 180, 0 ) )

	undo.Create("Coaster Train")
		undo.AddEntity( train )
		undo.SetPlayer( ply )
		undo.SetCustomUndoText("Undone Train")
	undo.Finish()


	return train
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

