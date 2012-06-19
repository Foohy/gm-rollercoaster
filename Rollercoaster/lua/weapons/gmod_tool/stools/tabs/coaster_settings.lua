local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "track_settings"

TAB.Name = "Settings"
TAB.UniqueName = UNIQUENAME
TAB.Description = "Change track-wide and addon-wide settings"
TAB.Icon = "coaster/settings"
TAB.Position = 6

TAB.ClientConVar["r"] = "255"
TAB.ClientConVar["g"] = "255"
TAB.ClientConVar["b"] = "255"

TAB.ClientConVar["tracktype"] = "1"

function TAB:LeftClick( trace, tool )
	local ply   = tool:GetOwner()

	local CartNum = self:GetClientNumber("cart_amount", tool )
	local Powered = self:GetClientNumber("powered", tool)
	local tracktype = self:GetClientNumber("tracktype", tool)
	local r = self:GetClientNumber("r", tool) or 255
	local g = self:GetClientNumber("g", tool) or 255
	local b = self:GetClientNumber("b", tool) or 255

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

	local CartNum = self:GetClientNumber("cart_amount", tool)
	local Powered = self:GetClientNumber("powered", tool)
	
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

function UpdateConColors()

end

function TAB:BuildPanel( )
	local panel = vgui.Create("DForm")
	panel:SetText("Track Settings")

	local ColorMixer = vgui.Create("DColorMixer", panel )
	ColorMixer:SetText("Track Color")
	ColorMixer:SetHeight( 150 )
	ColorMixer:SetConVarA( nil )
	ColorMixer.m_ConVarR = "coaster_supertool_tab_track_settings_r"
	ColorMixer.m_ConVarG = "coaster_supertool_tab_track_settings_g"
	ColorMixer.m_ConVarB = "coaster_supertool_tab_track_settings_b"

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
	panel:AddItem( ComboBox )

	//panel:AddControl( "Header", { Text = "#Tool_coaster_settings_name", Description = "#Tool_coaster_settings_desc" }  )

	return panel
end

/////////////////
//Util Functions
/////////////////

function TAB:GetClientNumber( convar, tool)
	return tool:GetOwner():GetInfoNum("coaster_supertool_tab_" .. self.UniqueName .. "_" .. convar, 0 )
end

function TAB:GetClientInfo(convar, tool)
	return tool:GetOwner():GetInfo("coaster_supertool_tab_" .. self.UniqueName .. "_" .. convar )
end

coastertabmanager.Register( UNIQUENAME, TAB )