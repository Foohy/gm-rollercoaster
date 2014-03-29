include( "shared.lua" )
include( "autorun/mesh_beams.lua")

-- Enumeration for outdate settings
OUTDATE_ALL 	= 1
OUTDATE_LARGE 	= 2
OUTDATE_SMALL 	= 3
OUTDATE_ONE 	= 4

ENT.PoleHeight = 512 //How tall, in source units, the coaster support poles are
ENT.BaseHeight = 38 //How tall, in source units, the coaster base is
ENT.BuildingMesh = false //Are we currently building a mesh? if so, don't draw them
ENT.NWVarNotifyFuncs = -- Get notified whenever any of these functions changes value.
{ 
	"GetLooped", 
	"GetNextNode", 
	"GetTrackType", 
	"GetRoll", 
	"GetTrackColor",
	"GetColor",
}

ENT.TrackMeshes = {} //Store generated track meshes to render
ENT.Wheels = {} //Store the positions of where break and speedup wheels will be placed

ENT.SupportModel 		= nil
ENT.SupportModelStart 	= nil
ENT.SupportModelBase 	= nil

ENT.LastGenTime = 0
ENT.CachedPosition = nil

ENT.Nodes = {}
ENT.CatmullRom = {}

local mat_chain = Material("sunabouzu/old_chain") //sunabouzu/old_chain
local mat_debug = Material("foohy/warning")


local function AddNotify( text, type, time )
	if GAMEMODE && GAMEMODE.AddNotify then
		GAMEMODE:AddNotify( text, type, time )
	else
		print( text )
	end
end

-- Quickly remove all wheels from a specific segment
local function ClearSegmentWheels( self, segment )
	if IsValid( self ) && self.Wheels && self.Wheels[segment] then
		for _, v in pairs( self.Wheels[segment]) do
			if IsValid(v) then v:Remove() end
		end
		self.Wheels[segment] = nil
	end
end

local function SegmentHasWheels( self, segment )
	return self.Wheels && self.Wheels[segment] && #self.Wheels[segment] > 0
end

//Re-add the old scaling functionality
local scalefix = Matrix()
local function SetModelScale( ent, scale )
	if !IsValid( ent ) then return end
	scalefix = Matrix()
	scalefix:Scale( scale )

	ent:EnableMatrix("RenderMultiply", scalefix)
end

//Move these variables out to prevent excess garbage collection
local node = -1
local Dist = 0
local AngVec = Vector(0,0,0)
local ang = Angle( 0, 0, 0 )
local Roll = 0
local NextSegment = nil
local ThisSegment = nil

//Draw the dynamic side beams along a specified segment
local function DrawSideRail( self, segment, offset)
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


local WheelOffset = 1
local WheelNode = nil
local ThisSegment = nil
local NextSegment = nil
local WheelPercent = 0
local WheelAngle = Angle( 0, 0, 0)
local WheelPosition = Vector( 0, 0, 0 )
local Roll = 0

