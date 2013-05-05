include("weapons/gmod_tool/tab/tab_utils.lua")

local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "track_settings"

TAB.Name = ""
TAB.Name2 = "Settings" //Name for the non-tab stuff
TAB.UniqueName = UNIQUENAME
TAB.Description = "Change track-wide and addon-wide settings"
TAB.Instructions = "Click on any node of a rollercoaster to update its settings."
TAB.Icon = "coaster/settings"
TAB.Position = 6

TAB.ClientConVar["r"] = "255"
TAB.ClientConVar["g"] = "255"
TAB.ClientConVar["b"] = "255"

TAB.ClientConVar["tracktype"] = "1"

function TAB:LeftClick( trace, tool )
	local ply   = tool:GetOwner()

	local CartNum = GetClientNumber( self, "cart_amount", tool )
	local Powered = GetClientNumber( self, "powered", tool)
	local tracktype = GetClientNumber( self, "tracktype", tool)
	local r = GetClientNumber( self, "r", tool)/255 or 1
	local g = GetClientNumber( self, "g", tool)/255 or 1
	local b = GetClientNumber( self, "b", tool)/255 or 1

	local Ent = trace.Entity
	
	if IsValid( Ent ) && Ent:GetClass() == "coaster_node" || Ent:GetClass() == "coaster_physmesh" then
		if SERVER then
			local controller = Ent:GetController()
			if !IsValid( controller ) then return end

			local node = nil

			if Ent:GetClass() == "coaster_node" then node = Ent 
			else node = controller.Nodes[ Ent.Segment ] end

			if IsValid( node ) then
				node:SetTrackColor( Vector(r,g,b) )
				controller:SetTrackColor( Vector(r,g,b))

				-- If we're changing to a new generation type, invalidate the entire track as it needs to be rebuilt
				if controller:GetTrackType() != tracktype then
					controller:InvalidateTrack()
				end

				controller:SetTrackType(tracktype)
				node:Invalidate( false )
			end
		end

		return true
	end

end

function TAB:RightClick( trace, tool )

end

function TAB:Reload( trace )

end

//Called when our tab is closing or the tool was holstered
function TAB:Holster()
	if CLIENT then
		ClearNodeSelection()
	end
end

//Called when our tab being selected
function TAB:Equip( tool )

end

function TAB:Think( tool )
	if CLIENT then
		local ply = LocalPlayer()

		trace = {}
		trace.start  = ply:GetShootPos()
		trace.endpos = trace.start + (ply:GetAimVector() * 999999)
		trace.filter = ply
		trace = util.TraceLine(trace)

		if IsValid( trace.Entity ) && ( trace.Entity:GetClass() == "coaster_node") then
			local controller = trace.Entity:GetController()

			if IsValid( controller ) then
				SelectAllNodes( controller, Color( 180 - math.random( 0, 80 ), 220 - math.random( 0, 50 ), 255, 255 ) )
			end
		else 
			ClearNodeSelection()
		end

	end
end

function TAB:BuildPanel( )
	local panel = vgui.Create("DForm")
	panel:SetName("Settings")

	local ColorMixer = vgui.Create("CtrlColor", panel )
	ColorMixer:SetLabel("Track Color")
	ColorMixer:SetHeight( 150 )
	ColorMixer:SetConVarR("coaster_supertool_tab_track_settings_r")
	ColorMixer:SetConVarG("coaster_supertool_tab_track_settings_g")
	ColorMixer:SetConVarB("coaster_supertool_tab_track_settings_b")
	ColorMixer:SetConVarA( nil )

	panel.ColorMixer = ColorMixer
	panel:AddItem( ColorMixer )

	local ComboBox = vgui.Create("DComboBox", panel)

	//Create some nice choices
	if EnumNames.Tracks && #EnumNames.Tracks > 0 then
		for k, v in pairs( EnumNames.Tracks ) do
			ComboBox:AddChoice(v)
		end
		local trackConVar = GetConVar("coaster_supertool_tab_track_settings_tracktype" )

		if trackConVar && trackConVar:GetInt() > 0 then
			local int = trackConVar:GetInt() 
			ComboBox:ChooseOptionID( int < #ComboBox.Data and int or COASTER_TRACK_METAL )
			RunConsoleCommand("coaster_supertool_tab_track_settings_tracktype", trackConVar:GetInt() ) //Default to normal
		else
			ComboBox:ChooseOptionID( COASTER_TRACK_METAL )
			RunConsoleCommand("coaster_supertool_tab_track_settings_tracktype", COASTER_TRACK_METAL ) //Default to normal
		end
	end

	ComboBox.OnSelect = function(index, value, data)
		RunConsoleCommand("coaster_supertool_tab_track_settings_tracktype" , tostring( value ) )
	end

	ComboBox:ChooseOptionID( 1 )
	panel:AddItem( ComboBox )

	panel:ControlHelp("Generation types change the look of clientside meshes. Select a type, shoot a node, and rebuild your clientside mesh.")
	return panel
end

coastertabmanager.Register( UNIQUENAME, TAB )