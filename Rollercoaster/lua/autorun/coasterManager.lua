AddCSLuaFile( "autorun/coasterManager.lua" )

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
		if !string.find("Rollercoaster") then
		RunConsoleCommand( "sv_tags", tag .. ",Rollercoaster" )
		end
	end )

	//For use with spawning coasters from a file. Less automagic bs, but you have to know what you're doing
	function CoasterManager.CreateNodeSimple( id, pos, ang ) //For use with spawning coasters from a file. Less automagic bs
		local node = ents.Create("coaster_node")		
		node.CoasterID = id
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
end

