AddCSLuaFile( "autorun/coasterManager.lua" )

Rollercoasters = {} //Holds all the rollercoasters
CoasterManager = {} //Holds all the methods and variables for rollercoasters
Controller	   = {}

resource.AddFile("sound/coaster_ride.wav")
resource.AddFile("sound/coaster_chain.wav")
resource.AddFile("sound/coaster_offdarailz.wav")
resource.AddFile("sound/coaster_wind.wav")

resource.AddFile("materials/sunabouzu/old_chain.vmt")
resource.AddFile("materials/sunabouzu/coaster_track.vmt")

resource.AddFile("models/sunabouzu/coaster_base.mdl")
resource.AddFile("materials/models/sunabouzu/coaster_base.vmt")
resource.AddFile("materials/models/sunabouzu/coaster_base2.vmt")
resource.AddFile("materials/models/sunabouzu/coaster_base3.vmt")
resource.AddFile("models/sunabouzu/coaster_pole.mdl")
resource.AddFile("materials/models/sunabouzu/coaster_pole.vmt")
resource.AddFile("models/sunabouzu/coaster_pole_start.mdl")
resource.AddFile("materials/models/sunabouzu/coaster_pole_start.vmt")

if SERVER then

	hook.Add("InitPostEntity", "CoasterSetPerfSettings", function()
		CoasterManager.Settings = {}
		CoasterManager.Settings.MaxVelocity = 6000000
		physenv.SetPerformanceSettings(CoasterManager.Settings)
		
	end )

	function CoasterManager.CreateNode( id, pos, ang, chains )
		local node = ents.Create("coaster_node")		
		node.CoasterID = id
		node:SetChains(chains or false)
		
		node:SetPos( pos )
		node:SetAngles( ang )
		node:Spawn()
		node:Activate()

		if !IsValid( Rollercoasters[id] ) then //The ID isn't an existing rollercoaster, so lets create one
			Msg("Creating a new rollercoaster with ID: "..id.."\n" )
			Rollercoasters[id] = node
			Rollercoasters[id]:SetController(true)
			Rollercoasters[id]:SetModel( "models/props_junk/PopCan01a.mdl" )
			Rollercoasters[id]:AddTrackNode( node ) //The first node is always the controller node
		else //The ID IS an actual rollercoaster, so let's add to it
			Rollercoasters[id]:AddTrackNode( node )
			Msg("Creating a new node: "..tostring(Rollercoasters[id]:GetNumNodes()).." for coaster ID: "..id.."\n")
		end
		
		return node

		/*
		if !IsValid(Rollercoasters[id]) then //Track doesn't exist, create a new one
			Msg("Creating a new coaster. ID: "..id.."\n")
			node:SetController(true) //This first node will control things like the clientside tracks, splining, etc.
			Rollercoasters[id] = node //Add to our list of rollercoasters
		else
			//local controller = Rollercoasters[id]
			print( "Controller: "..tostring(Rollercoasters[id]) )
			print( "Real Count: "..tostring(#Rollercoasters[id].Nodes) )
			print( "Node ID: "..Rollercoasters[id].CoasterID)

			local numNodes = Rollercoasters[id]:GetNumNodes()
			table.insert( Rollercoasters[id].Nodes, node ) //Add ourselves to the controller node's list

			Msg("Creating a new node: "..tostring(numNodes).." for coaster ID: "..id.."\n")
		end
		*/
	end
end


if CLIENT then
//Perfomance settings
CreateClientConVar("coaster_supports", 1, false, false )


	hook.Add( "PreDrawOpaqueRenderables", "CoasterDrawTrack", function()
		for k, v in pairs( ents.FindByClass( "coaster_node" ) ) do
			if IsValid( v ) && v:IsController() then
				v:DrawTrack()
			end
		end
	end )
end

