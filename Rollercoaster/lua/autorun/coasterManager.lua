AddCSLuaFile( "autorun/coasterManager.lua" )
AddCSLuaFile("trackmanager.lua")
include("trackmanager.lua")

//I should probably make this a package and combine these two global tables into one.
Rollercoasters = {} //Holds all the rollercoasters
CoasterManager = {} //Holds all the methods and variables for rollercoasters
COASTER_VERSION = 7

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


resource.AddFile("models/sunabouzu/coaster_base.mdl")
resource.AddFile("materials/models/sunabouzu/coaster_base.vmt")
resource.AddFile("materials/models/sunabouzu/coaster_base2.vmt")
resource.AddFile("materials/models/sunabouzu/coaster_base3.vmt")
resource.AddFile("models/sunabouzu/coaster_pole.mdl")
resource.AddFile("materials/models/sunabouzu/coaster_pole.vmt")
resource.AddFile("models/sunabouzu/coaster_pole_start.mdl")
resource.AddFile("materials/models/sunabouzu/coaster_pole_start.vmt")

resource.AddFile("materials/models/sunabouzu/sonic_the_carthog.vmt")
resource.AddFile("models/sunabouzu/sonic_the_carthog.mdl")

cleanup.Register("Rollercoaster")

if SERVER then

	//For use with spawning coasters from a file. Less automagic bs, but you have to know what you're doing
	function CoasterManager.CreateNodeSimple( id, pos, ang ) //For use with spawning coasters from a file. Less automagic bs
		local node = ents.Create("coaster_node")		
		node:SetCoasterID( id )
		node:SetTrackType( COASTER_TRACK_METAL )
		node:SetController( Rollercoasters[id] or node )

		node:SetPos( pos )
		node:SetAngles( ang )
		node:Spawn()
		node:Activate()

		if !IsValid( Rollercoasters[id] ) then
			Rollercoasters[id] = node
			Rollercoasters[id]:SetIsController(true)
			Rollercoasters[id]:SetModel( "models/props_junk/PopCan01a.mdl" )

			//Call the hook telling a new coaster was created
			hook.Call("Coaster_NewCoaster", node )
		else
			//Nocollide the node with the main node so that the remover gun removes all nodes
			constraint.NoCollide( node, Rollercoasters[id], 0, 0 )
		end

		//Call the hook telling a new node was created
		hook.Call("Coaster_NewNode", node )

		Rollercoasters[id]:AddNodeSimple( node )
		return node
	end

	//Spawn a new rollercoaster the simple way
	function CoasterManager.CreateNode( id, pos, ang, type, ply )
		//Make sure we're allowed to spawn one
		if !game.SinglePlayer() && IsValid( ply ) && ply:NumCoasterNodes() >= GetConVarNumber("coaster_maxnodes") then
			ply:LimitHit("maxnodes")
			return nil 
		end

		local node = ents.Create("coaster_node")		
		node:SetCoasterID( id )
		node:SetType( type )
		node:SetTrackType( COASTER_TRACK_METAL )

		node:SetController( Rollercoasters[id] or node )
		
		node:SetPos( pos )
		node:SetAngles( ang )
		node:Spawn()
		node:Activate()

		if !IsValid( Rollercoasters[id] ) then //The ID isn't an existing rollercoaster, so lets create one
			Msg("Creating a new rollercoaster with ID: "..tostring(id).."\n" )
			Rollercoasters[id] = node
			node:SetIsController(true)
			node:SetModel( "models/props_junk/PopCan01a.mdl" )
			node:AddTrackNode( node, ply ) //The first node is always the controller node
			node:SetController( node )

			cleanup.Add( ply, "Rollercoaster", node )

			//Call the hook telling a new coaster was created
			hook.Call("Coaster_NewCoaster", node )
		else //The ID IS an actual rollercoaster, so let's append to it
			//Nocollide the node with the main node so that the remover gun removes all nodes
			constraint.NoCollide( node, Rollercoasters[id], 0, 0 )

			Rollercoasters[id]:AddTrackNode( node, ply )
			//Msg("Creating a new node: "..tostring(Rollercoasters[id]:GetNumNodes()).." for coaster ID: "..tostring(id).."\n")
		end

		//Call the hook telling a new node was created
		hook.Call("Coaster_NewNode", node )
		
		return node

	end

	hook.Add("EntityRemoved", "CoasterEntityRemoved", function(ent) 
		if IsValid( ent ) && ent:GetClass() == "coaster_node" then  
			//Call the hook telling a node was removed
			hook.Call("Coaster_NodeRemoved", ent )

			if ent:IsController() then
				//Call the hook telling a new node was created
				hook.Call("Coaster_CoasterRemoved", node )
			end
		end
	end )

	//Because rollercoaster can go faster than what source allows, change what source allows.
	hook.Add("InitPostEntity", "CoasterSetPerfSettings", function()
		CoasterManager.Settings = {}
		CoasterManager.Settings.MaxVelocity = 6000000 //Let's hope this doesn't break things
		physenv.SetPerformanceSettings(CoasterManager.Settings)
		

		//sv_tags, why not
		/*
		local tag = GetConVar("sv_tags"):GetString()
		tag = string.gsub( tag, "Rollercoaster", "")

		RunConsoleCommand( "sv_tags", tag .. ",Rollercoaster" )
		*/
	end )

	//Tell newly joining players to update their shit
	hook.Add( "PlayerInitialSpawn", "UpdateWithAllTracks", function( ply )
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
	CreateConVar("coaster_cart_cooldown", "1", FCVAR_NOTIFY, "Have a cooldown for screaming and vomiting")
end

//Don't let the physics mesh be picked up.
hook.Add("PhysgunPickup", "PreventCoasterMeshPickup", function( ply, ent ) 
	if ent:GetClass() == "coaster_physmesh" then return false end
end )

//Manage cart collisions (So trains don't collide with themselves, but collide with other trains)
hook.Add("ShouldCollide","CoasterShouldCartCollide",function(ent1,ent2)
	//Prevent two coaster physics meshes from colliding
	if ent1:GetClass() == "coaster_physmesh" && ent2:GetClass() == "coaster_physmesh" then return false end

	//These aren't shared because their variables really don't need to be networked
	if SERVER then
		//Prevent carts from colliding with the physics mesh of the tracks
		if ent1:GetClass() == "coaster_cart" and ent2:GetClass() == "coaster_physmesh" && ent1.CoasterID == ent2:GetController():GetCoasterID() then return false end
		if ent2:GetClass() == "coaster_cart" and ent1:GetClass() == "coaster_physmesh" && ent2.CoasterID == ent1:GetController():GetCoasterID() then return false end

		//If none of the ents arent a coaster_cart, stop executing here
		if ent1:GetClass() != "coaster_cart" || ent2:GetClass() != "coaster_cart" then return end

		//If both carts are derailed, do not let them collide
		if ent1.IsOffDaRailz && ent2.IsOffDaRailz then return false end

		//If either of the carts are off da railz, collide the hell outta them
		if ent1.IsOffDaRailz || ent2.IsOffDaRailz then return true end

		//Prevent trains from colliding with itself but collide them with other trains
		if ent1.CartTable == nil || ent2.CartTable == nil then return false end

		//the first entry in the cart table is ALWAYS the dummy cart. don't fuck that up.
		if ent1.CartTable[1] == ent1 && #ent1.CartTable > 1 then return false end
		if ent2.CartTable[1] == ent2 && #ent2.CartTable > 1 then return false end

		if ent1.CartTable == ent2.CartTable then return false else return true end
	end

end )

function table.Find(tab,entry)
	for k, v in pairs(tab) do
			if entry == v then
					return true, k
			end
	end
	return false, nil
end
 
function ents.FindAllButExclusions(exclusions, classes)
	exclusions = exclusions or {}
	local entities = classes or {}
	local eligibleentities = {}
	for k, v in pairs(entities) do
			if !table.Find(exclusions,v) then
					table.insert(eligibleentities,v)
			end
	end
	local returntable = {}
	for k, v in pairs(ents.GetAll()) do
			if table.Find(eligibleentities,v:GetClass()) then
					table.insert(returntable,v)
			end
	end
	return returntable
end

//handle saving
saverestore.AddSaveHook("CoasterSaveTrack", function( save )
	print("sayve")
	saverestore.WriteVar( table.Count(Rollercoasters) )
	for k, v in pairs(Rollercoasters) do
		saverestore.WriteTable({v, v:GetCoasterID()}, save)
	end
end )

saverestore.AddRestoreHook("CoasterRestoreTrack", function( restore )
	local num = saverestore.ReadVar( restore )
	local nodes = {}
	print( "restore")
	for i=1, num do
		nodes[i] = {}
		nodes[i] = saverestore.ReadTable( restore )
	end

	PrintTable( nodes )
end )



if CLIENT then
	//Language for admin limits
	language.Add("SBoxLimit_maxcarts", "You've hit the Carts limit!")
	language.Add("SBoxLimit_maxnodes", "You've hit the Nodes limit!")
	language.Add("Cleanup_Rollercoaster", "Rollercoasters")
	language.Add("Cleaned_Rollercoaster", "Cleaned up all rollercoasters")

	CoasterBlur = 0.00003 //Blur multiplier
	CoasterTracks = {}

	//Perfomance settings
	CreateClientConVar("coaster_supports", 1, false, false )
	CreateClientConVar("coaster_previews", 1, false, false )
	CreateClientConVar("coaster_motionblur", 1, false, false )
	CreateClientConVar("coaster_maxwheels", 15, false, false)
	CreateClientConVar("coaster_resolution", 15, false, false)

	//Misc Settings
	CreateClientConVar("coaster_cart_spin_override", 0, false, true) //Override cart spawning to make it spin like the carousel

	//Change callbacks
	cvars.AddChangeCallback( "coaster_supports", function()
		//Go through all of the nodes and tell them to update their shit
		for k, v in pairs( ents.FindByClass("coaster_node") ) do
			if v:IsController() then
				v:SupportFullUpdate()
			end
		end
	end )

	//Motion blur
	local function GetMotionBlurValues( x, y, fwd, spin )
		if LocalPlayer():GetInfoNum("coaster_motionblur", 0) == 0 then return end

		if IsValid(LocalPlayer():GetVehicle()) && IsValid(LocalPlayer():GetVehicle():GetParent()) then
			return x, y, LocalPlayer():GetVehicle():GetParent():GetVelocity():Length() * CoasterBlur, spin //HOLY SHIT
		else
			return x, y, fwd, spin
		end
	end
	hook.Add( "GetMotionBlurValues", "Coaster_motionblur", GetMotionBlurValues )

	//Every little bit update the clientside 'tracklist' of tracks to update/draw/etc.
	local CoasterUpdateTrackTime = 0
	hook.Add( "Think", "CoasterCacheTracks", function()
		if CurTime() > CoasterUpdateTrackTime then
			CoasterTracks = {}

			for k, v in pairs( ents.FindByClass( "coaster_node" ) ) do
				if IsValid( v ) && v:IsController() then
					table.insert( CoasterTracks, v )
				end
			end

			CoasterUpdateTrackTime = CurTime() + 1.0
		end
	end )

	//Track rendering. Renders meshes
	hook.Add( "PreDrawOpaqueRenderables", "CoasterDrawTrack", function()
		for k, v in pairs( CoasterTracks ) do
			if IsValid( v ) then
				v:DrawTrack()
			end
		end
	end )

	//Track rendering. Renders previews/beams/transluecent
	hook.Add( "PostDrawTranslucentRenderables", "CoasterDrawTrackTranslucents", function()
		for k, v in pairs( CoasterTracks ) do
			if IsValid( v ) then
				v:DrawTrackTranslucents()
			end
		end
	end )

	//Conflict 'fixer'
	/*
	hook.Add( "Think", "CoasterExpressDominance", function()
		if !CoasterManager.NextThink || CoasterManager.NextThink < CurTime() then
			CoasterManager.NextThink = CurTime() + 10

			//Express dominance
			hook.Remove("PreDrawOpaqueRenderables", "ScaleUpdate")
		end
	end )
	*/

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


	hook.Add( "PopulateToolMenu", "PopulateOptionMenus", function()
		spawnmenu.AddToolMenuOption("Options", "Rollercoaster", "Performance Settings", "Performance Settings", "", "", function( panel )
			panel:NumSlider("Max wheels per segment: ", "coaster_maxwheels", 0, 100, 0 )

			local TrackResolutionSlider = panel:NumSlider("Track Resolution: ", "coaster_resolution", 1, 100, 0 )
			TrackResolutionSlider.OnValueChanged = function() //See the effects in realtime
				for _, v in pairs( ents.FindByClass("coaster_node") ) do
					if IsValid( v ) && !v.IsSpawning && v.IsController && v:IsController() then 
						v:UpdateClientSpline()
					end
				end
			end

			panel:CheckBox("Draw track previews", "coaster_previews")
			panel:CheckBox("Draw track supports", "coaster_supports")
			panel:CheckBox("Draw motion blur", "coaster_motionblur")

		end )
	end )


end