-- Let's try this
local function UpdateWheelPositions( self, segment, type, forceRefresh )
	if not IsValid( self ) then return end
	if not (segment > 1 && (#self.CatmullRom.PointsList > segment )) then return end
	if not self.CatmullRom || !self.CatmullRom.Spline then return end

	-- Make sure this is valid
	type = self.TypeToWheelProp[type] and type

	if not type then return end

	ThisSegment = self.Nodes[ segment ]
	NextSegment = self.Nodes[ segment + 1 ]

	-- Check if the segments are valid
	if !IsValid( ThisSegment ) || !IsValid( NextSegment ) then return end 
	if !ThisSegment.GetRoll || !NextSegment.GetRoll then return end

	-- Force ourselves to recreate all the models
	if (forceRefresh && self.Wheels && self.Wheels[segment]) then
		-- Delete any existing wheels
		ClearSegmentWheels( self, segment )

		self.Wheels[segment] = {}
	end

	-- Create the table, if neccessary
	if !self.Wheels then self.Wheels = {} end

	WheelPercent = 0
	WheelAngle = Angle( 0, 0, 0)
	WheelPosition = Vector( 0, 0, 0 )
	Roll = 0
	local currentWheel = 1
	
	Multiplier = self:GetMultiplier(segment, WheelPercent)

	//Move ourselves forward along the track
	WheelPercent = Multiplier / 2

	while WheelPercent < 1 do
		-- Create the table if neccessary
		if !self.Wheels[segment] then self.Wheels[segment] = {} end

		WheelAngle = self:AngleAt( segment, WheelPercent)

		-- Change the roll depending on the track
		Roll = -Lerp( WheelPercent, math.NormalizeAngle( ThisSegment:GetRoll() ), NextSegment:GetRoll())	
		
		-- Set the roll for the current track peice
		WheelAngle.r = Roll
		WheelPosition = self.CatmullRom:Point(segment, WheelPercent)

		-- Now... manage moving throughout the track evenly
		-- Each spline has a certain multiplier so things can be placed at a consistent distance
		Multiplier = self:GetMultiplier(segment, WheelPercent)

		local wheel = IsValid(self.Wheels[segment][currentWheel]) and self.Wheels[segment][currentWheel] or ClientsideModel( self.TypeToWheelProp[type].Model )

		if IsValid( wheel ) then
			-- Move it down a bit
			WheelPosition = WheelPosition + WheelAngle:Up() * self.TypeToWheelProp[type].DownOffset
			WheelPosition = WheelPosition + WheelAngle:Right() * self.TypeToWheelProp[type].SideOffset

			WheelAngle:RotateAroundAxis( WheelAngle:Forward(), self.TypeToWheelProp[type].RotationOffset ) 

			wheel:SetPos( WheelPosition )
			wheel:SetAngles( WheelAngle )
		end

		self.Wheels[segment][currentWheel] = wheel 
		currentWheel = currentWheel + 1

		-- Move ourselves forward along the track
		WheelPercent = WheelPercent + ( Multiplier * WheelOffset )

		-- Check if we've hit the max wheel limit

		if currentWheel > GetConVarNumber("coaster_maxwheels", 30 ) then break end
	end

	-- If there's any extra wheels, tell em to frick off
	if self.Wheels != nil then
		for i=currentWheel, #self.Wheels[segment] do
			if IsValid( self.Wheels[segment][i] ) then
				self.Wheels[segment][i]:Remove()
				self.Wheels[segment][i] = nil
			end
		end
	end

end

usermessage.Hook("Coaster_RefreshTrack", function( um )
	self = um:ReadEntity()
	if !IsValid( self ) || !self.GetIsController then return end

	if self:GetIsController() then
		self:RefreshClientSpline()
		self:SupportFullUpdate()

		//Update the positions of the wheels
		for num, node in pairs( self.Nodes ) do 
			local nodeType = node:GetNodeType()
			if self.TypeToWheelProp[nodeType] then
				UpdateWheelPositions( self, num, nodeType, true )
			end
		end
	end	

end )

usermessage.Hook("Coaster_invalidateall", function( um )
	local self = um:ReadEntity()

	if !IsValid( self ) || !self.GetIsController || !self:GetIsController() then return end


	self:RefreshClientSpline()
	self:SupportFullUpdate()
	self:UpdateClientsidePhysics()

	self:SetOutdated( OUTDATE_ALL )

	if self.BuildingMesh || GetConVarNumber("coaster_mesh_autobuild") == 1 && self.ResetUpdateMesh then
		self:ResetUpdateMesh()
	end
end )

usermessage.Hook("Coaster_CartFailed", function( um )
	local needed = um:ReadChar() or 0
	AddNotify("Need " .. needed .. " more nodes to create track!", NOTIFY_ERROR, 3 )
end )

function ENT:Initialize()

 	-- Default to node being outdated and needing to be rebuilt
	self.IsOutdated = true

 	//Support models
	self:CreateSupportBase()

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

	if !self:GetIsController() then return end //Don't continue executing -- the rest of this stuff is for only the controller
	CoasterUpdateTrackTime = 0 //Tell the thingy that it's time to update its cache of coasters

	//Initialize the clientside list of nodes
	self.Nodes = {}
	self.Wheels = {}

	//And create the clientside spline controller to govern drawing the spline
	self.CatmullRom = {}
	self.CatmullRom = CoasterManager.Controller:New( self )
	self.CatmullRom:Reset()

	//Create a list of invalid physmeshes
	self.InvalidNodes = {}

	//Cache some user preferences
	local convar = GetConVar("coaster_mesh_drawoutdatedmesh")
	local bool = convar && convar:GetBool()

	self.ShouldDrawOutdatedMesh = bool

	convar = GetConVar("coaster_mesh_drawunfinishedmesh")
	bool = convar && convar:GetBool()

	self.ShouldDrawUnfinishedMesh = bool

	//Create a table of wheel models to their correspondent node type
	self.TypeToWheelProp = {}
	self.TypeToWheelProp[COASTER_NODE_SPEEDUP] = { 
		Model = Model("models/props_phx/wheels/trucktire.mdl"),
		DownOffset = -14.5,
		SideOffset = -8.5,
		RotationOffset = 90,
		RotationSpeed = 1000,
	}
	self.TypeToWheelProp[COASTER_NODE_BRAKES] = { 
		Model = Model("models/props_phx/wheels/trucktire2.mdl"),
		DownOffset = -14.5,
		SideOffset = -17,
		RotationOffset = 90,
		RotationSpeed = -120,
	}

end

//Function to get if we are being driven with garry's new drive system
function ENT:IsBeingDriven()
	for _, v in pairs( player.GetAll() ) do
		if v:GetViewEntity() == self then return true end
	end

	return false
end

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

local function IsWithinLoopedRegion( Controller, pivot, index, leftSpread, rightSpread)
	-- Right spread
	if (pivot - #Controller.Nodes + 2 + rightSpread) >= index then return true end 

	-- Left spread
	if (#Controller.Nodes - 2 - leftSpread + pivot <= index ) then return true end

	return false 
end

function ENT:SetOutdated( outdate_type )
	local Controller = self:GetController()
	if not IsValid( Controller ) or not self.NodeIndex then return end
	if self.NodeIndex > #Controller.Nodes or self.NodeIndex < 1 then return end  

	-- If they only want to update this single node, don't bother looping through
	if outdate_type == OUTDATE_ONE then
		self.IsOutdated = true 
		Controller:InvalidatePhysmesh(self.NodeIndex)
	else
		for k, v in pairs( Controller.Nodes ) do
			-- Store the displacement of the index from the calling node
			local indexDiff = self.NodeIndex - k

			if outdate_type == OUTDATE_ALL then
				v.IsOutdated = true 
				Controller:InvalidatePhysmesh(k)
			elseif outdate_type == OUTDATE_LARGE then
				if indexDiff < 3 and indexDiff > -2 or 
				(Controller:GetLooped() and IsWithinLoopedRegion(Controller, self.NodeIndex, k, 3, 2)) then
					v.IsOutdated = true 
					Controller:InvalidatePhysmesh(k)
				end
			elseif outdate_type == OUTDATE_SMALL then
				if indexDiff < 2 and indexDiff > -1 or
					(Controller:GetLooped() and IsWithinLoopedRegion(Controller, self.NodeIndex, k, 2, 1)) then
					v.IsOutdated = true 
					Controller:InvalidatePhysmesh(k)
				end
			end
		end
	end

	if Controller.BuildingMesh || GetConVarNumber("coaster_mesh_autobuild", 1) == 1 && Controller.ResetUpdateMesh then
		Controller:ResetUpdateMesh()
	end

	-- Refresh the clientside physics object for prediction
	Controller:UpdateClientsidePhysics()

	-- Tell the track panel to update itself
	UpdateTrackPanel( controlpanel.Get("coaster_supertool").CoasterList )
end

//Invalid ourselves and nearby affected node
function ENT:Invalidate( controller, minimal_invalidation )
	if !IsValid( controller ) then return end
	if #controller.Nodes < 1 then return end
	print("invalidated something at " .. CurTime())
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
				elseif controller:GetLooped() then
					fourthlastnode.Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(#controller.Nodes-3))
					controller:InvalidatePhysmesh(#controller.Nodes-3)
				end

				if IsValid( controller.Nodes[ k - 2 ] ) && k != 3 then
					controller.Nodes[ k - 2 ].Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(k - 2))
					controller:InvalidatePhysmesh(k-2)
				elseif controller:GetLooped() then
					thirdlastnode.Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(#controller.Nodes-2))
					controller:InvalidatePhysmesh(#controller.Nodes-2)
				end

				if IsValid( controller.Nodes[ k + 1 ] ) && k != #controller.Nodes-2 then
					controller.Nodes[ k + 1 ].Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(k + 1))
					controller:InvalidatePhysmesh(k+1)
				elseif controller:GetLooped() then
					firstnode.Invalidated = true
					//table.insert(controller.InvalidNodes, controller:FindPhysmeshBySegment(2))
					controller:InvalidatePhysmesh(2)
				end

				if controller:GetLooped() && k == #controller.Nodes - 1 then
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
	if !controller:GetIsController() then controller = self:GetController() end
	if !IsValid( controller ) then return end

	for k, v in pairs( controller.Nodes ) do
		if v.Invalidated then return true end
	end

	return false
end

-- Return whether the track has any outdated/unbuilt nodes
function ENT:HasOutdatedNodes()
	local Controller = self:GetController()
	if not IsValid( Controller ) then return false end

	-- Find any outdated nodes
	for _, v in pairs( Controller.Nodes ) do if v.IsOutdated then return true end end

	-- Didn't find any, we're clean!
	return false 
end

-- Create or recreate the support models
function ENT:CreateSupportBase()
	if IsValid( self.SupportModel ) then self.SupportModel:Remove() end 
	if IsValid( self.SupportModelStart ) then self.SupportModelStart:Remove() end 
	if IsValid( self.SupportModelBase ) then self.SupportModelBase:Remove() end 

	 	//Support models
	self.SupportModel 		= ClientsideModel( "models/sunabouzu/coaster_pole.mdl" )
	self.SupportModelStart 	= ClientsideModel( "models/sunabouzu/coaster_pole_start.mdl" )
	self.SupportModelBase 	= ClientsideModel( "models/sunabouzu/coaster_base.mdl" )

	//hide them (shh)
	self.SupportModel:SetNoDraw( true )
	self.SupportModelStart:SetNoDraw( true )
	self.SupportModelBase:SetNoDraw( true )
end

-- Return if we have for real support models on us
function ENT:HasValidSupportModels()
	return IsValid( self.SupportModel ) and IsValid( self.SupportModelStart ) and IsValid( self.SupportModelBase )
end

//Refresh the client spline for track previews and mesh generation
function ENT:RefreshClientSpline()

	--Empty all current splines and nodes
	self.CatmullRom:Reset()
	table.Empty( self.Nodes )
	
	--Set ourselves as the first node as we're used to calculate the track's spline
	self.CatmullRom:AddPointAngle( 1, self:GetPos(), self:GetAngles(), 1.0 ) 
	table.insert( self.Nodes, self )
	self.NodeIndex = 1
	local firstNode = self:GetNextNode()


	if !IsValid(firstNode) then return end
	
	self.CatmullRom:AddPointAngle( 2, firstNode:GetPos(), firstNode:GetAngles(), 1.0 )
	table.insert( self.Nodes, firstNode )
	firstNode.NodeIndex = 1

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
			node.NodeIndex = amt 

			if node.GetNextNode then
				node = node:GetNextNode()

				amt = amt + 1	
			else
				End = true
			end
		else
			End = true
		end
	until (!IsValid(node) || !node.GetIsController || node:GetIsController() || node == firstNode || End)

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
-- Makes it so there isn't a noticable freeze when spawning nodes with coaster_mesh_autobuild 1
-- Will not reset the time if it is called before time is up
function ENT:SoftUpdateMesh()
	if self.BuildQueued then return end

	self.GeneratorThread = nil -- Remove all progress if we were currently generating
	self.BuildQueued = true 
	self.BuildAt = CurTime() + 1 -- TODO: Make this time customizable
end

-- Reset the timer counting down to when to start building the mesh
function ENT:ResetUpdateMesh()
	self.GeneratorThread = nil -- Remove all progress if we were currently generating
	self.BuildQueued = true 
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

-- Reset outdated nodes to be up to date
function ENT:ClearOutdatedNodes()
	if self.Nodes != nil && #self.Nodes > 0 then
		for _, v in pairs( self.Nodes ) do
			if v.IsOutdated then v.IsOutdated = false end 
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
				nodeType = self.Nodes[i]:GetNodeType()

				-- if this type has specific wheel properties, do some wheel cool business
				if self.TypeToWheelProp[ nodeType ] then
					self:WheelModelThink( i, nodeType )
				else

					if nodeType == COASTER_NODE_CHAINS then
						self:DrawSegment( i, CTime )
					end
					
					-- This node doesn't have wheel properties, so it shouldn't have wheels
					if SegmentHasWheels( self, i ) then
						ClearSegmentWheels( self, i )
					end
				end
			end 
		end

		-- Clear the segments of the first and last nodes, just in case
		if SegmentHasWheels( self, 1 ) then
			ClearSegmentWheels( self, 1 )
		end
		if SegmentHasWheels( self, #self.CatmullRom.PointsList-1 ) then
			ClearSegmentWheels( self, #self.CatmullRom.PointsList-1 )
		end

		render.SetMaterial( mat_debug )
		self:DrawInvalidNodes()

	end

end

//Draw invalid nodes, otherwise known as track preview
function ENT:DrawInvalidNodes()
	if self.InvalidNodes == nil then return end
	if LocalPlayer():GetInfoNum("coaster_mesh_previews", 0) == 0 then return end

	for k, v in pairs( self.InvalidNodes ) do
		if IsValid( v ) && v.TrackMesh then v.TrackMesh:Draw() end
	end
	
	-- Draw the side yellow and black beams
	for k, v in pairs( self.Nodes ) do
		-- Don't draw up to date nodes/the last node
		if not v.IsOutdated or k + 1 == #self.Nodes then continue end

		-- If this node is being held or the one before it, draw the sidelines
		if (v.WasBeingHeld or (self.Nodes[k+1] and self.Nodes[k+1].WasBeingHeld)) then 
			DrawSideRail( self, k, -15 )
			DrawSideRail( self, k, 15 )
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

function ENT:WheelModelThink( segment, type )
	if !self.Wheels[segment] then UpdateWheelPositions( self, segment, type ) return end
	if #self.Wheels[segment] < 1 then return end

	-- Make sure this is valid
	type = self.TypeToWheelProp[type] and type or COASTER_NODE_SPEEDUP

	local ang = Angle( 0,0,0)
	local needsUpdate = false
	for _, wheel in pairs( self.Wheels[segment] ) do
		if !IsValid( wheel ) then continue end
		if wheel:GetModel() != self.TypeToWheelProp[type].Model then
			needsUpdate = true
		end

		ang = wheel:GetAngles()
		ang:RotateAroundAxis( ang:Up(), FrameTime() * self.TypeToWheelProp[type].RotationSpeed ) //Rotate the wheel

		wheel:SetAngles(ang )
	end

	if needsUpdate then UpdateWheelPositions( self, segment, type, true ) end

end

--Draw the pre-generated rail mesh
function ENT:DrawRailMesh()

	if !self.BuildingMesh && self.TrackClass then
		self.TrackClass:Draw(self.TrackClass.TrackMeshes)
	else
		if (self.ShouldDrawOutdatedMesh && self.PreviousTrackClass) then self.PreviousTrackClass:Draw(self.PreviousTrackClass.TrackMeshes) end
	end

	//Draw currently-being-built meshes
	if self.ShouldDrawUnfinishedMesh && self.BuildingMesh && self.TrackClass.BuildingTrackMeshes then
		self.TrackClass:DrawUnfinished(self.TrackClass.BuildingTrackMeshes)
	end
	
end

function ENT:UpdateSupportDrawBounds()
	if self:GetIsController() then
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
	if self.GetIsController && self:GetIsController() || controller.Nodes[ #controller.Nodes ] == self then return false end //Don't draw the controller or the very last (unconnected) node
	if math.abs( math.NormalizeAngle( self:GetRoll() ) ) > 90 then return false end //If a track is upside down, don't draw the supports
	if controller:GetLooped() && controller.Nodes[ 2 ] == self then return false end //Don't draw the supports for the second node ONLY if the track is looped

	-- If we don't have valid support models, recreate them someone probably fucked up
	if not self:HasValidSupportModels() then self:CreateSupportBase() end


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

	if self.IsOutdated then
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

-- There's no callback for when a networkvar changes, so let's make one ourselves
function ENT:NetworkVarCallbackThink()
	for _, v in pairs( self.NWVarNotifyFuncs ) do
		-- this just looks so strange
		local val = self[v] and self[v](self)
		local cacheName = "Cached" .. v

		if self[cacheName] ~= val then
			self:OnNetworkVarChanged( v, self[cacheName], val )
			self[cacheName] = val 
		end
	end
end

-- Called when one of our specified network vars changes
-- Used to automatically outdate nodes when stuff changes
function ENT:OnNetworkVarChanged( name, oldval, newval )
	-- May as well use this place to get a callback to when the color changes
	if name == "GetColor" then
		self:DrawSupport()
		return 
	end

	if name == "GetRoll" then 
		self:SetOutdated(OUTDATE_SMALL)
	elseif name == "GetNextNode" then
		local Controller = self:GetController()
		if IsValid( Controller ) then Controller:RefreshClientSpline() end
		self:SetOutdated( OUTDATE_LARGE)
		self:SupportFullUpdate()
	end

	-- shh this is for grownups only go play outside
	if not self:GetIsController() then return end
	if name == "GetTrackColor" or name == "GetTrackType" then
		self:RefreshClientSpline()
		self:SetOutdated(OUTDATE_ALL)
	elseif name == "GetLooped" then
		--self:SetOutdated(OUTDATE_ONE)
	end
end

-- Draw function for the node itself, not related to the track
function ENT:Draw()
	-- Prevent oversized balls
	SetModelScale( self, Vector( 1, 1, 1 ) ) 

	-- Only draw if we have the physgun or toolgun out 
	local wep = LocalPlayer():GetActiveWeapon()
	if not IsValid( wep ) or ( wep:GetClass() ~= "weapon_physgun" and wep:GetClass() ~= "gmod_tool" ) then
		return 
	end

	--If we're in a vehicle ( cart ), don't draw
	if LocalPlayer():InVehicle() then
		return
	end

	-- Also don't draw the first and last nodes
	local controller = self:GetController()
	if ( IsValid( controller ) && controller.Nodes && self == controller.Nodes[ #controller.Nodes ] && #controller.Nodes > 2 ) or self:GetIsController() then //Don't draw if we are the start/end nodes
		return
	end

	-- boom
	self:DrawModel()
end


function ENT:Think()
	-- Before anything, let's check if any useful networkvars changed
	self:NetworkVarCallbackThink()

	--force-invalidate ourselves if we're being driven at all
	if self:IsBeingDriven() && !self.IsOutdated then
		self:SetOutdated( OUTDATE_LARGE )
	end

	-- Let's just have this around
	local Controller = self:GetController() 

	-- Keep track of if we were being held or moved in any way
	if self:GetPos() ~= self.CachedPosition or self:GetVelocity():LengthSqr() > 0 then
		-- Store that we were at this position
		self.CachedPosition = self:GetPos()


		if IsValid( Controller ) then 
			-- So we can see the beams move while me move a node
			Controller:UpdateClientSpline( self.NodeIndex ) 

			-- If we were in the middle the build process, it's probably all bunked up
			if Controller.BuildQueued || GetConVarNumber("coaster_mesh_autobuild") == 1 && self.ResetUpdateMesh then
				Controller:ResetUpdateMesh()
			end

			-- Update wheel positions
			local nodeType = self.GetNodeType and self:GetNodeType() or nil

			UpdateWheelPositions( Controller, self.NodeIndex, nodeType )

			-- Also update it for the one before us so they both update
			local prevNode = Controller.Nodes[self.NodeIndex-1]
			if IsValid( prevNode ) then
				local nodeType = prevNode.GetNodeType and prevNode:GetNodeType() or nil
				UpdateWheelPositions( Controller, prevNode.NodeIndex, nodeType )
			end
		end



		if not self.WasBeingHeld then
			self.WasBeingHeld = true
			self:SetOutdated( OUTDATE_LARGE )

			-- Update support positions
			Controller:SupportFullUpdate() //Update all of the nodes when we let go of the node
		end
	else
		if self.WasBeingHeld then
			self.WasBeingHeld = false 
			self:SetOutdated( OUTDATE_LARGE )
		end
	end

	-- FROM HERE ON OUT ONLY THE CONTROLLER DOES THE THINKIN'
	if !self:GetIsController() then return end

	/*
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
				local nodeType = ( IsValid( node) && node.GetNodeType && node:GetNodeType() ) or nil
				if self.TypeToWheelProp[nodeType] then			
					UpdateWheelPositions( self, num, nodeType )
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
			if self.BuildQueued || GetConVarNumber("coaster_mesh_autobuild") == 1 && self.ResetUpdateMesh then
				self:ResetUpdateMesh()
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
	*/
	-- Check if we are queued to update the mesh
	if self.BuildQueued && CurTime() > self.BuildAt then
		self.BuildQueued = false 
		self:UpdateClientMesh()
	end

	self:UpdateSupportDrawBounds()
end

function ENT:OnRemove()
	if !IsValid( self ) then return end

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

	if self:GetIsController() then
		for _, seg in pairs( self.Wheels ) do
			for _, model in pairs( seg ) do
				if IsValid( model ) then
					model:Remove()
					model = nil
				end
			end
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


//Change callbacks
cvars.AddChangeCallback( "coaster_supports", function()
	//Go through all of the nodes and tell them to update their shit
	for k, v in pairs( ents.FindByClass("coaster_node") ) do
		if IsValid( v ) && v:GetIsController() then
			v:SupportFullUpdate()
		end
	end
end )

//Cache the data so it's not retreiving each frame
cvars.AddChangeCallback( "coaster_mesh_drawoutdatedmesh", function()
	local convar = GetConVar("coaster_mesh_drawoutdatedmesh")
	local bool = convar && convar:GetBool()

	//Go through all of the nodes and tell them to update their shit
	for k, v in pairs( ents.FindByClass("coaster_node") ) do
		if IsValid( v ) && v:GetIsController() then
			v.ShouldDrawOutdatedMesh = bool
		end
	end
end )

//Cache the data so it's not retreiving each frame
cvars.AddChangeCallback( "coaster_mesh_drawunfinishedmesh", function()
	local convar = GetConVar("coaster_mesh_drawunfinishedmesh")
	local bool = convar && convar:GetBool()

	//Go through all of the nodes and tell them to update their shit
	for k, v in pairs( ents.FindByClass("coaster_node") ) do
		if IsValid( v ) && v:GetIsController() then
			v.ShouldDrawUnfinishedMesh = bool
		end
	end
end )

//Cache the data so it's not retreiving each frame
cvars.AddChangeCallback( "coaster_maxwheels", function()
	local num = GetConVarNumber("coaster_maxwheels", 30)

	//Go through all of the nodes and tell them to update their shit
	for k, v in pairs( ents.FindByClass("coaster_node") ) do
		if IsValid( v ) && v:GetIsController() then
			for segment, node in pairs( v.Nodes ) do 
				local nodeType = node:GetNodeType()
				if v.TypeToWheelProp[nodeType] then
					UpdateWheelPositions( v, segment, nodeType, true )
				end
			end
		end
	end
end )

//Refresh the drawbounds of the support models
concommand.Add("coaster_refresh_drawbounds", function()
	for k, v in pairs( CoasterTracks ) do
		if IsValid( v ) then
			v:UpdateSupportDrawBounds()
		end
	end

end )

//Build all coaster's clientside mesh
concommand.Add("coaster_update_mesh", function()
	for _, v in pairs( ents.FindByClass("coaster_node") ) do
		if IsValid( v ) && v:GetIsController() then 
			v:UpdateClientMesh()
		end
	end
	AddNotify( "Updated rollercoaster meshes", NOTIFY_GENERIC, 4 )
end )

//Make doubly sure our client is up to date
concommand.Add("coaster_update_nodes", function() 
	for _, v in pairs( ents.FindByClass("coaster_node") ) do
		if IsValid( v ) && v:GetIsController() then 
			v:RefreshClientSpline()
		end
	end
end)