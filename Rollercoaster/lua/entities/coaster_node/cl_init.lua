include( "shared.lua" )
include( "mesh_beams.lua")

CoasterBlur = 0.00003 //Blur multiplier
ENT.TrackMatrix = Matrix()
ENT.Spacing = 30 //How many units away each wood track is
ENT.TrackModel = Model("models/props_debris/wood_board06a.mdl")
ENT.PoleHeight = 512 //How tall, in source units, the coaster support poles are
ENT.BaseHeight = 38 //How tall, in source units, the coaster base is
ENT.BuildingMesh = false 
ENT.TrackMeshes = {}

ENT.SupportModel 		= nil
ENT.SupportModelStart 	= nil
ENT.SupportModelBase 	= nil

ENT.Nodes = {}
ENT.CatmullRom = {}

local MatLaser  = Material("cable/hydra")
local MatCable  = Material("cable/cable2")
local mat_beam 	= Material("phoenix_storms/metalfloor_2-3")
local mat_debug	= Material("phoenix_storms/dome") //models/wireframe // phoenix_storms/stripes
local mat_chain = Material("sunabouzu/old_chain") //sunabouzu/old_chain

function ENT:Initialize()
	//Default to being invalidated
	self.Invalidated = true

	if !self:IsController() then return end //Don't continue executing -- the rest of this stuff is for only the controller

	//Create the client side models
	//self.TrackMesh   		= NewMesh()
	self.SupportModel 		= ClientsideModel( "models/sunabouzu/coaster_pole.mdl" )
	self.SupportModelStart 	= ClientsideModel("models/sunabouzu/coaster_pole_start.mdl")
	self.SupportModelBase 	= ClientsideModel( "models/sunabouzu/coaster_base.mdl" )
	
	self.SupportModel:SetPos( Vector( 100000, 10000, -10000000) )
	self.SupportModelStart:SetPos( Vector( 100000, 10000, -10000000) )
	self.SupportModelBase:SetPos( Vector( 100000, 10000, -10000000) )

	//Create the index to hold all compiled track meshes
	self.TrackMeshes = {}
	
	//Material table, to vary the base skin depending on the type of ground it's on
	self.MatSkins = {
		[MAT_DIRT] 		= 0,
        [MAT_CONCRETE] 	= 1,
		[MAT_SAND] 		= 2,
	}
	
	//Track material
	/*
	self.TrackMaterial = CreateMaterial( "OBJMaterial", "UnlitGeneric", {
    ["$basetexture"] = "phoenix_storms/metalfloor_2-3k",
	["$nocull"] = 1,
	["$translucent"] = 1,
	["$vertexalpha"] = 1,
	} )
	*/
	self.TrackMaterial = Material( "sunabouzu/coaster_track")

	//Initialize the clientside list of nodes
	self.Nodes = {}

	//And create the clientside spline controller to govern drawing the spline
	self.CatmullRom = {}
	self.CatmullRom = CoasterManager.Controller:New( self )
	//self.CatmullRom.STEPS = 20
	self.CatmullRom:Reset()

end

usermessage.Hook("Coaster_RefreshTrack", function( um )
	self = um:ReadEntity()
	
	if self:IsController() then
		//self:SetupTrack()
		self:RefreshClientSpline()
		//self:UpdateClientMesh()
	end	

end )

usermessage.Hook("Coaster_CartFailed", function( um )
	local needed = um:ReadChar() or 0
	GAMEMODE:AddNotify("Need " .. needed .. " more nodes to create track!", NOTIFY_ERROR, 3 )
end )

usermessage.Hook("Coaster_AddNode", function( um )
	local self = Entity(um:ReadShort())
	/*local node = Entity(um:ReadShort())

	if self.Nodes == nil then self.Nodes = {} end
	//table.insert( self.Nodes, node )
	if (self.Nodes == nil ) then 
		self.Nodes = {}
		self.Nodes[1] = node 
	else
		self.Nodes[ #self.Nodes + 1] = node 
	end*/
	if !self.IsController then return end //Shared functions don't exist yet.

	if (self:IsController()) then
		//self:SetupTrack()
		self:RefreshClientSpline()
		//self:UpdateClientMesh()
		
		//Invalidate nearby nodes
		if self.Nodes != nil then
			last = #self.Nodes

			if IsValid( self.Nodes[ last ] ) then
				self.Nodes[ last ].Invalidated = true
			end
			if IsValid( self.Nodes[ last - 1 ] ) then
				self.Nodes[ last - 1 ].Invalidated = true
			end
			if IsValid( self.Nodes[ last - 2 ] ) then
				self.Nodes[ last - 2 ].Invalidated = true
			end
			if IsValid( self.Nodes[ last - 3 ] ) then
				self.Nodes[ last - 3 ].Invalidated = true
			end
		end
	end
end )

