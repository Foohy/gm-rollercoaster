AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "autorun/mesh_beams.lua")
include( "shared.lua" )

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
ENT.StopTime = 5 //Time to stop and wait for people to leave/board

//Break node options/variables
ENT.BreakForce = 1400 //Force of which to deccelerate the car
ENT.BreakSpeed = 3 //The minimum speed of the car when in break zone

-- If we're currently launching some carts forward
ENT.Launching = false 

ENT.NodeModel			= Model( "models/hunter/misc/sphere075x075.mdl" )

duplicator.RegisterEntityModifier("rollercoaster_node_order", function( ply, ent, data )
	duplicator.StoreEntityModifier( ent, "rollercoaster_node_order", data )
end )


function ENT:Initialize()
	self.Nodes = {} //List of nodes (assuming we are the controller)
	self.PhysMeshes = {}

	self:SetModel( self.NodeModel )	
	self:SetMaterial( self.Material )

	self:SetUseType( SIMPLE_USE )

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	self:SetCollisionGroup( COLLISION_GROUP_WORLD)

	self:DrawShadow( false )
	self.CartsOnMe={}

	local phys = self:GetPhysicsObject()

	if phys:IsValid() then
		phys:Sleep()
	end

	//Mainly to prevent duplicator spamming until I figure out how to correctly spawn nodes from garry's duplicator
	if !self:GetCoasterID() || self:GetCoasterID() == "" then self:Remove() end
	
	self.CatmullRom = CoasterManager.Controller:New( self )
	self.CatmullRom:Reset()

	local col = self:GetTrackColor()
	if col.x == 0 && col.y == 0 && col.z == 0 then
		self:SetTrackColor( Vector(1, 1, 1) )
	end

	self:NetworkVarNotify("TrackType", self.OnTrackTypeChanged )

end

function ENT:TriggerInput(n,v)
	if n=="Launch!" then
		self.Launching = v != 0 and #self.CartsOnMe > 0
	end
end

function ENT:OnTrackTypeChanged(varname, oldvalue, newvalue)
	local controller = self:GetController()

	if oldvalue == newvalue || !IsValid( controller ) || !istable( controller.Nodes ) then return end 

	for k, v in pairs( controller.Nodes ) do
		v.dt.TrackType = newvalue
	end

	controller:InvalidateTrack()
end

//Function to get if we are being driven with garry's new drive system
function ENT:IsBeingDriven()
	for _, v in pairs( player.GetAll() ) do
		if v:GetViewEntity() == self then return true end
	end

	return false
end

function ENT:SetOrder( num )
	local data = self.EntityMods && self.EntityMods["rollercoaster_node_order"] or {}
	data.Order = num 
	duplicator.StoreEntityModifier( self, "rollercoaster_node_order", data)
end

function ENT:GetOrder()
	return istable(self.EntityMods) && self.EntityMods["rollercoaster_node_order"] && self.EntityMods["rollercoaster_node_order"].Order or self.dt.Order or -1
end

function ENT:SetNumCoasterNodes( num )
	local data = self.EntityMods && self.EntityMods["rollercoaster_node_order"] or {}
	data.Total = num 
	duplicator.StoreEntityModifier( self, "rollercoaster_node_order", data)
end

