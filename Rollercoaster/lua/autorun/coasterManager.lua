AddCSLuaFile( "autorun/coasterManager.lua" )

AddCSLuaFile("trackmanager.lua")
include("trackmanager.lua")

Rollercoasters = {} //Holds all the rollercoasters
CoasterManager = {} //Holds all the methods and variables for rollercoasters
Controller	   = {}


//Some content (Remove these lines if you don't want clients to download)
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

	//Because rollercoaster can go faster than what source allows, change what source allows.
	hook.Add("InitPostEntity", "CoasterSetPerfSettings", function()
		CoasterManager.Settings = {}
		CoasterManager.Settings.MaxVelocity = 600000 //Let's hope this doesn't break things
		physenv.SetPerformanceSettings(CoasterManager.Settings)
		

		//sv_tags, why not
		local tag = GetConVar("sv_tags"):GetString()
		tag = string.gsub( tag, "Rollercoaster", "")

		RunConsoleCommand( "sv_tags", tag .. ",Rollercoaster" )

	end )

	//For use with spawning coasters from a file. Less automagic bs, but you have to know what you're doing
	function CoasterManager.CreateNodeSimple( id, pos, ang ) //For use with spawning coasters from a file. Less automagic bs
		local node = ents.Create("coaster_node")		
		node.CoasterID = id
		node:SetTrackType( COASTER_TRACK_METAL )
		
		node:SetPos( pos )
		node:SetAngles( ang )
		node:Spawn()
		node:Activate()

		if !IsValid( Rollercoasters[id] ) then

			Rollercoasters[id] = node
			Rollercoasters[id]:SetController(true)
			Rollercoasters[id]:SetModel( "models/props_junk/PopCan01a.mdl" )
		end

		Rollercoasters[id]:AddNodeSimple( node )
		return node
	end

	//Spawn a new rollercoaster the simple way
	function CoasterManager.CreateNode( id, pos, ang, type )
		local node = ents.Create("coaster_node")		
		node.CoasterID = id
		node:SetType( type )
		node:SetTrackType( COASTER_TRACK_METAL )
		
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
		else //The ID IS an actual rollercoaster, so let's append to it
			Rollercoasters[id]:AddTrackNode( node )
			Msg("Creating a new node: "..tostring(Rollercoasters[id]:GetNumNodes()).." for coaster ID: "..id.."\n")
		end
		
		return node

	end
end


if CLIENT then
	CoasterBlur = 0.00003 //Blur multiplier
	//Perfomance settings
	CreateClientConVar("coaster_supports", 1, false, false )
	CreateClientConVar("coaster_previews", 1, false, false )
	CreateClientConVar("coaster_motionblur", 1, false, false )

	//Motion blur
	local function GetMotionBlurValues( x, y, fwd, spin )
		if LocalPlayer():GetInfoNum("coaster_motionblur") == 0 then return end

		if IsValid(LocalPlayer():GetVehicle()) && IsValid(LocalPlayer():GetVehicle():GetParent()) then
			return x, y, LocalPlayer():GetVehicle():GetParent():GetVelocity():Length() * CoasterBlur, spin //HOLY SHIT
		else
			return x, y, fwd, spin
		end
	end
	hook.Add( "GetMotionBlurValues", "Coaster_motionblur", GetMotionBlurValues )

	//Track rendering. Renders EVERYTHING-- mesh, previews, support beams, etc.
	hook.Add( "PreDrawOpaqueRenderables", "CoasterDrawTrack", function()
		for k, v in pairs( ents.FindByClass( "coaster_node" ) ) do
			if IsValid( v ) && v:IsController() then
				v:DrawTrack()
			end
		end
	end )

	//Add all ents of a track to the glow filter
	function SelectAllNodes(controller, color)
		if !IsValid( controller ) || !controller.Nodes || #controller.Nodes < 1 then return end
		if !coaster_track_creator_HoverEnts then coaster_track_creator_HoverEnts = {} end

		coaster_track_creator_HoverEnts = controller.Nodes 
		coaster_track_creator_HoverColor = color or Color( 180 - math.random( 0, 80 ), 220 - math.random( 0, 50 ), 255, 255 )
	end

	function SelectSingleNode( ent, color )
		if !IsValid( ent ) then return end
		if !coaster_track_creator_HoverEnts then coaster_track_creator_HoverEnts = {} end

		coaster_track_creator_HoverEnts[1] =  ent
		coaster_track_creator_HoverColor = color or Color( 180 - math.random( 0, 80 ), 220 - math.random( 0, 50 ), 255, 255 )
	end

	function ClearNodeSelection()
		coaster_track_creator_HoverEnts = {}
		coaster_track_creator_HoverColor = Color( 180 - math.random( 0, 80 ), 220 - math.random( 0, 50 ), 255, 255 )
	end

	//Glow functions yeahhhh
	hook.Add( "PreDrawHalos", "DrawHoverHalo", function()
		if ( !coaster_track_creator_HoverEnts || #coaster_track_creator_HoverEnts < 1 ) then return end
		coaster_track_creator_HoverColor = coaster_track_creator_HoverColor or Color( 180 - math.random( 0, 80 ), 220 - math.random( 0, 50 ), 255, 255 )

		local size = math.random( 1, 3 )
		effects.halo.Add( coaster_track_creator_HoverEnts, coaster_track_creator_HoverColor, size, size, 1, true, false )

	end )

end