usermessage.Hook("Coaster_nodeinvalidate", function( um )
	local controller = um:ReadEntity()
	local node	 = um:ReadEntity()
	local inval_minimal = um:ReadBool() //Should we only invalidate the node before this one?

	if !IsValid( controller ) or !IsValid( node ) then return end
	if #controller.Nodes < 1 then return end

	for k, v in pairs( controller.Nodes ) do
		if v == node then
			if inval_minimal then
				v.Invalidated = true

				if IsValid( controller.Nodes[ k - 1 ] ) then
					controller.Nodes[ k - 1 ].Invalidated = true
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

				if IsValid( controller.Nodes[ k - 1 ] ) && k != 2 then
					controller.Nodes[ k - 1 ].Invalidated = true
				elseif controller:Looped() then
					fourthlastnode.Invalidated = true
				end

				if IsValid( controller.Nodes[ k - 2 ] ) && k != 3 then
					controller.Nodes[ k - 2 ].Invalidated = true
				elseif controller:Looped() then
					thirdlastnode.Invalidated = true
				end

				if IsValid( controller.Nodes[ k + 1 ] ) && k != #controller.Nodes-2 then
					controller.Nodes[ k + 1 ].Invalidated = true
				elseif controller:Looped() then
					firstnode.Invalidated = true
				end

				if controller:Looped() && k == #controller.Nodes - 1 then
					firstnode.Invalidated = true
					secondnode.Invalidated = true
				end

			end

			return
		end
	end

end )

function ENT:RefreshClientSpline()
	self.CatmullRom:Reset()
	table.Empty( self.Nodes )
	
	self.CatmullRom:AddPointAngle( 1, self:GetPos(), self:GetAngles(), 1.0 ) //Set ourselves as the first node as we're used to calculate the track's spline
	table.insert( self.Nodes, self )
	local firstNode = self:GetFirstNode()

	if !IsValid(firstNode) then return end
	
	self.CatmullRom:AddPointAngle( 2, firstNode:GetPos(), firstNode:GetAngles(), 1.0 )
	table.insert( self.Nodes, firstNode )
	local node = firstNode:GetNextNode()
	if !IsValid(node) then return end

	local amt = 3
	local End = false
	repeat
		if node:GetClass() == "coaster_node" && node:EntIndex() != 0 then

			self.CatmullRom:AddPointAngle( amt, node:GetPos(), node:GetAngles(), 1.0 )
			table.insert( self.Nodes, node )
			//print("ADDED POINT: " .. tostring(node) .. ", " .. tostring(amt) .. ", Index: " .. node:EntIndex() .. "\n")
			node = node:GetNextNode()

			amt = amt + 1		
		else
			End = true
		end
	until (!IsValid(node) || node == firstNode || End)
	
	/*for i=1, #self.Nodes do
		if IsValid( self.Nodes[i] ) then
			self.CatmullRom:AddPointAngle( i, self.Nodes[i]:GetPos(), self.Nodes[i]:GetAngles(), 1.0 )
		end
	end*/

	if #self.CatmullRom.PointsList > 3 then
		self.CatmullRom:CalcEntireSpline()
	end
	//print(#self.CatmullRom.PointsList)
end

function ENT:UpdateClientSpline()
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
	
	self.CatmullRom:CalcEntireSpline()
end

concommand.Add("update_mesh", function()
	for _, v in pairs( ents.FindByClass("coaster_node") ) do
		if IsValid( v ) && v:IsController() then 
			v:UpdateClientMesh()
			//v:UpdateMesh()
			//PrintTable( v.Nodes )
		end
	end
end )

