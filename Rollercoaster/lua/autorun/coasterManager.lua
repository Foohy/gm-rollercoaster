AddCSLuaFile( "autorun/coasterManager.lua" )

AddCSLuaFile("trackmanager.lua")
include("trackmanager.lua")

Rollercoasters = {} //Holds all the rollercoasters
CoasterManager = {} //Holds all the methods and variables for rollercoasters
//Controller	   = {}


//Some content (Remove these lines if you don't want clients to download)
resource.AddFile("sound/coaster_ride.wav")
resource.AddFile("sound/coaster_chain.wav")
resource.AddFile("sound/coaster_offdarailz.wav")
resource.AddFile("sound/coaster_wind.wav")
resource.AddFile("sound/coaster_sonic_the_carthog.mp3")

resource.AddFile("materials/sunabouzu/old_chain.vmt")
resource.AddFile("materials/sunabouzu/coaster_track.vmt")
resource.AddFile("materials/coaster/cart.vmt")
resource.AddFile("materials/coaster/remover.vmt")
resource.AddFile("materials/coaster/settings.vmt")
resource.AddFile("materials/coaster/track.vmt")
resource.AddFile("materials/coaster/save.vmt")
resource.AddFile("materials/models/sunabouzu/sonic_the_carthog.vmt")

resource.AddFile("models/sunabouzu/coaster_base.mdl")
resource.AddFile("materials/models/sunabouzu/coaster_base.vmt")
resource.AddFile("materials/models/sunabouzu/coaster_base2.vmt")
resource.AddFile("materials/models/sunabouzu/coaster_base3.vmt")
resource.AddFile("models/sunabouzu/coaster_pole.mdl")
resource.AddFile("materials/models/sunabouzu/coaster_pole.vmt")
resource.AddFile("models/sunabouzu/coaster_pole_start.mdl")
resource.AddFile("materials/models/sunabouzu/coaster_pole_start.vmt")

resource.AddFile("models/sunabouzu/sonic_the_carthog.mdl")

