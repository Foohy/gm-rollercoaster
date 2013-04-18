include( "shared.lua" )
include( "autorun/mesh_beams.lua")

ENT.PoleHeight = 512 //How tall, in source units, the coaster support poles are
ENT.BaseHeight = 38 //How tall, in source units, the coaster base is
ENT.BuildingMesh = false //Are we currently building a mesh? if so, don't draw them
ENT.TrackMeshes = {} //Store generated track meshes to render
ENT.WheelPositions = {} //Store the positions of where break and speedup wheels will be placed

ENT.SupportModel 		= nil
ENT.SupportModelStart 	= nil
ENT.SupportModelBase 	= nil
ENT.WheelModel 			= nil

ENT.LastGenTime = 0

ENT.Nodes = {}
ENT.CatmullRom = {}

local mat_chain = Material("sunabouzu/old_chain") //sunabouzu/old_chain
local mat_debug = Material("foohy/warning")




////////////////////////////////////////////////////////
//Recreate the shared functions on the client, since MANY times they'll be called before shared.lua is included
//This is incredibly annoying
////////////////////////////////////////////////////////

//Function to get if we are being driven with garry's new drive system
function ENT:IsBeingDriven()
	for _, v in pairs( player.GetAll() ) do
		if v:GetViewEntity() == self then return true end
	end

	return false
end

function ENT:SetIsController(bController)
	self.dt.IsController = bController
end

function ENT:IsController()
	return self.dt.IsController or false
end

function ENT:SetController( cont )
	self.dt.Controller = cont
end

function ENT:GetController()
	return self.dt.Controller
end

function ENT:SetRelativeRoll(bRelRoll)
	self.dt.RelativeRoll = bRelRoll
end

function ENT:RelativeRoll()
	return self.dt.RelativeRoll or false
end

function ENT:SetLooped(looped)
	self.dt.Looped = looped
end

function ENT:Looped()
	return self.dt.Looped or false
end

function ENT:SetNextNode(node)
	self.dt.NextNode = node
end

function ENT:GetNextNode()
	return self.dt.NextNode
end

function ENT:SetType(type)
	self.dt.Type = type
end

function ENT:GetType()
	return self.dt.Type or COASTER_NODE_NORMAL
end

function ENT:SetTrackType(type)
	self.dt.TrackType = type
end

function ENT:GetTrackType()
	return self.dt.TrackType or COASTER_TRACK_METAL
end

function ENT:SetCoasterID( id )
	self.dt.CoasterID = id
end

function ENT:GetCoasterID()
	return self.dt.CoasterID;
end

function ENT:SetRoll(roll) //Not to be confused with CLuaParticle.SetRoll()
	self.dt.Roll = roll
end

function ENT:GetRoll() //Not to be confused with CLuaParticle.GetRoll()
	return self.dt.Roll or 0
end

function ENT:SetTrackColor(r,g,b) 
	self.dt.TrackColor = Vector( r, g, b )
end

function ENT:GetTrackColor() 
	return Color( self.dt.TrackColor.x, self.dt.TrackColor.y, self.dt.TrackColor.z )
end

function ENT:SetSupportColor(r,g,b) 
	self.dt.SupportColor = Vector( r, g, b )
end

function ENT:GetSupportColor() 
	return self.dt.SupportColor.x, self.dt.SupportColor.y, self.dt.SupportColor.z 
end

////////////////////////////////////////////////////////
//END OF 'SHARED' FUNCTIONS
////////////////////////////////////////////////////////

local function AddNotify( text, type, time )
	if GAMEMODE && GAMEMODE.AddNotify then
		GAMEMODE:AddNotify( text, type, time )
	else
		print( text )
	end
end