//Give spline index, return percent of a node
function ENT:PercAlongNode(spline, qf)
	while spline >= self.CatmullRom.STEPS do
		spline = spline - self.CatmullRom.STEPS
	end
	if qf && spline == 0 then return 1 end
	return spline / self.CatmullRom.STEPS
end


function ENT:UpdateClientMesh()
	print("Building clientside mesh...")
	local StrutOffset = 2 //Space between coaster struts
	local Offset = 20
	local RailOffset = 25
	local Radius = 10
	local PointCount = 7
	local modelCount = 1

	if #self.CatmullRom.PointsList > 3 then
		self.BuildingMesh = true //Tell the mesh to stop drawing because we're gonna rebuild it

		//Destroy ALL meshes
		for k,v in pairs( self.TrackMeshes ) do
			if IsValid ( v ) then
				v:Destroy() 
				v = nil
			end
		end

		local Vertices = {} //Create an array that will hold an array of vertices (This is to split up the model)

		Cylinder.Start( Radius, PointCount ) //We're starting up making a beam of cylinders
		local LastAng = nil
		for i = 1, #self.CatmullRom.Spline do
			local NexterSegment = self.Nodes[ self:GetSplineSegment(i) + 2]
			local NextSegment = self.Nodes[self:GetSplineSegment(i) + 1]
			local ThisSegment = self.Nodes[ self:GetSplineSegment(i) ]

			local AngVec = Vector( 0, 0, 0 )
			local AngVec2 = Vector( 0, 0, 0 )

			if #self.CatmullRom.Spline >= i + 1 then		
				AngVec = self.CatmullRom.Spline[i] - self.CatmullRom.Spline[i + 1]
				AngVec:Normalize()
			else
				AngVec = self.CatmullRom.Spline[i] - self.CatmullRom.PointsList[ #self.CatmullRom.PointsList ]
				AngVec:Normalize()
			end

			if #self.CatmullRom.Spline >= i + 2 then
				AngVec2 = self.CatmullRom.Spline[i+1] - self.CatmullRom.Spline[i+2]
				AngVec2:Normalize()
			else
				AngVec2 = AngVec

			end

			//print(tostring(AngVec) .. tostring(AngVec2))

			local ang = AngVec:Angle()
			local ang2 = AngVec2:Angle()
			if IsValid( ThisSegment ) && IsValid( NextSegment ) then
				//Get the percent along this node
				//local perc = (i % self.CatmullRom.STEPS) / self.CatmullRom.STEPS
				local perc = self:PercAlongNode( i )

				//local Roll = Lerp( perc, ThisSegment:GetAngles().r,NextSegment:GetAngles().r )	
				local Roll = Lerp( perc, ThisSegment:GetRoll(),NextSegment:GetRoll())	
				if ThisSegment:RelativeRoll() then
					//Roll = Roll + ang.p
					Roll = Roll - ( ang.p - 180 )
				end
				//print(Roll .. " at:" .. i)
				ang:RotateAroundAxis( AngVec, Roll ) //Segment:GetAngles().r

				//For shits and giggles get it for this one too
				local perc2 = self:PercAlongNode( i + 1, true )
				//perc2 = (((i + 1) % self.CatmullRom.STEPS) / self.CatmullRom.STEPS )
				//if ((i + 1) % 10 ) == 0 then perc2 = 1 end //quick fix
				local Roll2 = Lerp( perc2, ThisSegment:GetRoll(), NextSegment:GetRoll() )
				if ThisSegment:RelativeRoll() then
					Roll2 = Roll2 - ( ang2.p - 180 )
				end
				ang2:RotateAroundAxis( AngVec2, Roll2 )
			end


			if #self.CatmullRom.Spline >= i+1 then
				local posL = self.CatmullRom.Spline[i] + ang:Right() * -RailOffset
				local posR = self.CatmullRom.Spline[i] + ang:Right() * RailOffset
				local nPosL = self.CatmullRom.Spline[i+1] + ang2:Right() * -RailOffset
				local nPosR = self.CatmullRom.Spline[i+1] + ang2:Right() * RailOffset

				local vec = self.CatmullRom.Spline[i] - self.CatmullRom.Spline[i+1]

				local vec2 = vec

				if #self.CatmullRom.Spline >= i+2 then
					vec2 = self.CatmullRom.Spline[i+1] - self.CatmullRom.Spline[i+2]
				end
				//vec:Normalize() //new
				NewAng = vec:Angle()
				NewAng:RotateAroundAxis( vec:Angle():Right(), 90 )
				NewAng:RotateAroundAxis( vec:Angle():Up(), 270 )

				if LastAng == nil then LastAng = NewAng end

				//vec:ANgle()
				Cylinder.AddBeam(self.CatmullRom.Spline[i] + (ang:Up() * -Offset), LastAng, self.CatmullRom.Spline[i+1] + (ang2:Up() * -Offset), NewAng, Radius )

				//Side rails
				Cylinder.AddBeam( posL, LastAng, nPosL, NewAng, 4 )
				Cylinder.AddBeam( posR, LastAng, nPosR, NewAng, 4 )

				if #Cylinder.Vertices > 50000 then// some arbitrary limit to split up the verts into seperate meshes

					Vertices[modelCount] = Cylinder.Vertices
					modelCount = modelCount + 1
					print( modelCount )

					Cylinder.Vertices = {}
					Cylinder.TriCount = 1
				end
				LastAng = NewAng
			end
		end	

		local verts = Cylinder.EndBeam()
		Vertices[modelCount] = verts

		//Stage 2, create the struts in between the coaster rails
		local CurSegment = 2
		local Percent = 0
		local Multiplier = 1
		local StrutVerts = {} //mmm yeah strut those verts

		while CurSegment < #self.CatmullRom.PointsList - 1 do
			local CurNode = self.Nodes[CurSegment]
			local NextNode = self.Nodes[CurSegment + 1]

			local Position = self.CatmullRom:Point(CurSegment, Percent)

			local ang = self:AngleAt(CurSegment, Percent)

			//Change the roll depending on the track
			local Roll = Lerp( Percent, CurNode:GetRoll(), NextNode:GetRoll())	
			
			//Set the roll for the current track peice
			ang.r = Roll
			//ang:RotateAroundAxis( self:AngleAt(CurSegment, Percent), Roll ) //BAM

			//Now... manage moving throughout the track evenly
			//Each spline has a certain multiplier so the cart travel at a constant speed throughout the track
			Multiplier = self:GetMultiplier(CurSegment, Percent)

			//Move ourselves forward along the track
			Percent = Percent + ( Multiplier * StrutOffset )

			//Manage moving between nodes
			if Percent > 1 then
				CurSegment = CurSegment + 1
				if CurSegment > #self.Nodes - 2 then 			
					break
				end	
				Percent = 0
			end
			local verts = self:CreateStrutsMesh(Position, ang)
			table.Add( StrutVerts, verts ) //Combine the tables into da big table
		end

		//put the struts into the big vertices table
		if #Vertices > 0 then
			Vertices[#Vertices + 1] = StrutVerts
		end
		//self.Verts = verts //Only stored for debugging

		for i=1, #Vertices do
			if #Vertices[i] > 2 then
				self.TrackMeshes[i] = NewMesh()
				self.TrackMeshes[i]:BuildFromTriangles( Vertices[i] )
			end
		end
		self:ValidateNodes()
		self.BuildingMesh = false
	end
end

//Get the angle at a specific point on a track
function ENT:AngleAt(i, perc )
	local Vec1 = self.CatmullRom:Point( i, perc )
	local Vec2 = self.CatmullRom:Point( i, perc + 0.03 )

	local AngVec = Vector(0,0,0)


	AngVec = Vec1 - Vec2

	return AngVec:Normalize():Angle()
end

//Set invalid nodes to valid (for when the mesh is first built
function ENT:ValidateNodes()
	if self.Nodes != nil && #self.Nodes > 0 then
		for _, v in pairs( self.Nodes ) do
			if v.Invalidated then v.Invalidated = false end 
		end
	end
end

//Get the multiplier for the current spline (to make things smooth )
function ENT:GetMultiplier(i, perc)
	local Dist = 1
	local Vec1 = self.CatmullRom:Point( i, perc )
	local Vec2 = self.CatmullRom:Point( i, perc + 0.03 )

	Dist = Vec1:Distance( Vec2 )
	
	return 1 / Dist 
end

//I can't retrieve the triangles from a compiled model, SO LET'S MAKE OUR OWN
function ENT:CreateStrutsMesh(pos, ang)
	local width = 5
	local Offset = 15
	local RailOffset = 25

	//Front tri
	local F_Right = pos + ang:Right() * RailOffset
	local F_Bottom = pos + ang:Up() * -Offset
	local F_Left = pos + ang:Right() * -RailOffset

	//Back tri
	local B_Right = F_Right + ( ang:Forward() * width )
	local B_Bottom = F_Bottom + ( ang:Forward() * width )
	local B_Left = F_Left + ( ang:Forward() * width )

	local Vertices = {}

	//Vars to get the proper normal of the left/right bits of the struts
	local angLeft = F_Bottom - F_Left
	angLeft:Normalize()
	local angRight = F_Bottom - F_Right
	angRight:Normalize()

	local NormTop = ang:Up()
	local NormFwd = -ang:Forward()
	local NormBkwd = ang:Forward()
	local NormLeft = angLeft
	local NormRight = angRight

	local norm = Vector( 0, 0, 1)

	//Front triangle
	Vertices[1] = {
		pos = F_Right,
		normal = NormFwd,
		u = 0,
		v = 0
	}
	Vertices[2] = {
		pos = F_Bottom,
		normal = NormFwd,
		u = 0.5,
		v = 1
	}
	Vertices[3] = {
		pos = F_Left,
		normal = NormFwd,
		u = 1,
		v = 0
	}

	//Back triangle
	Vertices[4] = {
		pos = B_Left,
		normal = NormBkwd,
		u = 0,
		v = 0
	}
	Vertices[5] = {
		pos = B_Bottom,
		normal = NormBkwd,
		u = 0.5,
		v = 1
	}
	Vertices[6] = {
		pos = B_Right,
		normal = NormBkwd,
		u = 1,
		v = 0
	}

	//Top Quad
	Vertices[7] = {
		pos = B_Left,
		normal = NormTop,
		u = 0,
		v = 0
	}
	Vertices[8] = {
		pos = B_Right,
		normal = NormTop,
		u = 0.5,
		v = 1
	}
	Vertices[9] = {
		pos = F_Right,
		normal = NormTop,
		u = 1,
		v = 0
	}

	Vertices[10] = {
		pos = F_Right,
		normal = NormTop,
		u = 0,
		v = 0
	}
	Vertices[11] = {
		pos = F_Left,
		normal = NormTop,
		u = 0.5,
		v = 1
	}
	Vertices[12] = {
		pos = B_Left,
		normal = NormTop,
		u = 1,
		v = 0
	}

	//Left Quad
	Vertices[13] = {
		pos = F_Bottom,
		normal = NormLeft,
		u = 0,
		v = 0
	}
	Vertices[14] = {
		pos = B_Bottom,
		normal = NormLeft,
		u = 0.5,
		v = 1
	}
	Vertices[15] = {
		pos = B_Left,
		normal = NormLeft,
		u = 1,
		v = 0
	}

	Vertices[16] = {
		pos = B_Left,
		normal = NormLeft,
		u = 0,
		v = 0
	}
	Vertices[17] = {
		pos = F_Left,
		normal = NormLeft,
		u = 0.5,
		v = 1
	}
	Vertices[18] = {
		pos = F_Bottom,
		normal = NormLeft,
		u = 1,
		v = 0
	}

	//Right Quad
	Vertices[19] = {
		pos = F_Bottom,
		normal = NormRight,
		u = 0,
		v = 0
	}
	Vertices[20] = {
		pos = F_Right,
		normal = NormRight,
		u = 0.5,
		v = 1
	}
	Vertices[21] = {
		pos = B_Right,
		normal = NormRight,
		u = 1,
		v = 0
	}

	Vertices[22] = {
		pos = B_Right,
		normal = NormRight,
		u = 0,
		v = 0
	}
	Vertices[23] = {
		pos = B_Bottom,
		normal = NormRight,
		u = 0.5,
		v = 1
	}
	Vertices[24] = {
		pos = F_Bottom,
		normal = NormRight,
		u = 1,
		v = 0
	}


	return Vertices
end

function ENT:GetTrackDistance() //Gets the distance along the track
	if #self.Nodes < 2 then return 0 end
	
	local dist = 0
	for k, v in pairs(self.Nodes) do
		if IsValid( v ) && IsValid( self.Nodes[ k + 1 ] )then
			dist = dist + (v:GetPos():Distance( self.Nodes[ k + 1] ) )
		end
	end
	
	return dist
end

function ENT:FarthestNodeDist()
	local LargestDist = 0
	local Ent = nil
	for k, v in pairs( self.Nodes ) do
		local dist = self:GetPos():Distance( v:GetPos() )
		if dist > LargestDist then
			LargestDist = dist
			Ent = v
		end
	end
	if IsValid( Ent ) then return Ent:GetPos() end
	return nil
end

function ENT:GetSplineSegment(spline) //Get the segment of the given spline
	local STEPS = self.CatmullRom.STEPS
	
	return math.floor( spline / STEPS ) + 2
end

function ENT:DrawTrack()
	if self.CatmullRom == nil then return end //Shit

	if #self.CatmullRom.PointsList > 3 then
		local CTime = CurTime()
		
		for i = 2, (#self.CatmullRom.PointsList - 2) do
			if IsValid( self.Nodes[i] ) && self.Nodes[i]:HasChains() then
				render.SetMaterial( mat_chain ) //mat_chain
				self:DrawSegment( i, CTime )
			end 
		end
		
		/*
		render.StartBeam(#self.CatmullRom.Spline)
		render.AddBeam(self.CatmullRom.PointsList[2], 10, CTime, Color( 64, 255, 64, 255 ))
		*
		for i = 1, #self.CatmullRom.Spline do*/
			/*
			if IsValid(self.Nodes[self:GetSplineSegment( i )]) &&self.Nodes[self:GetSplineSegment( i )].HasChains then
				render.SetMaterial( Chain )
				render.DrawSprite( self.CatmullRom.Spline[i], 16, 16, color_white )
				render.SetMaterial( MatLaser )
			else
				render.SetColorModulation( 1, 1, 1 )
			end
			*//*
			render.AddBeam(self.CatmullRom.Spline[i], 10, CTime, Color(64,255,64,255) )
		end	
		render.AddBeam(self.CatmullRom.PointsList[#self.CatmullRom.PointsList], 10, CTime, Color(64, 255, 64, 255 ))
		render.EndBeam()
		render.SetColorModulation( 1, 1, 1 )
		*/
		
		
		//Draw the actual tracks



		//self:DrawRail( 25 )
		//self:DrawRail( -25 )

		render.SetMaterial( mat_debug )
		self:DrawRailMesh()

		render.SetMaterial( MatLaser )
		self:DrawInvalidNodes()		

		//Draw the supports
		self:DrawSupports()

	end

end

function ENT:DrawInvalidNodes()
	if self.Nodes == nil then return end
	
	for k, v in pairs( self.Nodes ) do
		if v.Invalidated && k + 1 < #self.Nodes then //Don't draw the last node
			self:DrawSideRail( k, -15 )
			self:DrawSideRail( k, 15 )
		end
	end

end

function ENT:DrawSegment(segment)
	if not (segment > 1 && (#self.CatmullRom.PointsList > segment )) then return end
	if self.CatmullRom.Spline == nil or #self.CatmullRom.Spline < 1 then return end
	
	local MULTIPLIER = 4
	local node = (segment - 2) * self.CatmullRom.STEPS
	local Dist = 0
	//Draw the main Rail
	render.StartBeam( self.CatmullRom.STEPS )
	render.AddBeam(self.CatmullRom.PointsList[segment], 32, Dist, color_white) //time or 1

	for i = 1, (self.CatmullRom.STEPS) do
		if i==1 then
			Dist = Dist - self.CatmullRom.Spline[node + 1]:Distance( self.CatmullRom.PointsList[segment] ) 
		else
			Dist = Dist - self.CatmullRom.Spline[node + i]:Distance( self.CatmullRom.Spline[node + i - 1] ) 
		end
		render.AddBeam(self.CatmullRom.Spline[node + i],32, Dist*0.05, color_white)
	end
	
	Dist = Dist - self.CatmullRom.PointsList[ segment + 1]:Distance( self.CatmullRom.Spline[ node + self.CatmullRom.STEPS ] )
	render.AddBeam(self.CatmullRom.PointsList[segment + 1], 32, Dist*0.05, color_white)
	render.EndBeam()

end

function ENT:DrawSupports()
	if LocalPlayer():GetInfoNum("coaster_supports") == 0 then return end

	for k, v in pairs( self.Nodes ) do
		local cont = true

		if IsValid( v ) then
			if v:IsController() || k == #self.Nodes then cont = false end //Don't draw the controller or the very last (unconnected) node
			if math.NormalizeAngle(v:GetRoll()) > 90 || math.NormalizeAngle(v:GetRoll()) < -90 then cont = false end //If a track is upside down, don't draw the supports
		else
	 		cont = false 
		end

		if cont then
			self.SupportModel:SetNoDraw( false )
			self.SupportModelStart:SetNoDraw( false )
			self.SupportModelBase:SetNoDraw( false )
				
			local dist = 100000
			trace = {}

				trace.start  = v:GetPos()
				trace.endpos = v:GetPos() - Vector( 0, 0, dist ) //Trace straight down
				trace.filter = v
				trace.mask = MASK_SOLID_BRUSHONLY
				trace = util.TraceLine(trace)
				
			local Distance = v:GetPos():Distance( trace.HitPos + Vector( 0, 0, self.BaseHeight) )
			//Set their colors
			local color = v:GetColor()
			
			if v.Invalidated then
				color.r = 255
				color.g = 0
				color.b = 0
			end
			render.SetColorModulation( color.r / 255, color.g / 255, color.b / 255)

			//Draw the first pole
			self.SupportModelStart:SetRenderOrigin( trace.HitPos + Vector( 0, 0, self.BaseHeight ) ) //Add 64 units so it's right on top of the base

			local height = math.Clamp( Distance, 1, self.PoleHeight + self.BaseHeight )
			self.SupportModelStart:SetModelScale( Vector( 1, 1, height / self.PoleHeight ) )
			self.SupportModelStart:SetAngles( Angle( 0, v:GetAngles().y, 0 ) )
			self.SupportModelStart:SetupBones()
			self.SupportModelStart:DrawModel()
				
			//Draw the second pole (if applicable)
			if Distance > self.PoleHeight + self.BaseHeight then
				self.SupportModel:SetRenderOrigin( trace.HitPos + Vector(0, 0, self.PoleHeight + self.BaseHeight ))
				self.SupportModel:SetModelScale( Vector( 1, 1, ((Distance - self.PoleHeight) / self.PoleHeight)   ) )
				self.SupportModel:SetAngles( Angle( 0, v:GetAngles().y, 0 ) )				
				self.SupportModel:SetupBones()	
				self.SupportModel:DrawModel()
			end
				
			local skin = self.MatSkins[trace.MatType]
			//render.SetMaterial( skin or table.GetFirstValue(self.MatSkins) )

			render.SetColorModulation( 1, 1, 1 )
			self.SupportModelBase:SetSkin( skin or 1 )
			self.SupportModelBase:SetRenderOrigin( trace.HitPos )
			self.SupportModelBase:SetAngles( Angle( 0, v:GetAngles().y, 0 ) )
			self.SupportModelBase:SetupBones()
			self.SupportModelBase:DrawModel()

		end
	end
	
	self.SupportModel:SetNoDraw( true )
	self.SupportModelStart:SetNoDraw( true )
	self.SupportModelBase:SetNoDraw( true )
	
end


function ENT:DrawSideRail( segment, offset )
	if not (segment > 1 && (#self.CatmullRom.PointsList > segment )) then return end
	local node = (segment - 2) * self.CatmullRom.STEPS
	local NextSegment = self.Nodes[ segment + 1 ]
	local ThisSegment = self.Nodes[ segment ]
	self.RailU = self.RailU or 0
	local AngVec = Vector(0,0,0)
	local ang = Angle( 0, 0, 0 )
	render.StartBeam( self.CatmullRom.STEPS + 1 )

	//Very first beam position
	AngVec = self.CatmullRom.PointsList[segment] - self.CatmullRom.Spline[1]
	AngVec:Normalize()
	
	self.RailU = self.RailU + self.CatmullRom.PointsList[segment]:Distance( self.CatmullRom.Spline[1] )
	render.AddBeam( self.CatmullRom.PointsList[segment] + AngVec:Angle():Right() * -offset, 10, self.RailU*0.05, Color( 255, 0, 0 ) )
	
	//Draw the beams in between
	for i=1, self.CatmullRom.STEPS do
		if i < self.CatmullRom.STEPS then
			AngVec = self.CatmullRom.Spline[node + i] - self.CatmullRom.Spline[node + i + 1]
			AngVec:Normalize()
			ang = AngVec:Angle()

			self.RailU = self.RailU + self.CatmullRom.Spline[node + i]:Distance( self.CatmullRom.Spline[node + i + 1] )

			if IsValid( ThisSegment ) && IsValid( NextSegment ) then
				//Get the percent along this node
				perc = (i % self.CatmullRom.STEPS) / self.CatmullRom.STEPS
				//local Roll = Lerp( perc, ThisSegment:GetAngles().r,NextSegment:GetAngles().r )	
				local Roll = Lerp( perc, ThisSegment:GetRoll(),NextSegment:GetRoll())	
				ang:RotateAroundAxis( AngVec, Roll ) //Segment:GetAngles().r
			end
		end

		render.AddBeam(self.CatmullRom.Spline[node + i] + ang:Right() * offset, 10, self.RailU*0.05, Color( 255, 0, 0 ) )
	end
	
	//Draw the final beam pos
	//AngVec = self.CatmullRom.PointsList[segment + 1] - self.CatmullRom.Spline[self.CatmullRom.STEPS]
	//AngVec:Normalize()
	//render.AddBeam( self.CatmullRom.PointsList[segment + 1] + AngVec:Angle():Right() * offset, 10, 1, color_white  )	

	render.EndBeam()
	//local pos = self.CatmullRom.Spline[i] + AngVec:Angle():Right() * -nOffset
end


function ENT:DrawRailMesh()
	//Set their colors
	local r, g, b = self:GetTrackColor()


	if self.TrackMeshes != nil && #self.TrackMeshes > 0 && !self.BuildingMesh then
		for k, v in pairs( self.TrackMeshes ) do
			render.SetColorModulation( r / 255, g / 255, b / 255)
			v:Draw() //TODO: I think IMesh resets color modulation upon drawing. Figure out a way around this?
			render.SetColorModulation( 1, 1, 1)
		end
		
	end
	
end

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
			local Roll = Lerp( perc, ThisSegment:GetRoll(),NextSegment:GetRoll())	
			ang:RotateAroundAxis( AngVec, Roll ) //Segment:GetAngles().r
		end
			
		local pos = self.CatmullRom.Spline[i] + ang:Right() * -nOffset

		render.AddBeam(pos, 4, 6, color_white )
	end	
	render.EndBeam()
end

function ENT:GetController()
	if self:IsController() then return self end

	for _, v in pairs( ents.FindByClass( self:GetClass() )) do
		if v:IsController() then
			if v.Nodes && #v.Nodes > 0 then
				for _, node in pairs( v.Nodes ) do
					if node == self then
						return v
					end
				end
			end
		end
	end

end

function ENT:Draw()
	if !LocalPlayer():InVehicle() then
		self:DrawModel()
	end
end

function ENT:Think()
	if !self:IsController() then return end
	
	for k, v in pairs( self.Nodes ) do	
		if IsValid( v ) && v:GetVelocity():Length() > 0 then
			self:UpdateClientSpline() //So we can see the beams move while me move a node
			//self:UpdateClientMesh() //Update the mesh itself
			break
		end
	end
end

function ENT:OnRemove()
	if IsValid( self ) && self:IsController() then
		self:UpdateClientSpline()
	end
end

local function GetMotionBlurValues( x, y, fwd, spin )
	if IsValid(LocalPlayer():GetVehicle()) && IsValid(LocalPlayer():GetVehicle():GetParent()) then
		return x, y, LocalPlayer():GetVehicle():GetParent():GetVelocity():Length() * CoasterBlur, spin //HOLY SHIT
	else
		return x, y, fwd, spin
	end
end
hook.Add( "GetMotionBlurValues", "Coaster_motionblur", GetMotionBlurValues )







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