if SERVER then


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
	function CoasterManager.CreateNode( id, pos, ang, type, ply )
		//Make sure we're allowed to spawn one
		if !SinglePlayer() && IsValid( ply ) && ply:NumCoasterNodes() >= GetConVarNumber("coaster_maxnodes") then
			ply:LimitHit("maxnodes")
			return nil 
		end

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
			Rollercoasters[id]:AddTrackNode( node, ply ) //The first node is always the controller node
		else //The ID IS an actual rollercoaster, so let's append to it
			Rollercoasters[id]:AddTrackNode( node, ply )
			Msg("Creating a new node: "..tostring(Rollercoasters[id]:GetNumNodes()).." for coaster ID: "..id.."\n")
		end
		
		return node

	end

	//Because rollercoaster can go faster than what source allows, change what source allows.
	hook.Add("InitPostEntity", "CoasterSetPerfSettings", function()
		CoasterManager.Settings = {}
		CoasterManager.Settings.MaxVelocity = 6000000 //Let's hope this doesn't break things
		physenv.SetPerformanceSettings(CoasterManager.Settings)
		

		//sv_tags, why not
		local tag = GetConVar("sv_tags"):GetString()
		tag = string.gsub( tag, "Rollercoaster", "")

		RunConsoleCommand( "sv_tags", tag .. ",Rollercoaster" )

	end )

	//Tell newly joining players to update their shit
	hook.Add( "PlayerInitialSpawn", "UpdateWitAllTracks", function( ply )
		timer.Simple( 5, function() //is there a hook when the player is able to receive umsgs?
			for k, v in pairs( ents.FindByClass("coaster_node") ) do
				if IsValid( v ) && v:IsController() then
					umsg.Start("Coaster_RefreshTrack", ply)
						umsg.Entity(v)
					umsg.End()
				end
			end
		end )
	end )

	//Manage cart collisions (So trains don't collide with themselves, but collide with other trains)
	hook.Add("ShouldCollide","RollercoasterShouldCartCollide",function(ent1,ent2)
		//Prevent carts from colliding with the physics mesh of the tracks
		if ent1:GetClass() == "coaster_cart" and ent2:GetClass() == "coaster_physmesh" then return false end
		if ent2:GetClass() == "coaster_cart" and ent1:GetClass() == "coaster_physmesh" then return false end

		
		if ent1:GetClass() != "coaster_cart" or ent2:GetClass() != "coaster_cart" then return end

		//If either of the carts are off da railz, collide the hell outta them
		if ent1.IsOffDaRailz || ent2.IsOffDaRailz then return true end

		//Prevent trains from colliding with itself but collide them with other trains
		if ent1.CartTable == nil or ent2.CartTable == nil then return false end

		//the first entry in the cart table is ALWAYS the dummy cart. don't fuck that up.
		if ent1.CartTable[1] == ent1 then return false end
		if ent2.CartTable[1] == ent2 then return false end

		if ent1.CartTable == ent2.CartTable then return false else return true end
	end )

	//Don't let the physics mesh be picked up.
	hook.Add("PhysgunPickup", "PreventCoasterMeshPickup", function( ply, ent ) 
		if ent:GetClass() == "coaster_physmesh" then return false end
	end )

	//Be 1000% sure cart dummies are NEVER left over after their train has since exploded
	hook.Add("Think", "RemoveGhostedDummies", function() 
		if !CoasterManager.NextThink || CoasterManager.NextThink < CurTime() then
			CoasterManager.NextThink = CurTime() + 2

			for k, v in pairs( ents.FindByClass("coaster_cart") ) do
				if IsValid( v ) && v.IsDummy then
					local remove = true

					if v.CartTable then
						for _, ent in pairs( v.CartTable ) do

							if IsValid( ent ) && ent != v then 
								remove = false 
								break
							end

						end
					end

					if remove then
						v:Remove()
					end
				end
			end
		end
	end )


	//Admin settings (Remember to add clientside language if creating more if it's a numerical limit)
	CreateConVar("coaster_maxcarts", "16", FCVAR_NOTIFY) //Maximum number of carts per person
	CreateConVar("coaster_maxnodes", "70", FCVAR_NOTIFY) //Maximum numbr of nodes per person
	CreateConVar("coaster_cart_explosive_damage", "1", FCVAR_NOTIFY, "Should the cart deal explosive damage and remove itself after going Off Da Railz?") //Should the cart do explosive damage?

end


if CLIENT then
	//Language for admin limits
	language.Add("SBoxLimit_maxcarts", "You've hit the Carts limit!")
	language.Add("SBoxLimit_maxnodes", "You've hit the Nodes limit!")

	CoasterBlur = 0.00003 //Blur multiplier

	//Perfomance settings
	CreateClientConVar("coaster_supports", 1, false, false )
	CreateClientConVar("coaster_previews", 1, false, false )
	CreateClientConVar("coaster_motionblur", 1, false, false )
	CreateClientConVar("coaster_maxwheels", 15, false, false)
	CreateClientConVar("coaster_resolution", 15, false, false)

	//Misc Settings
	CreateClientConVar("coaster_cart_spin_override", 0, false, true) //Override cart spawning to make it spin like the carousel

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

	//Track rendering. Renders meshes
	hook.Add( "PreDrawOpaqueRenderables", "CoasterDrawTrack", function()
		for k, v in pairs( ents.FindByClass( "coaster_node" ) ) do
			if IsValid( v ) && v:IsController() then
				v:DrawTrack()
			end
		end
	end )

	//Track rendering. Renders previews/beams/transluecent
	hook.Add( "PostDrawTranslucentRenderables", "CoasterDrawTrackTranslucents", function()
		for k, v in pairs( ents.FindByClass( "coaster_node" ) ) do
			if IsValid( v ) && v:IsController() then
				v:DrawTrackTranslucents()
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

