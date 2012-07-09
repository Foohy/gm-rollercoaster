include("weapons/gmod_tool/tab/tab_utils.lua")

local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "track_settings"

TAB.Name = "Settings"
TAB.UniqueName = UNIQUENAME
TAB.Description = "Change track-wide and addon-wide settings"
TAB.Instructions = "Click on any node of a rollercoaster to update its settings. Alternatively, adjust clientside settings for all rollercoasters"
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
	local r = GetClientNumber( self, "r", tool) or 255
	local g = GetClientNumber( self, "g", tool) or 255
	local b = GetClientNumber( self, "b", tool) or 255

	local Ent = trace.Entity
	
	if IsValid( Ent ) && Ent:GetClass() == "coaster_node" then
		if SERVER then 
			local controller = Ent:GetController()

			if IsValid( controller ) then
				print("Editing settings for "..tostring(controller.CoasterID))
				controller:SetTrackColor(r,g,b)
				controller:SetTrackType(tracktype)
			end
		end
	
		return true
	end
end

function TAB:RightClick( trace, tool )
	local ply   = tool:GetOwner()

	local CartNum = GetClientNumber( self, "cart_amount", tool)
	local Powered = GetClientNumber( self, "powered", tool)
	
	local Ent 		= trace.Entity
	
	if IsValid( Ent ) && Ent:GetClass() == "coaster_node" then
		if SERVER then
			local controller = Ent:GetController()
		
			if IsValid( controller ) && SERVER then 
				print("Doing nothing for "..tostring(controller.CoasterID))
				//controller:ClearTrains()
			end
		end
		
		return true
	end
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

	local TrackPanel = vgui.Create("DForm", panel )
	TrackPanel:SetName("Track-Specific Settings")

	local ColorMixer = vgui.Create("CtrlColor", TrackPanel )
	ColorMixer:SetLabel("Track Color")
	ColorMixer:SetHeight( 150 )
	ColorMixer:SetConVarR("coaster_supertool_tab_track_settings_r")
	ColorMixer:SetConVarG("coaster_supertool_tab_track_settings_g")
	ColorMixer:SetConVarB("coaster_supertool_tab_track_settings_b")
	ColorMixer:SetConVarA( nil )
	/*
	ColorMixer.m_ConVarR = "coaster_supertool_tab_track_settings_r"
	ColorMixer.m_ConVarG = "coaster_supertool_tab_track_settings_g"
	ColorMixer.m_ConVarB = "coaster_supertool_tab_track_settings_b"
	*/
	TrackPanel.ColorMixer = ColorMixer
	TrackPanel:AddItem( ColorMixer )

	//local TrackTypesLabel = vgui.Create("DLabel", TrackPanel)
	//TrackTypesLabel:SetText("Generation Types: ")
	//TrackPanel:AddItem( TrackTypesLabel )

	local ComboBox = vgui.Create("DComboBox", TrackPanel)

	//Create some nice choices
	if EnumNames.Tracks && #EnumNames.Tracks > 0 then
		for k, v in pairs( EnumNames.Tracks ) do
			ComboBox:AddChoice(v)
		end
		local trackConVar = GetConVar("coaster_supertool_tab_track_settings_tracktype" )

		if trackConVar && trackConVar:GetInt() > 0 then
			ComboBox:ChooseOptionID( trackConVar:GetInt() )
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
	TrackPanel:AddItem( ComboBox )

	TrackPanel:ControlHelp("Generation types change the look of clientside meshes. Select a type, shoot a node, and rebuild your clientside mesh.")


	panel:AddItem( TrackPanel )
	local AllSettingsPanel = vgui.Create("DForm", panel )
	AllSettingsPanel:SetName("Addon-Wide Settings")

	AllSettingsPanel:NumSlider("Max wheels per segment: ", "coaster_maxwheels", 0, 100, 0 )

	local TrackResolutionSlider = AllSettingsPanel:NumSlider("Track Resolution: ", "coaster_resolution", 1, 100, 0 )
	TrackResolutionSlider.OnValueChanged = function() //See the effects in realtime
		for _, v in pairs( ents.FindByClass("coaster_node") ) do
			if IsValid( v ) && !v.IsSpawning && v.IsController && v:IsController() then 
				v:UpdateClientSpline()
			end
		end
	end

	AllSettingsPanel:CheckBox("Draw track previews", "coaster_previews")
	AllSettingsPanel:CheckBox("Draw track supports", "coaster_supports")
	AllSettingsPanel:CheckBox("Draw motion blur", "coaster_motionblur")
	/*
	local MaxWheels = vgui.Create("DNumSlider", AllSettingsPanel )
	MaxWheels:SetText("Max wheels per segment: ")
	MaxWheels:SetDecimals( 0 )
	MaxWheels:SetMin( 0 )
	MaxWheels:SetMax( 100 )
	MaxWheels:SetConVar( "coaster_maxwheels")
	AllSettingsPanel:AddItem( MaxWheels )
	
	local TrackResolution = vgui.Create("DNumSlider", AllSettingsPanel )
	TrackResolution:SetText("Track Resolution: ")
	TrackResolution:SetDecimals( 0 )
	TrackResolution:SetMin( 1 )
	TrackResolution:SetMax( 100 )
	TrackResolution:SetConVar( "coaster_resolution")
	TrackResolution.OnValueChanged = function() //See the effects in realtime
		for _, v in pairs( ents.FindByClass("coaster_node") ) do
			if IsValid( v ) && !v.IsSpawning && v.IsController && v:IsController() then 
				v:UpdateClientSpline()
			end
		end
	end
	AllSettingsPanel:AddItem( TrackResolution )
	

	local TrackPreviews = vgui.Create("DCheckBoxLabel", AllSettingsPanel )
	TrackPreviews:SetText("Draw track previews")
	TrackPreviews:SetConVar("coaster_previews")
	AllSettingsPanel:AddItem( TrackPreviews )

	local TrackSupports = vgui.Create("DCheckBoxLabel", AllSettingsPanel )
	TrackSupports:SetText("Draw track supports")
	TrackSupports:SetConVar("coaster_supports")
	AllSettingsPanel:AddItem( TrackSupports )

	local MotionBlur = vgui.Create("DCheckBoxLabel", AllSettingsPanel )
	MotionBlur:SetText("Draw fancy motion blur")
	MotionBlur:SetConVar("coaster_motionblur")
	AllSettingsPanel:AddItem( MotionBlur )
	*/

	panel:AddItem( AllSettingsPanel )
	return panel
end

coastertabmanager.Register( UNIQUENAME, TAB )