function ENT:GetNumCoasterNodes()
	return istable(self.EntityMods) && self.EntityMods["rollercoaster_node_order"] && self.EntityMods["rollercoaster_node_order"].Total or self.dt.NumCoasterNodes or -1
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
		if !IsValid(self:GetFirstNode()) and !ent:GetIsController() then
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
			if !prevNode:GetIsController() && prevNode != FirstNode then
				prevNode:SetModel( self.NodeModel )
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
		if ( !IsValid( FirstNode ) || FirstNode:EntIndex() == 1 ) && ent:GetIsController() then
			local node = CoasterManager.CreateNode( ent:GetCoasterID(), ent:GetPos(), ent:GetAngles(), ent:GetNodeType(), ply, ent:GetRoll())

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
			local node = CoasterManager.CreateNode( ent:GetCoasterID(), ent:GetPos(), ent:GetAngles(), ent:GetNodeType(), ply, ent:GetRoll() )
			
			undo.Create("Coaster Node")
				undo.AddEntity( ent )
				undo.AddEntity( node )
				undo.SetPlayer( ply )
				undo.SetCustomUndoText("Undone Rollercoaster")
			undo.Finish()

			node:SetModel( "models/props_junk/PopCan01a.mdl" )
		end
		
		// First node is the node after the controller
		if ( !IsValid(FirstNode ) || FirstNode:EntIndex() == 1 ) and !ent:GetIsController() then
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
	local controller = Rollercoasters[ self:GetCoasterID() ]

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

		for k, v in pairs( controller.Nodes ) do
			if k > 1 && k < #controller.Nodes - 1 then
				v:BuildSegmentMesh()
			else
				if IsValid( v.PhysMesh ) then v.PhysMesh:Remove() end
			end
		end
		//controller:BuildPhysicsMesh()

		//if self:GetIsController() then
		//	local node = self.Nodes[3]
			//controller:UpdateTrackLength()
		//end
	end
end

concommand.Add("update_physmesh", function()
	for k, v in pairs( ents.FindByClass("coaster_node")) do
		if IsValid( v ) && v:GetIsController() then
			v:UpdateServerSpline()
		end
	end
end )

