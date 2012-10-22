/*
	This is a render.Addbeam() equivalent for cylinder meshes, 
	and it returns the vertices in triangles to be put into a mesh manually.

	This is just to make creating meshes easier

	NOTE: This is not meant to run real-time. It returns the vertices for use with an IMesh
*/
AddCSLuaFile("mesh_beams.lua")
Cylinder = {}


function Cylinder.Start(Radius, Num)

	Cylinder.Vertices = {} //Table holding all of the current vertices in the correct format

	Cylinder.CurVerts = {} //Holding the verts at the start of a cylinder
	Cylinder.NextVerts = {} //holding all the verts at the end of a cylinder

	Cylinder.Radius = Radius //Radius of the points
	Cylinder.Count  = Num //Number of points

	Cylinder.TriCount = 1 //Number of current vertices
	Cylinder.TotalU = 0
	Cylinder.TotalV = 0



end

local function CreateSquare( P1, P2, P3, P4, Normal, TrackColor )	//BACKRIGHT, BACKLEFT, FRONT LEFT, FRONT RIGHT
	local u = P1:Distance( P2 ) / 200
	local v = P2:Distance( P3 ) / 200

	//Create some variables for proper lightmapped color
	local colVec = Vector( 0, 0, 0 )

	//And the user selected color too
	local SelectedColor = Vector( 1, 1, 1 )
	if TrackColor then
		SelectedColor = Vector( TrackColor.r / 255, TrackColor.g / 255, TrackColor.b / 255 ) 
	end
	
	//Create the 6 verts that make up a single quad
	colVec = render.ComputeLighting( P1, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P1, Normal)
	Cylinder.Vertices[Cylinder.TriCount] = { 
		pos = P1, 
		normal = Normal, 
		u = u,
		v = 0,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	Cylinder.TriCount = Cylinder.TriCount + 1

	colVec = render.ComputeLighting( P2, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P2, Normal)
	Cylinder.Vertices[Cylinder.TriCount] = { 
		pos = P2, 
		normal = Normal, 
		u = 0,
		v = 0,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	Cylinder.TriCount = Cylinder.TriCount + 1

	colVec = render.ComputeLighting( P3, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P3, Normal )
	Cylinder.Vertices[Cylinder.TriCount] = { 
		pos = P3, 
		normal = Normal, 
		u = 0,
		v = v,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	Cylinder.TriCount = Cylinder.TriCount + 1
	
	


	//Second tri
	colVec = render.ComputeLighting( P3, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P3, Normal )
	Cylinder.Vertices[Cylinder.TriCount] = { 
		pos = P3, 
		normal = Normal, 
		u = 0,
		v = v,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	Cylinder.TriCount = Cylinder.TriCount + 1

	colVec = render.ComputeLighting( P4, Normal )
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P4, Normal )
	Cylinder.Vertices[Cylinder.TriCount] = { 
		pos = P4, 
		normal = Normal, 
		u = u,
		v = v,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	Cylinder.TriCount = Cylinder.TriCount + 1

	colVec = render.ComputeLighting( P1, Normal)
	colVec = colVec + render.GetAmbientLightColor()
	colVec = colVec + render.ComputeDynamicLighting(P1, Normal )
	Cylinder.Vertices[Cylinder.TriCount] = { 
		pos = P1, 
		normal = Normal, 
		u = u,
		v = 0,
		color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
	}
	Cylinder.TriCount = Cylinder.TriCount + 1
	
end

local function Point( Position, Ang, Offset, Corner )
	local ang = Angle(Ang.p,Ang.y,Ang.r)
	ang:RotateAroundAxis(ang:Up(), (90 * (Corner-1)) + 45 )
	return Position + (ang:Right() * Offset)
end

function Cylinder.AddBeamSquare( Pos1, Ang1, Pos2, Ang2, Width, TrackColor )
	if Pos1 == nil || Ang1 == nil || Pos2 == nil || Ang2 == nil then 
		print("FAILED TO CREATE CYLINDER, NIL VALUE")
		return
	end

	Cylinder.Radius = Width or Cylinder.Radius

	local offset = math.sqrt( 2 * math.pow(Width/2, 2) )

	//Calculate the positions
	local TopFrontLeft = Point(Pos1, Ang1, Width, 1 ) //Pos1 + Point( Vector( -offset, offset, 0), Ang1 ) // Vector( -offset, offset, 0)
	local TopFrontRight = Point(Pos1, Ang1, Width, 4 )//Pos1 + Point( Vector( offset, offset, 0), Ang1 ) //Vector( offset, offset, 0)
	local TopBackLeft = Point(Pos1, Ang1, Width, 2 )//Pos1 + Point( Vector( -offset, -offset, 0), Ang1 ) //Vector( -offset, -offset, 0)
	local TopBackRight = Point(Pos1, Ang1, Width, 3 )//Pos1 + Point( Vector( offset, -offset, 0), Ang1 ) //Vector( offset, -offset, 0)
 
	local BottomFrontLeft = Point(Pos2, Ang2, Width, 1 )//Pos2 + Vector( -offset, offset, 0)
	local BottomFrontRight = Point(Pos2, Ang2, Width, 4 )// Pos2 + Vector( offset, offset, 0)
	local BottomBackLeft = Point(Pos2, Ang2, Width, 2 )//Pos2 + Vector( -offset, -offset, 0)
	local BottomBackRight = Point(Pos2, Ang2, Width, 3 )//Pos2 + Vector( offset, -offset, 0)

	//Calculate normals
	local normtop = TopFrontLeft - BottomFrontLeft
	normtop:Normalize()
	local normLeft = TopFrontLeft - TopFrontRight
	normLeft:Normalize()
	local normFront = TopFrontLeft - TopBackLeft
	normFront:Normalize()

	//Top
	CreateSquare( TopBackRight, TopBackLeft, TopFrontLeft, TopFrontRight, normtop )

	//Sides
	CreateSquare( BottomBackLeft, BottomFrontLeft, TopFrontLeft, TopBackLeft, normLeft )
	CreateSquare( BottomBackRight, BottomBackLeft, TopBackLeft, TopBackRight, -normFront )
	CreateSquare( TopFrontRight, TopFrontLeft, BottomFrontLeft, BottomFrontRight, normFront )
	CreateSquare( BottomFrontRight, BottomBackRight, TopBackRight, TopFrontRight, -normLeft )

	//Bottom
	CreateSquare( BottomFrontRight, BottomFrontLeft, BottomBackLeft, BottomBackRight, -normtop ) //BottomBackRight, BottomBackLeft, BottomFrontLeft, BottomFrontRight 
end

function Cylinder.AddBeam( Pos1, Ang1, Pos2, Ang2, Radius, TrackColor )
	if Pos1 == nil || Ang1 == nil || Pos2 == nil || Ang2 == nil then 
		print("FAILED TO CREATE CYLINDER, NIL VALUE")
		return
	end
	Cylinder.Radius = Radius or Cylinder.Radius

	//Calculate the positions of the current Vertices
	for i=1, Cylinder.Count do
		local ang = Angle(Ang1.p,Ang1.y,Ang1.r) //Create a new instance of the angle so we don't modify the original (Is there a better way to do this?)
		Cylinder.CurVerts[i] = {}

		ang:RotateAroundAxis(ang:Right(), (360 / Cylinder.Count) * i )
		local pos = Pos1 + (ang:Up() * Cylinder.Radius)

		Cylinder.CurVerts[i].pos = pos
		Cylinder.CurVerts[i].norm = ang:Up()
	end

	//Calculate the positions of the next vertices
	for i=1, Cylinder.Count do
		local ang = Angle(Ang2.p,Ang2.y,Ang2.r) 
		Cylinder.NextVerts[i] = {}

		ang:RotateAroundAxis(ang:Right(), (360 / Cylinder.Count) * i )
		local pos = Pos2 + (ang:Up() * Cylinder.Radius)

		Cylinder.NextVerts[i].pos = pos
		Cylinder.NextVerts[i].norm = ang:Up()
	end

	//Variable to keep track of our triangle count
	local OldU  	= Cylinder.TotalU
	Cylinder.TotalU = Cylinder.TotalU + (Cylinder.CurVerts[1].pos:Distance( Cylinder.NextVerts[1].pos )) / 32//Get the distance so we can set the UV effectively


	local NewV      = Cylinder.TotalV


	//put them into proper triangle format
	for i=1, Cylinder.Count do
		//Set up our variables
		local CurLeft = Cylinder.CurVerts[i]
		local NextLeft = Cylinder.NextVerts[i]

		local CurRight = Vector(0)
		local NextRight = Vector(0)

		if (i+1) > Cylinder.Count then //Wrap around to 1
			CurRight = Cylinder.CurVerts[1]
			NextRight = Cylinder.NextVerts[1]
		else
			CurRight = Cylinder.CurVerts[i+1]
			NextRight = Cylinder.NextVerts[i+1]
		end

		//NewV = OldV + (i / Cylinder.Count)
		local OldV      = Cylinder.TotalV
		Cylinder.TotalV = Cylinder.TotalV + ( 1 / Cylinder.Count)

		//Create some variables for proper lightmapped color
		local colVec = Vector( 0, 0, 0 )

		//And the user selected color too
		local SelectedColor = Vector( 1, 1, 1 )
		if TrackColor then
			SelectedColor = Vector( TrackColor.r / 255, TrackColor.g / 255, TrackColor.b / 255 ) 
		end

		//Create the 6 verts that make up a single quad
		colVec = render.ComputeLighting( CurRight.pos, CurRight.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(CurRight.pos, CurRight.norm )
		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = CurRight.pos, 
			normal = CurRight.norm, 
			u = OldU,
			v = Cylinder.TotalV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		colVec = render.ComputeLighting( CurLeft.pos, CurLeft.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(CurLeft.pos, CurLeft.norm )
		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = CurLeft.pos, 
			normal = CurLeft.norm, 
			u = OldU,
			v = OldV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		colVec = render.ComputeLighting( NextLeft.pos, NextLeft.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(NextLeft.pos, NextLeft.norm )
		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = NextLeft.pos, 
			normal = NextLeft.norm, 
			u = Cylinder.TotalU,
			v = OldV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		//Second tri
		colVec = render.ComputeLighting( NextLeft.pos, NextLeft.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(NextLeft.pos, NextLeft.norm )
		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = NextLeft.pos, 
			normal = NextLeft.norm, 
			u = Cylinder.TotalU,
			v = OldV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		colVec = render.ComputeLighting( NextRight.pos, NextRight.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(NextRight.pos, NextRight.norm )
		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = NextRight.pos, 
			normal = NextRight.norm, 
			u = Cylinder.TotalU,
			v = Cylinder.TotalV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		colVec = render.ComputeLighting( CurRight.pos, CurRight.norm )
		colVec = colVec + render.GetAmbientLightColor()
		colVec = colVec + render.ComputeDynamicLighting(CurRight.pos, CurRight.norm )
		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = CurRight.pos, 
			normal = CurRight.norm, 
			u = OldU,
			v = Cylinder.TotalV,
			color = Color( colVec.x*SelectedColor.x*255, colVec.y*SelectedColor.y*255, colVec.z*SelectedColor.z*255)
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		OldV = NewV
		
	end
	Cylinder.TotalV = NewV
	//Cylinder.TotalU = 0
end

function Cylinder.EndBeam()
	return Cylinder.Vertices 
end