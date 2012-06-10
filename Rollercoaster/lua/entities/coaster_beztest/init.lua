AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )


ENT.WasBeingHeld	= false //Was the entity being held just now (by the physgun)

function ENT:SpawnFunction( ply, tr )

	if !tr.Hit then return end
	
	local SpawnPos = tr.HitPos + tr.HitNormal * 16
	local ent = ents.Create( self.ClassName )
	ent:SetPos( SpawnPos )
	ent:SetAngles( Angle( 0, 0, 0) )
	ent:Spawn()
	ent:Activate()

	return ent

end

concommand.Add("coaster_editnode", function( ply, cmd, args )
	local ctrl = nil
	for _, v in pairs( ents.FindByClass( "coaster_beztest")) do
		if v:IsController() then
			ctrl = v
			break
		end
	end

	if IsValid( ctrl ) then ctrl:EditControlNode(tonumber( args[1] ) or 1) end
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
	
	local num = 0
	local ent = nil
	local ctrl = nil
	for k, v in pairs( ents.FindByClass( self:GetClass() )) do
		if IsValid( v ) && v != self then
			if v.Number > num then
				num = v.Number
				ent = v
			end

			if v.Number == 1 then
				ctrl = v
			end
		end
	end
	if !IsValid( ent ) then
		self.Number = 1
		self:AddTrackNode( self )
	else
		self.Number = num + 1
		if IsValid( ctrl ) then
			ctrl:AddTrackNode( self )
		end
	end

	if !self:IsController() then return end

	self.Bezier = CoasterManager.BezierController:New( self )
	self.Bezier:Reset()

	//self:SetNWBool("IsCoasterController", self:IsController() )
end

function ENT:GetNumNodes()
	return #self.Nodes or 0
end

//Called by the control nodes to notify they moved
function ENT:ControlNodeUpdate( node )
	local ctrl = self:GetController()

	if node == ctrl.Control1 then
		local dist = ctrl.Control2:GetPos():Distance( self:GetPos() )
		local ang = self:GetPos() - ctrl.Control1:GetPos()
		ang:Normalize()

		local pos = self:GetPos() + (ang * dist)
		ctrl.Control2:SetPos( pos )

		local ct1, ct2 = self:GetControls()
		self:SetControls( ct1, pos )
	elseif node == ctrl.Control2 then
		local dist = ctrl.Control1:GetPos():Distance( self:GetPos() )
		local ang = self:GetPos() - ctrl.Control2:GetPos()
		ang:Normalize()

		local pos = self:GetPos() + (ang * dist)
		ctrl.Control1:SetPos( pos )

		local ct1, ct2 = self:GetControls()
		self:SetControls( pos, ct1)
	end

end

function ENT:EditControlNode( node_index )
	for _, v in pairs( ents.FindByClass("coaster_controlnode")) do
		if IsValid( v ) then 
			if v:GetMainNode() == self.Nodes[ node_index ] then
				v:Remove()
			end

			if !IsValid( v:GetMainNode() ) then v:Remove() end
		end
	end
	local ct1, ct2 = self:GetControls()
	if ct1 == Vector( 0, 0, 0 ) then ct1 = nil end
	if ct2 == Vector( 0, 0, 0 ) then ct2 = nil end

	local ctrl1 = ents.Create("coaster_controlnode")
	ctrl1:SetPos( ct1 or self.Nodes[ node_index ]:GetPos() - Vector( 200, 0, 0 ) )
	ctrl1:Spawn()
	ctrl1:Activate()
	ctrl1:SetMainNode( self.Nodes[ node_index ])

	local ctrl2 = ents.Create("coaster_controlnode")
	ctrl2:SetPos( ct2 or self.Nodes[ node_index ]:GetPos() + Vector( 200, 0, 0 ) )
	ctrl2:Spawn()
	ctrl2:Activate()
	ctrl2:SetMainNode( self.Nodes[ node_index ])

	self.Control1 = ctrl1
	self.Control2 = ctrl2

	timer.Simple( 0.21, function()
		umsg.Start( "Coaster_editnode")
			umsg.Entity( self )
			umsg.Entity( ctrl1 )
			umsg.Entity( ctrl2 )
			umsg.Short(node_index)
		umsg.End()
	end )
end

function ENT:AddTrackNode( ent )
	if IsValid( ent ) && ent:GetClass() == self:GetClass() then
		local index = table.insert( self.Nodes, ent )
		

		local prevNode = self.Nodes[index-1]
		if IsValid(prevNode) then
			prevNode:SetNextNode(ent)	
			
			//Set the new node to the old 'unconnected' node's position
			//if !prevNode:IsController() && prevNode != self:GetFirstNode() then
			//	prevNode:SetModel( self.Model )
			//	prevNode:SetPos( ent:GetPos() )
			//ent:SetModel( "models/props_junk/PopCan01a.mdl" )
			//end
		else
			self:SetController( true )
		end
		
		//Create the second node if we are the very first created node(controller)
		//if !IsValid( self:GetFirstNode() ) && ent:IsController() then
		//	print( ent:GetPos() )
		//	local node = CoasterManager.CreateNode( ent.CoasterID, ent:GetPos(), ent:GetAngles(), ent:HasChains() )

			//node:Invalidate()
		//end
		
		//Create the 4th node if we are the 3rd node created (2nd click)
		//local firstNode = self:GetFirstNode()
		//if IsValid( firstNode ) && firstNode:GetNextNode() == ent then
		//	local node = CoasterManager.CreateNode( ent.CoasterID, ent:GetPos(), ent:GetAngles(), ent:HasChains() )
			//node:Invalidate()
		//	node:SetModel( "models/props_junk/PopCan01a.mdl" )
		//end
		
		// First node is the node after the controller
		if !IsValid(self:GetFirstNode()) and !ent:IsController() then
			self:SetFirstNode(ent)
			//self:SetPos( ent:GetPos() )
		end

		timer.Simple( 0.21, function() //Delay so the client can initialize too before we send the usermessage
			umsg.Start("Bezier_AddNode")
				umsg.Short( self:EntIndex() )
				//umsg.Short( ent:EntIndex() )
			umsg.End()
		end )
	end
end

function ENT:GetController()
	local ctrl = nil

	for k, v in pairs( ents.FindByClass(self:GetClass())) do
		if v.Number == 1 then return v end
	end

	return nil
end