function ENT:Think()
	for k,v in pairs(self.CartsOnMe)do
		if !IsValid(v)then
			table.remove(self.CartsOnMe,k)
		end
	end
	if #self.CartsOnMe == 0 then
		self.Launching = false
	end
	if #self.CartsOnMe != self.LastCartsOnMe then
		self.LastCartsOnMe = #self.CartsOnMe
		if WireLib then Wire_TriggerOutput(self,"Cart On Track",math.min(#self.CartsOnMe,1)) end
	end
end

//Build the mesh for the specific segment
//This function is NOT controller only, call it on the segment you want to update the mesh on
function ENT:BuildSegmentMesh()
	local Segment = -1
	local controller = Rollercoasters[ self:GetCoasterID() ]

	//Find our proper segment
	if IsValid( controller ) && controller.Nodes && #controller.Nodes > 3 then
		for k, v in pairs( controller.Nodes ) do
			if v == self then Segment = k end
		end
	else
		return //get the fuck out
	end

	if Segment < 2 or Segment >= #controller.Nodes - 1 then 
		if IsValid( self.PhysMesh ) then
			self.PhysMesh:Remove()
		end
		return
	end

	if IsValid( self.PhysMesh ) then
		//Make sure it's information is up to date
		self.PhysMesh.Segment = Segment
		self.PhysMesh:SetController( controller )
	else
		//Create the physics mesh entity
		local physmesh = ents.Create("coaster_physmesh")
		physmesh:SetPos( self:GetPos() )
		physmesh:SetAngles( Angle( 0, 0, 0 ) )

		//Give the entity some nice information about it
		physmesh.Segment		= Segment

		//Spawn it and store it
		physmesh:Spawn()
		physmesh:SetController( controller )
		physmesh:Activate()

		self.PhysMesh = physmesh
	end

	//Build meshhhhhhhhes
	self.PhysMesh:BuildMesh()
end


function ENT:PhysicsUpdate(physobj)

	if !self:IsPlayerHolding() && !self:IsBeingDriven() then
		physobj:Sleep()
		physobj:EnableMotion( false )
		
		if self.WasBeingHeld then
			self.WasBeingHeld = false

			umsg.Start("Coaster_RefreshTrack")
				umsg.Entity( self:GetController() )
			umsg.End()

			local controller = Rollercoasters[ self:GetCoasterID() ]

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
	if !IsValid( Rollercoasters[ self:GetCoasterID() ] ) then return end 

	if self:GetLooped() || Rollercoasters[ self:GetCoasterID() ]:GetLooped() then
		local controller = Rollercoasters[ self:GetCoasterID() ]
		
		if controller.Nodes[ #controller.Nodes - 2] == self then
			controller:SetPos( self:GetPos() )
		elseif self:GetIsController() && IsValid( controller.Nodes[ #controller.Nodes - 2 ] ) then
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
		local controller = Rollercoasters[ self:GetCoasterID() ]
		
		if self == controller:GetFirstNode() then
			controller:SetPos( self:GetPos() )
		elseif self == controller.Nodes[ #controller.Nodes - 1 ] && IsValid( controller.Nodes[#controller.Nodes] ) then //If we are grabbing the last connected node, set the last unconnected node's position to it
			controller.Nodes[ #controller.Nodes]:SetPos( self:GetPos() )
		end

	end

end

//Hack. Update all of the child nodes to store their index in the node array
//This is so we can later reconstruct the track when loading from a save
function ENT:UpdateNodeOrders()
	for k, v in pairs( self.Nodes ) do
		v:SetOrder( k )
	end
end

//Invalidate the node on the client
function ENT:Invalidate(minimal)
	self:BuildSegmentMesh()

	umsg.Start("Coaster_nodeinvalidate")
		umsg.Entity( self:GetController() )
		umsg.Entity( self )
		umsg.Bool( minimal )
	umsg.End()
end

//Invalidate everything
function ENT:InvalidateTrack()
	umsg.Start("Coaster_invalidateall")
		umsg.Entity( self )
	umsg.End()
end

function ENT:UpdateTrackLength()
	//update length()
	//update length for other appropriate nodes too
	//print("invalidating")
	local controller = Rollercoasters[self:GetCoasterID()]
	if !IsValid( controller ) or !IsValid( self ) then return end
	if #controller.Nodes < 1 then return end
	
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
	local controller = nil
	local segment = nil
	for k, v in pairs(Rollercoasters[self:GetCoasterID()].Nodes) do
		if v == self then segment = k end
	end

	controller = Rollercoasters[ self:GetCoasterID() ]

	//if not self:GetIsController() then print("fail1") return end
	//print("segment: "..segment)
	//print("otherthing: "..#Rollercoasters[self:GetCoasterID()].CatmullRom.PointsList)
	if not (segment > 1 && (#controller.CatmullRom.PointsList > segment )) then /*print("fail2")*/ return end
	if controller.CatmullRom.Spline == nil or #controller.CatmullRom.Spline < 1 then /*print("fail3")*/ return end


	local node = (segment - 2) * controller.CatmullRom.STEPS
	local Dist = 0
	
	if controller.CatmullRom.Spline[node + 1] == nil then /*print("fail4")*/ return end
	if controller.CatmullRom.PointsList[segment] == nil then /*print("fail5")*/ return end

	for i = 1, (controller.CatmullRom.STEPS) do
		if i==1 then
			Dist = Dist + controller.CatmullRom.Spline[node + 1]:Distance( controller.CatmullRom.PointsList[segment] ) 
		else
			Dist = Dist + controller.CatmullRom.Spline[node + i]:Distance( controller.CatmullRom.Spline[node + i - 1] ) 
		end
	end

	Dist = Dist + controller.CatmullRom.PointsList[segment + 1]:Distance( controller.CatmullRom.Spline[ node + controller.CatmullRom.STEPS ] )

	self.SegLength = Dist
end

function ENT:AddTrain(ply, model, cartnum, segment)
	segment = segment or 2
	
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

	local Segment = segment
	local Multiplier = 1
	local Position = Vector( 0, 0, 0 )
	local Percent = 0
	local createdCarts = 1
	local Offset = 1

	local Train = {}
	while Percent < 1 do

		//Spawn only the specified amount of carts
		if createdCarts > cartnum then 
			RollercoasterUpdateCartTable(cartgroup)
			return Train
		end

		//Limit a player's maximum number of carts
		if !game.SinglePlayer() && IsValid( ply ) && ply:NumActiveCarts() >= GetConVarNumber("coaster_maxcarts") then
			ply:LimitHit("maxcarts")
			return Train
		end

		Position = self.CatmullRom:Point(Segment, Percent)
		Multiplier = self:GetMultiplier(Segment, Percent)

		//Create a dummy cart for bletotum's code for fixing up cart spacing
		if createdCarts == 1 && cartnum > 1 then //If we're only spawning 1 cart, we don't need a dummy cart.
			local dummy			= ents.Create( "coaster_cart")
			dummy.Model 		= model 
			dummy.NumCarts 		= cartnum
			dummy.CoasterID 	= self:GetCoasterID()
			dummy.Controller 	= self
			dummy.IsDummy 		= true
			dummy.Owner 		= ply
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
		cart.CoasterID 		= self:GetCoasterID()
		cart.Controller 	= self
		cart.IsDummy		= false
		cart.Owner 			= ply
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

//Function to simply store the first node
function ENT:GetFirstNode()
	return self.FirstNode
end

function ENT:SetFirstNode( node )
	self.FirstNode = node
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
		if IsValid( v ) && v.CoasterID == self:GetCoasterID() then
			v:Remove()
		end
	end
end

function ENT:Use(activator, caller)
	if IsValid(activator) then
		-- Find the closest cart, if one exists
		local closestDist = math.huge 
		local closestCart = nil
		for _, v in pairs( ents.FindByClass("coaster_cart") ) do
			local dist = IsValid( v) && v.CoasterID == self:GetCoasterID() && activator:GetPos():Distance( v:GetPos() ) or math.huge
			if dist < closestDist then
				closestDist = dist
				closestCart = v
			end
		end

		-- Check if we got a valid cart
		if IsValid( closestCart ) then
			-- Tell the seats module we want to enter the cart
			ForceEnterGivenCart( closestCart, activator, activator:GetPos() )
		end
	end
end

function ENT:OnRemove()	
	if !self:GetCoasterID() || self:GetCoasterID() == "" then return end

	local cont = Rollercoasters[self:GetCoasterID()]

	//if it is the controller, or there are less than 4 nodes, or this is the second node
	if self:GetIsController() then
		for _, v in pairs( self.Nodes ) do
			if IsValid( v ) then 
				v.SafeDeleted = true 
				v:Remove() 
			end
		end
		
		self:ClearTrains() 


		timer.Simple(0.25, function() 
			umsg.Start("Coaster_RefreshTrack")
				umsg.Entity( self )
			umsg.End()
		end )
	elseif (IsValid( cont ) && #cont.Nodes <= 4 )|| (IsValid( cont ) && self == cont.Nodes[2]) then // || (IsValid( cont ) && cont.Nodes[2] == self ) 
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
	//If there are less than 4 nodes and the 4th node is us OR we are the third node
	elseif ( IsValid( cont ) && #cont.Nodes <= 4 ) && cont.Nodes[4] == self /*|| cont.Nodes[3] == self*/ then
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
							self:GetNextNode():Invalidate( true ) //invalidate the node before the removed node to show it's out of date
							cont.Nodes[ k - 1]:Invalidate( true )
						end
						
						//If it's a looped track and we are either the last or very last node	
						if cont:GetLooped() && ( cont.Nodes[ #cont.Nodes ] == self || cont.Nodes[ #cont.Nodes - 1 ] == self ) then
							cont:SetLooped( false )
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

	if !self.SafeDeleted && IsValid( cont ) then
		//Update the track
		cont:CheckForInvalidNodes()
		cont:UpdateServerSpline() 
	end

	//Remove the physics mesh
	if IsValid( self.PhysMesh ) then self.PhysMesh:Remove() end

	//Go through and make sure everything is in their proper place
	if !IsValid( cont ) || !cont.Nodes then return end

	for _, v in pairs( cont.Nodes ) do
		if IsValid( v ) then v:UpdateMagicPositions() end
	end
end