function ENT:Initialize()

	//Default to being invalidated
	self.Invalidated = true
 
 	//Support models
	self.SupportModel 		= ClientsideModel( "models/sunabouzu/coaster_pole.mdl" )
	self.SupportModelStart 	= ClientsideModel( "models/sunabouzu/coaster_pole_start.mdl" )
	self.SupportModelBase 	= ClientsideModel( "models/sunabouzu/coaster_base.mdl" )

	//hide them (shh)
	self.SupportModel:SetNoDraw( true )
	self.SupportModelStart:SetNoDraw( true )
	self.SupportModelBase:SetNoDraw( true )

	//Make sure we draw the support model even though we stretched it to hell and back
	self:UpdateSupportDrawBounds()
	
	//Material table, to vary the base skin depending on the type of ground it's on
	self.MatSkins = {
		[MAT_DIRT] 		= 0,
        [MAT_CONCRETE] 	= 1,
		[MAT_SAND] 		= 2,
		[MAT_GLASS] 	= 1,
	}
	local controller = self:GetController()
	if IsValid( controller ) && controller.Nodes then
		controller:InvalidatePhysmesh(#controller.Nodes-1)
		if #controller.Nodes == 2 then controller:InvalidatePhysmesh(#controller.Nodes) end
	end

	if !self:IsController() then return end //Don't continue executing -- the rest of this stuff is for only the controller
	CoasterUpdateTrackTime = 0 //Tell the thingy that it's time to update its cache of coasters

	//The controller handles the drawing of the track mesh -- so we always want it to draw.
	self:SetRenderBoundsWS(Vector(-1000000,-1000000,-1000000), Vector( 1000000, 1000000, 1000000 ) ) //There must be a better way to do this

	//Other misc. clientside models that are only used by the controller
	self.WheelModel	= ClientsideModel( "models/props_vehicles/carparts_wheel01a.mdl")
	self.WheelModel:SetPos( Vector( 100000, 100000, -100000 ) )
	SetModelScale(self.WheelModel,  Vector( 1.6, 1.6, 1.6))

	//Initialize the clientside list of nodes
	self.Nodes = {}

	//And create the clientside spline controller to govern drawing the spline
	self.CatmullRom = {}
	self.CatmullRom = CoasterManager.Controller:New( self )
	self.CatmullRom:Reset()

	//Create a list of invalid physmeshes
	self.InvalidNodes = {}
end

usermessage.Hook("Coaster_RefreshTrack", function( um )
	self = um:ReadEntity()
	if !IsValid( self ) || !self.IsController then return end

	if self:IsController() then
		self:RefreshClientSpline()
		self:SupportFullUpdate()

		//Update the positions of the wheels
		for num, node in pairs( self.Nodes ) do 
			if node:GetType() == COASTER_NODE_BRAKES || node:GetType() == COASTER_NODE_SPEEDUP then
				self:UpdateWheelPositions( num )
			end
		end
	end	

end )

usermessage.Hook("Coaster_invalidateall", function( um )
	local self = um:ReadEntity()
	if !IsValid( self ) || !self.IsController || !self:IsController() then return end


	self:RefreshClientSpline()
	self:SupportFullUpdate()
	self:UpdateClientsidePhysics()

	for k, v in pairs( self.Nodes ) do
		v.Invalidated = true
		self:InvalidatePhysmesh(k)

	end

	if self.BuildingMesh || GetConVarNumber("coaster_autobuild") == 1 && self.SoftUpdateMesh then
		self:SoftUpdateMesh()
	end
end )

usermessage.Hook("Coaster_CartFailed", function( um )
	local needed = um:ReadChar() or 0
	AddNotify("Need " .. needed .. " more nodes to create track!", NOTIFY_ERROR, 3 )
end )

usermessage.Hook("Coaster_AddNode", function( um )
	local self = Entity(um:ReadShort())

	if !IsValid( self ) || !self.IsController then return end //Shared functions don't exist yet.

	if (self:IsController()) then
		
		self:RefreshClientSpline()

		//Invalidate nearby nodes
		if self.Nodes != nil then
			last = #self.Nodes

			if IsValid( self.Nodes[ last ] ) then
				self.Nodes[ last ].Invalidated = true
				self:InvalidatePhysmesh(last)
			end
			if IsValid( self.Nodes[ last - 1 ] ) then
				self.Nodes[ last - 1 ].Invalidated = true
				self:InvalidatePhysmesh(last-1)
			end
			if IsValid( self.Nodes[ last - 2 ] ) then
				self.Nodes[ last - 2 ].Invalidated = true
				self:InvalidatePhysmesh(last-2)
			end
			if IsValid( self.Nodes[ last - 3 ] ) then
				self.Nodes[ last - 3 ].Invalidated = true
				self:InvalidatePhysmesh(last-3)
			end
		end

		//Update the positions of the wheels
		for num, node in pairs( self.Nodes ) do 
			if !IsValid( node ) || !node.GetType then continue end
			if node:GetType() == COASTER_NODE_BRAKES || node:GetType() == COASTER_NODE_SPEEDUP then
				self:UpdateWheelPositions( num )
			end
		end

		self:SupportFullUpdate()

		if self.BuildingMesh || GetConVarNumber("coaster_autobuild") == 1 && self.SoftUpdateMesh then
			self:SoftUpdateMesh()
		end
	end
end )

//Invalidates nearby nodes, either due to roll changing or position changing. Means clientside mesh is out of date and needs to be rebuilt
usermessage.Hook("Coaster_nodeinvalidate", function( um )
	local self = um:ReadEntity()
	local node	 = um:ReadEntity()
	local inval_minimal = um:ReadBool() //Should we only invalidate the node before this one?

	if IsValid( node ) && node.Invalidate && IsValid( self ) then
		node:Invalidate( self, inval_minimal )
		self:UpdateClientsidePhysics()
	end

	if self.BuildingMesh || GetConVarNumber("coaster_autobuild") == 1 && self.SoftUpdateMesh then
		self:SoftUpdateMesh()
	end
end )

function ENT:UpdateClientsidePhysics( )
	for k, v in pairs( ents.FindByClass("coaster_physmesh") ) do
		if v.GetController && v:GetController() == self then
			v:BuildMesh()
		end
	end
end

function ENT:FindPhysmeshBySegment( segment )
	for k, v in pairs( ents.FindByClass("coaster_physmesh") ) do
		if v.GetController && v:GetController() == self && v:GetSegment() == segment then
			return v
		end
	end
end

function ENT:InvalidatePhysmesh( segment )
	local node = self:FindPhysmeshBySegment( segment )
	if !IsValid( node ) then return end 
	if table.HasValue( self.InvalidNodes, node ) then return end 

	table.insert( self.InvalidNodes, node )
end

//Invalid ourselves and nearby affected node
function ENT:Invalidate( controller, minimal_invalidation )
	if !IsValid( controller ) then return end
	if #controller.Nodes < 1 then return end

	for k, v in pairs( controller.Nodes ) do
		if v == self then
			if minimal_invalidation then
				v.Invalidated = true
				controller:InvalidatePhysmesh(k)

				if IsValid( controller.Nodes[ k - 1 ] ) then
					controller.Nodes[ k - 1 ].Invalidated = true
					controller:InvalidatePhysmesh(k-1)
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(k - 1))
				end
			else
				//Close your eyes, move down your scroll wheel 15 times and open them again
				local lastnode = controller.Nodes[#controller.Nodes-1]
				local secondlastnode = controller.Nodes[#controller.Nodes-2]
				local thirdlastnode = controller.Nodes[#controller.Nodes-2]
				local fourthlastnode = controller.Nodes[#controller.Nodes-3]
				local firstnode = controller.Nodes[2]
				local secondnode = controller.Nodes[3]

				v.Invalidated = true
				controller:InvalidatePhysmesh(k)

				if IsValid( controller.Nodes[ k - 1 ] ) && k != 2 then
					controller.Nodes[ k - 1 ].Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(k - 1))
					controller:InvalidatePhysmesh(k-1)
				elseif controller:Looped() then
					fourthlastnode.Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(#controller.Nodes-3))
					controller:InvalidatePhysmesh(#controller.Nodes-3)
				end

				if IsValid( controller.Nodes[ k - 2 ] ) && k != 3 then
					controller.Nodes[ k - 2 ].Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(k - 2))
					controller:InvalidatePhysmesh(k-2)
				elseif controller:Looped() then
					thirdlastnode.Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(#controller.Nodes-2))
					controller:InvalidatePhysmesh(#controller.Nodes-2)
				end

				if IsValid( controller.Nodes[ k + 1 ] ) && k != #controller.Nodes-2 then
					controller.Nodes[ k + 1 ].Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(k + 1))
					controller:InvalidatePhysmesh(k+1)
				elseif controller:Looped() then
					firstnode.Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(2))
					controller:InvalidatePhysmesh(2)
				end

				if controller:Looped() && k == #controller.Nodes - 1 then
					firstnode.Invalidated = true
					secondnode.Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(2))
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(3))
					controller:InvalidatePhysmesh(2)
					controller:InvalidatePhysmesh(3)
				end

			end

			return
		end
	end

	controller:UpdateClientsidePhysics()

	//Tell the track panel to update itself
	UpdateTrackPanel( controlpanel.Get("coaster_supertool").CoasterList )
end

//Return if the track has any unbuilt nodes
function ENT:HasInvalidNodes()
	local controller = self
	if !controller:IsController() then controller = self:GetController() end
	if !IsValid( controller ) then return end

	for k, v in pairs( controller.Nodes ) do
		if v.Invalidated then return true end
	end

	return false
end

//Refresh the client spline for track previews and mesh generation
function ENT:RefreshClientSpline()

	--Empty all current splines and nodes
	self.CatmullRom:Reset()
	table.Empty( self.Nodes )

	-- If we were in the middle of building the track, tell it to queue the build again
	if self.BuildingMesh then
		self:SoftUpdateMesh()
	end
	
	--Set ourselves as the first node as we're used to calculate the track's spline
	self.CatmullRom:AddPointAngle( 1, self:GetPos(), self:GetAngles(), 1.0 ) 
	table.insert( self.Nodes, self )
	local firstNode = self:GetNextNode()


	if !IsValid(firstNode) then return end
	
	self.CatmullRom:AddPointAngle( 2, firstNode:GetPos(), firstNode:GetAngles(), 1.0 )
	table.insert( self.Nodes, firstNode )

	local node = nil
	if IsValid( firstNode ) && firstNode.GetNextNode then
		node = firstNode:GetNextNode()
	end


	if !IsValid(node) then return end

	--Recurse through all the nodes, adding them, until they are no longer valid
	local amt = 3
	local End = false
	repeat
		if node:GetClass() == "coaster_node" && node:EntIndex() != 1 then

			self.CatmullRom:AddPointAngle( amt, node:GetPos(), node:GetAngles(), 1.0 )
			table.insert( self.Nodes, node )

			if node.GetNextNode then
				node = node:GetNextNode()

				amt = amt + 1	
			else
				End = true
			end
		else
			End = true
		end
	until (!IsValid(node) || !node.IsController || node:IsController() || node == firstNode || End)

	--If there are enough nodes (4 for catmull-rom), calculate the curve
	if #self.CatmullRom.PointsList > 3 then
		self.CatmullRom:CalcEntireSpline()

		--And the clientside mesh
		self:UpdateClientsidePhysics()
		self:SupportFullUpdate()
	end
end


//Update the client spline, less perfomance heavy than above function
//Use only when nodes have moved position.
function ENT:UpdateClientSpline( point ) //The point is the node that is moving
	if #self.CatmullRom.PointsList < 4 then return end
	
	//Loop through the points in the catmull controller object, updating the position of each one per entity
	for i = 1, #self.CatmullRom.PointsList do
		if IsValid( self.Nodes[ i ] ) then //Each node corresponds to the points index
			local ang = self.Nodes[i]:GetAngles()
			
			//Manually change the settings
			self.CatmullRom.PointsList[i] = self.Nodes[i]:GetPos()
			self.CatmullRom.FacingsList[i]   = ang:Forward()
			self.CatmullRom.RotationsList[i] = ang.r
		end
	end
	
	//self.CatmullRom:CalcEntireSpline()
	if point then
		self.CatmullRom:CalcSection( math.Clamp( point - 2, 2, #self.Nodes - 2), math.Clamp( point + 2, 2, #self.Nodes - 2))
		//self.CatmullRom:CalcSection( 2, #self.CatmullRom.PointsList)
	else self.CatmullRom:CalcEntireSpline() end

end

//Build all coaster's clientside mesh
concommand.Add("coaster_update_mesh", function()
	for _, v in pairs( ents.FindByClass("coaster_node") ) do
		if IsValid( v ) && v:IsController() then 
			v:UpdateClientMesh()
		end
	end
	AddNotify( "Updated rollercoaster meshes", NOTIFY_GENERIC, 4 )
end )

//Make doubly sure our client is up to date
concommand.Add("coaster_update_nodes", function() 
	for _, v in pairs( ents.FindByClass("coaster_node") ) do
		if IsValid( v ) && v:IsController() then 
			v:RefreshClientSpline()
		end
	end
end)

//Given spline index, return percent of a node
//Util function
function ENT:PercAlongNode(spline, qf)
	while spline >= self.CatmullRom.STEPS do
		spline = spline - self.CatmullRom.STEPS
	end
	if qf && spline == 0 then return 1 end
	return spline / self.CatmullRom.STEPS
end

-- Create a 'queue' that the mesh needs to be built, and wait a second before actually starting to build it
-- Makes it so there isn't a noticable freeze when spawning nodes with coaster_autobuild 1
function ENT:SoftUpdateMesh()
	self.GeneratorThread = nil -- Remove all progress if we were currently generating
	self.BuildQueued = true 
	self.BuildingMesh = false
	self.BuildAt = CurTime() + 1 -- TODO: Make this time customizable
end

//This baby is what builds the clientside mesh. It's really complicated.
function ENT:UpdateClientMesh()
	//Make sure we have the most up to date version of the track
	self:RefreshClientSpline()

	//And the clientside mesh
	self:UpdateClientsidePhysics()

	if #self.CatmullRom.PointsList > 3 then
		self.BuildingMesh = true //Tell the mesh to stop drawing because we're gonna rebuild it

		//Get the currently selected node type
		local gentype = self:GetTrackType()
		local track = trackmanager.Get(EnumNames.Tracks[gentype])
		local generated = nil

		if track then

			-- Tell the last track class to immolate itself, if applicable
			if self.TrackClass && istable( self.TrackClass.TrackMeshes ) && #self.TrackClass.TrackMeshes > 0 then
				if self.PreviousTrackClass then
					self.PreviousTrackClass:Remove()
				end
				self.PreviousTrackClass = self.TrackClass
			end


			self.TrackClass = track

			-- Create our coroutine thread that'll generate our mesh
			self.GeneratorThread = coroutine.create( self.TrackClass.Generate )
			assert(coroutine.resume(self.GeneratorThread, self.TrackClass, self ))

		else
			print("Failed to use track type \"" .. ( EnumNames.Tracks[gentype] or "Unknown (" .. gentype .. ")" ) .. "\"!" )
		end

		-- One more update can't hurt
		self:SupportFullUpdate()

		//Tell the track panel to update itself
		UpdateTrackPanel( controlpanel.Get("coaster_supertool").CoasterList )
	end
end

//Get the angle at a specific point on a track
function ENT:AngleAt(i, perc )
	local Vec1 = self.CatmullRom:Point( i, perc - 0.015 )
	local Vec2 = self.CatmullRom:Point( i, perc + 0.015 )

	local AngVec = Vector(0,0,0)

	AngVec = Vec1 - Vec2

	return AngVec:GetNormal():Angle()
end

//Set invalid nodes to valid (for when the mesh is first built)
function ENT:ValidateNodes()
	if self.Nodes != nil && #self.Nodes > 0 then
		for _, v in pairs( self.Nodes ) do
			if v.Invalidated then v.Invalidated = false end 
		end
	end

	table.Empty( self.InvalidNodes )
end

//Get the multiplier for the current spline (to make things smooth along the track)
function ENT:GetMultiplier(i, perc)
	local Dist = 1
	local Vec1 = self.CatmullRom:Point( i, perc - 0.005)
	local Vec2 = self.CatmullRom:Point( i, perc + 0.005 )

	Dist = Vec1:Distance( Vec2 )
	
	return 1 / Dist 
end



//Given a spline number, return the segment it's on
function ENT:GetSplineSegment(spline) //Get the segment of the given spline
	local STEPS = self.CatmullRom.STEPS
	
	return math.floor( spline / STEPS ) + 2
end

local nodeType = nil
local CTime = 0

//Main function for all track rendering
//track preview beams, track mesh
function ENT:DrawTrack()
	if self.CatmullRom == nil then return end //Shit
	if #self.CatmullRom.PointsList > 3 then

		render.SetMaterial( mat_debug )
		self:DrawRailMesh()

		CTime = CurTime()

		render.SetMaterial( mat_chain ) //mat_chain
		for i = 2, (#self.CatmullRom.PointsList - 2) do
			if IsValid( self.Nodes[i] ) then
				nodeType = self.Nodes[i]:GetType()
				
				if nodeType == COASTER_NODE_CHAINS then
					
					self:DrawSegment( i, CTime )
				elseif nodeType == COASTER_NODE_SPEEDUP then
					self:DrawSpeedupModels(i)

				elseif nodeType == COASTER_NODE_BRAKES then
					self:DrawBreakModels( i )
					
				end
				

			end 
		end

		render.SetMaterial( mat_debug )
		self:DrawInvalidNodes()

	end

end

//Draw invalid nodes, otherwise known as track preview
function ENT:DrawInvalidNodes()

	if self.InvalidNodes == nil then return end
	if LocalPlayer():GetInfoNum("coaster_previews", 0) == 0 then return end

	for k, v in pairs( self.InvalidNodes ) do
		if IsValid( v ) && v.TrackMesh then v.TrackMesh:Draw() end
	end
	
	for k, v in pairs( self.Nodes ) do
		if v.Invalidated && k + 1 < #self.Nodes && v.WasBeingHeld then //Don't draw the last node
			self:DrawSideRail( k, -15 )
			self:DrawSideRail( k, 15 )
		end
	end
	
end

//Draw a single segment's curve
function ENT:DrawSegment(segment)
	if not (segment > 1 && (#self.CatmullRom.PointsList > segment )) then return end
	if self.CatmullRom.Spline == nil or #self.CatmullRom.Spline < 1 then return end

	local node = (segment - 2) * self.CatmullRom.STEPS
	local Dist = 0
	//Draw the main Rail
	render.StartBeam( self.CatmullRom.STEPS + 1 )
	render.AddBeam(self.CatmullRom.PointsList[segment], 32, Dist, color_white) //time or 1

	for i = 1, (self.CatmullRom.STEPS) do
		if i==1 then
			Dist = Dist - self.CatmullRom.Spline[node + 1]:Distance( self.CatmullRom.PointsList[segment] ) 
		else
			Dist = Dist - self.CatmullRom.Spline[node + i]:Distance( self.CatmullRom.Spline[node + i - 1] ) 
		end
		render.AddBeam(self.CatmullRom.Spline[node + i],32, Dist*0.05, color_white)
	end
	
	Dist = Dist - self.CatmullRom.PointsList[segment + 1]:Distance( self.CatmullRom.Spline[ node + self.CatmullRom.STEPS ] )
	render.AddBeam(self.CatmullRom.PointsList[segment + 1], 32, Dist*0.05, color_white)
	render.EndBeam()

end

//Re-add the old scaling functionality (garry it's called renaming a function, not replacing it)
local scalefix = Matrix()
function SetModelScale( ent, scale )
	if !IsValid( ent ) then return end
	scalefix = Matrix()
	scalefix:Scale( scale )

	ent:EnableMatrix("RenderMultiply", scalefix)
end


local WheelOffset = 1
local WheelNode = nil
local ThisSegment = nil
local NextSegment = nil
local WheelPercent = 0
local WheelAngle = Angle( 0, 0, 0)
local WheelPosition = Vector( 0, 0, 0 )
local Roll = 0
//Generate the positions to set the break and wheel models
function ENT:UpdateWheelPositions( segment )
	if not (segment > 1 && (#self.CatmullRom.PointsList > segment )) then return end
	if not self.CatmullRom || !self.CatmullRom.Spline then return end
	if !IsValid( self.WheelModel ) then return end

	ThisSegment = self.Nodes[ segment ]
	NextSegment = self.Nodes[ segment + 1 ]

	WheelPercent = 0
	WheelAngle = Angle( 0, 0, 0)
	WheelPosition = Vector( 0, 0, 0 )
	Roll = 0
	local numwheels = 0

	if !IsValid( ThisSegment ) || !IsValid( NextSegment ) then return end 
	if !ThisSegment.GetRoll || !NextSegment.GetRoll then return end
	
	self.WheelPositions[segment] = {}

	Multiplier = self:GetMultiplier(segment, WheelPercent)

	//Move ourselves forward along the track
	//Percent = ( Percent + ( Multiplier * 2 ) ) / 2 //move ourselves one half forward, so the wheels are between track struts
	WheelPercent = Multiplier / 2

	while WheelPercent < 1 do

		WheelAngle = self:AngleAt( segment, WheelPercent)

		//Change the roll depending on the track
		Roll = -Lerp( WheelPercent, math.NormalizeAngle( ThisSegment:GetRoll() ), NextSegment:GetRoll())	
		
		//Set the roll for the current track peice
		WheelAngle.r = Roll
		//ang.y = ang.y - 90
		//ang:RotateAroundAxis( ang:Up(), -90 )
		WheelPosition = self.CatmullRom:Point(segment, WheelPercent)

		//ang:RotateAroundAxis( ang:Right(), CurTime() * 1000 ) //BAM

		//Now... manage moving throughout the track evenly
		//Each spline has a certain multiplier so the cart travel at a constant speed throughout the track
		Multiplier = self:GetMultiplier(segment, WheelPercent)
			
		numwheels = numwheels + 1

		self.WheelPositions[segment][numwheels] = {}
		self.WheelPositions[segment][numwheels].pos = WheelPosition
		self.WheelPositions[segment][numwheels].ang = WheelAngle


		//Move ourselves forward along the track
		WheelPercent = WheelPercent + ( Multiplier * WheelOffset )

	end

end

function ENT:DrawSpeedupModels( segment )
	if !self.WheelPositions[segment] then self:UpdateWheelPositions( segment ) return end
	if #self.WheelPositions[segment] < 1 then return end
	if !IsValid( self.WheelModel ) then return end

	local segment = self.WheelPositions[segment]
	local position = Vector( 0, 0, 0 )
	local ang = Angle( 0, 0, 0)

	self.WheelModel:SetNoDraw( false )
	for i=1, #segment do
		if i > GetConVar("coaster_maxwheels"):GetInt() then return end

		if i % 2 == 0 then //Draw every other wheel
			position = segment[i].pos
			ang = Angle( segment[i].ang.p, segment[i].ang.y, segment[i].ang.r ) //Create a new instance of the angle so we don't modify the source

			position = position + ang:Up() * -13
			ang:RotateAroundAxis( ang:Right(), CurTime() * 1300 ) //Rotate the wheel


			self.WheelModel:SetRenderOrigin( position )
			render.SetLightingOrigin( position )
			self.WheelModel:SetAngles( ang )
			self.WheelModel:SetupBones()
			self.WheelModel:DrawModel()
		end
	end

	self.WheelModel:SetNoDraw( true )

end

local PositionL = Vector( 0, 0, 0 )
local PositionR = Vector( 0, 0, 0 )
function ENT:DrawBreakModels( segment )
	if !self.WheelPositions[segment] then self:UpdateWheelPositions( segment ) return end
	if #self.WheelPositions[segment] < 1 then return end
	if !IsValid( self.WheelModel ) then return end

	local segment = self.WheelPositions[segment]
	local position = Vector( 0, 0, 0 )
	local ang = Angle( 0, 0, 0)
	self.WheelModel:SetNoDraw( false )

	for i=1, #segment do
		if i > GetConVar("coaster_maxwheels"):GetInt() then return end

		if i % 2 == 0 then //Draw every other wheel
			position = segment[i].pos
			ang = Angle( segment[i].ang.p, segment[i].ang.y, segment[i].ang.r ) //Create a new instance of the angle so we don't modify the source
			position = position + WheelAngle:Up() * 13

			PositionL = position + ( ang:Up() * -13 ) + ( ang:Right() * 15 )
			PositionR = position + ( ang:Up() * -13 ) + ( ang:Right() * -15 )

			ang:RotateAroundAxis( ang:Right(), CurTime() * -140 ) //Rotate the wheel

			self.WheelModel:SetRenderOrigin( PositionL )
			render.SetLightingOrigin( PositionL )
			self.WheelModel:SetAngles( ang )
			self.WheelModel:SetupBones()
			self.WheelModel:DrawModel()

			self.WheelModel:SetRenderOrigin( PositionR )
			render.SetLightingOrigin( PositionR )
			self.WheelModel:SetupBones()
			self.WheelModel:DrawModel()
		end
	end

	self.WheelModel:SetNoDraw( true )

end

//Move these variables out to prevent excess garbage collection
local node = -1
local Dist = 0
local AngVec = Vector(0,0,0)
local ang = Angle( 0, 0, 0 )
local Roll = 0
local NextSegment = nil
local ThisSegment = nil

function ENT:DrawSideRail( segment, offset )
	if not (segment > 1 && (#self.CatmullRom.PointsList > segment )) then return end
	if self.CatmullRom.Spline == nil or #self.CatmullRom.Spline < 1 then return end

	NextSegment = self.Nodes[ segment + 1 ]
	ThisSegment = self.Nodes[ segment ]

	if !IsValid( NextSegment ) || !IsValid( ThisSegment ) then return end
	if !NextSegment.GetRoll || !ThisSegment.GetRoll then return end

	//Set up some variables (these are declared outside this function)
	node = (segment - 2) * self.CatmullRom.STEPS
	Dist = CurTime() * 20
	Roll = 0

	//Very first beam position
	AngVec = self.CatmullRom.Spline[node + 1] - self.CatmullRom.PointsList[segment] 
	AngVec:Normalize()
	ang = AngVec:Angle()

	ang:RotateAroundAxis( AngVec, math.NormalizeAngle( ThisSegment:GetRoll() ) )

	//Draw the main Rail
	render.StartBeam( self.CatmullRom.STEPS + 1 )
	render.AddBeam(self.CatmullRom.PointsList[segment] + ( ang:Right() * offset ), 10, Dist*0.05, color_white) 

	for i = 1, (self.CatmullRom.STEPS) do
		if i==1 then
			Dist = Dist - self.CatmullRom.Spline[node + 1]:Distance( self.CatmullRom.PointsList[segment] ) 
			AngVec = self.CatmullRom.Spline[node + 1] - self.CatmullRom.PointsList[segment] 
		else
			AngVec = self.CatmullRom.Spline[node + i] - self.CatmullRom.Spline[node + i - 1]

			Dist = Dist - self.CatmullRom.Spline[node + i]:Distance( self.CatmullRom.Spline[node + i - 1] ) 
		end
		AngVec:Normalize()
		ang = AngVec:Angle()
		Roll = Lerp( i / self.CatmullRom.STEPS, math.NormalizeAngle( ThisSegment:GetRoll() ),NextSegment:GetRoll())

		ang:RotateAroundAxis( AngVec, Roll )

		render.AddBeam( self.CatmullRom.Spline[node + i] + ( ang:Right() * offset ) ,10, Dist*0.05, color_white)
	end

	AngVec = self.CatmullRom.PointsList[segment + 1] - self.CatmullRom.Spline[ node + self.CatmullRom.STEPS ]
	AngVec:Normalize()
	ang = AngVec:Angle()

	ang:RotateAroundAxis( AngVec,  NextSegment:GetRoll()  )

	Dist = Dist - self.CatmullRom.PointsList[segment + 1]:Distance( self.CatmullRom.Spline[ node + self.CatmullRom.STEPS ] )
	render.AddBeam(self.CatmullRom.PointsList[segment + 1] + (ang:Right() * offset ), 10, Dist*0.05, color_white)
	render.EndBeam()
end

//Though easier to understand, this was more laggy than the above function, so it isn't used.
function ENT:DrawSideRail2( segment, offset )
	if not (segment > 1 && (#self.CatmullRom.PointsList > segment )) then return end
	if self.CatmullRom.Spline == nil or #self.CatmullRom.Spline < 1 then return end

	local NextSegment = self.Nodes[ segment + 1 ]
	local ThisSegment = self.Nodes[ segment ]
	local ThisPos = Vector( 0, 0, 0 )
	local NextPos = Vector( 0, 0, 0 )

	if !IsValid( NextSegment ) || !IsValid( ThisSegment ) then return end
	if !NextSegment.GetRoll || !ThisSegment.GetRoll then return end

	//Set up some variables (these are declared outside this function)
	node = (segment - 2) * self.CatmullRom.STEPS
	Dist = CurTime() * 200
	Roll = 0



	//Very first beam position
	//AngVec = self.CatmullRom.Point(node, 0.01) - self.CatmullRom.Point(node, 0)
	//AngVec:Normalize()
	//ang = AngVec:Angle()

	//ang:RotateAroundAxis( AngVec, math.NormalizeAngle( ThisSegment:GetRoll() ) )

	//Draw the main Rail
	render.StartBeam( self.CatmullRom.STEPS + 1)
	//render.AddBeam(self.CatmullRom.Point(node, 0) + ( ang:Right() * offset ), 10, Dist*0.05, color_white) 

	//NOTE: this starts at 0 so the beam begins at the node, not a little bit after the node
	for i = 0, (self.CatmullRom.STEPS) do

		ThisPos = self.CatmullRom:Point(segment, i/self.CatmullRom.STEPS)
		NextPos = self.CatmullRom:Point(segment, (i+1)/self.CatmullRom.STEPS)

		//if i==1 then
		//	Dist = Dist - self.CatmullRom.Point(node, i/self.CatmullRom.STEPS):Distance( self.CatmullRom.Point(node, 0) ) 
		//	AngVec = self.CatmullRom.Point(node, i/self.CatmullRom.STEPS) - self.CatmullRom.Point(node, 0)
		//else
		AngVec = ThisPos - NextPos

		Dist = Dist - ThisPos:Distance( NextPos ) 
		//end

		AngVec:Normalize()
		ang = AngVec:Angle()
		Roll = Lerp( i / self.CatmullRom.STEPS, math.NormalizeAngle( ThisSegment:GetRoll() ),NextSegment:GetRoll())

		ang:RotateAroundAxis( AngVec, Roll )

		render.AddBeam( ThisPos + ( ang:Right() * offset ), 10, Dist*0.05, color_white)
	end

	//AngVec = self.CatmullRom.PointsList[segment + 1] - self.CatmullRom.Spline[ node + self.CatmullRom.STEPS ]
	//AngVec:Normalize()
	//ang = AngVec:Angle()

	//ang:RotateAroundAxis( AngVec,  NextSegment:GetRoll()  )

	//Dist = Dist - self.CatmullRom.PointsList[segment + 1]:Distance( self.CatmullRom.Spline[ node + self.CatmullRom.STEPS ] )
	//render.AddBeam(self.CatmullRom.PointsList[segment + 1] + (ang:Right() * offset ), 10, Dist*0.05, color_white)
	render.EndBeam()
end


--Draw the pre-generated rail mesh
function ENT:DrawRailMesh()
	if !self.BuildingMesh && self.TrackClass && #self.TrackClass.TrackMeshes > 0 then
		self.TrackClass:Draw()
	else
		if self.PreviousTrackClass then self.PreviousTrackClass:Draw() end
	end
	
end

//Draw a rail along the entirety of the track
//This was what was use before track meshes
//It also got really laggy
function ENT:DrawRail(offset)
	local nOffset = offset
	render.StartBeam(#self.CatmullRom.Spline)
	//render.AddBeam(self.CatmullRom.PointsList[2], 10, 6, color_white)	

	for i = 1, #self.CatmullRom.Spline do
		//local ang = self.CatmullRom:Angle( 39.3700787, i / #self.CatmullRom.Spline ) //Get the angle at that point (hopefully)
		local NextSegment = self.Nodes[self:GetSplineSegment(i) + 1]
		local ThisSegment = self.Nodes[ self:GetSplineSegment(i) ]
		local AngVec = Vector( 0, 0, 0 )
		//print(#self.CatmullRom.Spline.." > "..tostring(i+1))
		if #self.CatmullRom.Spline > i + 1 then
			
			AngVec = self.CatmullRom.Spline[i] - self.CatmullRom.Spline[i + 1]
			AngVec:Normalize()
		end
		local ang = AngVec:Angle()
		
		if IsValid( ThisSegment ) && IsValid( NextSegment ) then
			//Get the percent along this node
			perc = (i % self.CatmullRom.STEPS) / self.CatmullRom.STEPS
			//local Roll = Lerp( perc, ThisSegment:GetAngles().r,NextSegment:GetAngles().r )	
			local Roll = -Lerp( perc, math.NormalizeAngle( ThisSegment:GetRoll() ),NextSegment:GetRoll())	
			ang:RotateAroundAxis( AngVec, Roll ) //Segment:GetAngles().r
		end
			
		local pos = self.CatmullRom.Spline[i] + ang:Right() * -nOffset

		render.AddBeam(pos, 4, 6, color_white )
	end	
	render.EndBeam()
end

function ENT:UpdateSupportDrawBounds()
	if self:IsController() then
		self:SetRenderBoundsWS(Vector(-1000000,-1000000,-1000000), Vector( 1000000, 1000000, 1000000 ) ) //There must be a better way to do this
	else
		if !IsValid( self.SupportModel ) then return end

		//Update their render bounds so it draws the supports too
		trace = {}

		trace.start  = self:GetPos()
		trace.endpos = self:GetPos() - Vector( 0, 0, 100000 ) //Trace straight down
		trace.filter = self
		trace.mask = MASK_SOLID_BRUSHONLY
		trace = util.TraceLine(trace)

		self.SupportModel:SetRenderBoundsWS( trace.StartPos - Vector( 50, 50, -50), trace.HitPos + Vector( 50, 50, -50) )		
	end
end

//Update the entirety of the supports - their draw bounds, their colors, their positions, whether or not to draw, etc.
function ENT:SupportFullUpdate()
	for i=1, #self.Nodes do
		local ent = self.Nodes[i]

		if IsValid(ent.SupportModel) && IsValid(ent.SupportModelStart) && IsValid(ent.SupportModelBase) then
			if !ent:DrawSupport() then
				ent.SupportModelStart:SetNoDraw( true )
				ent.SupportModel:SetNoDraw( true )
				ent.SupportModelBase:SetNoDraw( true )
			end

			ent:UpdateSupportDrawBounds()
		end

	end

	//Tell the track panel to update itself
	UpdateTrackPanel( controlpanel.Get("coaster_supertool").CoasterList )
end


function ENT:DrawSupport()
	local controller = self:GetController()
	if !IsValid( controller ) then return end
	if LocalPlayer().GetInfoNum && LocalPlayer():GetInfoNum("coaster_supports", 0) == 0 then return end //Don't draw if they don't want us to draw.
	if controller.TrackClass && controller.TrackClass.SupportOverride then return end //Dont' draw supports if the current track makes its own
	if self.IsController && self:IsController() || controller.Nodes[ #controller.Nodes ] == self then return false end //Don't draw the controller or the very last (unconnected) node
	if math.abs( math.NormalizeAngle( self:GetRoll() ) ) > 90 then return false end //If a track is upside down, don't draw the supports
	if controller:Looped() && controller.Nodes[ 2 ] == self then return false end //Don't draw the supports for the second node ONLY if the track is looped

	self.SupportModelStart:SetNoDraw( false )
	self.SupportModel:SetNoDraw( false )
	self.SupportModelBase:SetNoDraw( false )
	local SupportScale = controller.TrackClass && controller.TrackClass.SupportScale or 1

	local dist = 100000
	trace = {}

		trace.start  = self:GetPos()
		trace.endpos = self:GetPos() - Vector( 0, 0, dist ) //Trace straight down
		trace.filter = self
		trace.mask = MASK_SOLID_BRUSHONLY
		trace = util.TraceLine(trace)
		

	local Distance = self:GetPos():Distance( trace.HitPos + Vector( 0, 0, self.BaseHeight) )

	//Set their colors
	local color = self:GetColor()
	
	if self.Invalidated then
		color.r = 255
		color.g = 0
		color.b = 0
	end

	self.SupportModelStart:SetColor( color )
	self.SupportModel:SetColor( color )

	//Draw the first pole
	self.SupportModelStart:SetPos( trace.HitPos + Vector( 0, 0, self.BaseHeight ) ) //Add 64 units so it's right on top of the base
	local height = math.Clamp( Distance, 1, self.PoleHeight - self.BaseHeight )
	SetModelScale( self.SupportModelStart, Vector( SupportScale, SupportScale, height / (self.PoleHeight  ) ) )
	self.SupportModelStart:SetAngles( Angle( 0, self:GetAngles().y, 0 ) )

	//Draw the second pole (if applicable)
	if Distance > self.PoleHeight - self.BaseHeight then
		self.SupportModel:SetPos(trace.HitPos + Vector(0, 0, self.PoleHeight ))
		SetModelScale( self.SupportModel,Vector( SupportScale, SupportScale, ( (Distance - self.PoleHeight + self.BaseHeight) / self.PoleHeight)   ) )
		self.SupportModel:SetAngles( Angle( 0, self:GetAngles().y, 0 ) )				
	else
		self.SupportModel:SetNoDraw( true )
	end
	
	if self:GetPos():Distance( trace.HitPos ) > self.BaseHeight + 10 then
		local skin = self.MatSkins[trace.MatType]
		self.SupportModelBase:SetSkin( skin or 1 )
		self.SupportModelBase:SetPos( trace.HitPos )
		self.SupportModelBase:SetAngles( Angle( 0, self:GetAngles().y, 0 ) )
	else
		self.SupportModelBase:SetNoDraw( true )
		self.SupportModelStart:SetPos( trace.HitPos )
		SetModelScale( self.SupportModelStart, Vector( SupportScale, SupportScale, self:GetPos():Distance( trace.HitPos ) / (self.PoleHeight) ) )
	end

	return true
end

//Draw the node
function ENT:Draw()

	SetModelScale( self, Vector( 1, 1, 1 ) ) //I love addons that change the scale of other entities even when their tool isn't out! It's wonderful!
	
	// Don't draw if we're taking pictures
	local wep = LocalPlayer():GetActiveWeapon()
	if wep:IsValid() && wep:GetClass() == "gmod_camera" && !self:IsController() then
		return
	end

	//If we're in a vehicle ( cart ), don't draw
	if LocalPlayer():InVehicle() && !self:IsController() then
		return
	end


	local controller = self:GetController()
	if ( IsValid( controller ) && controller.Nodes && self == controller.Nodes[ #controller.Nodes ] && #controller.Nodes > 2 ) or self:IsController() then //Don't draw if we are the start/end nodes
		return
	end

	self:DrawModel()

	//Usually for proper lighting to work we need to draw the mesh after we draw a proper model
	//However, because I pretty much fake all of the lighting, that doesn't matter any more.
	/*
	if self:IsController() then
		if #self.CatmullRom.PointsList > 3 then
			//self:DrawRailMesh()
		end
	end
	*/
end

//Update the node's spline if our velocity (and thus position) changes
function ENT:Think()

	//force-invalidate ourselves if we're being driven at all
	if self:IsBeingDriven() && !self.Invalidated then
		self:Invalidate( self:GetController(), false )
	end

	if !self:IsController() then return end

	for k, v in pairs( self.Nodes ) do	
		if IsValid( v ) && v:GetVelocity():Length() > 0 && v != self then
			if !self.WasBeingHeld then
				self.WasBeingHeld = true
				v.WasBeingHeld = true
				if IsValid( self.Nodes[k-1] ) then self.Nodes[k-1].WasBeingHeld = true end
				self:SupportFullUpdate() //Update all of the nodes when we let go of the node
			end

			//So we can see the beams move while me move a node
			self:UpdateClientSpline( k ) 

			//Update the positions of the wheels
			for num, node in pairs( self.Nodes ) do 
				if IsValid( node ) && node.GetType && (node:GetType() == COASTER_NODE_BRAKES || node:GetType() == COASTER_NODE_SPEEDUP) then
					self:UpdateWheelPositions( num )
				end
			end

			v:UpdateSupportDrawBounds()

			//Set the positions of the clientside support models
			if IsValid(v.SupportModel) && IsValid(v.SupportModelStart) && IsValid(v.SupportModelBase) then

				if !v:DrawSupport() then
					v.SupportModelStart:SetNoDraw( true )
					v.SupportModel:SetNoDraw( true )
					v.SupportModelBase:SetNoDraw( true )
				end
			else //If they are no longer valid, recreate them
				if !IsValid( v.SupportModel ) then v.SupportModel = ClientsideModel( "models/sunabouzu/coaster_pole.mdl" ) end
				if !IsValid( v.SupportModelStart ) then v.SupportModelStart = ClientsideModel( "models/sunabouzu/coaster_pole_start.mdl" ) end
				if !IsValid( v.SupportModelBase ) then v.SupportModelBase = ClientsideModel( "models/sunabouzu/coaster_base.mdl" ) end
			end

			-- If we were in the middle the build process, it's probably all bunked up
			if self.BuildQueued || GetConVarNumber("coaster_autobuild") == 1 && self.SoftUpdateMesh then
				self:SoftUpdateMesh()
			end

			break //We really only need to do this once, not on a per segment basis.
		elseif (k == #self.Nodes ) then
			if self.WasBeingHeld then
				self.WasBeingHeld = false
				for _, node in pairs( self.Nodes ) do node.WasBeingHeld = false end
				self:SupportFullUpdate() //Update all of the nodes when we let go of the node
			end
		end
	end

	-- Check if we are queued to update the mesh
	if self.BuildQueued && CurTime() > self.BuildAt then
		self.BuildQueued = false 
		self:UpdateClientMesh()
	end

	self:UpdateSupportDrawBounds()
end

function ENT:OnRemove()
	//Remove models
	if IsValid( self.SupportModel  ) then 
		self.SupportModel:SetNoDraw( true )
		self.SupportModel:Remove() 
		self.SupportModel = nil
	end
	if IsValid( self.SupportModelStart ) then 
		self.SupportModelStart:SetNoDraw( true )
		self.SupportModelStart:Remove() 
		self.SupportModelStart = nil
	end
	if IsValid( self.SupportModelBase ) then 
		self.SupportModelBase:SetNoDraw( true )
		self.SupportModelBase:Remove() 
		self.SupportModelBase = nil
	end


	if IsValid( self ) && self:IsController() then

		if IsValid( self.WheelModel ) then 
			self.WheelModel:Remove() 
		end
	else
		local Controller = self:GetController()
		if !IsValid( Controller ) then return end

		for k, v in pairs( Controller.Nodes ) do
			if v == self then 			
				table.remove( Controller.Nodes, k ) 
				Controller:RefreshClientSpline()

				break
			end
		end

	end
end

concommand.Add("coaster_refresh_drawbounds", function()
	for k, v in pairs( CoasterTracks ) do
		if IsValid( v ) then
			v:UpdateSupportDrawBounds()
		end
	end

end )





//FUCKYOU DEBUG
/*
local pos,material,white = Vector(0,0,0), Material( "sprites/splodesprite" ),Color(255,255,255,255) --Define this sort of stuff outside of loops to make more efficient code.
hook.Add( "HUDPaint", "paintsprites", function()
	cam.Start3D(EyePos(),EyeAngles()) -- Start the 3D function so we can draw onto the screen.
		render.SetMaterial( material ) -- Tell render what material we want, in this case the flash from the gravgun
		for k, v in pairs( ents.FindByClass("coaster_node")) do
			if v.Verts && #v.Verts > 0 then

				if v.Verts.TimeChange == nil then v.Verts.TimeChange = CurTime() + 1 end
				if v.Verts.CurVert == nil then v.Verts.CurVert = 1 end

				if v.Verts.TimeChange < CurTime() then
					v.Verts.CurVert = v.Verts.CurVert + 1
					if v.Verts.CurVert > #v.Verts then
						v.Verts.CurVert = 1
					end
					print( v.Verts.CurVert )
					v.Verts.TimeChange = CurTime() + 1
				end
				render.DrawSprite(v.Verts[v.Verts.CurVert].pos, 16, 16, white) 
			end
		end
	cam.End3D()
end )
*/