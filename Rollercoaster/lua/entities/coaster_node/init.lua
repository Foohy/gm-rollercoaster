AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "mesh_beams.lua")
include( "shared.lua" )


ENT.Spacing = 30 //How many units away each wood track is

ENT.TrackEnts		= {} //List of all the track entities
ENT.Nodes 			= {} //List of nodes (assuming we are the controller)
ENT.CoasterID 		= -1 //The rollercoaster ID this node is associated with
ENT.WasBeingHeld	= false //Was the entity being held just now (by the physgun)
ENT.ChainSpeed		= 5

concommand.Add("coaster_forcerefresh", function(ply, cmd, args)
	for _, v in pairs( ents.FindByClass("coaster_node") ) do
		if IsValid( v ) && v:IsController() then 
			v:UpdateServerSpline()
			//PrintTable( v.Nodes )
		end
	end
end )

function ENT:Initialize()
	self.Nodes = {} //List of nodes (assuming we are the controller)
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

	//self:SetNWBool("IsCoasterController", self:IsController() )


end

function ENT:GetNumNodes()
	return #self.Nodes or 0
end

function ENT:AddTrackNode( ent )
	if IsValid( ent ) && ent:GetClass() == self:GetClass() then
		local index = table.insert( self.Nodes, ent )
		

		local prevNode = self.Nodes[index-1]
		if IsValid(prevNode) then
			prevNode:SetNextNode(ent)	
			
			//Set the new node to the old 'unconnected' node's position
			if !prevNode:IsController() && prevNode != self:GetFirstNode() then
				prevNode:SetModel( self.Model )
				prevNode:SetPos( ent:GetPos() )
				ent:SetModel( "models/props_junk/PopCan01a.mdl" )
			end
		end
		
		//Create the second node if we are the very first created node(controller)
		if !IsValid( self:GetFirstNode() ) && ent:IsController() then
			print( ent:GetPos() )
			local node = CoasterManager.CreateNode( ent.CoasterID, ent:GetPos(), ent:GetAngles(), ent:HasChains() )

			//node:Invalidate()
		end
		
		//Create the 4th node if we are the 3rd node created (2nd click)
		local firstNode = self:GetFirstNode()
		if IsValid( firstNode ) && firstNode:GetNextNode() == ent then
			local node = CoasterManager.CreateNode( ent.CoasterID, ent:GetPos(), ent:GetAngles(), ent:HasChains() )
			//node:Invalidate()
			node:SetModel( "models/props_junk/PopCan01a.mdl" )
		end
		
		// First node is the node after the controller
		if !IsValid(self:GetFirstNode()) and !ent:IsController() then
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
		
		//Create two more nodes for the second track to create a fully working track
		//if IsValid( self:GetFirstNode() ) && !IsValid( self:GetFirstNode():GetNextNode() ) then
		//	local endNode = CoasterManager.CreateNode( self.CoasterID, self:GetPos(), self:GetAngles(), self:HasChains() )
		//	endNode:SetModel( "models/props_junk/PopCan01a.mdl" )
		//end
		
		//if !IsValid( self:GetFirstNode() ) then
		//	CoasterManager.CreateNode( self.CoasterID, self:GetPos(), self:GetAngles(), self:HasChains() )
		//end

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
	end
end

//TODO: Fix this up
function ENT:PhysicsUpdate(physobj)
	if !self:IsPlayerHolding() then
		physobj:Sleep()
		physobj:EnableMotion( false )
		
		if self.WasBeingHeld then
			self.WasBeingHeld = false

			umsg.Start("Coaster_RefreshTrack")
				umsg.Entity( self:GetController() )
			umsg.End()

			//timer.Simple(2.5, function() self:SetupTrack() end )//WHAT THE FUCK IS WRONG WITH YOU
			RunConsoleCommand("coaster_forcerefresh")
		end
	else
		if self.WasBeingHeld == false then
			self.WasBeingHeld = true
			self:Invalidate() //invalidate ourselves, we moved
		end
		
		//This is a bit nasty... it sets the appropriate nodes to their proper position to keep a looped track looped
		if self.Looped || Rollercoasters[ self.CoasterID ].Looped then
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
end

//Invalidate the node on the client
function ENT:Invalidate()
	umsg.Start("Coaster_nodeinvalidate")
		umsg.Entity( self:GetController() )
		umsg.Entity( self )
	umsg.End()
end

//Return the main controller in charge of me, the node
function ENT:GetController()
	return Rollercoasters[self.CoasterID]
end

function ENT:SetTrain(ply, cartnum, powered)
	if #self.Nodes < 4 then
		umsg.Start("Coaster_CartFailed", ply)
			umsg.Char( 4 - #self.Nodes )
		umsg.End()
		return
	end
	self.Train 			= ents.Create( "coaster_cart")
	self.Train.NumCarts = cartnum
	self.Train.Powered 	= powered
	self.Train.CoasterID = self.CoasterID
	self.Train.Controller = self
	
	self.Train:SetPos(self:GetPos())
	self.Train:Spawn()
	self.Train:Activate()
	self.Train:SetAngles( Angle( 0, 180, 0 ) )
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
	if self:IsController() then
		for _, v in pairs( self.Nodes ) do
			if IsValid( v ) then 
				v.SafeDeleted = true 
				v:Remove() 
			end
		end
		
		self:ClearTrains() 
	else
		//This massive bit of ugly code removes unvalid nodes from the tables and stuff
		if !self.SafeDeleted then
			local cont = Rollercoasters[self.CoasterID]
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
			
			//Update the track
			self:UpdateServerSpline() 
		end
	end
end

