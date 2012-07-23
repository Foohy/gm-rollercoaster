include("autorun/sh_enums.lua")

local TRACK = {}

TRACK.Name = "Wooden Track"
TRACK.Description = "An old fashioned wooden track. Fancy."
TRACK.Material = Material("phoenix_storms/dome")

//local Offset = 20  //Downwards offset of large center beam
local RailOffset = 25 //Distance track beams away from eachother

TRACK.CylinderRadius = 10 //Radius of the circular track beams
TRACK.CylinderPointCount = 4 //How many points make the cylinder of the track mesh

function TRACK:Generate( controller )
	if !IsValid( controller ) || !controller:IsController() then return end
	local Vertices = {} //Create an array that will hold an array of vertices (This is to split up the model)
	Meshes = {} 

	local modelCount = 1 //how many models the mesh has been split into

	Cylinder.Start( self.CylinderRadius, self.CylinderPointCount ) //We're starting up making a beam of cylinders
	local LastAng = nil //Last angle so previous cylinder matches with the next cylinder

	//For every single spline segment 
	for i = 1, #controller.CatmullRom.Spline do
		//Some useful entities to be references
		local NexterSegment = controller.Nodes[ controller:GetSplineSegment(i) + 2]
		local NextSegment = controller.Nodes[controller:GetSplineSegment(i) + 1]
		local ThisSegment = controller.Nodes[ controller:GetSplineSegment(i) ]

		local AngVec = Vector( 0, 0, 0 )
		local AngVec2 = Vector( 0, 0, 0 )

		//Get the angles from the current spline to next spline
		if #controller.CatmullRom.Spline >= i + 1 then		
			AngVec = controller.CatmullRom.Spline[i] - controller.CatmullRom.Spline[i + 1]
			AngVec:Normalize()
		else
			AngVec = controller.CatmullRom.Spline[i] - controller.CatmullRom.PointsList[ #controller.CatmullRom.PointsList ]
			AngVec:Normalize()
		end

		if #controller.CatmullRom.Spline >= i + 2 then
			AngVec2 = controller.CatmullRom.Spline[i+1] - controller.CatmullRom.Spline[i+2]
			AngVec2:Normalize()
		else
			AngVec2 = AngVec

		end

		local ang = AngVec:Angle()
		local ang2 = AngVec2:Angle()

		//Calculate the roll
		if IsValid( ThisSegment ) && IsValid( NextSegment ) then
			//Get the percent along this node
			local perc = controller:PercAlongNode( i )
			
			//Note all Lerps are negated. This is because the actual roll value from the gun is backwards.
			local Roll = -Lerp( perc, ThisSegment:GetRoll(),NextSegment:GetRoll())	
			if ThisSegment:RelativeRoll() then
				Roll = Roll - ( ang.p - 180 )
			end

			//Rotated around axis
			//This takes roll into account in the angle so far
			ang:RotateAroundAxis( AngVec, Roll ) 

			//Now do it for the segment just ahead of us
			local perc2 = controller:PercAlongNode( i + 1, true ) //We have to do a quickfix so the function can handle how to end the track
			local Roll2 = -Lerp( perc2, ThisSegment:GetRoll(), NextSegment:GetRoll() )
			if ThisSegment:RelativeRoll() then
				Roll2 = Roll2 - ( ang2.p - 180 )
			end
			ang2:RotateAroundAxis( AngVec2, Roll2 )
		end

		//If the current spline is not the very last one
		if i+1 <= #controller.CatmullRom.Spline then
			//Get the positions now so it isn't super mess in the code
			local posL = controller.CatmullRom.Spline[i] + ang:Right() * -RailOffset
			local posR = controller.CatmullRom.Spline[i] + ang:Right() * RailOffset
			local nPosL = controller.CatmullRom.Spline[i+1] + ang2:Right() * -RailOffset
			local nPosR = controller.CatmullRom.Spline[i+1] + ang2:Right() * RailOffset

			//Get the normal 
			local vec = controller.CatmullRom.Spline[i] - controller.CatmullRom.Spline[i+1]
			local vec2 = vec

			//if we are the second to last spline, get the normal
			if #controller.CatmullRom.Spline >= i+2 then
				vec2 = controller.CatmullRom.Spline[i+1] - controller.CatmullRom.Spline[i+2]
			end
			//vec:Normalize() //new
			NewAng = vec:Angle()
			NewAng:RotateAroundAxis( vec:Angle():Right(), 90 )
			NewAng:RotateAroundAxis( vec:Angle():Up(), 270 )

			//if LastAng == nil then LastAng = NewAng end
			//only if LastAng is null do we set to it
			LastAng = LastAng or NewAng

			//Main center beam
			//Cylinder.AddBeam(controller.CatmullRom.Spline[i] + (ang:Up() * -Offset), LastAng, controller.CatmullRom.Spline[i+1] + (ang2:Up() * -Offset), NewAng, Radius )

			//Side rails
			Cylinder.AddBeam( posL, LastAng, nPosL, NewAng, 4 )
			Cylinder.AddBeam( posR, LastAng, nPosR, NewAng, 4 )

			if #Cylinder.Vertices > 50000 then// some arbitrary limit to split up the verts into seperate meshes. It's surprisingly easy to hit that limit

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

	//put the struts into the big vertices table
	if #Vertices > 0 then
		Vertices[#Vertices + 1] = StrutVerts
	end
	//controller.Verts = verts //Only stored for debugging

	for i=1, #Vertices do
		if #Vertices[i] > 2 then
			Meshes[i] = NewMesh()
			Meshes[i]:BuildFromTriangles( Vertices[i] )
		end
	end
end

function TRACK:Draw( controller )
	if !IsValid( controller ) || !controller:IsController() then return end

	if !Meshes || #Meshes < 1 then return end

	for k, v in pairs( Meshes ) do
		render.SetMaterial(self.Material)
		if v then 
			v:Draw() //TODO: I think IMesh resets color modulation upon drawing. Figure out a way around this?
		end
	end

end

//trackmanager.Register( EnumNames.Tracks[COASTER_TRACK_WOOD], TRACK )