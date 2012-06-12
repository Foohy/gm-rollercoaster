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

function Cylinder.AddBeam( Pos1, Ang1, Pos2, Ang2, Radius )
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

		//Create the 6 verts that make up a single quad

		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = CurRight.pos, 
			normal = CurRight.norm, 
			u = OldU,
			v = Cylinder.TotalV,
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = CurLeft.pos, 
			normal = CurLeft.norm, 
			u = OldU,
			v = OldV,
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = NextLeft.pos, 
			normal = NextLeft.norm, 
			u = Cylinder.TotalU,
			v = OldV,
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		//Second tri
		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = NextLeft.pos, 
			normal = NextLeft.norm, 
			u = Cylinder.TotalU,
			v = OldV,
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = NextRight.pos, 
			normal = NextRight.norm, 
			u = Cylinder.TotalU,
			v = Cylinder.TotalV,
		}
		Cylinder.TriCount = Cylinder.TriCount + 1

		Cylinder.Vertices[Cylinder.TriCount] = { 
			pos = CurRight.pos, 
			normal = CurRight.norm, 
			u = OldU,
			v = Cylinder.TotalV,
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